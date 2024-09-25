//
//  MidiClient_v2.m
//  MtcGenerator
//
//  Created by James Ketcham on 1/13/16.
//  Copyright © 2016 James Ketcham. All rights reserved.
//

#import "MidiClient_v2.h"
#import <Cocoa/Cocoa.h>
#import "AleDelegate.h"

#define PORT_NOT_OPEN 0

#define INPUT_KEY @"Input"
#define OUTPUT_KEY @"Output"
#define MIDI_KEY @"MIDI"
#define OFF_KEY @"Off"

@interface MidiClient(){
    
    MIDIPacketList packet_list;
    MIDIClientRef client;
    MIDIPortRef outPort,inPort;
    MIDIEndpointRef source,dest;
    NSString *title;
    NSString *defaultsInKey,*defaultsOutKey;
}

@end

@implementation MidiClient

@synthesize commandDecoder = _commandDecoder;

-(id)initWithTitle:(NSString*)menuTitle :(NSInteger) menuType{
    
    self = [super init];
    
    if(self){
        
        NSMenu *mainMenu = [NSApp mainMenu];
        NSMenuItem *midiMenuItem = [mainMenu itemWithTitle:MIDI_KEY];
        NSMenu *midiMenu = [[NSMenu alloc]initWithTitle:MIDI_KEY];
        
        // add a MIDI menu if there isn't one
        
        if(!midiMenuItem){
            
            midiMenuItem = [[NSMenuItem alloc]init];
            
            [midiMenuItem setTitle:MIDI_KEY];
            [mainMenu insertItem:midiMenuItem atIndex:mainMenu.numberOfItems - 1];
            [midiMenuItem setSubmenu:midiMenu];
            
        }else{
            
            midiMenuItem = [mainMenu itemWithTitle:MIDI_KEY];
            midiMenu = [midiMenuItem submenu];
        }
       
        outPort = PORT_NOT_OPEN;
        inPort = PORT_NOT_OPEN;
        
//        _delegate = [NSApp delegate];   // an assumption, can be changed
        
        title = menuTitle;  // initMenuItems needs this
        defaultsInKey = [menuTitle stringByAppendingString:[NSString stringWithFormat:@"_%@",INPUT_KEY]];
        defaultsOutKey = [menuTitle stringByAppendingString:[NSString stringWithFormat:@"_%@",OUTPUT_KEY]];
        
        MIDIClientCreate ((__bridge  CFStringRef)(menuTitle),
                          notifyProc,//MIDINotifyProc  notifyProc,
                          (__bridge  void*)self,//void            *notifyRefCon,
                          &client//MIDIClientRef   *outClient
                          );
        
        if(menuType != IN_ONLY) MIDIOutputPortCreate(client, (__bridge  CFStringRef)(defaultsOutKey), &outPort);
        
        if(menuType != OUT_ONLY) MIDIInputPortCreate(client,
                            (__bridge  CFStringRef)(defaultsInKey),
                            SourceReadProc,
                            (__bridge  void*)self,
                            &inPort);
        
        NSMenuItem *menuItem = [midiMenu itemWithTitle:menuTitle];
        
        if(!menuItem){
            
            // insert menu item before 'Help' menu
            menuItem = [[NSMenuItem alloc]init];
            [menuItem setTitle:menuTitle];
            [midiMenu addItem:menuItem];
            
        }
        
        // add in, out menus
        NSMenu *menu = [[NSMenu alloc]initWithTitle:menuTitle];
        [menu addItemWithTitle:INPUT_KEY action:NULL keyEquivalent:@""];
        [menu addItemWithTitle:OUTPUT_KEY action:NULL keyEquivalent:@""];
        [menuItem setSubmenu:menu];
        
        [self initMenuItems];   // fill the input and output menus TODO call this on changes
    }
    
    return self;
    
}
-(void)initMenuItems{
        
    NSMenuItem *newItem;

    // get the available inputs and outputs, add to input and output menus
    NSMenu *midiMenu = [[[NSApp mainMenu] itemWithTitle:MIDI_KEY] submenu];

    NSMenuItem *menuItem = [midiMenu itemWithTitle:title];
    NSMenu *menu = [menuItem submenu];
    NSMenuItem *inItem = [menu itemWithTitle:INPUT_KEY];
    NSMenuItem *outItem = [menu itemWithTitle:OUTPUT_KEY];

    NSMenu *inMenu = [[NSMenu alloc] initWithTitle:INPUT_KEY];
    NSMenu *outMenu = [[NSMenu alloc] initWithTitle:OUTPUT_KEY];

    NSString *inDefStr = [[NSUserDefaults standardUserDefaults] stringForKey:defaultsInKey];
    NSString *outDefStr = [[NSUserDefaults standardUserDefaults] stringForKey:defaultsOutKey];
    
    [self selectInput:inDefStr];
    [self selectOutput:outDefStr];
    
    NSArray *sourceNames = [self getSourceNames];
    NSArray *destinationNames = [self getDestinationNames];
    
    for(NSString *name in sourceNames){
        
        newItem = [[NSMenuItem alloc] initWithTitle:name action:@selector(inputAction:) keyEquivalent:@""];
        [newItem setTarget:self];
        [newItem setOnStateImage:[NSImage imageNamed:@"NSMenuRadio"]];
        
        if([name isEqualToString:inDefStr]){
            newItem.state = NSControlStateValueOn;
        }
        
        [inMenu addItem:newItem];

    }
    for(NSString *name in destinationNames){
        
        newItem = [[NSMenuItem alloc] initWithTitle:name action:@selector(outputAction:) keyEquivalent:@""];
        [newItem setTarget:self];
        [newItem setOnStateImage:[NSImage imageNamed:@"NSMenuRadio"]];
        
        if([name isEqualToString:outDefStr]){
            newItem.state = NSControlStateValueOn;
        }
        
        [outMenu addItem:newItem];

    }
    
    [inItem setSubmenu:inMenu];
    [outItem setSubmenu:outMenu];
    [inItem setEnabled:inPort != PORT_NOT_OPEN];
    [outItem setEnabled:outPort != PORT_NOT_OPEN];

}
//-(void)initMenuItemsx{
//
////    NSLog(@"initMenuItems");
//
//    NSMenuItem *newItem;
//
//    // get the available inputs and outputs, add to input and output menus
////    NSMenu *mainMenu = [NSApp mainMenu];
//    NSMenu *midiMenu = [[[NSApp mainMenu] itemWithTitle:MIDI_KEY] submenu];
//
//    NSMenuItem *menuItem = [midiMenu itemWithTitle:title];
//    NSMenu *menu = [menuItem submenu];
//    NSMenuItem *inItem = [menu itemWithTitle:INPUT_KEY];
//    NSMenuItem *outItem = [menu itemWithTitle:OUTPUT_KEY];
//
//    NSMenu *inMenu = [[NSMenu alloc] initWithTitle:INPUT_KEY];
//    NSMenu *outMenu = [[NSMenu alloc] initWithTitle:OUTPUT_KEY];
//
//    NSString *inDefStr = [[NSUserDefaults standardUserDefaults] stringForKey:defaultsInKey];
//    NSString *outDefStr = [[NSUserDefaults standardUserDefaults] stringForKey:defaultsOutKey];
//
//    NSMenuItem *inDefaultMenuItem = nil;
//    NSMenuItem *outDefaultMenuItem = nil;
//
//    // http://stackoverflow.com/questions/9051292/midireadproc-using-srcconnrefcon-to-listen-to-only-one-source
//    // or better...
//    //http://xmidi.com/blog/how-to-access-midi-devices-with-coremidi/
//    // Iterate through all MIDI devices
//    ItemCount deviceCount = MIDIGetNumberOfDevices();
//
//    //    NSLog(@"deviceCount: %ld",deviceCount);
//
//    for (ItemCount i = 0 ; i < deviceCount ; ++i) {
//
//        // Grab a reference to current device
//        MIDIDeviceRef device = MIDIGetDevice(i);
//        //        NSLog(@"Device: %@", [self getName:device]);
//
//        // Is this device online? (Currently connected?)
//        SInt32 isOffline = 0;
//        MIDIObjectGetIntegerProperty(device, kMIDIPropertyOffline, &isOffline);
//        //        NSLog(@"Device is online: %s", (isOffline ? "No" : "Yes"));
//
//        if(isOffline) continue; // don't list offline devices
//
//        // How many entities do we have?
//        ItemCount entityCount = MIDIDeviceGetNumberOfEntities(device);
//        //        NSLog(@"entityCount: %ld",entityCount);
//
//        // Iterate through this device's entities
//        for (ItemCount j = 0 ; j < entityCount ; ++j) {
//
//            // Grab a reference to an entity
//            MIDIEntityRef entity = MIDIDeviceGetEntity(device, j);  // an unsigned int
//            //            NSLog(@"  Entity: %@", [self getName:entity]);
//
//            // Iterate through this device's source endpoints (MIDI In)
//
//            ItemCount sourceCount = MIDIEntityGetNumberOfSources(entity);
//            for (ItemCount k = 0 ; k < sourceCount ; ++k) {
//
//                // Grab a reference to a source endpoint
//                MIDIEndpointRef src = MIDIEntityGetSource(entity, k);
//                //                NSLog(@"    Source: %@", [self getName:src]);
//
//                newItem = [[NSMenuItem alloc] initWithTitle:[self getName:src] action:@selector(inputAction:) keyEquivalent:@""];
//                [newItem setTag:src];
//                [newItem setTarget:self];
//                [newItem setOnStateImage:[NSImage imageNamed:@"NSMenuRadio"]];
//
//                if(inDefStr == nil || inDefStr.length == 0){
//
//                    inDefStr = [self getName:src];    //  default to first item if there is no user default
//                }
//
//                if(![inDefStr compare:[self getName:src]]){
//
//                    inDefaultMenuItem = newItem;
//                }
//
//                [inMenu addItem:newItem];
//            }
//
//            // Iterate through this device's destination endpoints
//            ItemCount destCount = MIDIEntityGetNumberOfDestinations(entity);
//            for (ItemCount k = 0 ; k < destCount ; ++k) {
//
//                // Grab a reference to a destination endpoint
//                MIDIEndpointRef dst = MIDIEntityGetDestination(entity, k);
//                //NSLog(@"    Destination: %@",[self getName:dst]);
//
//                newItem = [[NSMenuItem alloc] initWithTitle:[self getName:dst] action:@selector(outputAction:) keyEquivalent:@""];
//                [newItem setTag:dst];
//                [newItem setTarget:self];
//                [newItem setOnStateImage:[NSImage imageNamed:@"NSMenuRadio"]];
//
//                if(outDefStr == nil || outDefStr.length == 0){
//                    outDefStr = [self getName:dst]; //  default to first item if there is no user default
//                }
//
//                if(![outDefStr compare:[self getName:dst]]){
//
//                    outDefaultMenuItem = newItem;
//                }
//
//                [outMenu addItem:newItem];
//
//            }
//        }
//    }
//
//    [inItem setSubmenu:inMenu];
//    [outItem setSubmenu:outMenu];
//    [inItem setEnabled:inPort != PORT_NOT_OPEN];
//    [outItem setEnabled:outPort != PORT_NOT_OPEN];
//
//    if(inDefaultMenuItem && inItem.enabled) [self inputAction:inDefaultMenuItem];
//    if(outDefaultMenuItem && outItem.enabled) [self outputAction:outDefaultMenuItem];
//
//    [self initState];
//
//}
-(NSArray<NSString*>*)getSourceNames{
    
    NSMutableArray *array = [[NSMutableArray alloc] initWithObjects:OFF_KEY, nil];
    
    NSUInteger numSources = MIDIGetNumberOfSources();
    
    for(int i = 0; i < numSources; i++){
        
        MIDIEndpointRef ref = MIDIGetSource(i);
        
        [array addObject: [self getName:ref]];

    }
    
    
    return array;
    
}

