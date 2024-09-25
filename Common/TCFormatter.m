//
//  TCFormatter.m
//  VM15
//
//  Created by Barb Ketcham on 5/2/12.
//  Copyright (c) 2012 Endpoint Technology LLC. All rights reserved.
//  tc and feet/frs are stored as tc without : or + chars
//  the objects must be NSString objects
//  formatting is just punctuation, i.e. : and + chars

#import "TCFormatter.h"
#import "TcCalculator.h"
//#import "AleDelegate.h"

@interface TCFormatter ()
//
@property TcCalculator *tcc;
//@property bool isPreroll; // prerolls ignore the hours

@end

@implementation TCFormatter

@synthesize delegate = _delegate;

#pragma mark -
#pragma mark ----------------- no calcs, just display formatting ------------

-(id)init{
    
    self = [super init];
    
    _tcc = [[TcCalculator alloc] init];
    [self setDelegate:[NSApp delegate]] ;   // this gets replaced by EditorWindowController, maybe Document
    
    return self;
}
-(NSInteger)getDisplayFormat{
    
    return DISPLAY_FMT_TC;  // the default
}
-(NSString*)formatAsTc:(NSString*)string{
    
    if(!string) string = @"";
    
    int tcType = [self getTcType];
    
    unsigned char frsDelimiter = tcType == TCTYPE_DF ? ';' : ':';

    string = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        NSCharacterSet *cs = [NSCharacterSet characterSetWithCharactersInString:@".:;+"];
    string = [[string componentsSeparatedByCharactersInSet:cs] componentsJoinedByString:@""];
    
    string = [@"00000000" stringByAppendingString:string];
    string = [string substringFromIndex:string.length - 8];
    
    return [NSString stringWithFormat:@"%@:%@:%@%c%@",
            [string substringWithRange:NSMakeRange(0, 2)],
            [string substringWithRange:NSMakeRange(2, 2)],
            [string substringWithRange:NSMakeRange(4, 2)],
            frsDelimiter,
            [string substringWithRange:NSMakeRange(6, 2)]];
}
-(NSString*)formatAsFeet:(NSString*)string{
    
    if(!string) string = @"";
    
    string = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    string = [@"00000000" stringByAppendingString:string];
    string = [string stringByReplacingOccurrencesOfString:@":" withString:@""];
    string = [string stringByReplacingOccurrencesOfString:@";" withString:@""];
    string = [string stringByReplacingOccurrencesOfString:@"." withString:@""];
    string = [string stringByReplacingOccurrencesOfString:@"+" withString:@""];
    string = [string substringFromIndex:string.length - 8];
    
    int feet = [[string substringWithRange:NSMakeRange(0, string.length - 2)] intValue];
    int frames = [[string substringWithRange:NSMakeRange(string.length - 2, 2)] intValue];
    
    return [NSString stringWithFormat:@"%d+%02d",feet,frames];
}
- (NSString *)stringForObjectValue:(id)anObject{
    
    if (![anObject isKindOfClass:[NSString class]]) {
        return @""; // not a string, return empty string
    }
    
    NSString *string = (NSString*)anObject;
    
    NSInteger displayFormat = 1;   // default is timecode
    
    if(_delegate && [_delegate respondsToSelector:@selector(getDisplayFormat)]){
        
        displayFormat = [_delegate getDisplayFormat];
        
    }
    
    NSString *start = [_delegate getTcStartForObject:string]; // each row may have an [@"Hours"]
    int tcType = [_delegate getTcType];
    NSInteger startFrs = [_tcc tcToBinary:start withType:tcType];

    if([string containsString:@"+"]){   // ft+fr
        if(displayFormat != 2){
                        
            // feet+fr to tc
            int frs = [_tcc ftToBinary:string];
            frs += startFrs;
            string = [_tcc binaryToTc:frs withType:tcType];

        }
    }else{  // not ft+fr
        
        if(displayFormat == 2){
            
            // tc to ft+fr
            int frs = [_tcc tcToBinary:string withType:tcType];
            frs -= startFrs;
            string = [_tcc binaryToFt:frs];
        }
        
    }
    
    return string;
    
}

