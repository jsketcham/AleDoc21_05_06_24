//
//  ColorSupport.m
//  AleDoc21
//
//  Created by Pro Tools on 1/26/23.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "ColorSupport.h"
 
@implementation NSUserDefaults(ColorSupport)
 
- (void)setColor:(NSColor *)color forKey:(NSString *)aKey
{
    NSError *error;
    NSData *theData=[NSKeyedArchiver archivedDataWithRootObject:color requiringSecureCoding:false error:&error];
    [self setObject:theData forKey:aKey];
}
 
- (NSColor *)colorForKey:(NSString *)aKey
{
    NSColor *theColor=nil;
    NSError *error;
    NSData *theData=[self dataForKey:aKey];
    if (theData != nil)
        theColor=(NSColor *)[NSKeyedUnarchiver unarchivedObjectOfClass:[NSColor class] fromData:theData error:&error];
    return theColor;
}
 
@end
