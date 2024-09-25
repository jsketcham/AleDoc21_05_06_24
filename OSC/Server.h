//
//  Server.h
//  TestOscServer
//
//  Created by Jim on 5/30/22.
//  a tcp/udp server based on nwcat sample, which is based on the netcat/nc tool

#import <Foundation/Foundation.h>
#import <Network/Network.h>
#import <regex.h>

NS_ASSUME_NONNULL_BEGIN

@class Server;

@protocol ServerDelegate
-(void)receive:(Server*) server :(nw_connection_t) connection : (NSData *)data;
-(void)serverReady:(Server*) server;
-(void)serverFailed:(Server*) server;  // port not available
-(void)connectionReady:(nw_connection_t) connection;
-(void)appendToLog:(NSString*) msg;
@end


@interface Server : NSObject{
    regex_t ip4t;
    regex_t ip6t;   // Bonjour: serviceName not ipv4 or ipv6, port == NULL
    regmatch_t match;
}

@property (strong) NSString *serviceName;
@property (strong) NSString *serviceType;
@property (strong) NSString *port;
@property (strong) id delegate;
@property (strong) NSMutableArray *connections;
@property (strong,retain) nw_listener_t listener;
@property BOOL isUdp;
@property BOOL useBonjour;
@property BOOL isIpv4;
@property BOOL isIpv6;

-(void)send:  (nw_connection_t) connection : (NSData *)data;
-(id)init:  (id) delegate : (NSString *)serviceName : (NSString *)serviceType : (NSString *)port : (BOOL) isUdp;

@end

NS_ASSUME_NONNULL_END
