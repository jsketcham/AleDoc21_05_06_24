//
//  TcpClientConnection.m
//  ADAA_server
//
//  Created by James Ketcham on 6/5/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//  we would like to have streams for every netService item

#import "TcpClientConnection.h"
#include <arpa/inet.h>
#import <sys/socket.h>

// use strings in the ADR application
#define USE_CHUNKS 0

#pragma mark -
#pragma mark NSNetService

@interface NSNetService (QNetworkAdditions)

- (BOOL)qNetworkAdditions_getInputStream:(out NSInputStream **)inputStreamPtr
                            outputStream:(out NSOutputStream **)outputStreamPtr;

@end

@implementation NSNetService (QNetworkAdditions)

- (BOOL)qNetworkAdditions_getInputStream:(out NSInputStream **)inputStreamPtr
                            outputStream:(out NSOutputStream **)outputStreamPtr
// The following works around three problems with
// -[NSNetService getInputStream:outputStream:]:
//
// o <rdar://problem/6868813> -- Currently the returns the streams with
//   +1 retain count, which is counter to Cocoa conventions and results in
//   leaks when you use it in ARC code.
//
// o <rdar://problem/9821932> -- If you create two pairs of streams from
//   one NSNetService and then attempt to open all the streams simultaneously,
//   some of the streams might fail to open.
//
// o <rdar://problem/9856751> -- If you create streams using
//   -[NSNetService getInputStream:outputStream:], start to open them, and
//   then release the last reference to the original NSNetService, the
//   streams never finish opening.  This problem is exacerbated under ARC
//   because ARC is better about keeping things out of the autorelease pool.
{
    BOOL                result;
    CFReadStreamRef     readStream;
    CFWriteStreamRef    writeStream;
    
    result = NO;
    
    readStream = NULL;
    writeStream = NULL;
    
    if ( (inputStreamPtr != NULL) || (outputStreamPtr != NULL) ) {
        CFNetServiceRef     netService;
        
        netService = CFNetServiceCreate(
                                        NULL,
                                        (__bridge CFStringRef) [self domain],
                                        (__bridge CFStringRef) [self type],
                                        (__bridge CFStringRef) [self name],
                                        0
                                        );
        if (netService != NULL) {
            CFStreamCreatePairWithSocketToNetService(
                                                     NULL,
                                                     netService,
                                                     ((inputStreamPtr  != nil) ? &readStream  : NULL),
                                                     ((outputStreamPtr != nil) ? &writeStream : NULL)
                                                     );
            CFRelease(netService);
        }
        
        // We have failed if the client requested an input stream and didn't
        // get one, or requested an output stream and didn't get one.  We also
        // fail if the client requested neither the input nor the output
        // stream, but we don't get here in that case.
        
        result = ! ((( inputStreamPtr != NULL) && ( readStream == NULL)) ||
                    ((outputStreamPtr != NULL) && (writeStream == NULL)));
    }
    if (inputStreamPtr != NULL) {
        *inputStreamPtr  = CFBridgingRelease(readStream);
    }
    if (outputStreamPtr != NULL) {
        *outputStreamPtr = CFBridgingRelease(writeStream);
    }
    
    return result;
}

@end

@implementation TcpClientConnection

@synthesize inputBuffer = _inputBuffer;
@synthesize inputStream = _inputStream;
@synthesize outputBuffer = _outputBuffer;
@synthesize outputStream = _outputStream;
@synthesize netService = _netService;
@synthesize delegate = _delegate;

-(id)init{
    
    self = [super init];
    
    if(self){
        
        ioLock = [[NSLock alloc]init];
        _delegate = nil;
        _ipAddr = @"---.---.---.---";
        _version = @"";
        _returnAllCharacters = false;   // assume VM15 behavior
        
    }
    
    return self;
}

#pragma mark -
#pragma mark -------- setters/getters

-(void)setNetService:(NSNetService *)netService{
    
    _netService = netService;
    [_netService setDelegate:self]; // for callbacks to NSNetServiceDelegate methods
    [self openStreamsToNetService];
}
-(NSNetService*)netService{
    return _netService;
}
#pragma mark -
#pragma mark Stream methods

- (void)openStreamsToNetService {
    NSInputStream * istream;
    NSOutputStream * ostream;
    
    //NSLog(@"openStreamsToNetService %@",_netService.name);
    [self closeStreams];
    
    if(_netService == nil) return;
    
//    _responseCtr = 0;   // reset the downctr that detects 'no connection'
    
    if ([_netService qNetworkAdditions_getInputStream:&istream outputStream:&ostream]) {
        
//        _isConnected = false;   // no inputBuffer, outputBuffer
        self.inputStream = istream;
        self.outputStream = ostream;
        [self.inputStream  setDelegate:self];
        [self.outputStream setDelegate:self];
        [self.inputStream  scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.inputStream  open];
        [self.outputStream open];
        
        [_netService resolveWithTimeout:10];
    }
}

