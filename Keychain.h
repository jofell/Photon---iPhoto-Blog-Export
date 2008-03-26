//
//  KeyChain.h
//  Composition
//
//  Created by Jonathan Younger on Thu Apr 01 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import <CoreFoundation/CoreFoundation.h>
#import <Security/Security.h>
#import <CoreServices/CoreServices.h>

@interface PTWKeychain : NSObject {

}

- (NSNumber *)addGenericPassword:(NSString *)password forAccount:(NSString *)account forService:(NSString *)service replaceExisting:(BOOL)replace;
- (NSString *)findGenericPasswordForAccount:(NSString *)account forService:(NSString *)service;
- (NSNumber *)deleteItemForAccount:(NSString *)account forService:(NSString *)service;
@end
