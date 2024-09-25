//
//  Matrix.m
//  AleDoc
//
//  Created by James Ketcham on 8/15/14.
//  Copyright (c) 2014 James Ketcham. All rights reserved.
//  TODO: overlay

#import "Matrix.h"
#import "Slider.h"
#import "ItemView.h"
#import "AleDelegate.h"
#import "MatrixWindowController.h"
#import "Item.h"
#import "MatrixView.h"
#import "AleDoc21-Swift.h"    // must be here to avoid a circular reference

@implementation Matrix

//@synthesize state0 = _state0;
//@synthesize state1 = _state1;
//@synthesize state2 = _state2;
//@synthesize state3 = _state3;
//@synthesize state4 = _state4;
//@synthesize state5 = _state5;
//@synthesize state6 = _state6;
//@synthesize state7 = _state7;
//@synthesize state8 = _state8;
//@synthesize state9 = _state9;
//@synthesize state10 = _state10;
//@synthesize state11 = _state11;
//@synthesize state12 = _state12;
//@synthesize state13 = _state13;
//@synthesize state14 = _state14;

@synthesize fader0 = _fader0;
@synthesize fader1 = _fader1;
@synthesize fader2 = _fader2;
@synthesize fader3 = _fader3;
@synthesize fader4 = _fader4;

@synthesize isSelected = _isSelected;

//@synthesize rowDictionary = _rowDictionary;

//@synthesize parents = _parents;

@synthesize boxTitle = _boxTitle;

@synthesize item = _item;   // 2.00.00
@synthesize buttons = _buttons; // 2.00.00, hide if no buttons
@synthesize crosspointArrays = _crosspointArrays;   // crosspoints for faders
@synthesize followDelayedVideo = _followDelayedVideo;

//extern const int taper_table[]; // max gain (zero atten) is 0x1ffff

//Override this property in subclasses to provide an expanded or different set of allowed transformation classes.
//-(NSArray<Class>*)allowedTopLevelClasses{
//    NSArray *array = [NSArray arrayWithObjects:[NSString class],[NSData class], nil];
//    return array;
//}
// V2.00.00 changing to NSCoding,NSSecureCoding
+(BOOL)supportsSecureCoding{
    return true;
}


-(void)encodeWithCoder:(NSCoder *)coder{
    
    NSData *stateData = [[NSData alloc] initWithBytes:states length:sizeof(states)];

    [coder encodeObject:stateData forKey:@"states"];
    [coder encodeObject:_crosspointArrays forKey:@"crosspointArrays"];
    [coder encodeObject: _boxTitle forKey:@"boxTitle"];
    [coder encodeInteger:_fader0 forKey:@"fader0"];
    [coder encodeInteger:_fader1 forKey:@"fader1"];
    [coder encodeInteger:_fader2 forKey:@"fader2"];
    [coder encodeInteger:_fader3 forKey:@"fader3"];
    [coder encodeInteger:_fader4 forKey:@"fader4"]; //NSLog(@"encode %@ fader4 %ld",_boxTitle,_fader4);
    [coder encodeInteger:_buttons forKey:@"buttons"];
    [coder encodeInteger:_followDelayedVideo forKey:@"followDelayedVideo"];

}
-(Matrix*)initWithCoder:(NSCoder *)coder{
    
    NSSet *set = [NSSet setWithObjects:[NSMutableArray class],[NSString class],[NSDictionary class], nil];
    _crosspointArrays = [coder decodeObjectOfClasses:set forKey:@"crosspointArrays"];

    set = [NSSet setWithObjects:[NSData class], nil];
    NSData *data = [coder decodeObjectOfClasses:set forKey:@"states"];//[coder decodeObjectForKey:@"states"];
    
    memset(states,0,sizeof(states));
    
    if(data && data.length == sizeof(states)){
        
        [data getBytes:&states[0][0] length:sizeof(states)];
    }
    
//    [self stateFromStates];


    [self setBoxTitle:(NSString*)[coder decodeObjectForKey:@"boxTitle"]];
    if([self.boxTitle isEqualToString:@"ISDN"] ){
        self.boxTitle = @"Source Connect";   // fix old stored titles
        
    }
    [self setFader0: [coder decodeIntegerForKey:@"fader0"]];
    [self setFader1: [coder decodeIntegerForKey:@"fader1"]];
    [self setFader2: [coder decodeIntegerForKey:@"fader2"]];
    [self setFader3: [coder decodeIntegerForKey:@"fader3"]];
    [self setFader4: [coder decodeIntegerForKey:@"fader4"]];//NSLog(@"decode fader4 %ld",_fader4);
    [self setButtons: [coder decodeIntegerForKey:@"buttons"]];
    [self setFollowDelayedVideo: [coder decodeIntegerForKey:@"followDelayedVideo"]];

    return self;
}
-(id)init:(NSInteger)numInputs{
    
    self = [super init];
    
    if(self){
        
        memset(states, 0, sizeof(states));  // reh/rec/pb switch states
        
        _crosspointArrays = [[NSMutableArray alloc]init];
        
        for (int i = 0; i < numInputs; i++){
            
            NSMutableArray *array = [[NSMutableArray alloc] init];
            
            [_crosspointArrays addObject: array];
            
            
        }
    }
    return self;
}
-(NSInteger)aheadInPast{
    
    return _followDelayedVideo ? _delegate.delayedAheadInPast : _delegate.aheadInPast;
}

