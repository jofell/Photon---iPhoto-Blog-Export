//
//  DKNSDictionaryExtensions.h
//  PhotoToTypePad
//
//  Created by Jonathan Younger on Thu Jun 17 2004.
//  Copyright (c) 2004 Daikini Software. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface NSDictionary (DKNSDictionaryExtensions)
- (BOOL)boolForKey:(NSString *)defaultName;
- (int)integerForKey:(NSString *)defaultName;
- (NSArray *)stringArrayForKey:(NSString *)defaultName;
- (NSString *)stringForKey:(NSString *)defaultName;
- (NSArray *)arrayForKey:(NSString *)defaultName;
- (NSDictionary *)dictionaryForKey:(NSString *)defaultName;
@end
