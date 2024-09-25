//
//  Server.m
//  TestOscServer
//
//  Created by Jim on 5/30/22.
//  a tcp/udp server based on nwcat sample, which is based on the netcat/nc tool
//

#import "Server.h"

@implementation Server

@synthesize serviceName = _serviceName;
@synthesize serviceType = _serviceType;
@synthesize port = _port;
@synthesize delegate = _delegate;
@synthesize connections = _connections;
@synthesize listener = _listener;
@synthesize isUdp = _isUdp;
@synthesize useBonjour = _useBonjour;
@synthesize isIpv4 = _isIpv4;
@synthesize isIpv6 = _isIpv6;

-(id)init{
    
    self = [super init];
    
    return self;
}

-(id)init:  (id) delegate : (NSString *)serviceName : (NSString *)serviceType : (NSString *)port : (BOOL) isUdp{
    
    self = [super init];
    
    _delegate = delegate;
    _serviceName = serviceName;
    _serviceType = serviceType;
    _port = port;
    _isUdp = isUdp;
    
    _connections = [[NSMutableArray alloc]init];
    
    // do this once to reduce overhead
    // An IPv4 address has the following format: x . x . x . x where x is called an octet and must be a decimal value between 0 and 255.
    // https://www.regextutorial.org/regex-for-numbers-and-ranges.php

    (void)regcomp(&ip4t, "(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\\.)(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\\.)(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(\\.)(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)", REG_EXTENDED);
    // An IPv6 address is represented as eight groups of four hexadecimal digits, each group representing 16 bits The groups are separated by colons (:).
    (void)regcomp(&ip6t, "([0-9]|[a-f]|[A-F]){4}(\\:)([0-9]|[a-f]|[A-F]){4}(\\:)([0-9]|[a-f]|[A-F]){4}(\\:)([0-9]|[a-f]|[A-F]){4}(\\:)([0-9]|[a-f]|[A-F]){4}(\\:)([0-9]|[a-f]|[A-F]){4}(\\:)([0-9]|[a-f]|[A-F]){4}(\\:)([0-9]|[a-f]|[A-F]){4}", REG_EXTENDED);

    _isIpv4 =  !regexec(&ip4t, [serviceName UTF8String], 1, &match, 0);  // 0 if ipv4
    _isIpv6 = !regexec(&ip6t, [serviceName UTF8String], 1, &match, 0);   // 0 if ipv6

    // Bonjour: port == NULL, ipAddress not ipv4 or ipv6
    _useBonjour = !_isIpv4 && !_isIpv6 && port == NULL;
    
    [self startListening];

    return self;
    
}
-(void)appendToLog:(NSString*) msg{
    
    if(_delegate && [_delegate respondsToSelector:@selector(appendToLog:)]){
        
        // assume _logDelegate is a GUI
        [_delegate performSelectorOnMainThread:@selector(appendToLog:) withObject:msg waitUntilDone:false];
        
    }
}
-(void)startListening{
    
    nw_parameters_t parameters = NULL;
    
    if(_isUdp){
        
        // Create a UDP listener
        nw_parameters_configure_protocol_block_t configure_udp = ^(nw_protocol_options_t udp_options){
            udp_options = nw_udp_create_options();    // default options
        };
        parameters = nw_parameters_create_secure_udp(NW_PARAMETERS_DISABLE_PROTOCOL,configure_udp);

    }else{
        
        // Create a TCP listener
        nw_parameters_configure_protocol_block_t configure_tcp = ^(nw_protocol_options_t tcp_options){
            tcp_options = nw_tcp_create_options();    // default options
            nw_tcp_options_set_enable_keepalive(tcp_options,true);
            nw_tcp_options_set_keepalive_interval(tcp_options,180.0);   // seconds between keepalives
            nw_tcp_options_set_keepalive_count(tcp_options,3);
            nw_tcp_options_set_keepalive_idle_time(tcp_options,120.0);

        };
        
        parameters = nw_parameters_create_secure_tcp(NW_PARAMETERS_DISABLE_PROTOCOL, configure_tcp);
    }
    
    // Bind to local address and port, TODO: Bonjour
    nw_endpoint_t local_endpoint = nw_endpoint_create_host((const char*)[_serviceName UTF8String],(const char*)[_port UTF8String]);
    nw_parameters_set_local_endpoint(parameters,local_endpoint);

    _listener = nw_listener_create(parameters);
    nw_listener_set_queue(_listener,dispatch_get_main_queue());
    
    nw_listener_set_state_changed_handler(_listener, ^(nw_listener_state_t state, nw_error_t error) {
        errno = error ? nw_error_get_error_code(error) : 0;
        
        switch(state){
            case nw_listener_state_waiting:
                NSLog(@"startListening nw_listener_state_waiting");
                break;
            case nw_listener_state_failed:
                NSLog(@"startListening nw_listener_state_failed");
                
                if(self->_delegate && [self->_delegate respondsToSelector:@selector(serverFailed:)]){
                    
                    // assume _logDelegate is a GUI
                    [self->_delegate performSelectorOnMainThread:@selector(serverFailed:) withObject:self waitUntilDone:false];
                    
                }
                break;
            case nw_listener_state_ready:
                NSLog(@"startListening nw_listener_state_ready");
                
                if(self->_delegate && [self->_delegate respondsToSelector:@selector(serverReady:)]){
                    
                    // assume _logDelegate is a GUI
                    [self->_delegate performSelectorOnMainThread:@selector(serverReady:) withObject:self waitUntilDone:false];
                    
                }
                
                break;
            case nw_listener_state_cancelled:
                NSLog(@"startListening nw_listener_state_cancelled");
                break;
            default:
                break;
        }

    });
    
    nw_listener_set_new_connection_handler(_listener, ^(nw_connection_t connection) {
        
        NSLog(@"nw_listener_set_new_connection_handler has a connection");
        if(![self->_connections containsObject:connection]){
            
            [self->_connections addObject:connection];
            [self startConnection:connection];
       }


    });
    
    nw_listener_start(_listener);
}
-(void)startConnection: (nw_connection_t) connection{
    
//    NSLog(@"%@ startConnection",self.isUdp ? @"udp" : @"tcp");
    nw_connection_set_queue(connection,dispatch_get_main_queue());
    
    nw_connection_set_state_changed_handler(connection, ^(nw_connection_state_t state, nw_error_t error) {
        
        NSString *msg;
        NSString *protocol = self.isUdp ? @"udp" : @"tcp";

        errno = error ? nw_error_get_error_code(error) : 0;
        switch(state){
            case nw_connection_state_waiting:
                NSLog(@"%@ startConnection nw_connection_state_waiting", protocol);
                break;
            case nw_connection_state_failed:
                NSLog(@"%@ startConnection nw_connection_state_failed", protocol);
                break;
            case nw_connection_state_ready:
                NSLog(@"%@ startConnection nw_connection_state_ready", protocol);
                msg = [NSString stringWithFormat:@"%@ startConnection nw_connection_state_ready", protocol];
                [self appendToLog:msg];
                [self startReceiveLoop:connection];
                
                if(self->_delegate && [self->_delegate respondsToSelector:@selector(connectionReady:)]){
                    
                    // assume _logDelegate is a GUI
                    [self->_delegate performSelectorOnMainThread:@selector(connectionReady:) withObject:connection waitUntilDone:false];
                    
                }
                break;
            case nw_connection_state_cancelled:
                NSLog(@"%@ startConnection nw_connection_state_cancelled", protocol);
                
                
                break;
            default:
                break;
        }
        
    });
    nw_connection_start(connection);
}