-(void)stateFromStates{

    // when rehRecPb changes, this is called
    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending
        
    self.state0     = (int)states[rrpb][0];
    self.state1     = (int)states[rrpb][1];
    self.state2     = (int)states[rrpb][2];
    self.state3     = (int)states[rrpb][3];
    self.state4     = (int)states[rrpb][4];
    self.state5     = (int)states[rrpb][5];
    self.state6     = (int)states[rrpb][6];
    self.state7     = (int)states[rrpb][7];
    self.state8     = (int)states[rrpb][8];
    self.state9     = (int)states[rrpb][9];
    self.state10    = (int)states[rrpb][10];
    self.state11    = (int)states[rrpb][11];
    self.state12    = (int)states[rrpb][12];
    self.state13    = (int)states[rrpb][13];
    self.state14    = (int)states[rrpb][14];

}
-(int)toggleStates:(int)btnTag{
    
    switch(btnTag){
        case 0 :  self.state0  = !self.state0;  return self.state0;
        case 1 :  self.state1  = !self.state1;  return self.state1;
        case 2 :  self.state2  = !self.state2;  return self.state2;
        case 3 :  self.state3  = !self.state3;  return self.state3;
        case 4 :  self.state4  = !self.state4;  return self.state4;
        case 5 :  self.state5  = !self.state5;  return self.state5;
        case 6 :  self.state6  = !self.state6;  return self.state6;
        case 7 :  self.state7  = !self.state7;  return self.state7;
        case 8 :  self.state8  = !self.state8;  return self.state8;
        case 9 :  self.state9  = !self.state9;  return self.state9;
        case 10 : self.state10 = !self.state10; return self.state10;
        case 11 : self.state11 = !self.state11; return self.state11;
        case 12 : self.state12 = !self.state12; return self.state12;
        case 13 : self.state13 = !self.state13; return self.state13;
        case 14 : self.state14 = !self.state14; return self.state14;
        default: return 0;
    }
//
//    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending
//    
//    if(btnTag < 0 || btnTag >= STATE_ROWS){
//        return; // out of bounds
//    }
//
//    states[rrpb][btnTag] = !states[rrpb][btnTag];
//    
//    switch(btnTag){
//        case 0: self.state0     = (int)states[rrpb][0]; break;
//        case 1: self.state1     = (int)states[rrpb][1]; break;
//        case 2: self.state2     = (int)states[rrpb][2]; break;
//        case 3: self.state3     = (int)states[rrpb][3]; break;
//        case 4: self.state4     = (int)states[rrpb][4]; break;
//        case 5: self.state5     = (int)states[rrpb][5]; break;
//        case 6: self.state6     = (int)states[rrpb][6]; break;
//        case 7: self.state7     = (int)states[rrpb][7]; break;
//        case 8: self.state8     = (int)states[rrpb][8]; break;
//        case 9: self.state9     = (int)states[rrpb][9]; break;
//        case 10: self.state10   = (int)states[rrpb][10]; break;
//        case 11: self.state11   = (int)states[rrpb][11]; break;
//        case 12: self.state12   = (int)states[rrpb][12]; break;
//        case 13: self.state13   = (int)states[rrpb][13]; break;
//        case 14: self.state14   = (int)states[rrpb][14]; break;
//    }
}
-(void)forceState:(int) btnTag :(bool)on{
    
//    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending
//
//    states[rrpb][btnTag] = on;
    switch(btnTag){
        case 0:     self.state0  = on; break;
        case 1:     self.state1  = on; break;
        case 2:     self.state2  = on; break;
        case 3:     self.state3  = on; break;
        case 4:     self.state4  = on; break;
        case 5:     self.state5  = on; break;
        case 6:     self.state6  = on; break;
        case 7:     self.state7  = on; break;
        case 8:     self.state8  = on; break;
        case 9:     self.state9  = on; break;
        case 10:    self.state10 = on; break;
        case 11:    self.state11 = on; break;
        case 12:    self.state12 = on; break;
        case 13:    self.state13 = on; break;
        case 14:    self.state14 = on; break;
    }
    
}
-(void)forceSlider:(NSSlider*)slider{
    
    switch(slider.tag){
            
        case 0: self.fader0 = slider.integerValue; break;
        case 1: self.fader1 = slider.integerValue; break;
        case 2: self.fader2 = slider.integerValue; break;
        case 3: self.fader3 = slider.integerValue; break;
        case 4: self.fader4 = slider.integerValue; break;

        default: break;
    }
    
}
-(void)sendStateToAip:(int)tag :(int)state{

    int matrixNumber = (int)[_delegate.displayedMatrixArray indexOfObject:self];
    AleDelegate *aleDelegate = (AleDelegate*)[NSApp delegate];

    if(matrixNumber != -1){
        [aleDelegate.lpMini setMatrixIndicator:matrixNumber :tag :state];  // send to aip, osc
    }
}
-(NSInteger)stateForRow:(NSInteger)row{
        
    NSInteger rowIndex = (3 * row) + self.aheadInPast;
//    NSLog(@"row: %ld aheadInPast: %d",row,_delegate.aheadInPast);
    
    if(rowIndex >= STATE_ROWS){
        return 0;
    }
    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending

    return states[rrpb][rowIndex];
    
    return 0;
    
}
-(NSInteger)stateForTag:(NSInteger)tag{
    
    switch(tag){
        case 0: return self.state0;
        case 1: return self.state1;
        case 2: return self.state2;
        case 3: return self.state3;
        case 4: return self.state4;
        case 5: return self.state5;
        case 6: return self.state6;
        case 7: return self.state7;
        case 8: return self.state8;
        case 9: return self.state9;
        case 10: return self.state10;
        case 11: return self.state11;
        case 12: return self.state12;
        case 13: return self.state13;
        case 14: return self.state14;
        default: return 0;
    }
}
-(void)setAllStates:(bool)state{
    // hidden switchers have all states on
//    NSInteger states[STATE_COLS][STATE_ROWS];    // off/reh/rec/pb switches

    for(int i = 0; i < STATE_COLS; i++){
        for(int j= 0; j < STATE_ROWS; j++){
            
            states[i][j] = state;
        }
        
//        _state0     = state;
//        _state1     = state;
//        _state2     = state;
//        _state3     = state;
//        _state4     = state;
//        _state5     = state;
//        _state6     = state;
//        _state7     = state;
//        _state8     = state;
//        _state9     = state;
//        _state10    = state;
//        _state11    = state;
//        _state12    = state;
//        _state13    = state;
//        _state14    = state;
    }
    
}
-(NSData*)stateData{
    
    return [NSData dataWithBytes:&states[0][0] length:sizeof(states)];
}
-(void)copySettingsFromMatrix:(Matrix*)matrix{
    
    NSData *data = [matrix stateData];
    
    if(data && data.length == sizeof(states)){
        
        [data getBytes:&states[0][0] length:sizeof(states)];
//        [self stateFromStates];
    }

    self.fader0 = matrix.fader0;
    self.fader1 = matrix.fader1;
    self.fader2 = matrix.fader2;
    self.fader3 = matrix.fader3;
    self.fader4 = matrix.fader4;
    
    self.followDelayedVideo = matrix.followDelayedVideo;
    
}
#pragma mark -
#pragma mark ----------- debugging -----------------------
-(void)printStates{
    
    NSLog(@"");
    
    for(int i = 0; i < STATE_COLS; i++){
        NSString *str = [NSString stringWithFormat:@"[%d]:",i];
        for (int j = 0; j < STATE_ROWS; j++){
            
            if((j % 3) == 0){
                
                str = [str stringByAppendingString:@" "];
                
            }
            str = [str stringByAppendingString:states[i][j] ? @"1" : @"0"];
            
            
        }
        NSLog(@"%@",str);
        
    }

}

