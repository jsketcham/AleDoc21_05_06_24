//
//  BoomRecorderClient.h
//  AleDoc
//
//  Created by James Ketcham on 6/25/15.
//  Copyright (c) 2015 James Ketcham. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TcpClientBrowser.h"
#import "TcpClientConnection.h"

@interface BoomRecorderClient : NSObject<TcpClientConnectionDelegate>

-(void)txMsg:(NSString*)msg;
@property NSInteger isOnline;
@property TcpClientConnection *connection;
@property TcpClientBrowser *tcpClient;

-(void)setDefaultServer:(NSString*)server;

-(void)startBoomRecorder:(NSString*)frameRate :(NSString*)takeNumber :(NSString*)trackWidth :(NSString*)cueName :(NSString*)dialog;

-(void)stopBoomRecorder;
-(void)abortBoomRecorder;

@end