-(NSArray<NSString*>*)getDestinationNames{
    
    NSMutableArray *array = [[NSMutableArray alloc] initWithObjects:OFF_KEY, nil];
    
    NSUInteger numDestinations = MIDIGetNumberOfDestinations();
    
    for(int i = 0; i < numDestinations; i++){
        
        MIDIEndpointRef ref = MIDIGetDestination(i);
        
        [array addObject: [self getName:ref]];

    }
    
    return array;

}

-(void)initState{
    
    if(_commandDecoder && [_commandDecoder respondsToSelector:@selector(initState)]){
        
        [_commandDecoder performSelector:@selector(initState) withObject:nil];
    }
}

-(NSString *)getName:(MIDIObjectRef) object
{
    // Returns the name of a given MIDIObjectRef as an NSString
    CFStringRef name = nil;
    // kMIDIPropertyDisplayName V1.00.18
    // Provides the Apple-recommended user-visible name for an endpoint, by combining the device and endpoint names.
//    if (noErr != MIDIObjectGetStringProperty(object, kMIDIPropertyName, &name))
    if (noErr != MIDIObjectGetStringProperty(object, kMIDIPropertyDisplayName, &name))
        return nil;
    return (__bridge  NSString *)name;
}

-(void)inputAction:(id)sender{
    
    NSMenuItem *menuItem = (NSMenuItem*)sender;
    
    // clear other items in this menu
    NSMenu *menu = [menuItem menu];
    //NSLog(@"number of input items: %d",(int)[menu numberOfItems]);
    for(int i = 0; i < [menu numberOfItems]; i++)[[menu itemAtIndex:i] setState:NSControlStateValueOff];
    
    [menuItem setState:NSControlStateValueOn];
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:menuItem.title
                 forKey:defaultsInKey]; // Set a 1-week expiration

    [self selectInput:menuItem.title];
    
