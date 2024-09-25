//
//  ObjCRecordFile.m
//  Sampler
//
//  Created by James Ketcham on 6/22/15.
//  Copyright (c) 2015 James Ketcham. All rights reserved.
// from Audio Queue Services Programming Guide, Recording Audio

#import "ObjCRecordFile.h"
#include <Carbon/Carbon.h>
#include <AudioUnit/AudioUnit.h>
#include <AudioToolbox/AudioToolbox.h>
#include <sys/time.h>
#include <AudioToolbox/ExtendedAudioFile.h>

#include <stdio.h>

#pragma mark -

static const int kNumberBuffers = 3;                            // 1

struct AQRecorderState {
    
    AudioStreamBasicDescription  mDataFormat;                   // 2
    
    AudioQueueRef                mQueue;                        // 3
    
    AudioQueueBufferRef          mBuffers[kNumberBuffers];      // 4
    
    AudioFileID                  mAudioFile;                    // 5
    
    UInt32                       bufferByteSize;                // 6
    
    SInt64                       mCurrentPacket;                // 7
    
    bool                         mIsRunning;                    // 8
    
};

class RecordFile{
    
public:RecordFile();
    ~RecordFile();
    
    int startAudio(NSString *fName);//(const char *filePath);
    int stopAudio();
    
private:
    
    void DeriveBufferSize (
                           
                           AudioQueueRef                audioQueue,                  // 1
                           AudioStreamBasicDescription  &ASBDescription,             // 2
                           Float64                      seconds,                     // 3
                           UInt32                       *outBufferSize               // 4
    
    );

    AQRecorderState aqData; // 1
//    UInt32  outBufferSize;                      // 4 ????????
//    UInt32 outNumPacketsToRead;                 // 5 ????????

};



RecordFile::RecordFile(){
    
    memset(&aqData,0,sizeof(aqData));   // stopped because mIsRunning is 0
    
}
RecordFile::~RecordFile(){
    
    stopAudio();    // can't hurt
    
}
int RecordFile::stopAudio(){
    
    // Wait, on user interface thread, until user stops the recording
    if(!aqData.mIsRunning) return - 1;
    
    aqData.mIsRunning = false;
    
    AudioQueueStop (                                     // 6
                    aqData.mQueue,                                   // 7
                    true                                             // 8
                    );
    
    // Listing 2-15  Cleaning up after recording
    
    AudioQueueDispose (                                 // 1
                       
                       aqData.mQueue,                                  // 2
                       true                                            // 3
                       );
    
    
    
    AudioFileClose (aqData.mAudioFile);                 // 4
    
    return 0;
}



// Listing 2-2  The recording audio queue callback declaration
int ctr = 0;

