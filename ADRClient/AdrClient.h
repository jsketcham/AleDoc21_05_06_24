//
//  AdrClient.h
//  AleDoc
//
//  Created by Jim on 9/17/22.
//  Copyright © 2022 James Ketcham. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ScriptResult.h"

NS_ASSUME_NONNULL_BEGIN

@protocol adrClientDelegate

-(void)rxMsg:(NSString*)msg sender:sender;

@end

@interface AdrClient : NSObject

-(void)startAdrClient;
-(void)addToInArray:(NSString*)str;

@property bool adrClientRun;
@property NSMutableArray *inArray;
@property NSLock *inLock;
@property id delegate;

@end

NS_ASSUME_NONNULL_END