//    MIDIPortDisconnectSource(inPort,source );
//    source = (unsigned int)[menuItem tag];
//
//    if(MIDIPortConnectSource(inPort, source, (__bridge  void*)self)) NSLog(@"MIDI Input did not connect!");
//    else{
//
//
//    }
    
}
-(void)outputAction:(id)sender{
    
    NSMenuItem *menuItem = (NSMenuItem*)sender;
    
    // clear other items in this menu
    NSMenu *menu = [menuItem menu];
    for(int i = 0; i < [menu numberOfItems]; i++)[[menu itemAtIndex:i] setState:NSControlStateValueOff];
    
    [menuItem setState:NSControlStateValueOn];
    
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:menuItem.title forKey:defaultsOutKey]; // Set a 1-week expiration

    [self selectOutput:menuItem.title];
    
//    dest = (unsigned int)[menuItem tag];
//
//    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
//    [defaults setObject:[self getName:dest]
//                 forKey:defaultsOutKey]; // Set a 1-week expiration
    
}
-(void)selectInput:(NSString*)name{
    
    if(name == nil){return;}
    
    MIDIPortDisconnectSource(inPort,source );
    
    NSInteger count = MIDIGetNumberOfSources();
    
    for(int i = 0; i < count; i++){
        
        MIDIEndpointRef ref = MIDIGetSource(i);
        
        if(ref != 0 && [[self getName:ref] isEqualToString:name]){
            
            source = ref;
            
            if(MIDIPortConnectSource(inPort,source,nil) != 0){
                NSLog(@"MIDI in %@ did not connect",name);
            }
        }
    }
}
-(void)selectOutput:(NSString*)name{
    
    dest = 0;   // Off
    
    if(name == nil || [name isEqualToString:OFF_KEY]){
        return;
    }
    
    NSInteger count = MIDIGetNumberOfDestinations();
    
    for(int i = 0; i < count; i++){
        
        MIDIEndpointRef ref = MIDIGetDestination(i);
        
        if(ref != 0 && [[self getName:ref] isEqualToString:name]){
            
            dest = ref;
            return;

        }
    }
}