#pragma mark -
#pragma mark ----------- setters/getters -----------------------
-(void)setFollowDelayedVideo:(bool)followDelayedVideo{
    
    _followDelayedVideo = followDelayedVideo;
    [_delegate linkRemoteDelayedVideo:followDelayedVideo :self];
    [_delegate saveUserDefaults:self];
    
    // alt guide,beeps in record may have changed
    self.fader0 = self.fader0;  // guide
    self.fader4 = self.fader4;  // beeps
}
-(bool)followDelayedVideo{
    return _followDelayedVideo;
}
-(void)setItem:(Item*)item{
    _item = item;
    item.representedObject = self;
}
-(Item*)item{
    return _item;
}
-(void)setOverlay:(bool)overlay{
    
    [self willChangeValueForKey:@"state0"];
    [self willChangeValueForKey:@"state1"];
    [self willChangeValueForKey:@"state2"];
    
    self.fader0 = _fader0;

    [self didChangeValueForKey:@"state0"];
    [self didChangeValueForKey:@"state1"];
    [self didChangeValueForKey:@"state2"];
    
    [self sendStateToAip:0 :self.state0];
    [self sendStateToAip:1 :self.state1];
    [self sendStateToAip:2 :self.state2];
}
-(bool)overlay{
    AleDelegate *aleDelegate = (AleDelegate*)[NSApp delegate];
    return aleDelegate.overlay;
}
-(void)setState0:(int)state0{
    
//     _state0 = state0;
    
    // 01/27/24 we have a mess, button calls this via .representedObject
    // and also calls buttonPressed(). Should be one button event,
    // This bondo hides the issue.
    // 01/28/24 revised to be one event, setStatexx

    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending
    
    int delta = (int)states[rrpb][0] ^ state0;
    states[rrpb][0] = state0;

    [self sendStateToAip:0 :state0];
//    if(!isOverlayDisplay){  // inhibit recursion, while displaying overlay on AleDoc
//        [self setFader0:_fader0];
//    }
    [self setFader0:_fader0];

    [_delegate linkRemoteButton:0 :state0 :self]; // 2.10.02 link remote actor, remote editor
    
    if(delta){
        [_delegate saveUserDefaults:self];
    }

}
-(int)state0{
    int rrpb = _delegate.rehRecPb % 4;
    
    int state = (int)states[rrpb][0];
    
    // overlay logic
    AleDelegate *aleDelegate = (AleDelegate*)[NSApp delegate];
    if(aleDelegate.overlay){
        state |= (int)states[rrpb][6];
    }
    
    return state;
//    return _state0;
}
-(void)setState1:(int)state1{
    
//     _state1 = state1;
    
    // 01/27/24 we have a mess, button calls this via .representedObject
    // and also calls buttonPressed(). Should be one button event,
    // This bondo hides the issue.
    // 01/28/24 revised to be one event, setStatexx

    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending
    int delta = (int)states[rrpb][1] ^ state1;
    states[rrpb][1] = state1;
    
    
    // 01/28/24 getting rid of buttonPressed(), we want 1 event, not 2
    
    if(![[NSUserDefaults standardUserDefaults] boolForKey:@"enInPastSwitching"] && self.state2 != state1){
        
        self.state2 = state1;  // follow the other button, no recursion
        
    }
    [self sendStateToAip:1 :state1];
//    if(!isOverlayDisplay){  // inhibit recursion, while displaying overlay on AleDoc
//        [self setFader0:_fader0];
//    }
    [self setFader0:_fader0];

    [_delegate linkRemoteButton:1 :state1 :self]; // 2.10.02 link remote actor, remote editor

    if(delta){
        [_delegate saveUserDefaults:self];
    }
}
-(int)state1{
    int rrpb = _delegate.rehRecPb % 4;
    
    // overlay logic
    int state = (int)states[rrpb][1];

    AleDelegate *aleDelegate = (AleDelegate*)[NSApp delegate];
    if(aleDelegate.overlay){
        state |= (int)states[rrpb][7];
    }
    
    return state;
//    return (int)states[rrpb][1];
//    return _state1;
}
-(void)setState2:(int)state2{
    
//     _state2 = state2;
    
    // 01/27/24 we have a mess, button calls this via .representedObject
    // and also calls buttonPressed(). Should be one button event,
    // This bondo hides the issue.
    // 01/28/24 revised to be one event, setStatexx

    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending
    int delta = (int)states[rrpb][2] ^ state2;
    states[rrpb][2] = state2;
    
    if(![[NSUserDefaults standardUserDefaults] boolForKey:@"enInPastSwitching"] && state2 != self.state1){
        
        self.state1 = state2;  // follow the other button, no recursion
        
    }

    [self sendStateToAip:2 :state2];
//    if(!isOverlayDisplay){  // inhibit recursion, while displaying overlay on AleDoc
//        [self setFader0:_fader0];
//    }
    [self setFader0:_fader0];

    [_delegate linkRemoteButton:2 :state2 :self]; // 2.10.02 link remote actor, remote editor
    if(delta){
        [_delegate saveUserDefaults:self];
    }
}
-(int)state2{
    
    int rrpb = _delegate.rehRecPb % 4;
    
    // overlay logic
    int state = (int)states[rrpb][2];

    AleDelegate *aleDelegate = (AleDelegate*)[NSApp delegate];
    if(aleDelegate.overlay){
        state |= (int)states[rrpb][8];
    }
    
    return state;
//    return (int)states[rrpb][2];
//    return _state2;
}
-(void)setState3:(int)state3{
    
//     _state3 = state3;
    
    // 01/27/24 we have a mess, button calls this via .representedObject
    // and also calls buttonPressed(). Should be one button event,
    // This bondo hides the issue.
    // 01/28/24 revised to be one event, setStatexx

    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending
    int delta = (int)states[rrpb][3] ^ state3;
    states[rrpb][3] = state3;

    [self sendStateToAip:3 :state3];
    [self setFader1:_fader1];

    [_delegate linkRemoteButton:3 :state3 :self]; // 2.10.02 link remote actor, remote editor
    if(delta){
        [_delegate saveUserDefaults:self];
    }
}
-(int)state3{
    int rrpb = _delegate.rehRecPb % 4;
    return (int)states[rrpb][3];
//    return _state3;
}
-(void)setState4:(int)state4{
    
//     _state4 = state4;
    
    // 01/27/24 we have a mess, button calls this via .representedObject
    // and also calls buttonPressed(). Should be one button event,
    // This bondo hides the issue.
    // 01/28/24 revised to be one event, setStatexx

    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending
    int delta = (int)states[rrpb][4] ^ state4;
    states[rrpb][4] = state4;
    
    if(![[NSUserDefaults standardUserDefaults] boolForKey:@"enInPastSwitching"] && state4 != self.state5){
        
        self.state5 = state4;  // follow the other button, no recursion
        
    }

    [self sendStateToAip:4 :state4];
    [self setFader1:_fader1];
    
    [_delegate linkRemoteButton:4 :state4 :self]; // 2.10.02 link remote actor, remote editor
    if(delta){
        [_delegate saveUserDefaults:self];
    }
}
-(int)state4{
    int rrpb = _delegate.rehRecPb % 4;
    return (int)states[rrpb][4];
//    return _state4;
}
-(void)setState5:(int)state5{
    
//     _state5 = state5;
    
    // 01/27/24 we have a mess, button calls this via .representedObject
    // and also calls buttonPressed(). Should be one button event,
    // This bondo hides the issue.
    // 01/28/24 revised to be one event, setStatexx

    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending
    int delta = (int)states[rrpb][5] ^ state5;
    states[rrpb][5] = state5;
    
    if(![[NSUserDefaults standardUserDefaults] boolForKey:@"enInPastSwitching"] && self.state4 != state5){
        
        self.state4 = state5;  // follow the other button, no recursion
        
    }

    [self sendStateToAip:5 :state5];
    [self setFader1:_fader1];
    
    [_delegate linkRemoteButton:5 :state5 :self]; // 2.10.02 link remote actor, remote editor

    if(delta){
        [_delegate saveUserDefaults:self];
    }
}
-(int)state5{
    int rrpb = _delegate.rehRecPb % 4;
    return (int)states[rrpb][5];
//    return _state5;
}
-(void)setState6:(int)state6{
    
//     _state6 = state6;
    
    // 01/27/24 we have a mess, button calls this via .representedObject
    // and also calls buttonPressed(). Should be one button event,
    // This bondo hides the issue.
    // 01/28/24 revised to be one event, setStatexx

    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending
    int delta = (int)states[rrpb][6] ^ state6;
    states[rrpb][6] = state6;
    
    // linkCompAndPbRouting
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"linkCompAndPbRouting"]
       && self.state9 != state6){
        self.state9 = state6;
    }

    [self sendStateToAip:6 :state6];
    [self setFader2:_fader2];

    [_delegate linkRemoteButton:6 :state6 :self]; // 2.10.02 link remote actor, remote editor
    if(delta){
        [_delegate saveUserDefaults:self];
    }
}
-(int)state6{
    int rrpb = _delegate.rehRecPb % 4;
    return (int)states[rrpb][6];
//    return _state6;
}
-(void)setState7:(int)state7{
    
//     _state7 = state7;
    
    // 01/27/24 we have a mess, button calls this via .representedObject
    // and also calls buttonPressed(). Should be one button event,
    // This bondo hides the issue.
    // 01/28/24 revised to be one event, setStatexx

    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending
    int delta = (int)states[rrpb][7] ^ state7;
    states[rrpb][7] = state7;
    
    if(![[NSUserDefaults standardUserDefaults] boolForKey:@"enInPastSwitching"] && state7 != self.state8){
        
        self.state8 = state7;  // follow the other button, no recursion
        
    }
    
    // linkCompAndPbRouting
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"linkCompAndPbRouting"]
       && self.state10 != state7){
        self.state10 = state7;
    }

    [self sendStateToAip:7 :state7];
    [self setFader2:_fader2];
    
    [_delegate linkRemoteButton:7 :state7 :self]; // 2.10.02 link remote actor, remote editor
    if(delta){
        [_delegate saveUserDefaults:self];
    }
}
-(int)state7{
    int rrpb = _delegate.rehRecPb % 4;
    return (int)states[rrpb][7];
//    return _state7;
}
-(void)setState8:(int)state8{
    
//     _state8 = state8;
    
    // 01/27/24 we have a mess, button calls this via .representedObject
    // and also calls buttonPressed(). Should be one button event,
    // This bondo hides the issue.
    // 01/28/24 revised to be one event, setStatexx

    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending
    int delta = (int)states[rrpb][8] ^ state8;
    states[rrpb][8] = state8;
    
    if(![[NSUserDefaults standardUserDefaults] boolForKey:@"enInPastSwitching"] && self.state7 != state8){
        
        self.state7 = state8;  // follow the other button, no recursion
        
    }
    
    // linkCompAndPbRouting
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"linkCompAndPbRouting"]
       && self.state11 != state8){
        self.state11 = state8;
    }

    [self sendStateToAip:8 :state8];
    [self setFader2:_fader2];
    
    [_delegate linkRemoteButton:8 :state8 :self]; // 2.10.02 link remote actor, remote editor
    if(delta){
        [_delegate saveUserDefaults:self];
    }
}
-(int)state8{
    int rrpb = _delegate.rehRecPb % 4;
    return (int)states[rrpb][8];
//    return _state8;
}
-(void)setState9:(int)state9{
    
//     _state9 = state9;
    
    // 01/27/24 we have a mess, button calls this via .representedObject
    // and also calls buttonPressed(). Should be one button event,
    // This bondo hides the issue.
    // 01/28/24 revised to be one event, setStatexx

    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending
    int delta = (int)states[rrpb][9] ^ state9;
    states[rrpb][9] = state9;
    
    // linkCompAndPbRouting
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"linkCompAndPbRouting"]
       && self.state6 != state9){
        self.state6 = state9;
    }

    [self sendStateToAip:9 :state9];
    [self setFader3:_fader3];

    [_delegate linkRemoteButton:9 :state9 :self]; // 2.10.02 link remote actor, remote editor
    if(delta){
        [_delegate saveUserDefaults:self];
    }
}
-(int)state9{
    int rrpb = _delegate.rehRecPb % 4;
    return (int)states[rrpb][9];
//    return _state9;
}
-(void)setState10:(int)state10{
    
//     _state10 = state10;
    
    // 01/27/24 we have a mess, button calls this via .representedObject
    // and also calls buttonPressed(). Should be one button event,
    // This bondo hides the issue.
    // 01/28/24 revised to be one event, setStatexx

    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending
    int delta = (int)states[rrpb][10] ^ state10;
    states[rrpb][10] = state10;
    
    if(![[NSUserDefaults standardUserDefaults] boolForKey:@"enInPastSwitching"] && self.state10 != self.state11){
        
        self.state11 = self.state10;  // follow the other button, no recursion
        
    }
    
    // linkCompAndPbRouting
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"linkCompAndPbRouting"]
       && self.state7 != state10){
        self.state7 = state10;
    }

    [self sendStateToAip:10 :state10];
    [self setFader3:_fader3];
    
    [_delegate linkRemoteButton:10 :state10 :self]; // 2.10.02 link remote actor, remote editor
    if(delta){
        [_delegate saveUserDefaults:self];
    }
}
-(int)state10{
    int rrpb = _delegate.rehRecPb % 4;
    return (int)states[rrpb][10];
//    return _state10;
}
-(void)setState11:(int)state11{
    
//     _state11 = state11;
    
    // 01/27/24 we have a mess, button calls this via .representedObject
    // and also calls buttonPressed(). Should be one button event,
    // This bondo hides the issue.
    // 01/28/24 revised to be one event, setStatexx

    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending
    int delta = (int)states[rrpb][11] ^ state11;
    states[rrpb][11] = state11;
    
    if(![[NSUserDefaults standardUserDefaults] boolForKey:@"enInPastSwitching"] && self.state10 != self.state11){
        
        self.state10 = self.state11;  // follow the other button, no recursion
        
    }
    
    // linkCompAndPbRouting
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"linkCompAndPbRouting"]
       && self.state8 != state11){
        self.state8 = state11;
    }

    [self sendStateToAip:11 :state11];
    [self setFader3:_fader3];
    
    [_delegate linkRemoteButton:11 :state11 :self]; // 2.10.02 link remote actor, remote editor
    if(delta){
        [_delegate saveUserDefaults:self];
    }
}
-(int)state11{
    int rrpb = _delegate.rehRecPb % 4;
    return (int)states[rrpb][11];
//    return _state11;
}
-(void)setState12:(int)state12{

//     _state12 = state12;
    
    // 01/27/24 we have a mess, button calls this via .representedObject
    // and also calls buttonPressed(). Should be one button event,
    // This bondo hides the issue.
    // 01/28/24 revised to be one event, setStatexx

    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending
    int delta = (int)states[rrpb][12] ^ state12;
    states[rrpb][12] = state12;

    [self sendStateToAip:12 :state12];
    [self setFader4:_fader4];

    [_delegate linkRemoteButton:12 :state12 :self]; // 2.10.02 link remote actor, remote editor
    if(delta){
        [_delegate saveUserDefaults:self];
    }
}
-(int)state12{
    int rrpb = _delegate.rehRecPb % 4;
    return (int)states[rrpb][12];
//    return _state12;
}
-(void)setState13:(int)state13{

//     _state13 = state13;
    
    // 01/27/24 we have a mess, button calls this via .representedObject
    // and also calls buttonPressed(). Should be one button event,
    // This bondo hides the issue.
    // 01/28/24 revised to be one event, setStatexx

    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending
    int delta = (int)states[rrpb][13] ^ state13;
    states[rrpb][13] = state13;
    
    if(![[NSUserDefaults standardUserDefaults] boolForKey:@"enInPastSwitching"] && self.state13 != self.state14){
        
        self.state14 = self.state13;  // follow the other button, no recursion
        
    }

    [self sendStateToAip:13 :state13];
    [self setFader4:_fader4];
    
    [_delegate linkRemoteButton:13 :state13 :self]; // 2.10.02 link remote actor, remote editor

    if(delta){
        [_delegate saveUserDefaults:self];
    }
}
-(int)state13{
    int rrpb = _delegate.rehRecPb % 4;
    return (int)states[rrpb][13];
//    return _state13;
}
-(void)setState14:(int)state14{

//     _state14 = state14;
    
    // 01/27/24 we have a mess, button calls this via .representedObject
    // and also calls buttonPressed(). Should be one button event,
    // This bondo hides the issue.
    // 01/28/24 revised to be one event, setStatexx
    
    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending
    int delta = (int)states[rrpb][14] ^ state14;
    states[rrpb][14] = state14;

    if(![[NSUserDefaults standardUserDefaults] boolForKey:@"enInPastSwitching"] && self.state13 != self.state14){
        
        self.state13 = self.state14;  // follow the other button, no recursion
        
    }

    [self sendStateToAip:14 :state14];
    [self setFader4:_fader4];
    
    [_delegate linkRemoteButton:14 :state14 :self]; // 2.10.02 link remote actor, remote editor
    if(delta){
        [_delegate saveUserDefaults:self];
    }
}
-(int)state14{
    int rrpb = _delegate.rehRecPb % 4;
    return (int)states[rrpb][14];
//    return _state14;
}
//-(void)setState15:(int)state15{
//
//     _state15 = state15;
//    [self sendStateToAip:15 :state15];
//    [self setFader5:_fader5];
//
//}
//-(int)state15{
//    return _state15;
//}
//-(void)setParents:(NSArray *)parents{
//    
//    _parents = parents;
//    
//    NSMutableDictionary *dict = [[NSMutableDictionary alloc]init];
//    
//    for(int i = 0; i < parents.count; i++) {
//        
//        ChannelNodeData *data = [parents objectAtIndex:i];
//        
//        [dict setObject:data.name forKey:[NSString stringWithFormat:@"%d",i]];
//        
//        // unhide the buttons if any in the row are enabled
//        switch (i) {
//            case 0: [self setHide0:data.buttons == 0]; break;
//            case 1: [self setHide1:data.buttons == 0]; break;
//            case 2: [self setHide2:data.buttons == 0]; break;
//            case 3: [self setHide3:data.buttons == 0]; break;
//            case 4: [self setHide4:data.buttons == 0]; break;
//            case 5: [self setHide5:data.buttons == 0]; break;
//            case 6: [self setHide6:data.buttons == 0]; break;
//            case 7: [self setHide7:data.buttons == 0]; break;
//                
//            default:
//                break;
//        }
//    }
//    
//    _rowDictionary = dict;
//    
//}
//-(NSArray*)parents{
//    return _parents;
//}
-(void)setIsSelected:(bool)isSelected{
    _isSelected = isSelected;
    
    if(_item){
        
        ItemView *view = (ItemView *)[_item view];
        [view setIsSelected:isSelected];    // redraws the background color by isSelected
    }
}
-(bool)isSelected{
    return _isSelected;
}
-(void)initToolTips{
    
    [self setTip0:[_delegate sliderToString:_fader0]];
    [self setTip1:[_delegate sliderToString:_fader1]];
    [self setTip2:[_delegate sliderToString:_fader2]];
    [self setTip3:[_delegate sliderToString:_fader3]];
    [self setTip4:[_delegate sliderToString:_fader4]];
//    [self setTip5:[_delegate sliderToString:_fader5]];
//    [self setTip6:[_delegate sliderToString:_fader6]];
//    [self setTip7:[_delegate sliderToString:_fader7]];
//    [self setTipMaster:[_delegate sliderToString:_faderMaster]];
    
}

