//
//  OscServer.h
//  AleDoc
//
//  Created by Jim on 5/16/22.
//  Copyright © 2022 James Ketcham. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Server.h"

NS_ASSUME_NONNULL_BEGIN

@class OscServer;

@protocol OscServerDelegate
-(void)rxOsc:(NSString *)str;
-(void)connectionReady:(nw_connection_t) connection;
@end

@interface OscServer : NSObject<ServerDelegate>

@property (strong) Server *udpServer;
@property (strong) Server *tcpServer;
@property (strong) id delegate;

//-(void)setLEDForUnitID:(int)unitID :(int)index :(bool)on;
- (void)transmit:(NSString*)str;
-(id)init:(id)delegate;

@end

NS_ASSUME_NONNULL_END
