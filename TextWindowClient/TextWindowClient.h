//
//  TextWindowClient.h
//  AleDoc
//
//  Created by James Ketcham on 5/15/15.
//  Copyright (c) 2015 James Ketcham. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TcpClientBrowser.h"
//#import "TcpClientConnection.h"

enum{
    ANCHOR_TOP_LEFT,
    ANCHOR_BOTTOM_LEFT,
    ANCHOR_TOP_RIGHT,
    ANCHOR_BOTTOM_RIGHT
};

@interface TextWindowClient : NSObject

//-(void)txMsg:(NSString*)msg;
@property NSInteger isOnline;
//@property TcpClientConnection *connection;
//@property TcpClientBrowser *tcpClient;
//@property (readonly) bool isVersion2; // v1.00.23

-(void)setDefaultServer:(NSString*)server;
@end