//bool isOverlayDisplay = false;

-(void)setFader0:(NSInteger)fader{
    
    [_delegate linkRemoteSlider:_item.slider0 :self];
    
//    NSLog(@"setFader0");
    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending

    if(fader > FADER_6dB) fader = FADER_6dB; if(fader < 0) fader = 0;
    
    if(_fader0 != fader){
        _fader0 = fader;
        if(_delegate)[_delegate saveUserDefaults:self];
    }
    
    [self setTip0:[_delegate sliderToString:fader]];
    
    // V2.00.00
//    NSInteger state = states[rrpb][self.aheadInPast + 3 * 0]; // offset for row 0 buttons
    
    // overlay
//    int overlayStates[3];
//
//    overlayStates[0] = (int)states[rrpb][0];    // guide ahead
//    overlayStates[1] = (int)states[rrpb][1];    // guide in
//    overlayStates[2] = (int)states[rrpb][2];    // guide past
//
//    AleDelegate *aleDelegate = (AleDelegate*)[NSApp delegate];
//    if(aleDelegate.overlay){
//
//        overlayStates[0] |= states[rrpb][0+3*2];    // playback ahead
//        overlayStates[1] |= states[rrpb][1+3*2];    // playback in
//        overlayStates[2] |= states[rrpb][2+3*2];    // playback past
//
//        state |= states[rrpb][self.aheadInPast + 3 * 2]; // offset for playback
//    }
//
//    isOverlayDisplay = true;    // no recursion, we want to show overlay on AleDoc buttons
//    self.state0 = (int)overlayStates[0];    // show overlay state
//    self.state1 = (int)overlayStates[1];    // show overlay state
//    self.state2 = (int)overlayStates[2];    // show overlay state
//    isOverlayDisplay = false;
    
    int state = 0;
    
    switch(self.aheadInPast){
        case 0: state = self.state0; break;
        case 1: state = self.state1; break;
        case 2: state = self.state2; break;
        default: break;
    }
    
    NSInteger f = state ? fader : MAX_FADER_ATTENUATION;
    
    // 'ALT GUIDE IN RECORD' logic
    bool delayOff =  [[NSUserDefaults standardUserDefaults]boolForKey:@"DialMuteKey_103"];

    if(_followDelayedVideo && rrpb == MODE_CONTROL_RECORD && !delayOff){
        
        [_delegate.matrixView setCrosspoint:_crosspointArrays[0] :0 :false];
        [_delegate.matrixView setCrosspoint:_crosspointArrays[5] :f :false];

    }else{
        
        [_delegate.matrixView setCrosspoint:_crosspointArrays[0] :f :false];
        [_delegate.matrixView setCrosspoint:_crosspointArrays[5] :0 :false];

    }
}
-(NSInteger)fader0{
    return _fader0;
}

