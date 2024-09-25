//
//  MidiClient_v2.h
//  MtcGenerator
//
//  Created by James Ketcham on 1/13/16.
//  Copyright © 2016 James Ketcham. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <stddef.h>
#import <CoreMIDI/MIDIServices.h>

enum{
    IN_ONLY,
    OUT_ONLY,
    IN_AND_OUT
};

@interface MidiClient : NSObject

@property NSInteger tcType;
//@property id delegate;
@property id commandDecoder;

-(id)initWithTitle:(NSString*)menuTitle :(NSInteger)menuType;
-(void)midiTx:(NSData*)data;

@end