- (void)closeStreams {
    
    //NSLog(@"closeStreams %@", _netService.name);
    
    if(_netService)[_netService stop]; // stop any resolving in process
    [self setState:DID_NOT_RESOLVE];
    [self setIpAddr:@"---.---.---.---"];
    [self setVersion:@""];                  // trigger bindings to show we are not connected
    
    if(self.inputStream){
        
        [self.inputStream  setDelegate:nil];
        [self.inputStream  close];
        [self.inputStream  removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.inputStream  = nil;
        self.inputBuffer  = nil;
    }
    
    if(self.outputStream){
        
        [self.outputStream setDelegate:nil];
        [self.outputStream close];
        [self.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        self.outputStream = nil;
        self.outputBuffer = nil;
    }
 }

- (void)startOutput
{
    assert([self.outputBuffer length] != 0); // TODO NSLock for outputBuffer?
    
    NSInteger actuallyWritten = [self.outputStream write:[self.outputBuffer bytes] maxLength:[self.outputBuffer length]];
    if (actuallyWritten > 0) {
        [self.outputBuffer replaceBytesInRange:NSMakeRange(0, (NSUInteger) actuallyWritten) withBytes:NULL length:0];
        // If we didn't write all the bytes we'll continue writing them in response to the next
        // has-space-available event.
    } else {
        // A non-positive result from -write:maxLength: indicates a failure of some form; in this
        // simple app we respond by simply closing down our connection.
        [self closeStreams];
    }
}
//-(NSInteger)txChunk:(Chunk *)chunk{
//    
//    NSData *data = [chunk chunkToData];
//    NSInteger bytesWritten = data.length;
//    
//    [self txData:data];
//    //    //NSLog(@"txChunk outputBuffer.length: %d",(int)self.outputBuffer.length);
//    return bytesWritten;
//    
//}

- (void)txMsg:(NSString *)msg
{
    // VM15, VM15-MADI use \n as a terminator, make sure there is one at the end of the string

    msg = [msg stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];   // string with no \n
    msg = [msg stringByAppendingString:@"\n"];
        
    [self txData:[msg dataUsingEncoding:NSUTF8StringEncoding]];
    
}


-(void)txData:( NSData *)data{
    
    if(data.length == 0) return;// nothing to send
    
    [ioLock lock];
    if (self.outputBuffer != nil) {
        BOOL wasEmpty = ([self.outputBuffer length] == 0);
        [self.outputBuffer appendData:data];
        if (wasEmpty) {
            [self startOutput];
        }
    }
    [ioLock unlock];
}

-(void)processMsgArray:(NSMutableArray *)msgArray{
    
    if(_delegate){
        
        [_delegate processMsgArray:msgArray :self]; // we pass 'self' so that messages can be sent to this connection
    }
    
}
-(void)processString:(NSString*)msg{
    
    if(_delegate && [_delegate respondsToSelector:@selector(processString::)]){
        
        [_delegate performSelector:@selector(processString::) withObject:msg withObject:self];
    }
}
-(void)processInput{
    
//    if(_responseCtr < 0) _responseCtr = 1;
//    else _responseCtr++;  // did rx something
    
    @autoreleasepool {
        
        NSString *rxString = [[NSString alloc] initWithBytes:self.inputBuffer.bytes length:self.inputBuffer.length encoding:NSUTF8StringEncoding];
//        NSLog(@"%@ %ld",rxString,self.inputBuffer.length);
        
        if(rxString == nil || rxString.length == 0){
            
            if(self.inputBuffer.length){
                NSLog(@"MIDI in rx string!");   // vm15a handles UDP from interrupt, 4.03.32 and earlier MIDI UDP could end up in tcp/ip 'strings'
            }
            
            [self.inputBuffer setLength:0]; // assume no remainder
            return; // nothing to process
        }
        
        [self.inputBuffer setLength:0]; // assume no remainder
        
        if(_returnAllCharacters){   // we are just a serial port, no message splitting
            
            [self performSelectorOnMainThread:@selector(processString:) withObject:rxString waitUntilDone:false];
            
            return;
        }
        
        // VM15 splits messages here
        
        NSMutableArray *msgArray = [[NSMutableArray alloc] initWithArray:[rxString componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]];
        
        if(![rxString hasSuffix:@"\n"]){    // does not end in \n, keep remainder
            
            [self.inputBuffer appendData:[msgArray.lastObject dataUsingEncoding:NSUTF8StringEncoding]]; // keep the remainder
            [msgArray removeLastObject];    // remove remainder from list
            
        }
        
        if(msgArray && msgArray.count){    // process an array of strings that ended in \n
            
            // process rx messages on the main thread so that we can do GUI stuff
            [self performSelectorOnMainThread:@selector(processMsgArray:) withObject:msgArray waitUntilDone:false];
             
        }
        
    }
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)streamEvent {
    assert(aStream == self.inputStream || aStream == self.outputStream);
    switch(streamEvent) {
        case NSStreamEventOpenCompleted: {
            
            // We don't create the input and output buffers until we get the open-completed events.
            // This is important for the output buffer because -outputText: is a no-op until the
            // buffer is in place, which avoids us trying to write to a stream that's still in the
            // process of opening.
                        
            if (aStream == self.inputStream) {
                self.inputBuffer = [[NSMutableData alloc] init];
                //NSLog(@"NSStreamEventOpenCompleted: inputStream %@",_netService.name);
            } else {
                self.outputBuffer = [[NSMutableData alloc] init];
                //NSLog(@"NSStreamEventOpenCompleted: outputStream %@",_netService.name);
            }
            
        } break;
        case NSStreamEventHasSpaceAvailable: {
            [ioLock lock];
            if ([self.outputBuffer length] != 0) {
                [self startOutput];
            }
            [ioLock unlock];
        } break;
        case NSStreamEventHasBytesAvailable: {
            uint8_t buffer[0x10000];
            NSInteger actuallyRead = [self.inputStream read:buffer maxLength:sizeof(buffer)];
            if (actuallyRead > 0) {
                
                [ioLock lock];
                [self.inputBuffer appendBytes:buffer length:(NSUInteger)actuallyRead];
                [self processInput];
                [ioLock unlock];
                
                
            } else {
                // A non-positive value from -read:maxLength: indicates either end of file (0) or
                // an error (-1).  In either case we just wait for the corresponding stream event
                // to come through.
            }
        } break;
        case NSStreamEventErrorOccurred:
            [self closeStreams];
            break;
        case NSStreamEventEndEncountered:
            [self closeStreams];
         break;
        default:
            break;
    }
}
#pragma mark --
#pragma mark --------------------------------- helper methods ----------------------------------------

-(NSString*)ipAddrStringFromAddresses:(NSNetService*)service{
    
    // http://stackoverflow.com/questions/938521/iphone-bonjour-nsnetservice-ip-address-and-port
    
    char addressBuffer[INET6_ADDRSTRLEN];
    
    for (NSData *data in service.addresses)
    {
        memset(addressBuffer, 0, INET6_ADDRSTRLEN);
        
        typedef union {
            struct sockaddr sa;
            struct sockaddr_in ipv4;
            struct sockaddr_in6 ipv6;
        } ip_socket_address;
        
        ip_socket_address *socketAddress = (ip_socket_address *)[data bytes];
        
        if (socketAddress && (socketAddress->sa.sa_family == AF_INET || socketAddress->sa.sa_family == AF_INET6))
        {
            const char *addressStr = inet_ntop(
                                               socketAddress->sa.sa_family,
                                               (socketAddress->sa.sa_family == AF_INET ? (void *)&(socketAddress->ipv4.sin_addr) : (void *)&(socketAddress->ipv6.sin6_addr)),
                                               addressBuffer,
                                               sizeof(addressBuffer));
            
            int port = ntohs(socketAddress->sa.sa_family == AF_INET ? socketAddress->ipv4.sin_port : socketAddress->ipv6.sin6_port);
            
            if (addressStr && port)
            {
                //NSLog(@"Found service at %s:%d", addressStr, port);
                
                return [NSString stringWithUTF8String:addressStr];  // return the first address found
            }
        }
    }
    
    return @"---";
    
}

#pragma mark --
#pragma mark -------------------------- NSNetServiceDelegate methods ---------------------------------
- (void)netServiceWillResolve:(NSNetService *)sender{
    
    [self setState:WILL_RESOLVE];
    NSLog(@"netServiceWillResolve %@",sender.name);
    
    if (_delegate && [_delegate respondsToSelector:@selector(connectionWillResolveAddress:)] ) {
        
        [_delegate performSelectorOnMainThread:@selector(connectionWillResolveAddress:) withObject:self waitUntilDone:false];
        
    }
    
}
- (void)netServiceDidResolveAddress:(NSNetService *)sender{
    
    NSLog(@"netServiceDidResolveAddress %@",sender.name);
    
 // 04/29/20 the streams open a little later, check for self.outputBuffer == nil
    // to not send
//    if(self.outputBuffer == nil || self.inputBuffer == nil){
//
//        [self setState:DID_NOT_RESOLVE];
//        [self closeStreams];
//        return; // never got NSStreamEventOpenCompleted for input and output, the 'resolved' address is not on the network
//
//    }
    
    [self setState:DID_RESOLVE];
    
    [self setIpAddr:[self ipAddrStringFromAddresses:sender]];   // this does trigger bindings
    
    if (_delegate && [_delegate respondsToSelector:@selector(connectionDidResolveAddress:)] ) {
        
        [_delegate performSelectorOnMainThread:@selector(connectionDidResolveAddress:) withObject:self waitUntilDone:false];
        
    }
}
- (void)netService:(NSNetService *)sender
     didNotResolve:(NSDictionary *)errorDict{
    
    NSLog(@"didNotResolve %@",sender.name);
    
    [self setState:DID_NOT_RESOLVE];
    [self closeStreams];
   
}
@end