-(void)setFader1:(NSInteger)fader{
    
    [_delegate linkRemoteSlider:_item.slider1 :self];

    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending
    if(fader > FADER_6dB) fader = FADER_6dB; if(fader < 0) fader = 0;
    
    if(_fader1 != fader){
        _fader1 = fader;
        if(_delegate)[_delegate saveUserDefaults:self];
    }
    [self setTip1:[_delegate sliderToString:fader]];
    
    NSInteger state = states[rrpb][self.aheadInPast + 3 * 1]; // offset for row 0 buttons
    NSInteger f = state == NSControlStateValueOn ? fader : MAX_FADER_ATTENUATION;
    
    [_delegate.matrixView setCrosspoint:_crosspointArrays[1] :f :false];
}
-(NSInteger)fader1{
    return _fader1;
}

-(void)setFader2:(NSInteger)fader{
    
    [_delegate linkRemoteSlider:_item.slider2 :self];
    
    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending

    if(fader > FADER_6dB) fader = FADER_6dB; if(fader < 0) fader = 0;
    
    if(_fader2 != fader){
        _fader2 = fader;
        if(_delegate)[_delegate saveUserDefaults:self];
    }
    
    [self setTip2:[_delegate sliderToString:fader]];
    
    NSInteger state = states[rrpb][self.aheadInPast + 3 * 2]; // offset for row 0 buttons
    NSInteger f = state == NSControlStateValueOn ? fader : MAX_FADER_ATTENUATION;
    
    NSString *key = @"linkCompAndPbRouting";
    NSInteger linkCompAndPb = [[NSUserDefaults standardUserDefaults] integerForKey:key];

    [_delegate.matrixView setCrosspoint:_crosspointArrays[2] :f :false];
    
    if(linkCompAndPb == NSControlStateValueOn){
        
        // comp and pb are linked, send pb fader to comp row
        [_delegate.matrixView setCrosspoint:_crosspointArrays[3] :f :false];

    }
    
    
    
}
-(NSInteger)fader2{
    return _fader2;
}

