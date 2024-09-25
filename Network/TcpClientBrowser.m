//
//  TcpClientBrowser.m
//  ADAA_server
//
//  Created by James Ketcham on 6/5/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//  find all servers of a particular type, open a connection for each one
//  use this when there are several equivalent remotes that need to have the same info

#import "TcpClientBrowser.h"
#import "TcpClientConnection.h"
//
//@interface TcpClientBrowser()
//@property id delegate;
//@end

@implementation TcpClientBrowser

@synthesize delegate = _delegate;

-(id)init{
    
    self = [super init];
    
    if(self){
        
        [self setServiceBrowser: [[NSNetServiceBrowser alloc] init]];
        [self setConnections: [[NSMutableArray alloc] init]];           // list of items that resolved
        [self.serviceBrowser setDelegate:self];
        
    }
    
    return self;
}
-(void)searchForServicesOfType:(NSString *)type inDomain:(NSString *)domainString{
    
    [self.serviceBrowser searchForServicesOfType:type inDomain:domainString];
    
}
#pragma mark -
#pragma mark ---------------- NSNetServiceBrowser delegate methods -------------------------

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
#pragma unused(aNetServiceBrowser)
#pragma unused(moreComing)
    
//    NSLog(@"didFindService %@",aNetService.name);
    
    for(TcpClientConnection *connection in _connections){
        
        if([connection.netService isEqual:aNetService]) return;   // already on our list, should never happen
    }
    
    TcpClientConnection *connection = [[TcpClientConnection alloc] init];
    
    [connection setDelegate:_delegate];
    [connection setNetService: aNetService];    // calls openStreamsToNetService (resolving ip address)
    
    // trigger bindings for the array controller displaying 'connections'
    [self willChangeValueForKey:@"connections"];
    [_connections addObject:connection];
    [self didChangeValueForKey:@"connections"];
    
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
#pragma unused(aNetServiceBrowser)
#pragma unused(moreComing)
    
    for(TcpClientConnection *connection in [_connections copy]){    // 'copy' because we are going to change 'connections'
        
        if([connection.netService isEqual:aNetService]){
            
            [connection closeStreams];
            
            // trigger bindings for the array controller displaying 'connections'
            [self willChangeValueForKey:@"connections"];
            [_connections removeObject:connection];
            [self didChangeValueForKey:@"connections"];
        }
    }
}
- (void)netServiceBrowserWillSearch:(NSNetServiceBrowser *)netServiceBrowser{
//    NSLog(@"netServiceBrowserWillSearch");
    
}
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
             didNotSearch:(NSDictionary *)errorInfo{
    
//    NSLog(@"didNotSearch");
    
}
- (void)netServiceBrowserDidStopSearch:(NSNetServiceBrowser *)netServiceBrowser{
    
//    NSLog(@"netServiceBrowserDidStopSearch");
}
@end
