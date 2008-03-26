//
//  Keychain.m
//  Composition
//
//  Created by Jonathan Younger on Thu Apr 01 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "Keychain.h"


@implementation PTWKeychain

- (NSNumber *)addGenericPassword:(NSString *)password forAccount:(NSString *)account forService:(NSString *)service replaceExisting:(BOOL)replace
{
    OSStatus status;
    
    if (account == nil || service == nil || password == nil) { return [NSNumber numberWithInt:0]; }
    
    status = SecKeychainAddGenericPassword (NULL, strlen([service UTF8String]), [service UTF8String], strlen([account UTF8String]), [account UTF8String], strlen([password UTF8String]), [password UTF8String], NULL);
    
    // if we have a duplicate item error and user indicates that password should be replaced...
    if(status == errSecDuplicateItem && replace == YES) {
        UInt32             existingPasswordLength;
        char *             existingPasswordData ;
        SecKeychainItemRef existingItem;
        
        // ...get the existing password and a reference to the existing keychain item, then...
        status = SecKeychainFindGenericPassword (NULL, strlen([service UTF8String]), [service UTF8String], strlen([account UTF8String]), [account UTF8String], &existingPasswordLength, (void **)&existingPasswordData, &existingItem);
        
        // ...check to see that the passwords are not the same (no reason to muck around in the keychain if we don't need to;  this check may not be required, depending on whether it is anticipated that this method would be called with the same password as the password for an existing keychain item)  and if the passwords are not the same...
        if(![password isEqualToString:[NSString stringWithCString:existingPasswordData length:existingPasswordLength]]) {
            
            // ...modify the password for the existing keychain item;  (I'll admit to being mystified as to how this function works;  how does it know that it's the password data that's being modified??;  anyway, it seems to work); and finally...
            // Answer: the data of a keychain item is what is being modified.  In the case of internet or generic passwords, the data is the password.  For a certificate, for example, the data is the certificate itself.
            
            status = SecKeychainItemModifyContent (existingItem, NULL, strlen([password UTF8String]), (void *)[password UTF8String]);
        }
        
        // ...free the memory allocated in call to SecKeychainFindGenericPassword() above
        SecKeychainItemFreeContent(NULL, existingPasswordData);
        CFRelease(existingItem);
    }
    
    return [NSNumber numberWithInt:(status)];
}

- (NSString *)findGenericPasswordForAccount:(NSString *)account forService:(NSString *)service
{
    OSStatus status;
    char *passwordData;
    UInt32 passwordLength;
    SecKeychainItemRef itemRef;
    NSString *password;
    
    if (account == nil || service == nil) { return @""; }
    
    status = SecKeychainFindGenericPassword (NULL, strlen([service UTF8String]), [service UTF8String], strlen([account UTF8String]), [account UTF8String], &passwordLength, (void **)&passwordData, &itemRef);
    
    if (status == noErr) {
        password = [NSString stringWithCString:passwordData length:passwordLength];
    
        // ...free the memory allocated in call to SecKeychainFindGenericPassword() above
        SecKeychainItemFreeContent(NULL, passwordData);
        CFRelease(itemRef);
    } else {
        password = @"";
    }
    
    return password;
}

- (NSNumber *)deleteItemForAccount:(NSString *)account forService:(NSString *)service
{
    SecKeychainItemRef itemRef;
    OSStatus status;
    char *passwordData;
    UInt32 passwordLength;
    
    status = SecKeychainFindGenericPassword (NULL, strlen([service UTF8String]), [service UTF8String], strlen([account UTF8String]), [account UTF8String], &passwordLength, (void **)&passwordData, &itemRef);
    //status = SecKeychainItemModifyContent (itemRef, NULL, strlen([password UTF8String]), (void *)[password UTF8String]);
    if (status == noErr) {
        status = SecKeychainItemDelete (itemRef);
    }
    
    // ...free the memory allocated in call to SecKeychainFindGenericPassword() above
    SecKeychainItemFreeContent(NULL, passwordData);
    if (itemRef) {
        CFRelease(itemRef);
    }
    
    return [NSNumber numberWithInt:(status)];
}
@end