-(void)setFader3:(NSInteger)fader{
    
    [_delegate linkRemoteSlider:_item.slider3 :self];

    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending
    if(fader > FADER_6dB) fader = FADER_6dB; if(fader < 0) fader = 0;

    if(_fader3 != fader){
        _fader3 = fader;
        if(_delegate)[_delegate saveUserDefaults:self];
    }
    
    [self setTip3:[_delegate sliderToString:fader]];
    
    NSInteger state = states[rrpb][self.aheadInPast + 3 * 3]; // offset for row 0 buttons
    NSInteger f = state == NSControlStateValueOn ? fader : MAX_FADER_ATTENUATION;
    
    NSString *key = @"linkCompAndPbRouting";
    NSInteger linkCompAndPb = [[NSUserDefaults standardUserDefaults] integerForKey:key];
    
    if(linkCompAndPb == NSControlStateValueOff){
        [_delegate.matrixView setCrosspoint:_crosspointArrays[3] :f :false];
    }
}
-(NSInteger)fader3{
    return _fader3;
}

-(void)setFader4:(NSInteger)fader{
    
    [_delegate linkRemoteSlider:_item.slider4 :self];

    // beeps
    // some change for gitHub
    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending
    if(fader > FADER_6dB) fader = FADER_6dB; if(fader < 0) fader = 0;
    
    if(_fader4 != fader){
        _fader4 = fader;
        if(_delegate)[_delegate saveUserDefaults:self];
    }
    [self setTip4:[_delegate sliderToString:fader]];
    
    NSInteger state = states[rrpb][self.aheadInPast + 3 * 4]; // offset for row 0 buttons
    NSInteger f = state == NSControlStateValueOn ? fader : MAX_FADER_ATTENUATION;
    
//    [_delegate.matrixView setCrosspoint:_crosspointArrays[4] :f :false];
    
    // alt beeps
    bool delayOff =  [[NSUserDefaults standardUserDefaults]boolForKey:@"DialMuteKey_103"];

    if(_followDelayedVideo && rrpb == MODE_CONTROL_RECORD && !delayOff){
        
        [_delegate.matrixView setCrosspoint:_crosspointArrays[4] :0 :false];
        [_delegate.matrixView setCrosspoint:_crosspointArrays[7] :f :false];

    }else{
        
        [_delegate.matrixView setCrosspoint:_crosspointArrays[4] :f :false];
        [_delegate.matrixView setCrosspoint:_crosspointArrays[7] :0 :false];

    }

}
-(NSInteger)fader4{
    return _fader4;
}