static void notifyProc(const MIDINotification *message,
                       void *refCon){
    
//    NSLog(@"got to notifyProc");
    
    @autoreleasepool {
        
        MidiClient *client = (__bridge  MidiClient*)refCon;
        
        if(client && [client respondsToSelector:@selector(initMenuItems)]){
            [client performSelectorOnMainThread:@selector(initMenuItems) withObject:nil waitUntilDone:false];
        }
    }
}
//-(void)traceMidiData:(NSData*)data{
//    
//    AleDelegate *delegate = (AleDelegate*)[NSApp delegate];
//    Byte *buffer = (Byte*)[data bytes];
//    int len = (int)[data length];
//
//    if(len >= 3
//       && delegate.accClient == self
////       && (delegate.ptClient == self || delegate.ptHui.commandDecoder == self)
//       //&& buffer[0] >= 0xb0
//       //&& buffer[0] <= 0xbf
//       ){
//        
//        NSString *str = @"MIDI to accessory:";
//        
//        for(int i = 0; i < len; i++){
//            
//            str = [str stringByAppendingFormat:@" %02d",buffer[i]];
//            
//        }
//        
//        NSLog(@"%@",str);
//
//    }
//
//    
//}

//int midiTxByteCtr = 0;
//-(void)midiTxTimerService{
//    
//    // block sizes are good, problem is in UFX rx
//    NSLog(@"UFX send bytes %d",midiTxByteCtr);
//    
//}
//NSTimer *midiTxTimer;