static void HandleInputBuffer (
                               
                               void                                *aqData,             // 1
                               AudioQueueRef                       inAQ,                // 2
                               AudioQueueBufferRef                 inBuffer,            // 3
                               const AudioTimeStamp                *inStartTime,        // 4
                               UInt32                              inNumPackets,        // 5
                               const AudioStreamPacketDescription  *inPacketDesc        // 6

){
    NSLog(@"inNumPackets: %u",(unsigned int)inNumPackets);
    
    AQRecorderState *pAqData = (AQRecorderState *) aqData;               // 1
    
    if (inNumPackets == 0 &&                                             // 2
        pAqData->mDataFormat.mBytesPerPacket != 0)
        inNumPackets = inBuffer->mAudioDataByteSize / pAqData->mDataFormat.mBytesPerPacket;
    
    
    if (AudioFileWritePackets (                                          // 3
                               
                               pAqData->mAudioFile,
                               false,
                               inBuffer->mAudioDataByteSize,
                               inPacketDesc,
                               pAqData->mCurrentPacket,
                               &inNumPackets,
                               inBuffer->mAudioData
                               ) == noErr) {
        
        pAqData->mCurrentPacket += inNumPackets;                     // 4
    }
    
    if (!pAqData->mIsRunning)   // 5
        return;
    
    AudioQueueEnqueueBuffer (                                            // 6
                             pAqData->mQueue,
                             inBuffer,
                             0,
                             NULL
                             );
    
//    printf("."); ctr++; ctr %= 80; if(!ctr) printf("\n");
    
}
//int RecordFile::startAudiox(const char *filePath){
//    
//    
//    stopAudio();    // can't hurt
//    
//    // Listing 2-8  Specifying an audio queue’s audio data format
//    
//    
//    aqData.mDataFormat.mFormatID         = kAudioFormatLinearPCM; // 2
//    aqData.mDataFormat.mSampleRate       = 48000.0;               // 3
//    aqData.mDataFormat.mChannelsPerFrame = 2;                     // 4
//    aqData.mDataFormat.mBitsPerChannel   = 16;                    // 5
//    aqData.mDataFormat.mBytesPerPacket   =  4;                     // 6
//    aqData.mDataFormat.mBytesPerFrame = 4;
////    aqData.mDataFormat.mChannelsPerFrame * sizeof (SInt16);
//    aqData.mDataFormat.mFramesPerPacket  = 1;                     // 7
//    aqData.mDataFormat.mFormatFlags =                             // 9
//    kLinearPCMFormatFlagIsBigEndian
//    | kLinearPCMFormatFlagIsSignedInteger
//    | kLinearPCMFormatFlagIsPacked;
//    
//    /////////// copied from the 1Khz wav, does not fix OSStatus error ////////////
//    
////    aqData.mDataFormat.mSampleRate = 48000.0;
////    aqData.mDataFormat.mFormatID = kAudioFormatLinearPCM;
////    aqData.mDataFormat.mFormatFlags = 0xc;
////    aqData.mDataFormat.mBytesPerPacket = 4;
////    aqData.mDataFormat.mBytesPerPacket = 4;
////    aqData.mDataFormat.mBytesPerFrame = 4;
////    aqData.mDataFormat.mChannelsPerFrame = 2;
////    aqData.mDataFormat.mBitsPerChannel = 16;
//
//    ///////////////////////
//    
//    AudioFileTypeID fileType             = kAudioFileWAVEType;//kAudioFileAIFFType;    // 8
//    
//    // Listing 2-9  Creating a recording audio queue
//    
//    OSStatus status = AudioQueueNewInput (                              // 1
//                        
//                        &aqData.mDataFormat,                          // 2
//                        HandleInputBuffer,                            // 3
//                        &aqData,                                      // 4
//                        NULL,                                         // 5
//                        kCFRunLoopCommonModes,                        // 6
//                        0,                                            // 7
//                        &aqData.mQueue                                // 8
//                        );
//    
//    NSLog(@"AudioQueueNewInput: %d",(int)status);
//    // Listing 2-10  Getting the audio format from an audio queue
//    
//    UInt32 dataFormatSize = sizeof (aqData.mDataFormat);       // 1
//    
//    status = AudioQueueGetProperty (                                    // 2
//                           
//                           aqData.mQueue,                                         // 3
//                           //kAudioQueueProperty_StreamDescription,                 // 4
//                           // in Mac OS X, instead use
//                            kAudioConverterCurrentInputStreamDescription,
//                           &aqData.mDataFormat,                                   // 5
//                           &dataFormatSize                                        // 6
//                           
//                           );
//    
//    NSLog(@"AudioQueueGetProperty: %d",(int)status);
//    // Listing 2-11  Creating an audio file for recording
//    
//    CFURLRef audioFileURL =
//    
//    CFURLCreateFromFileSystemRepresentation (            // 1
//                                             
//                                             NULL,                                            // 2
//                                             (const UInt8 *) filePath,                        // 3
//                                             strlen (filePath),                               // 4
//                                             false                                            // 5
//                                             );
//    
//    
//    status = AudioFileCreateWithURL (                                 // 6
//                            
//                            audioFileURL,                                        // 7
//                            fileType,                                            // 8
//                            &aqData.mDataFormat,                                 // 9
//                            kAudioFileFlags_EraseFile,                           // 10
//                            &aqData.mAudioFile                                   // 11
//                            
//                            );
//    
//    NSLog(@"status: %d kAudioFormatUnsupportedDataFormatError: %d",(int)status, status == kAudioFormatUnsupportedDataFormatError);
//    
//    // Listing 2-12  Setting an audio queue buffer size
//    
//    DeriveBufferSize (                               // 1
//                      aqData.mQueue,                               // 2
//                      aqData.mDataFormat,                          // 3
//                      0.5,                                         // 4
//                      &aqData.bufferByteSize                       // 5
//                      );
//    
//    // Listing 2-13  Preparing a set of audio queue buffers
//    
//    for (int i = 0; i < kNumberBuffers; ++i) {           // 1
//        
//        AudioQueueAllocateBuffer (                       // 2
//                                  aqData.mQueue,                               // 3
//                                  aqData.bufferByteSize,                       // 4
//                                  &aqData.mBuffers[i]                          // 5
//                                  );
//        
//        
//        
//        AudioQueueEnqueueBuffer (                        // 6
//                                 aqData.mQueue,                               // 7
//                                 aqData.mBuffers[i],                          // 8
//                                 0,                                           // 9
//                                 NULL                                         // 10
//                                 );
//        
//    }
//    
//    // Listing 2-14  Recording audio
//    
//    aqData.mCurrentPacket = 0;                           // 1
//    
//    aqData.mIsRunning = true;                            // 2
//    
//    NSLog(@"start isRunning: %d pAqData: %lx",aqData.mIsRunning,(unsigned long)&aqData);
//    
//    AudioQueueStart (                                    // 3
//                     aqData.mQueue,                                   // 4
//                     NULL                                             // 5
//                     );
//    
//    return 0;
//    
//}

