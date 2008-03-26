//
//  DKNSDictionaryExtensions.m
//  PhotoToTypePad
//
//  Created by Jonathan Younger on Thu Jun 17 2004.
//  Copyright (c) 2004 Daikini Software. All rights reserved.
//

#import "DKNSDictionaryExtensions.h"


@implementation NSDictionary (DKNSDictionaryExtensions)

// Invokes objectForKey: with key defaultName. 
// Returns YES if the value associated with defaultName is an NSString containing the word ‚Äúyes‚Äù 
// in uppercase or lowercase or responds to the intValue message by returning a nonzero value. 
// Otherwise, returns NO.
- (BOOL)boolForKey:(NSString *)defaultName
{
	id returnValue = [self objectForKey:defaultName];
	if (returnValue != nil) {
		if ([returnValue isKindOfClass:[NSString class]]) {
			if (([[returnValue lowercaseString] isEqualToString:@"yes"]) || ([returnValue intValue] != 0)) {
				return YES;
			}
		} else if ([returnValue isKindOfClass:[NSNumber class]]) {
			return [returnValue intValue] != 0;
		}
	}
		
	return NO;
}

// Invokes objectForKey: with key defaultName. 
// Returns 0 if no string is returned. 
// Otherwise, the resulting string is sent an intValue message, which provides this method‚Äôs return value.
- (int)integerForKey:(NSString *)defaultName
{
	id returnValue = [self objectForKey:defaultName];
	if (returnValue != nil) {
		if (([returnValue isKindOfClass:[NSString class]]) || ([returnValue isKindOfClass:[NSNumber class]])) {
			return [returnValue intValue];
		}
	}

	return 0;
}

// Invokes objectForKey: with key defaultName. 
// Returns the corresponding value if it is an NSArray object containing NSStrings, 
// and nil otherwise.
- (NSArray *)stringArrayForKey:(NSString *)defaultName
{
	NSEnumerator *e;
	id arrayObject;
	id returnValue = [self objectForKey:defaultName];
	if ([returnValue isKindOfClass:[NSArray class]]) {
		e = [returnValue objectEnumerator];
		while (arrayObject = [e nextObject]) {
			if (![arrayObject isKindOfClass:[NSString class]]) {
				return nil;
			}
		}
	} else {
		return nil;
	}
	
	return returnValue;
}

// Invokes objectForKey: with key defaultName. 
// Returns the corresponding value if it is an NSString object 
// and nil otherwise.
- (NSString *)stringForKey:(NSString *)defaultName
{
	id returnValue = [self objectForKey:defaultName];
	if ([returnValue isKindOfClass:[NSString class]]) {
		return returnValue;
	} else {
		return nil;
	}
}

// Invokes objectForKey: with key defaultName. 
// Returns the value associated with defaultName if it’s an NSArray object 
//and nil otherwise.
- (NSArray *)arrayForKey:(NSString *)defaultName
{
	id returnValue = [self objectForKey:defaultName];
	if ([returnValue isKindOfClass:[NSArray class]]) {
		return returnValue;
	} else {
		return nil;
	}
}

// Invokes objectForKey: with key defaultName. 
// Returns the corresponding value if it’s an NSDictionary object 
// and nil otherwise.
- (NSDictionary *)dictionaryForKey:(NSString *)defaultName
{
	id returnValue = [self objectForKey:defaultName];
	if ([returnValue isKindOfClass:[NSDictionary class]]) {
		return returnValue;
	} else {
		return nil;
	}
}
@end