-(void)midiTx:(NSData*)data{
    
    if(outPort == PORT_NOT_OPEN || dest == 0) return;    // not open for tx, exit
    
    // debugging dropped MIDI to UFX
//    if([title isEqualToString:@"UFX"]){
//        
//        if(!midiTxTimer || !midiTxTimer.isValid){
//            midiTxByteCtr = 0;
//            midiTxTimer = [NSTimer scheduledTimerWithTimeInterval:0.3 target: self selector:@selector(midiTxTimerService) userInfo:nil repeats: false];
//        }
//        midiTxByteCtr += data.length;   // debugging missing UFX rx
//    }
    
    Byte *buffer = (Byte*)[data bytes];
    int len = (int)[data length];
    
    
//    [self performSelectorOnMainThread:@selector(traceMidiData:) withObject:data waitUntilDone:false];
    
    MIDIPacket* packet = MIDIPacketListInit (&packet_list);
    
    packet = MIDIPacketListAdd (&packet_list,
                                sizeof(packet_list),
                                packet,
                                0,  // timestamp
                                len,
                                buffer);
    
    MIDIFlushOutput(dest);
    
    MIDISend (
              outPort,
              dest,
              &packet_list
              );
    
}
static void SourceReadProc (const MIDIPacketList   *pktlist,
                            void                   *readProcRefCon,
                            void                   *srcConnRefCon)
{
    
    MidiClient *midiClient = (__bridge MidiClient*)readProcRefCon;
    
    MIDIPacket *packet = (MIDIPacket*)&pktlist->packet[0];
    
    for (int i = 0; i < pktlist->numPackets; ++i) {
        
        int len = packet->length;
        Byte *buffer = (Byte*)packet->data;
        
        @autoreleasepool {  // we believe that this at the top of the call tree should cover all objects created in the tree
            
            [midiClient decodeData:[NSData dataWithBytes:buffer length:len]];
        }
        
        packet = MIDIPacketNext(packet);    // per 'quick help' for MIDIPacketList
        
    }
}
-(void)decodeData:(NSData*)data{
    
//    if([title isEqualToString:@"Status"]){
//        
//        unsigned char *buffer = (unsigned char *)[data bytes];
//        NSLog(@"Status decodeData %ld: %02x %02x %02x",data.length,buffer[0],buffer[1],buffer[2]);
//        
//        NSLog(@"_commandDecoder: %x respondsToSelector: %d",(unsigned int)_commandDecoder,(int) [_commandDecoder respondsToSelector:@selector(decodeData:)]);
//    }
    
    if(_commandDecoder && [_commandDecoder respondsToSelector:@selector(decodeData:)]){
        
        [_commandDecoder performSelector:@selector(decodeData:) withObject:data];
    }
}
#pragma mark --
#pragma mark ---------- setters/getters --------------

-(void)setCommandDecoder:(id)commandDecoder{
    
    _commandDecoder = commandDecoder;
    
    if(_commandDecoder && [_commandDecoder respondsToSelector:@selector(setCommandDecoder:)]){
        
        [_commandDecoder performSelector:@selector(setCommandDecoder:) withObject:self];    // connect decoder to our midiTx:
        
    }
}
-(id)commandDecoder{
    return _commandDecoder;
}
    
@end
