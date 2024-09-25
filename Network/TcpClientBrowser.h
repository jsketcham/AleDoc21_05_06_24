//
//  TcpClientBrowser.h
//  ADAA_server
//
//  Created by James Ketcham on 6/5/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//

#import <Foundation/Foundation.h>


@class TcpClientBrowser;

@interface TcpClientBrowser : NSObject<NSNetServiceBrowserDelegate>

@property (nonatomic, strong, readwrite) NSMutableArray *       connections;           // of TcpClientConnection

@property (nonatomic, strong, readwrite) NSNetServiceBrowser *  serviceBrowser;

@property (strong) id delegate;

// access
-(void)searchForServicesOfType:(NSString *)type inDomain:(NSString *)domainString;
//-(void)txMsg:(NSString*)msg;
//-(NSInteger)txData:(NSData*)data;
@end
