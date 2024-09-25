//
//  PlayFile.mm
//  AleDoc
//
//  Created by James Ketcham on 9/17/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//
#include "ObjCPlayFile.h"
#include <Carbon/Carbon.h>
#include <AudioUnit/AudioUnit.h>
#include <AudioToolbox/AudioToolbox.h>
#include <sys/time.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#include <stdio.h>
#pragma mark -
#pragma mark -------------- the cpp section ------------------------
static const int kNumberBuffers = 3;                              // 1

struct AQPlayerState {
    
    AudioStreamBasicDescription   mDataFormat;                    // 2
    
    AudioQueueRef                 mQueue;                         // 3
    
    AudioQueueBufferRef           mBuffers[kNumberBuffers];       // 4
    
    AudioFileID                   mAudioFile;                     // 5    // contained in mExtAudioFileRef
    
    UInt32                        bufferByteSize;                 // 6
    
    SInt64                        mCurrentPacket;                 // 7
    
    UInt32                        mNumPacketsToRead;              // 8
    
    AudioStreamPacketDescription  *mPacketDescs;                  // 9, NULL for Constant Bit Rate (CBR)
    
    bool                          mIsRunning;                     // 10
    
    UInt64                        mNumberPackets;   // samples in file, used to determine crossfade point
    
    void                          *crossfadeBuffer;
    
    UInt32                        mDataByteSize;
};

class PlayFile{
    
public: PlayFile();
    ~PlayFile();
    
    int startAudio(const char *filePath);
    int stopAudio();
    
private:
    
    void DeriveBufferSize (
                                     AudioStreamBasicDescription &ASBDesc,                            // 1
                                     UInt32                      maxPacketSize,                       // 2
                                     Float64                     seconds,
                                     UInt32                      *outBufferSize,                      // 4
                                     UInt32                      *outNumPacketsToRead                 // 5
    );
    
    AQPlayerState aqData;                                   // 1
//    UInt32  outBufferSize;                      // 4
//    UInt32 outNumPacketsToRead;                 // 5
    
};

PlayFile::PlayFile(){
    
    memset(&aqData,0,sizeof(aqData));   // stopped because mIsRunning is 0
    
}
PlayFile::~PlayFile(){
    
    stopAudio();
    
}

#pragma mark -
#pragma mark ----------------- audio callback function ------------------------
// helper functions

typedef union _IC{
    
    SInt32 i;
    unsigned char c[4];
    
}*pIC,IC;

