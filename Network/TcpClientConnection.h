//
//  TcpClientConnection.h
//  ADAA_server
//
//  Created by James Ketcham on 6/5/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

//#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
//#import "Chunk.h" // 2.00.00 no more chunks

enum{DID_NOT_RESOLVE,
    WILL_RESOLVE,
    DID_RESOLVE};

@class TcpClientConnection;

@protocol TcpClientConnectionDelegate

-(void)processMsgArray:(NSMutableArray *)msgArray :(TcpClientConnection *)connection;
-(void)processString:(NSString*)msg :(TcpClientConnection *)connection;

- (void)connectionDidResolveAddress:(TcpClientConnection *)sender;

- (void)connectionWillResolveAddress:(TcpClientConnection *)sender;

@end

@interface TcpClientConnection : NSObject<NSStreamDelegate,NSNetServiceDelegate>{
    
    NSLock *ioLock;
    NSMutableArray *array;


}

@property (nonatomic, strong, readwrite) NSNetService *netService;
@property (nonatomic, strong, readwrite) NSInputStream *inputStream;
@property (nonatomic, strong, readwrite) NSOutputStream *outputStream;
@property (nonatomic, strong, readwrite) NSMutableData *inputBuffer;
@property (nonatomic, strong, readwrite) NSMutableData *outputBuffer;

@property NSString *ipAddr;
@property NSInteger state;
@property NSString *version;

@property id delegate;

// return all characters, addition 4/1/2018 (yes, April Fool's Day)
@property bool returnAllCharacters;

// access

-(void)txData:( NSData *)data;
- (void)txMsg:(NSString *)msg;
//-(NSInteger)txChunk:(Chunk *)chunk;
- (void)closeStreams;
- (void)openStreamsToNetService;


@end
