//
//  ColorSupport.h
//  AleDoc21
//
//  Created by Pro Tools on 1/26/23.
// https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/DrawColor/Tasks/StoringNSColorInDefaults.html
#import <Foundation/Foundation.h>

#ifndef ColorSupport_h
#define ColorSupport_h


@interface NSUserDefaults(myColorSupport)
- (void)setColor:(NSColor *)aColor forKey:(NSString *)aKey;
- (NSColor *)colorForKey:(NSString *)aKey;
@end


#endif /* ColorSupport_h */