-(void)startReceiveLoop:  (nw_connection_t) connection{
    
    nw_connection_receive(connection, 1, UINT32_MAX, ^(dispatch_data_t content, nw_content_context_t context, bool is_complete, nw_error_t receive_error) {
        
        errno = receive_error ? nw_error_get_error_code(receive_error) : 0;
        
        if(receive_error){
            NSLog(@"receive_error %d",errno);
            
        }else{
            
            if (is_complete &&
                (context == NULL || nw_content_context_get_is_final(context))){
                NSLog(@"connection closing");
                [self appendToLog:@"connection closing"];
                nw_connection_cancel(connection);
                [self.connections removeObject:connection];
                return;
            }
            
//            NSLog(@"did receive");
            
            if(self.delegate && [self.delegate respondsToSelector:@selector(receive:::)]){
                
                // for GUI access you must call performSelectoOnMainThread in inboundConnectionReceiveService:
                // 3 items to pass, can't use performSelector::
                [ self.delegate receive:self :connection :( NSData*)content];

            }
            [self startReceiveLoop:connection];
        }
        
    });
    
}

-(void)tx:(nw_connection_t) connection : (NSData *)data{
    
    size_t size = [data length];
//    void *buffer = (void*)[data bytes];   // this has an ARC issue, discovered debugging MIDI memory issue
    Byte buffer[size];
    [data getBytes:buffer length:size];

    dispatch_data_t ddt = dispatch_data_create(buffer, size, dispatch_get_main_queue(), DISPATCH_DATA_DESTRUCTOR_DEFAULT);
        
    dispatch_async(dispatch_get_main_queue(), ^{
        
        nw_connection_send(connection, ddt, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, false, ^(nw_error_t  _Nullable error) {
            if (error != NULL) {
                errno = nw_error_get_error_code(error);
                NSLog(@"Server send error %d",errno);
            }
        });
        
    });
}

-(void)send:  (nw_connection_t) connection : (NSData *)data{
    
    if(data == NULL){
        
        NSLog(@"Server send error, connection : %@ data : %@",connection, data);
        [self appendToLog:@"Server send error, null data"];
        return;
        
    }
    
//    size_t size = [data length];
////    void *buffer = (void*)[data bytes];   // this has an ARC issue, discovered debugging MIDI memory issue
//    Byte buffer[size];
//    [data getBytes:buffer length:size];
    
    // if called with a connection, send to it. If NULL, send to all.
    if(connection){
        
        [self tx: connection :data];
        
//        dispatch_data_t ddt = dispatch_data_create(buffer, size, dispatch_get_main_queue(), DISPATCH_DATA_DESTRUCTOR_DEFAULT);
//
//        dispatch_async(dispatch_get_main_queue(), ^{
//
//            nw_connection_send(connection, ddt, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, false, ^(nw_error_t  _Nullable error) {
//                if (error != NULL) {
//                    errno = nw_error_get_error_code(error);
//                    NSLog(@"Server send error %d",errno);
//                }
//            });
//
//        });

    }else for(connection in _connections){  // send to all connections
        
        [self tx: connection :data];

        
//        dispatch_data_t ddt = dispatch_data_create(buffer, size, dispatch_get_main_queue(), DISPATCH_DATA_DESTRUCTOR_DEFAULT);
//
//        dispatch_async(dispatch_get_main_queue(), ^{
//
//            nw_connection_send(connection, ddt, NW_CONNECTION_DEFAULT_MESSAGE_CONTEXT, false, ^(nw_error_t  _Nullable error) {
//                if (error != NULL) {
//                    errno = nw_error_get_error_code(error);
//                    NSLog(@"send error %d",errno);
//                }
//            });
//
//        });
    }
}

@end