#pragma mark
#pragma ----------- actions -----------------------

//-(void)linkCompAndPbRouting:(NSInteger) tag{
//    
//    NSString *key = @"linkCompAndPbRouting";
//    NSInteger state = [[NSUserDefaults standardUserDefaults] integerForKey:key];
//    
//    if(state != NSControlStateValueOn){
//        return;     // not linked
//    }
//    
//    // tie PB, comp if 'Link Comp, PB Routing' is set
//    // tie 6-8 to 9-11
//    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending
//
//    if(tag >= 6 && tag <= 8){
//        states[rrpb][tag + 3] = states[rrpb][tag];
//        switch(tag){
//            case 6: self.state9 = self.state6; break;
//            case 7: self.state10 = self.state7; break;
//            case 8: self.state11 = self.state8; break;
//            default: break;
//        }
//        self.fader3 = _fader3;  // send the other fader too
//
//    }else if(tag >= 9 && tag <= 11){
//        states[rrpb][tag - 3] = states[rrpb][tag];
//        switch(tag){
//            case 9: self.state6 = self.state9; break;
//            case 10: self.state7 = self.state10; break;
//            case 11: self.state8 = self.state11; break;
//            default: break;
//        }
//        self.fader2 = _fader2;  // send the other fader too
//    }
//    
//
//}
//-(void)buttonPressed:(id)sender{
//    
//    NSLog(@"buttonPressed, should not be calling this double event");
//    
//    return; // moved to setStatex
//    
//    NSButton *btn = (NSButton*)sender;
//    
//    [_delegate linkRemoteButton:btn :self]; // 2.10.02 link remote actor, remote editor
//    
//    int rrpb = _delegate.rehRecPb % 4;  // state indexes are not-pending
//
//    states[rrpb][btn.tag] = btn.state;
//    
//    // in/past switching
//    if([[NSUserDefaults standardUserDefaults] boolForKey:@"enInPastSwitching"] == false){
//        switch(btn.tag){
//            case 1:  states[rrpb][2]   = btn.state; self.state2 = (int)btn.state; break;
//            case 2:  states[rrpb][1]   = btn.state; self.state1 = (int)btn.state; break;
//            case 4:  states[rrpb][5]   = btn.state; self.state5 = (int)btn.state; break;
//            case 5:  states[rrpb][4]   = btn.state; self.state4 = (int)btn.state; break;
//            case 7:  states[rrpb][8]   = btn.state; self.state8 = (int)btn.state; break;
//            case 8:  states[rrpb][7]   = btn.state; self.state7 = (int)btn.state; break;
//            case 10: states[rrpb][11]  = btn.state; self.state11 = (int)btn.state; break;
//            case 11: states[rrpb][10]  = btn.state; self.state10 = (int)btn.state; break;
//            case 13: states[rrpb][14]  = btn.state; self.state14 = (int)btn.state; break;
//            case 14: states[rrpb][13]  = btn.state; self.state13 = (int)btn.state; break;
//            default: break;
//        }
//        
//        // playback/comp additional case
//        if([[NSUserDefaults standardUserDefaults] boolForKey:@"linkCompAndPbRouting"] == true){
//            switch(btn.tag){
//                case 7:  states[rrpb][11]   = btn.state; self.state11 = (int)btn.state; break;
//                case 8:  states[rrpb][10]   = btn.state; self.state10 = (int)btn.state; break;
//                case 10: states[rrpb][8]  = btn.state; self.state8 = (int)btn.state; break;
//                case 11: states[rrpb][7]  = btn.state; self.state7 = (int)btn.state; break;
//                default: break;
//            }
//        }
//        
//    }
//    // linkCompAndPbRouting
//    if([[NSUserDefaults standardUserDefaults] boolForKey:@"linkCompAndPbRouting"] == true){
//        
//        switch(btn.tag){
//            case 6:  states[rrpb][9]    = btn.state; self.state9    = (int)btn.state; break; // comp follows pb
//            case 7:  states[rrpb][10]   = btn.state; self.state10   = (int)btn.state; break;
//            case 8:  states[rrpb][11]   = btn.state; self.state11   = (int)btn.state; break;
//            case 9:  states[rrpb][6]    = btn.state; self.state6    = (int)btn.state; break; // pb follows comp
//            case 10: states[rrpb][7]    = btn.state; self.state7    = (int)btn.state; break;
//            case 11: states[rrpb][8]    = btn.state; self.state8    = (int)btn.state; break;
//            default: break;
//                
//
//        }
//        
//    }
//    
//    
//    
//    //NSLog(@"rehRecPb: %d tag: %ld state: %ld",_delegate.rehRecPb,btn.tag,(long)btn.state);
//    
////    [self linkCompAndPbRouting: btn.tag];
//
//    if(_delegate){
//        
//        [_delegate saveUserDefaults:self];
//        
//        // if this is not the active column, don't send faders
//        if((btn.tag % 3) != self.aheadInPast){
//            return;
//        }
//        
//        switch(btn.tag / 3){
//            case 0: [self setFader0:_fader0]; break;
//            case 1: [self setFader1:_fader1]; break;
//            case 2: [self setFader2:_fader2]; break;
//            case 3: [self setFader3:_fader3]; break;
//            case 4: [self setFader4:_fader4]; break;
//            default: break;
//        }
//
//    }
//}
-(void)setToDefaultSliderValue:(NSInteger)tag{
    
    // this fn exists so that the user default gets set when slider is cmd-clicked
    
    switch (tag) {
            
        case 0: [self setFader0:FADER_0dB]; break;
        case 1: [self setFader1:FADER_0dB]; break;
        case 2: [self setFader2:FADER_0dB]; break;
        case 3: [self setFader3:FADER_0dB]; break;
        case 4: [self setFader4:FADER_0dB]; break;
            
        default:
            break;
    }
}
-(void)setAllFadersToDefaultSliderValue{
    
    _fader0 = FADER_0dB;
    _fader1 = FADER_0dB;
    _fader2 = FADER_0dB;
    _fader3 = FADER_0dB;
    _fader4 = FADER_0dB;
//    _fader5 = FADER_0dB;
//    _fader6 = FADER_0dB;
//    _fader7 = FADER_0dB;
//    _faderMaster = FADER_0dB;
}
-(void)refreshCrosspoints{
    
    self.fader0 = self.fader0;
    self.fader1 = self.fader1;
    self.fader2 = self.fader2;
    self.fader3 = self.fader3;
    self.fader4 = self.fader4;
//    self.fader5 = self.fader5;
//    self.fader6 = self.fader6;

}

@end