//Listing 2-6  Deriving a recording audio queue buffer size
void RecordFile:: DeriveBufferSize (
                       
                       AudioQueueRef                audioQueue,                  // 1
                       AudioStreamBasicDescription  &ASBDescription,             // 2
                       Float64                      seconds,                     // 3
                       UInt32                       *outBufferSize               // 4

) {
    
    static const int maxBufferSize = 0x50000;                 // 5
    
    
    
    int maxPacketSize = ASBDescription.mBytesPerPacket;       // 6
    
    if (maxPacketSize == 0) {                                 // 7
        
        UInt32 maxVBRPacketSize = sizeof(maxPacketSize);
        
        AudioQueueGetProperty (
                               
                               audioQueue,
                               
                               kAudioQueueProperty_MaximumOutputPacketSize,
                               
                               // in Mac OS X v10.5, instead use
                               
                               //   kAudioConverterPropertyMaximumOutputPacketSize
                               
                               &maxPacketSize,
                               
                               &maxVBRPacketSize
                               
                               );
        
    }
    
    
    
    Float64 numBytesForTime =
    
    ASBDescription.mSampleRate * maxPacketSize * seconds; // 8
    
    *outBufferSize =
    
    UInt32 (numBytesForTime < maxBufferSize ?
            
            numBytesForTime : maxBufferSize);                     // 9
    
}
int RecordFile::startAudio(NSString *fName){
    
    OSStatus status;
    
    stopAudio();    // can't hurt
    
    NSURL *url = [[NSURL alloc]initFileURLWithPath:fName];
    NSLog(@"url: %@",url);
//
//    //try to create an audio file there
//    
    aqData.mDataFormat.mSampleRate         = 48000.00;
    aqData.mDataFormat.mFormatID           = kAudioFormatLinearPCM;
    aqData.mDataFormat.mFormatFlags        = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    aqData.mDataFormat.mFramesPerPacket    = 1;
    aqData.mDataFormat.mChannelsPerFrame   = 2;
    aqData.mDataFormat.mBitsPerChannel     = 16;
    aqData.mDataFormat.mBytesPerPacket     = 4;
    aqData.mDataFormat.mBytesPerFrame      = 4;
    
//    NSLog(@"aqData.mDataFormat after setup:");
//    NSLog(@"mSampleRate: %5f3",aqData.mDataFormat.mSampleRate);
//    NSLog(@"AudioFormatID: %x",(int)aqData.mDataFormat.mFormatID);
//    NSLog(@"AudioFormatFlags: %x",(int)aqData.mDataFormat.mFormatFlags);
//    NSLog(@"mBytesPerPacket: %d",(int)aqData.mDataFormat.mBytesPerPacket);
//    NSLog(@"mBytesPerFrame: %d",(int)aqData.mDataFormat.mBytesPerFrame);
//    NSLog(@"mChannelsPerFrame: %d",(int)aqData.mDataFormat.mChannelsPerFrame);
//    NSLog(@"mBitsPerChannel: %d",(int)aqData.mDataFormat.mBitsPerChannel);
    
    // Listing 2-9  Creating a recording audio queue
    
    status = AudioFileCreateWithURL((__bridge CFURLRef)url,
                                             kAudioFileWAVEType,
                                             &aqData.mDataFormat,
                                             kAudioFileFlags_EraseFile,
                                             &aqData.mAudioFile );
    
    NSLog(@"AudioFileCreateWithURL: %d",(int)status);
    
    status = AudioQueueNewInput (                              // 1
                                          
                                          &aqData.mDataFormat,                          // 2
                                          HandleInputBuffer,                            // 3
                                          &aqData,                                      // 4
                                          NULL,                                         // 5
                                          kCFRunLoopCommonModes,                        // 6
                                          0,                                            // 7
                                          &aqData.mQueue                                // 8
                                          );
    
    NSLog(@"AudioQueueNewInput: %d",(int)status);
    // Listing 2-10  Getting the audio format from an audio queue
    
    UInt32 dataFormatSize = sizeof (aqData.mDataFormat);       // 1
    
    status = AudioQueueGetProperty (                                    // 2
                                    
                                    aqData.mQueue,                                         // 3
                                    //kAudioQueueProperty_StreamDescription,                 // 4
                                    // in Mac OS X, instead use
                                    kAudioConverterCurrentInputStreamDescription,
                                    &aqData.mDataFormat,                                   // 5
                                    &dataFormatSize                                        // 6
                                    
                                    );
    
//    NSLog(@"AudioQueueGetProperty: %d",(int)status);
//    
//    NSLog(@"aqData.mDataFormat after AudioQueueNewInput, AudioQueueGetProperty:");
//    NSLog(@"mSampleRate: %5f3",aqData.mDataFormat.mSampleRate);
//    NSLog(@"AudioFormatID: %x",(int)aqData.mDataFormat.mFormatID);
//    NSLog(@"AudioFormatFlags: %x",(int)aqData.mDataFormat.mFormatFlags);
//    NSLog(@"mBytesPerPacket: %d",(int)aqData.mDataFormat.mBytesPerPacket);
//    NSLog(@"mBytesPerFrame: %d",(int)aqData.mDataFormat.mBytesPerFrame);
//    NSLog(@"mChannelsPerFrame: %d",(int)aqData.mDataFormat.mChannelsPerFrame);
//    NSLog(@"mBitsPerChannel: %d",(int)aqData.mDataFormat.mBitsPerChannel);
    
    // AudioFormatFlags changed to 0x29, mBitsPerChannel is 32 (note that mBytesPerPacket and mBytesPerFrame are now off)
    // trying to init mDataFormat with those values causes an error in AudioQueueNewInput
    
    // Listing 2-12  Setting an audio queue buffer size
    
    DeriveBufferSize (                               // 1
                      aqData.mQueue,                               // 2
                      aqData.mDataFormat,                          // 3
                      0.5,                                         // 4
                      &aqData.bufferByteSize                       // 5
                      );
    
    // Listing 2-13  Preparing a set of audio queue buffers
    
    for (int i = 0; i < kNumberBuffers; ++i) {           // 1
        
        AudioQueueAllocateBuffer (                       // 2
                                  aqData.mQueue,                               // 3
                                  aqData.bufferByteSize,                       // 4
                                  &aqData.mBuffers[i]                          // 5
                                  );
        
        
        
        AudioQueueEnqueueBuffer (                        // 6
                                 aqData.mQueue,                               // 7
                                 aqData.mBuffers[i],                          // 8
                                 0,                                           // 9
                                 NULL                                         // 10
                                 );
        
    }
    
    // Listing 2-14  Recording audio
    
    aqData.mCurrentPacket = 0;                           // 1
    
    aqData.mIsRunning = true;                            // 2
    
    NSLog(@"start isRunning: %d pAqData: %lx",aqData.mIsRunning,(unsigned long)&aqData);
    
    AudioQueueStart (                                    // 3
                     aqData.mQueue,                                   // 4
                     NULL                                             // 5
                     );
    
    return 0;
    
}

@interface ObjCRecordFile (){
    
    RecordFile *wrapped;
}

@end
@implementation ObjCRecordFile

-(id)init{
    
    self = [super init];
    
    if(self){
        
        wrapped = new RecordFile();
    }
    return self;
}

-(void)cleanup{
    
    if(wrapped){
        
        free(wrapped);
        wrapped = nil;
    }
}
-(void)start:(NSString*)fName{
    
    if(wrapped){
        
//        const char *str = [fName cStringUsingEncoding:NSASCIIStringEncoding];
        wrapped->startAudio(fName);//(str);

        
    }
    
}
-(void)stop{
    
    if(wrapped){
        
        wrapped->stopAudio();
    }
    
}

@end