static SInt32 getSampleInt(AQPlayerState *pAqData,unsigned char *buffer){
    
    IC ic;
    
    ic.i = 0;   // init value
//    SInt32  bigEndian32;
//    SInt32  swapped32;
//    
//    // Swap a 16 bit value read from network.
//    swapped32 = CFSwapInt32BigToHost(bigEndian32);
    
    if(pAqData->mDataFormat.mFormatFlags & kAudioFormatFlagIsBigEndian){
        
        if(buffer[0] & 0x80) ic.i = -1;
        
        switch (pAqData->mDataFormat.mBitsPerChannel) {
                
            case 32:
                ic.c[3] = buffer[0];
                ic.c[2] = buffer[1];
                ic.c[1] = buffer[2];
                ic.c[0] = buffer[3];
                break;
            case 24:
                ic.c[2] = buffer[0];
                ic.c[1] = buffer[1];
                ic.c[0] = buffer[2];
                break;
            default:
                ic.c[1] = buffer[0];
                ic.c[0] = buffer[1];
                break;
            case 8:
                ic.c[0] = buffer[0];
                break;
        }
        
    }else{
        
        switch (pAqData->mDataFormat.mBitsPerChannel) {
                
            case 32:
                ic.c[3] = buffer[3];
                ic.c[2] = buffer[2];
                ic.c[1] = buffer[1];
                ic.c[0] = buffer[0];
                break;
            case 24:
                if(buffer[2] & 0x80) ic.i = -1;
                ic.c[2] = buffer[2];
                ic.c[1] = buffer[1];
                ic.c[0] = buffer[0];
                break;
            default:
                if(buffer[1] & 0x80) ic.i = -1;
                ic.c[1] = buffer[1];
                ic.c[0] = buffer[0];
                break;
                
            case 8:
                if(buffer[0] & 0x80) ic.i = -1;
                ic.c[0] = buffer[0];
                break;
        }
    }
    
    return ic.i;
}
static void putSampleInt(AQPlayerState *pAqData,unsigned char *buffer, SInt32 value){
    
    IC ic;
    
    ic.i = value;
    
    if(pAqData->mDataFormat.mFormatFlags & kAudioFormatFlagIsBigEndian){
        
        switch (pAqData->mDataFormat.mBitsPerChannel) {
                
            case 32:
                buffer[0] = ic.c[3];
                buffer[1] = ic.c[2];
                buffer[2] = ic.c[1];
                buffer[3] = ic.c[0];
               break;
            case 24:
                buffer[0] = ic.c[2];
                buffer[1] = ic.c[1];
                buffer[2] = ic.c[0];
                break;
            default:
                buffer[0] = ic.c[1];
                buffer[1] = ic.c[0];
                break;
            case 8:
                buffer[0] = ic.c[0];
                break;
                
        }
    }else{
        
        switch (pAqData->mDataFormat.mBitsPerChannel) {
                
            case 32:
                buffer[3] = ic.c[3];
                buffer[2] = ic.c[2];
                buffer[1] = ic.c[1];
                buffer[0] = ic.c[0];
                break;
            case 24:
                buffer[2] = ic.c[2];
                buffer[1] = ic.c[1];
                buffer[0] = ic.c[0];
                break;
            default:
                buffer[1] = ic.c[1];
                buffer[0] = ic.c[0];
                break;
            case 8:
                buffer[0] = ic.c[0];
                break;
                
        }
    }
    
}
static void HandleOutputBuffer (
                                void                *aqData,
                                AudioQueueRef       inAQ,
                                AudioQueueBufferRef inBuffer
                                ) {
    AQPlayerState *pAqData = (AQPlayerState *) aqData;        // 1
    
    if (pAqData->mIsRunning == 0) return;                     // 2
    
    UInt32 numBytesReadFromFile;                              // 3
    UInt32 numPackets = pAqData->mNumPacketsToRead;           // 4
    
    OSStatus status = AudioFileReadPackets (
                          pAqData->mAudioFile,
                          false,
                          &numBytesReadFromFile,
                          pAqData->mPacketDescs,
                          pAqData->mCurrentPacket,
                          &numPackets,
                          inBuffer->mAudioData
                          );
    
    pAqData->mCurrentPacket += numPackets;                // 7
    
    UInt64 packetsRemaining = pAqData->mNumberPackets - pAqData->mCurrentPacket;
    
    // crossfade to start of file when there is not a buffer's worth of data remaining
    
    if(packetsRemaining < pAqData->mNumPacketsToRead) pAqData->mCurrentPacket = 0;  // loop all formats
    
    // crossfade PCM, assume compressed audio will crossfade on block edits (like DTS theatrical did)
    
    if(packetsRemaining < pAqData->mNumPacketsToRead && pAqData->mDataFormat.mFormatID == 'lpcm'){  // we can't crossfade compressed audio
        
        status = AudioFileReadPackets (
                              pAqData->mAudioFile,
                              false,
                              &numBytesReadFromFile,
                              pAqData->mPacketDescs,
                              pAqData->mCurrentPacket,
                              &numPackets,
                              pAqData->crossfadeBuffer
                              );
        
        pAqData->mCurrentPacket += numPackets;
        
        // crossfade first and last buffers
        // we need to know the bytes per sample, little/big endian
        
        double d = 1.0 / (double)pAqData->mNumPacketsToRead;    // the amount to change the gain every sample, linear crossfade
        double dAccum = 0;
        
        unsigned char *src = (unsigned char *)pAqData->crossfadeBuffer;
        unsigned char  *dest = (unsigned char *)inBuffer->mAudioData;
        
        for(int i = 0; i < pAqData->mNumPacketsToRead; i++){    // samples
            
            for (int j = 0; j < pAqData->mDataFormat.mChannelsPerFrame; j++) {  // channels per sample
                
                SInt32 sample = getSampleInt(pAqData, src);
                SInt32 sampleDest = getSampleInt(pAqData,dest);
                
                // sum the samples
                double dSample = dAccum * (double)sample;
                double dDest = (1.0 - dAccum) * (double)sampleDest;
                dDest += dSample;
                
                // put sum to dest
                putSampleInt(pAqData, dest, (SInt32)dDest);
                
                // incr ptrs by number of bytes per channel
                switch (pAqData->mDataFormat.mBitsPerChannel) {
                    case 32:
                        src += 4;
                        dest += 4;
                        break;
                    case 24:
                        src += 3;
                        dest += 3;
                        break;
                    default:
                        src += 2;
                        dest += 2;
                        break;
                        
                    case 8:
                        src++;
                        dest++;
                        break;
                }
                
            }
            
            dAccum += d;    // accumulate the crossfade
            
        }
        
//        printf("rewind\n");
        
    }
    
    if (numPackets > 0) {                                     // 5
        
        inBuffer->mAudioDataByteSize = numBytesReadFromFile;  // 6
        
        status = AudioQueueEnqueueBuffer (
                                 pAqData->mQueue,
                                 inBuffer,
                                 (pAqData->mPacketDescs ? numPackets : 0),
                                 pAqData->mPacketDescs
                                 );
    }
//    else {
//        AudioQueueStop (
//                        pAqData->mQueue,
//                        false
//                        );
//        pAqData->mIsRunning = false; 
//    }
}