//- (NSString *)stringForObjectValue:(id)anObject{
//    
//    if (![anObject isKindOfClass:[NSString class]]) {
//        return @""; // not a string, return empty string
//    }
//    NSString *string = (NSString*)anObject;
//    
//    if(string.length){
//        // if it does not start with a digit, assume it is text. Return it without formatting it
//        NSCharacterSet *digits = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
//        if(![digits characterIsMember:[string characterAtIndex:0]]) return string;
//    }
//    
////    id delegate = (id)[NSApp delegate];
//    
//    NSInteger format = [self getDisplayFormat];
//    
//    if(_delegate && [_delegate respondsToSelector:@selector(getDisplayFormat)]){
//        
//        format = [_delegate getDisplayFormat];
//        
//    }
//    
//    string = format == DISPLAY_FMT_TC ? [self formatAsTc:string] : [self formatAsFeet:string];
//    
//    return string;
//}
- (BOOL)isPartialStringValid:(NSString *)partialString
            newEditingString:(NSString **)newString
            errorDescription:(NSString **)error{
    
    partialString = [@"00000000" stringByAppendingString:partialString];
    partialString = [partialString stringByReplacingOccurrencesOfString:@":" withString:@""];
    partialString = [partialString stringByReplacingOccurrencesOfString:@";" withString:@""];
    partialString = [partialString stringByReplacingOccurrencesOfString:@"." withString:@""];
    partialString = [partialString stringByReplacingOccurrencesOfString:@"+" withString:@""];
    partialString = [partialString substringFromIndex:partialString.length - 8];
    
    int tcType = [_delegate getTcType];
    
    unsigned char frsDelimiter = tcType == TCTYPE_DF ? ';' : ':';
        
//    NSLog(@"partialString %@",partialString);
    
    int ft = [partialString substringWithRange:NSMakeRange(0, 6)].intValue;
    NSString *fr = [partialString substringWithRange:NSMakeRange(6, 2)];
    
    NSString *hh = [partialString substringWithRange:NSMakeRange(0, 2)];
    NSString *mm = [partialString substringWithRange:NSMakeRange(2, 2)];
    NSString *ss = [partialString substringWithRange:NSMakeRange(4, 2)];
    NSString *ff = [partialString substringWithRange:NSMakeRange(6, 2)];

    switch ([_delegate getDisplayFormat]) {
        case DISPLAY_FMT_FT:
            
            partialString = [NSString stringWithFormat:@"%d+%@",ft,fr];

            break;
            
        default:
            
            partialString = [NSString stringWithFormat:@"%@:%@:%@%c%@",hh,mm,ss,frsDelimiter,ff];

            break;
    }
    *newString = [self stringForObjectValue:partialString];
    
    return false;   // always correct the input
}

- (BOOL)getObjectValue:(out id *)anObject
             forString:(NSString *)string
      errorDescription:(out NSString **)error{
    
    NSString *str = [self stringForObjectValue:string];
    
    *anObject = str;
    
    return true;
}
// a concession to keep from making too many changes

-(NSString*)tcForPreroll:(NSString*)digits{
    
    //    id delegate = [NSApp delegate];
    
    NSInteger format = [self getDisplayFormat];
    
    if(_delegate && [_delegate respondsToSelector:@selector(getDisplayFormat)]){
        
        format = [_delegate getDisplayFormat];
        
    }
    
    if(format == DISPLAY_FMT_TC) return [self formatAsTc:digits];   // already tc
    
    // only 24fps works FIXME when you fix the tc/ft calculator
    
    int tcType = [self getTcType];

//    if([[NSApp delegate] isKindOfClass:[AleDelegate class]]){
//        
//        // we do have a midi client and can do a proper tc calc
//        tcType = [((AleDelegate*)[NSApp delegate]).midiClient getTcType];
//        
//    }
    
    NSString *ftFr = [self formatAsFeet:digits];
    int frames = [_tcc ftToBinary:ftFr];
    return [_tcc binaryToTc:frames withType:tcType]; // feet to tc
    
}
-(NSString*)tcForString:(NSString*)digits{
    
//    id delegate = [NSApp delegate];
    
    if(digits == nil || digits.length == 0) return @"";
    
    NSInteger format = [self getDisplayFormat];
    
    if(_delegate && [_delegate respondsToSelector:@selector(getDisplayFormat)]){
        
        format = [_delegate getDisplayFormat];
        
    }
    
    if(format == DISPLAY_FMT_TC) return [self formatAsTc:digits];   // already tc
    
    NSString *tcStart = [self getTcStart];
    
    tcStart = [self formatAsTc:tcStart];
    
    // only 24fps works FIXME when you fix the tc/ft calculator
    
    int tcType = [self getTcType];

//    if([[NSApp delegate] isKindOfClass:[AleDelegate class]]){
//        
//        // we do have a midi client and can do a proper tc calc
//        tcType = [((AleDelegate*)[NSApp delegate]).midiClient getTcType];
//        
//    }
    
    NSString *ftFr = [self formatAsFeet:digits];
    
    int frames = [_tcc ftToBinary:ftFr];    
    frames += [_tcc tcToBinary:tcStart withType:tcType]; // FIXME
    
    return [_tcc binaryToTc:frames withType:tcType]; // feet to tc
}

-(int)getTcType{
    
    if(_delegate && [_delegate respondsToSelector:@selector(getTcType)]) return [_delegate getTcType];
    
    id delegate = [NSApp delegate];

    if([delegate respondsToSelector:@selector(getTcType)]){

        return [delegate getTcType];

    }
    
    return  TCTYPE_24;  // default
}
-(NSString*)getTcStart{
    
    if(_delegate) return [_delegate getTcStart];
    
    id delegate = [NSApp delegate];
    
    if([delegate respondsToSelector:@selector(getTcStart)]){
        
        return [delegate getTcStart];
        
    }
    
    return @"01:00:00:00";  // default start
}
#pragma mark --
#pragma mark ------------ setters/getters -------------------
-(void)setDelegate:(id)delegate{
    _delegate = delegate;
//    NSLog(@"delegate: %x",(int)delegate);
}
-(id)delegate{
    return _delegate;
}

@end
