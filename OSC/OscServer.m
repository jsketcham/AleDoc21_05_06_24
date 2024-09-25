//
//  OscServer.m
//  AleDoc
//
//  Created by Jim on 5/16/22.
//  Copyright © 2022 James Ketcham. All rights reserved.
//  udp listener on 127.00.1:55554
//  tcp client (to Controller software) on 127.0.0.1:8000

#import "OscServer.h"

#define BONJOUR_SERVICE_DOMAIN "local"
#define BONJOUR_SERVICE_TCP_TYPE "_aledoc_fp._tcp" // a plausible name
#define BONJOUR_SERVICE_UDP_TYPE "_aledoc_fp._udp" // a plausible name

#define SERVICE_NAME @"127.0.0.1"
#define UDP_PORT @"3128"    //Wikipedia has it as 'Squid caching web proxy[181]'
#define TCP_PORT @"3101"    // Wikipedia has it as 'BlackBerry Enterprise Server communication protocol[180]'

@implementation OscServer

@synthesize udpServer = _udpServer;
@synthesize tcpServer = _tcpServer;
@synthesize delegate = _delegate;

-(id)init:(id)delegate{
    self = [super init];
    self.delegate = delegate;
    
    NSString *serviceType = NULL;
    
   // AleDoc UDP port is 3128, Wikipedia has it as 'Squid caching web proxy[181]'

    // OSC uses UDP, we did some tests using this port, but OSC has no feedback (indicators)
//    _udpServer = [[Server alloc] init: self : SERVICE_NAME : serviceType : UDP_PORT : true];
    
    // AleDoc tcp port is 3101, Wikipedia has it as 'BlackBerry Enterprise Server communication protocol[180]'
    // Middle Control, which we are using as a model, is tcp after their version 2.2
    // so, we will do tcp and not udp
    _tcpServer = [[Server alloc] init: self : SERVICE_NAME : serviceType : TCP_PORT : false];

    return self;
}
-(void)appendToLog:(NSString*) msg{
    
    if(_delegate && [_delegate respondsToSelector:@selector(appendToLog:)]){
        
        // assume _logDelegate is a GUI
        [_delegate performSelectorOnMainThread:@selector(appendToLog:) withObject:msg waitUntilDone:false];
        
    }
}
- (void)transmit:(NSString*)str {
    
    if (![str containsString:@"\n"]){
        
        str = [NSString stringWithFormat:@"%@\n",str];
        
    }

    if(_tcpServer){
        
        nw_connection_t connection = NULL;  // send to all
        
        [_tcpServer send: connection : [str dataUsingEncoding:NSUTF8StringEncoding]];
        
    }
    
    if(_udpServer){
        
        nw_connection_t connection = NULL;  // send to all
        
        [_udpServer send: connection : [str dataUsingEncoding:NSUTF8StringEncoding]];
        
    }

}
//-(void)setLEDForUnitID:(int)unitID :(int)index :(bool)on{
//    // message: LED unitID,index on
//}


// MARK: ------- ServerDelegate ------------
-(void)receive:(Server*) server :(nw_connection_t) connection : (NSData *)data{
    
    NSString *msg = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];

    [self appendToLog:[NSString stringWithFormat:@"%@: %@",server.isUdp ? @"udp" : @"tcp", msg]];
    
    if(_delegate && [_delegate respondsToSelector:@selector(rxOsc:)]){
        
        [_delegate performSelectorOnMainThread:@selector(rxOsc:) withObject:msg waitUntilDone:false];
        
    }
}
-(void)serverReady:(Server*) server{
    
    NSString *msg = [NSString stringWithFormat:@"%@ server ready, port: %@",server.isUdp ?@"udp" : @"tcp", server.port];
    [self appendToLog:msg];
    
}
-(void)serverFailed:(Server*) server{
    
    // assume port not available, increment port number
    
    [self appendToLog:@"serverFailed"];
    int p = (int)[server.port integerValue] + 1;
    NSString *port = [NSString stringWithFormat:@"%d",p];
    NSString *serviceType = NULL;
    
    if(server.isUdp){
    _udpServer = [[Server alloc] init: self : SERVICE_NAME : serviceType : port : server.isUdp];
    }else{
        
        _tcpServer = [[Server alloc] init: self : SERVICE_NAME : serviceType : TCP_PORT : false];
    }
}
-(void)connectionReady:(nw_connection_t) connection{
    
    if(_delegate && [_delegate respondsToSelector:@selector(connectionReady:)]){
        
        [_delegate performSelectorOnMainThread:@selector(connectionReady:) withObject:connection waitUntilDone:false];

    }
    
}

@end
