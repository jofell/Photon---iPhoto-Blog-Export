//
//  PhotoEnabledValueTransformer.m
//  Photon
//
//  Created by Jonathan Younger on 8/13/04.
//  Copyright 2004 Daikini Software. All rights reserved.
//

#import "PhotoEnabledValueTransformer.h"
#import "EntryOptionViews.h"

@implementation PhotoEnabledValueTransformer
+ (Class)transformedValueClass { return [NSNumber self]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value {
	NSDictionary *theEntryOption;
	NSEnumerator *e = [value objectEnumerator];
	
	while(theEntryOption = [e nextObject]) {
		if ([[theEntryOption objectForKey:@"source"] isEqual:[NSNumber numberWithInt:EOSPhoto]]) {
			return [NSNumber numberWithBool:YES];
		}
	}
	
	return [NSNumber numberWithBool:NO];
}
@end