void PlayFile::DeriveBufferSize (
                       AudioStreamBasicDescription &ASBDesc,                            // 1
                       UInt32                      maxPacketSize,                       // 2
                       Float64                     seconds,
                       UInt32                      *outBufferSize,                      // 4
                       UInt32                      *outNumPacketsToRead                 // 5


)
{
    
    static const int maxBufferSize = 0x50000;                        // 6
    static const int minBufferSize = 0x4000;                         // 7
    
    if (ASBDesc.mFramesPerPacket != 0) {                             // 8
        
        Float64 numPacketsForTime =
        
        ASBDesc.mSampleRate / ASBDesc.mFramesPerPacket * seconds;
        
        *outBufferSize = numPacketsForTime * maxPacketSize;
        
    } else {                                                         // 9
        
        *outBufferSize =
        
        maxBufferSize > maxPacketSize ?
        
        maxBufferSize : maxPacketSize;
        
    }
    
    
    
    if (                                                             // 10
        
        *outBufferSize > maxBufferSize &&
        
        *outBufferSize > maxPacketSize
        
        )
        
        *outBufferSize = maxBufferSize;
    
    else {                                                           // 11
        
        if (*outBufferSize < minBufferSize)
            
            *outBufferSize = minBufferSize;
        
    }
    
    
    
    *outNumPacketsToRead = *outBufferSize / maxPacketSize;           // 12
    
}
int PlayFile::startAudio(const char *filePath){
    
    if(filePath && strlen(filePath)){
        
        stopAudio();    // can't hurt

        // try to open the file
        // from https://developer.apple.com/library/mac/documentation/MusicAudio/Conceptual/AudioQueueProgrammingGuide/AQPlayback/PlayingAudio.html#//apple_ref/doc/uid/TP40005343-CH3-SW1
        CFURLRef audioFileURL = CFURLCreateFromFileSystemRepresentation (           // 1
                                                  NULL,                                           // 2
                                                 (const UInt8 *) filePath,                       // 3
                                                 strlen (filePath),                              // 4
                                                 false                                           // 5
                                                 );
        
        AudioFilePermissions fsRdPerm = kAudioFileReadPermission;
        
        OSStatus result = AudioFileOpenURL (                                  // 2
                          audioFileURL,                                   // 3
                          fsRdPerm,                                       // 4
                          0,                                              // 5
                          &aqData.mAudioFile                              // 6
                          );
        
        CFRelease (audioFileURL);                               // 7
        
        if(result) return -1;   // file did not open
        
        UInt32 dataFormatSize = sizeof (aqData.mDataFormat);
        
        AudioFileGetProperty (                                  // 2
                              aqData.mAudioFile,                                  // 3
                              kAudioFilePropertyDataFormat,                       // 4
                              &dataFormatSize,                                    // 5
                              &aqData.mDataFormat                                 // 6
                              );
        
        // list contents of mDataFormat
        /*
         struct AudioStreamBasicDescription
         {
         Float64             mSampleRate;
         AudioFormatID       mFormatID;
         AudioFormatFlags    mFormatFlags;
         UInt32              mBytesPerPacket;
         UInt32              mFramesPerPacket;
         UInt32              mBytesPerFrame;
         UInt32              mChannelsPerFrame;
         UInt32              mBitsPerChannel;
         UInt32              mReserved;
         };
         typedef struct AudioStreamBasicDescription  AudioStreamBasicDescription;
         
         */
        // looking at the format to copy it in the recorder, having a kAudioFormatUnsupportedDataFormatError
        
//        NSLog(@"mSampleRate: %5f3",aqData.mDataFormat.mSampleRate);
//        NSLog(@"AudioFormatID: %x",(int)aqData.mDataFormat.mFormatID);
//        NSLog(@"AudioFormatFlags: %x",(int)aqData.mDataFormat.mFormatFlags);
//        NSLog(@"mBytesPerPacket: %d",(int)aqData.mDataFormat.mBytesPerPacket);
//        NSLog(@"mBytesPerFrame: %d",(int)aqData.mDataFormat.mBytesPerFrame);
//        NSLog(@"mChannelsPerFrame: %d",(int)aqData.mDataFormat.mChannelsPerFrame);
//        NSLog(@"mBitsPerChannel: %d",(int)aqData.mDataFormat.mBitsPerChannel);
        
        // we expect uncompressed audio
        
//        if(aqData.mDataFormat.mFramesPerPacket != 1) return -1;
        
        //kAudioFilePropertyAudioDataPacketCount
        
        dataFormatSize = sizeof(aqData.mNumberPackets);
        
        AudioFileGetProperty (
                              aqData.mAudioFile,
                              kAudioFilePropertyAudioDataPacketCount,
                              &dataFormatSize,
                              &aqData.mNumberPackets
                              );
        
        // temp 1 second loop
//        aqData.mNumberPackets = 48000;
        
        // get number of bytes in sample
        
        dataFormatSize = sizeof (aqData.mDataByteSize);
        
        AudioFileGetProperty (
                              aqData.mAudioFile,
                              kAudioFilePropertyPacketSizeUpperBound,
                              &dataFormatSize,
                              &aqData.mDataByteSize
                              );
        
        if(aqData.mDataByteSize == 0) return -1;   // failure, should be number of bytes in sample
        
        // Create a Playback Audio Queue
        
        AudioQueueNewOutput (                                // 1
                             &aqData.mDataFormat,                             // 2
                             HandleOutputBuffer,                              // 3
                             &aqData,                                         // 4
                             CFRunLoopGetCurrent (),                          // 5
                             kCFRunLoopCommonModes,                           // 6
                             0,                                               // 7
                             &aqData.mQueue                                   // 8
                             );
        
        
        // determine buffer size
        DeriveBufferSize (
                          aqData.mDataFormat,                            // 1
                          aqData.mDataByteSize,                       // 2
                          0.1,//                     seconds
                          &aqData.bufferByteSize,                          // 10
                          &aqData.mNumPacketsToRead                        // 11
                          
                          );
        
        aqData.crossfadeBuffer = malloc(aqData.bufferByteSize);
        
        // check for variable bit rate, alloc memory for packet descriptions
        
        bool isFormatVBR = (                                       // 1
                            
                            aqData.mDataFormat.mBytesPerPacket == 0 ||
                            
                            aqData.mDataFormat.mFramesPerPacket == 0
                            
                            );
        
        
        
        if (isFormatVBR) {                                         // 2
            
            if(aqData.mPacketDescs) free(aqData.mPacketDescs);  // free previous if any
            
            aqData.mPacketDescs =
            
            (AudioStreamPacketDescription*) malloc (
                                                    
                                                    aqData.mNumPacketsToRead * sizeof (AudioStreamPacketDescription)
                                                    
                                                    );
            
        } else {                                                   // 3
            
            aqData.mPacketDescs = NULL;
            
        }
//        NSLog(@"outBufferSize: %d outNumPacketsToRead: %d",(int)outBufferSize,(int)outNumPacketsToRead);
        
        // set the gain
        
        Float32 gain = 1.0;                                       // 1
        
        // Optionally, allow user to override gain setting here
        
        AudioQueueSetParameter (                                  // 2
                                aqData.mQueue,                                        // 3
                                kAudioQueueParam_Volume,                              // 4
                                gain                                                  // 5
                                );
        
        
        // start playback
        
        aqData.mIsRunning = true;   // has to be set for the callback to work
        // 1
        // allocate and prime audio buffers
        
        aqData.mCurrentPacket = 0;                                // 1
        
        for (int i = 0; i < kNumberBuffers; ++i) {                // 2
            
            AudioQueueAllocateBuffer (                            // 3
                                      aqData.mQueue,                                    // 4
                                      aqData.bufferByteSize,                            // 5
                                      &aqData.mBuffers[i]                               // 6
                                      );
            
            
            
            HandleOutputBuffer (                                  // 7
                                &aqData,                                          // 8
                                aqData.mQueue,                                    // 9
                                aqData.mBuffers[i]                                // 10
                                );
        }
        
        result = AudioQueueStart (                                  // 2
                         aqData.mQueue,                                 // 3
                         NULL                                           // 4
                         );
        
//        NSLog(@"AudioQueueStart status: %d",(int)result);
        
    }
    
    
    return 0;
    
}
int PlayFile::stopAudio(){
    
    
    if(aqData.mIsRunning){
        
        aqData.mIsRunning = false;
        
        AudioQueueFlush(aqData.mQueue);
        
        AudioQueueStop (
                        aqData.mQueue,
                        true    // immediate
                        );
        
        if(aqData.crossfadeBuffer){
            
           free(aqData.crossfadeBuffer);
            aqData.crossfadeBuffer = nil;
        }
        
        // free buffers from last time
        for(int i = 0; i < kNumberBuffers; i++ ) {
            
            if(aqData.mQueue && aqData.mBuffers[i]) AudioQueueFreeBuffer (
                                                    aqData.mQueue,
                                                    aqData.mBuffers[i]
                                                    );
            aqData.mBuffers[i] = nil;
            
        }
        return 0;  // stopped
    }
    
    // already stopped
    
    return -1;
}
#pragma mark -
#pragma mark -------------- the objective C section ------------------------

@interface ObjCPlayFile(){
    
    PlayFile *wrapped;
    
}
@end

@implementation ObjCPlayFile

-(id)init{
    self = [super init];
    
    if(self) {
        
        wrapped = new PlayFile();
        
    }
    
    return  self;
}

-(int) stopAudio{
    
    return wrapped->stopAudio();
    
    
}
-(int) startAudio: (NSString*)fName{
    
    const char *str = [fName cStringUsingEncoding:NSASCIIStringEncoding];
    
    return wrapped->startAudio(str);
}

@end
