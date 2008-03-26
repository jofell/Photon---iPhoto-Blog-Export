//
//  Photon.m
//  Photon
//
//  Created by Jonathan Younger on Thu Apr 22 2004.
//  Copyright (c) 2004 Daikini Software. All rights reserved.
//

#import "Photon.h"
#import "Keychain.h"
#import "DKNSDictionaryExtensions.h"
#import <SystemConfiguration/SCNetwork.h>
#import "XMLRPC.h"
#import "AtomExtensions.h"
#import "AGRegex.h"
#import <Carbon/Carbon.h>
#import "PhotoEnabledValueTransformer.h"
#import "ThumbnailEnabledValueTransformer.h"
#import "DKURLConnection.h"

@interface Photon (PhotonPrivate)
- (void)loadPreferences;
- (void)savePreferences;
- (BOOL)isNetworkConnectionOK;
- (BOOL)createMTCategory:(NSString *)aCategory;
- (BOOL)createTypePadCategory:(NSString *)aCategory;
- (BOOL)createPhotopiaCategory:(NSString *)aCategory;
- (BOOL)createWordPressCategory:(NSString *)aCategory;
- (BOOL)createBlojsomCategory:(NSString *)aCategory;
- (NSSize)lastThumbnailSize:(void *)fp16;
- (float)imageAspectRatioAtIndex:(unsigned int)fp12;
- (BOOL)imageIsPortraitAtIndex:(unsigned int)fp12;
- (void)loadEntryOptionViews;
- (void)entryOptionChanged:(NSNotification *)aNotification;
- (id)entryOptionSource:(int)aSource fromDictionary:(NSDictionary *)aDictionary;
- (NSString *)entryOptionDestination:(int)aDestination;
- (void)syncImageSizes;
- (void)undoAccountChanges:(NSMutableArray *)someWeblogs;
- (NSMutableArray *)cloneWeblogs:(NSMutableArray *)someWeblogs;
- (NSMutableArray *)cloneExportCategories:(NSMutableArray *)someCategories;
- (NSString *)parameterizedUploadPath:(NSString *)anUploadPath usingDate:(NSDate *)aDate albumName:(NSString *)anAlbumName;
- (NSString *)localizedStringForKey:(NSString *)aKey;

- (BOOL)isCurrentWeblogSetup;

- (void)requestAuthorization;
- (NSString *)keychainPasswordForUserName:(NSString *)aUserName weblogURL:(NSString *)aWeblogURL;

- (NSString *)password;
- (void)setPassword:(NSString *)aPassword;

- (NSString *)previousPassword;
- (void)setPreviousPassword:(NSString *)aPreviousPassword;

- (NSMutableArray *)weblogs;
- (int)weblogCount;

- (NSMutableArray *)undoWeblogs;
- (void)setUndoWeblogs:(NSMutableArray *)anUndoWeblogs;

- (NSDictionary *)currentWeblog;
- (NSString *)currentWeblogId;

- (NSMutableArray *)categories;
- (void)setCategories:(NSMutableArray *)aCategories;

- (NSMutableArray *)exportCategories;
- (void)setExportCategories:(NSMutableArray *)anExportCategories;

- (NSArray *)metaWeblogExportCategories;
- (NSArray *)mtExportCategories;

- (NSMutableArray *)undoExportCategories;
- (void)setUndoExportCategories:(NSMutableArray *)anUndoExportCategories;

- (NSString *)version;
- (void)setVersion:(NSString *)aVersion;
@end

@implementation Photon (PhotonPrivate)
+ (void)initialize
{
	OSStatus err;
	FSRef myBundleRef;
	NSURL *myBundleURL = [NSURL fileURLWithPath:[[NSBundle bundleWithIdentifier:@"com.daikini.Photon"] bundlePath]];
	if (!CFURLGetFSRef((CFURLRef)myBundleURL, &myBundleRef)) err = fnfErr;
	err = AHRegisterHelpBook(&myBundleRef);
}

- (int)indexOfEntryOptionView:(NSView *)aView
{
	NSView *superview = [aView superview];
	return [[superview subviews] indexOfObject:aView];
}

- (void)loadPreferences
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *domain = [defaults persistentDomainForName:@"com.daikini.Photon"];
	NSData *weblogsAsData;
    	
	if (domain != nil) {
		if ([domain objectForKey:@"weblogs"] != nil) {
			weblogsAsData = [domain objectForKey:@"weblogs"];
			[weblogArrayController setContent:[NSKeyedUnarchiver unarchiveObjectWithData:weblogsAsData]];
			
			if (([self weblogCount] > 0) && ([domain integerForKey:@"selectedWeblogIndex"] != NSNotFound) && ([domain integerForKey:@"selectedWeblogIndex"] >= 0)) {
				[weblogArrayController setSelectionIndex:[domain integerForKey:@"selectedWeblogIndex"]];
			}
		}
    }
}

- (void)savePreferences
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *domain = [NSMutableDictionary dictionaryWithCapacity:10];

	
	if ([self weblogCount] > 0) {		
		NSData *weblogsAsData = [NSKeyedArchiver archivedDataWithRootObject:[self weblogs]];
		[domain setObject:weblogsAsData forKey:@"weblogs"];
	}
	
	[domain setObject:[NSNumber numberWithInt:[weblogArrayController selectionIndex]] forKey:@"selectedWeblogIndex"];

	[defaults setPersistentDomain:domain forName:@"com.daikini.Photon"];
	
}

- (BOOL)isNetworkConnectionOK
{
    BOOL                     	result = NO;
    SCNetworkConnectionFlags    flags;
	
	//assert(sizeof(SCNetworkConnectionFlags) == sizeof(int));
    
	if ( SCNetworkCheckReachabilityByName([@"www.google.com" cString], &flags) ) {
        result =!(flags & kSCNetworkFlagsConnectionRequired) &&  (flags & kSCNetworkFlagsReachable);
    }
	
    return result;
}

- (BOOL)createMTCategory:(NSString *)aCategory
{
	NSURLResponse *response;
	NSError *error;
	NSData *dataReply;
	NSString *newCategoryName;
	
	NSString *weblogPassword;
	
	if ([[self password] isEqualToString:@""]) {
		[self requestAuthorization];
	}
	
	if ([[self password] isEqualToString:@""]) {
		return NO;
	} else {
		weblogPassword = [self password];
	}
	
	NSDictionary *weblog = [self currentWeblog];
	NSMutableString *stringURL = [NSMutableString stringWithString:[weblog stringForKey:@"apiURL"]];
	[stringURL replaceOccurrencesOfString:@"mt-xmlrpc.cgi" withString:@"mt.cgi" options:0 range:NSMakeRange(0, [[weblog stringForKey:@"apiURL"] length])];
	
	NSURL *requestURL = [NSURL URLWithString:stringURL];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL];
	
	[request setHTTPMethod: @"POST"];
	[request setHTTPBody:[[NSString stringWithFormat:@"username=%@&password=%@&submit=Log%20In", [weblog stringForKey:@"userName"], weblogPassword] dataUsingEncoding:NSUTF8StringEncoding]];
	[request setHTTPShouldHandleCookies:NO];
	dataReply = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
	
	NSString *cookie = [[(NSHTTPURLResponse *)response allHeaderFields] objectForKey:@"Set-Cookie"];
	NSRange beginningRangeOfSessionId = [cookie rangeOfString:@"mt_user="];
	if (beginningRangeOfSessionId.location == NSNotFound) {
		beginningRangeOfSessionId = [cookie rangeOfString:@"user="];
	}
	NSRange endingRangeOfSessionId = [cookie rangeOfString:@";" options:nil range:NSMakeRange(beginningRangeOfSessionId.location, [cookie length] - beginningRangeOfSessionId.location)];
	NSString *sessionId = [cookie substringWithRange:NSMakeRange(beginningRangeOfSessionId.location, endingRangeOfSessionId.location - beginningRangeOfSessionId.location)];
	
	if (sessionId == nil) {
		[createCategoryProgressIndicator stopAnimation:self];
		[createCategoryProgressTextField setStringValue:@""];
		
		[NSApp stopModal];
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:[self localizedStringForKey:@"CategoryCreateError"], aCategory] defaultButton:[self localizedStringForKey:@"OK"] alternateButton:nil otherButton:nil informativeTextWithFormat:[self localizedStringForKey:@"NewCategoryAuthenticationError"], [weblog stringForKey:@"weblogName"]];
		[alert runModal];
		return NO;
	}
	
	newCategoryName = [(NSString*)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)aCategory, NULL, (CFStringRef)@"&", kCFStringEncodingUTF8) autorelease];
	
	request = [NSMutableURLRequest requestWithURL:requestURL];
	[request setHTTPMethod: @"POST"];
	[request addValue:sessionId forHTTPHeaderField:@"Cookie"];
	[request setHTTPBody:[[NSString stringWithFormat:@"__mode=save_cat&blog_id=%@&category-new=%@&category-new-parent-0=%@", [[self currentWeblogId] stringByAddingPercentEscapes], newCategoryName, newCategoryName] dataUsingEncoding:NSUTF8StringEncoding]];
	[request setHTTPShouldHandleCookies:NO];
		
	dataReply = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
	
	return YES;
}

- (BOOL)createTypePadCategory:(NSString *)aCategory
{
	NSURLResponse *response;
	NSError *error;
	NSData *dataReply;
	NSString *weblogPassword;
	
	if ([[self password] isEqualToString:@""]) {
		[self requestAuthorization];
	}
	
	if ([[self password] isEqualToString:@""]) {
		return NO;
	} else {
		 weblogPassword = [self password];
	}
	
	NSDictionary *weblog = [self currentWeblog];

	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: [NSURL URLWithString:@"https://www.typepad.com/t/app"]];

	[request setHTTPMethod: @"POST"];
	[request setHTTPBody:[[NSString stringWithFormat:@"__mode=home&username=%@&password=%@&submit=Log%20In", [weblog stringForKey:@"userName"], weblogPassword] dataUsingEncoding:NSUTF8StringEncoding]];
	[request setHTTPShouldHandleCookies:NO];
	dataReply = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];

	NSString *cookie = [[(NSHTTPURLResponse *)response allHeaderFields] objectForKey:@"Set-Cookie"];
	NSRange beginningRangeOfSessionId = [cookie rangeOfString:@"session_id="];
	NSRange endingRangeOfSessionId = [cookie rangeOfString:@";" options:nil range:NSMakeRange(beginningRangeOfSessionId.location, [cookie length] - beginningRangeOfSessionId.location)];
	NSString *sessionId = [cookie substringWithRange:NSMakeRange(beginningRangeOfSessionId.location, endingRangeOfSessionId.location - beginningRangeOfSessionId.location)];

	if ([sessionId isEqualToString:@"session_id="]) {
		[createCategoryProgressIndicator stopAnimation:self];
		[createCategoryProgressTextField setStringValue:@""];
		
		[NSApp stopModal];
		NSAlert *alert = [NSAlert alertWithMessageText:[NSString stringWithFormat:[self localizedStringForKey:@"CategoryCreateError"], aCategory] defaultButton:[self localizedStringForKey:@"OK"] alternateButton:nil otherButton:nil informativeTextWithFormat:[self localizedStringForKey:@"NewCategoryAuthenticationError"], [weblog stringForKey:@"weblogName"]];
		[alert runModal];
		return NO;
	}

	request = [NSMutableURLRequest requestWithURL: [NSURL URLWithString:@"https://www.typepad.com/t/app/weblog/configure"]];
	[request setHTTPMethod: @"POST"];
	[request addValue:sessionId forHTTPHeaderField:@"Cookie"];
	[request setHTTPBody:[[NSString stringWithFormat:@"__mode=save_categories&blog_id=%@&category-new=%@", [[self currentWeblogId] stringByAddingPercentEscapes], [(NSString*)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)aCategory, NULL, (CFStringRef)@"&", kCFStringEncodingUTF8) autorelease]] dataUsingEncoding:NSUTF8StringEncoding]];
	[request setHTTPShouldHandleCookies:NO];

	dataReply = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];

	return YES;
}

- (BOOL)createPhotopiaCategory:(NSString *)aCategory
{
	NSString *weblogPassword;
	
	if ([[self password] isEqualToString:@""]) {
		[self requestAuthorization];
	}
	
	if ([[self password] isEqualToString:@""]) {
		return NO;
	} else {
		weblogPassword = [self password];
	}
	
	NSDictionary *weblog = [self currentWeblog];
    XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithHost: [NSURL URLWithString:[weblog stringForKey:@"apiURL"]]];
	
	NSMutableDictionary *contentStruct = [[NSMutableDictionary alloc] init];
	[contentStruct setObject:aCategory forKey:@"categoryName"];
	
	[request setMethod:@"photopia.newCategory" withObjects:[NSArray arrayWithObjects: [self currentWeblogId], [weblog stringForKey:@"userName"], weblogPassword, contentStruct, nil]];
	[request setUserAgent: version];
	
    XMLRPCResponse *response = [XMLRPCConnection sendSynchronousXMLRPCRequest:request];
	
	if (response != nil) {
        if ([response isFault]) {
			NSLog(@"Photon: XML-RPC Fault photopia.newCategory: %@", [response fault]);
			return NO;
        }else {
			return YES;
		}
    } else{
        NSLog(@"Unable to parse response.");
    }
	
	return NO;
	
}

- (BOOL)createWordPressCategory:(NSString *)aCategory
{
	NSURLResponse *response;
	NSError *error;
	NSData *dataReply;
	NSString *weblogPassword;
	NSMutableString *stringURL;
	
	if ([[self password] isEqualToString:@""]) {
		[self requestAuthorization];
	}
	
	if ([[self password] isEqualToString:@""]) {
		return NO;
	} else {
		weblogPassword = [self password];
	}
	
	NSDictionary *weblog = [self currentWeblog];
	
	DKURLConnection *connection = [[DKURLConnection alloc] init];
	
	stringURL = [NSMutableString stringWithString:[weblog stringForKey:@"apiURL"]];
	[stringURL replaceOccurrencesOfString:@"xmlrpc.php" withString:@"wp-login.php" options:0 range:NSMakeRange(0, [[weblog stringForKey:@"apiURL"] length])];
	
	NSURL *requestURL = [NSURL URLWithString:stringURL];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL];
	
	[request setHTTPMethod: @"POST"];
	[request setHTTPBody:[[NSString stringWithFormat:@"redirect_to=/&action=login&log=%@&pwd=%@&Submit2=OK", [weblog stringForKey:@"userName"], weblogPassword] dataUsingEncoding:NSUTF8StringEncoding]];
	[request setHTTPShouldHandleCookies:NO];
	dataReply = [connection sendSynchronousRequest:request followRedirects:NO returningResponse:&response error:&error];
	NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:[(NSHTTPURLResponse *)response allHeaderFields] forURL:requestURL];
	[connection release];
	
	stringURL = [NSMutableString stringWithString:[weblog stringForKey:@"apiURL"]];
	[stringURL replaceOccurrencesOfString:@"xmlrpc.php" withString:@"wp-admin/categories.php" options:0 range:NSMakeRange(0, [[weblog stringForKey:@"apiURL"] length])];
	
	request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:stringURL]];
	[request setHTTPMethod: @"POST"];
	[request setAllHTTPHeaderFields:[NSHTTPCookie requestHeaderFieldsWithCookies:cookies]];
	[request setHTTPBody:[[NSString stringWithFormat:@"action=addcat&cat_name=%@&cat=0", [(NSString*)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)aCategory, NULL, (CFStringRef)@"&", kCFStringEncodingUTF8) autorelease]] dataUsingEncoding:NSUTF8StringEncoding]];
	[request setHTTPShouldHandleCookies:NO];
	
	dataReply = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
	
	return YES;
}

- (BOOL)createBlojsomCategory:(NSString *)aCategory
{
	NSURLResponse *response;
	NSError *error;
	NSData *dataReply;
	NSString *newCategoryName;
	
	NSString *weblogPassword;
	
	if ([[self password] isEqualToString:@""]) {
		[self requestAuthorization];
	}
	
	if ([[self password] isEqualToString:@""]) {
		return NO;
	} else {
		weblogPassword = [self password];
	}
	
	NSDictionary *weblog = [self currentWeblog];
	NSMutableString *stringURL = [NSMutableString stringWithString:[weblog stringForKey:@"weblogURL"]];
	[stringURL appendString:@"?flavor=admin"];
	
	NSURL *requestURL = [NSURL URLWithString:stringURL];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL];
	
	[request setHTTPMethod: @"POST"];
	[request setHTTPBody:[[NSString stringWithFormat:@"username=%@&password=%@", [weblog stringForKey:@"userName"], weblogPassword] dataUsingEncoding:NSUTF8StringEncoding]];
	[request setHTTPShouldHandleCookies:NO];
	dataReply = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
	NSArray *cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:[(NSHTTPURLResponse *)response allHeaderFields] forURL:requestURL];
	
	stringURL = [NSMutableString stringWithString:[weblog stringForKey:@"weblogURL"]];
	
	request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:stringURL]];
	[request setHTTPMethod: @"POST"];
	[request setAllHTTPHeaderFields:[NSHTTPCookie requestHeaderFieldsWithCookies:cookies]];
	
	newCategoryName = [(NSString*)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)aCategory, NULL, (CFStringRef)@"&", kCFStringEncodingUTF8) autorelease];
	
	[request setHTTPBody:[[NSString stringWithFormat:@"action=add-blog-category&flavor=admin&plugins=edit-blog-categories&blog-category-parent=/&blog-category-description=&blog-category-meta-data=&blog-category-name=%@&submit=Add%20category", newCategoryName] dataUsingEncoding:NSUTF8StringEncoding]];
	[request setHTTPShouldHandleCookies:NO];
	
	dataReply = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];

	return YES;
}

- (NSSize)lastThumbnailSize:(void *)fp16
{
	return [exportManager lastThumbnailSize:fp16];
}

- (float)imageAspectRatioAtIndex:(unsigned int)fp12
{
	return [exportManager imageAspectRatioAtIndex:fp12];
}

- (BOOL)imageIsPortraitAtIndex:(unsigned int)fp12
{
	return [exportManager imageIsPortraitAtIndex:fp12];
}

- (NSString *)parameterizedUploadPath:(NSString *)anUploadPath usingDate:(NSDate *)aDate albumName:(NSString *)anAlbumName
{
	NSMutableString *parameterizedUploadPath = [NSMutableString stringWithString:anUploadPath];
	[parameterizedUploadPath replaceOccurrencesOfString:@"^Y" withString:[aDate descriptionWithCalendarFormat: @"%Y" timeZone: nil locale: nil] options:0 range:NSMakeRange(0, [parameterizedUploadPath length])];
	[parameterizedUploadPath replaceOccurrencesOfString:@"^y" withString:[aDate descriptionWithCalendarFormat: @"%y" timeZone: nil locale: nil] options:0 range:NSMakeRange(0, [parameterizedUploadPath length])];
	[parameterizedUploadPath replaceOccurrencesOfString:@"^m" withString:[aDate descriptionWithCalendarFormat: @"%m" timeZone: nil locale: nil] options:0 range:NSMakeRange(0, [parameterizedUploadPath length])];
	[parameterizedUploadPath replaceOccurrencesOfString:@"^d" withString:[aDate descriptionWithCalendarFormat: @"%d" timeZone: nil locale: nil] options:0 range:NSMakeRange(0, [parameterizedUploadPath length])];
	[parameterizedUploadPath replaceOccurrencesOfString:@"^A" withString:anAlbumName options:0 range:NSMakeRange(0, [parameterizedUploadPath length])];
	return parameterizedUploadPath;
}

- (NSString *)localizedStringForKey:(NSString *)aKey
{
	return [[NSBundle bundleWithIdentifier:@"com.daikini.Photon"] localizedStringForKey:aKey value:nil table:nil];
}

- (BOOL)isCurrentWeblogSetup
{
	NSDictionary *weblog = [self currentWeblog];
	
	if (([[weblog stringForKey:@"weblogName"] isEqualToString:@""]) || ([weblog stringForKey:@"weblogName"] == nil)) return NO;
	if (([[weblog stringForKey:@"apiURL"] isEqualToString:@""]) || ([weblog stringForKey:@"apiURL"] == nil)) return NO;
	if ([weblog integerForKey:@"weblogPlatform"] <= 0) return NO;
	
	return YES;
}

- (void)requestAuthorization
{
	NSDictionary *weblog = [self currentWeblog];
	
	if (![self isCurrentWeblogSetup]) return;
	
	NSAlert *alert = [NSAlert alertWithMessageText:[self localizedStringForKey:@"AuthenticationRequired"] defaultButton:[self localizedStringForKey:@"Authenticate"] alternateButton:[self localizedStringForKey:@"Cancel"] otherButton:nil informativeTextWithFormat:[self localizedStringForKey:@"PasswordNeeded"], [weblog stringForKey:@"weblogName"]];

	int usersChoice = [alert runModal];
	if (usersChoice == NSAlertAlternateReturn) {
		return;
	} else {
		[tempPasswordSecureTextField setStringValue:@""];
		[self showPasswordSheet:self];
	}
}

- (NSString *)keychainPasswordForUserName:(NSString *)aUserName weblogURL:(NSString *)aWeblogURL
{
	NSString *thePassword;

	PTWKeychain *keychain = [[PTWKeychain alloc] init];
	thePassword = [keychain findGenericPasswordForAccount:aUserName forService:[NSString stringWithFormat:@"Photon: %@", aWeblogURL]];
	[keychain release];
	
	return thePassword;
}


- (NSString *)password { return password; }

- (void)setPassword:(NSString *)aPassword
{
    if (password != aPassword) {
        [aPassword retain];
        [password release];
        password = aPassword;
    }
}

- (NSString *)previousPassword { return previousPassword; }

- (void)setPreviousPassword:(NSString *)aPreviousPassword
{
    if (previousPassword != aPreviousPassword) {
        [aPreviousPassword retain];
        [previousPassword release];
        previousPassword = aPreviousPassword;
    }
}

- (void)loadEntryOptionViews
{
	if ([(NSArray *)[weblogArrayController content] count] > 0) {
		NSEnumerator *e = [[weblogArrayController valueForKeyPath:@"selection.entryOptions"] objectEnumerator];
		NSDictionary *theEntryOption = nil;
		
		while(theEntryOption = [e nextObject]) {
			[entryOptionViews addEntryOptionViewWithSource:[theEntryOption integerForKey:@"source"] destination:[theEntryOption integerForKey:@"destination"] relativeTo:nil];
		}
	}
}

- (void)entryOptionChanged:(NSNotification *)aNotification
{
	if ([(NSArray *)[weblogArrayController content] count] > 0) {
		[weblogArrayController setValue:[aNotification object] forKeyPath:@"selection.entryOptions"];
	}
}

- (id)entryOptionSource:(int)aSource fromDictionary:(NSDictionary *)aDictionary
{
	switch(aSource) {
		case EOSPhoto:
			return [aDictionary stringForKey:@"photoURL"];
		case EOSThumbnail:
			return [aDictionary stringForKey:@"thumbnailURL"];
		case EOSTitle:
			return [aDictionary stringForKey:@"title"];
		case EOSAlbumName:
			return [aDictionary stringForKey:@"albumName"];
		case EOSComments:
			return [aDictionary stringForKey:@"comments"];
		case EOSDateTaken:
			return [aDictionary objectForKey:@"dateTaken"];
		case EOSFilename:
			return [[aDictionary stringForKey:@"filename"] lastPathComponent];
		case EOSKeyWords:
			return [aDictionary stringForKey:@"keyWords"];
	}
	
	return nil;
}

- (NSString *)entryOptionDestination:(int)aDestination
{
	switch(aDestination) {
		case EODEntryTitle:
			return @"title";
		case EODEntryBody:
			return @"description";
		case EODEntryExtended:
			return @"mt_text_more";
		case EODEntryExcerpt:
			return @"mt_excerpt";
		case EODKeywords:
			return @"mt_keywords";
	}
	
	return nil;
}

- (void)syncImageSizes
{
	NSDictionary *weblog = [self currentWeblog];
	
	if ([entryOptionViews entryOptionForSource:EOSPhoto] != nil) {
		if ([weblog integerForKey:@"imageWidth"] > 0) {
			[(NSTextFieldCell *)imageWidthFormCell setPlaceholderString:[[NSNumber numberWithInt:[weblog integerForKey:@"imageWidth"]] stringValue]];
			if ([imageWidthFormCell intValue] <= 0) [imageWidthFormCell setObjectValue:[NSNull null]];
		} else {
			[(NSTextFieldCell *)imageWidthFormCell setPlaceholderString:@"°"];
		}
		
		if ([weblog integerForKey:@"imageHeight"] > 0) {
			[(NSTextFieldCell *)imageHeightFormCell setPlaceholderString:[[NSNumber numberWithInt:[weblog integerForKey:@"imageHeight"]] stringValue]];
			if ([imageHeightFormCell intValue] <= 0) [imageHeightFormCell setObjectValue:[NSNull null]];
		} else {
			[(NSTextFieldCell *)imageHeightFormCell setPlaceholderString:@"°"];
		}
	} else {
		[(NSTextFieldCell *)imageWidthFormCell setPlaceholderString:@" "];
		[(NSTextFieldCell *)imageHeightFormCell setPlaceholderString:@" "];
	}
	
	[[imageWidthFormCell controlView] setNeedsDisplay:YES];
	
	if ([entryOptionViews entryOptionForSource:EOSThumbnail] != nil) {
		if ([weblog integerForKey:@"thumbnailWidth"] > 0) {
			[(NSTextFieldCell *)thumbnailWidthFormCell setPlaceholderString:[[NSNumber numberWithInt:[weblog integerForKey:@"thumbnailWidth"]] stringValue]];
			if ([thumbnailWidthFormCell intValue] <= 0) [thumbnailWidthFormCell setObjectValue:[NSNull null]];
		} else {
			[(NSTextFieldCell *)thumbnailWidthFormCell setPlaceholderString:@"°"];
		}
		
		if ([weblog integerForKey:@"thumbnailHeight"] > 0) {
			[(NSTextFieldCell *)thumbnailHeightFormCell setPlaceholderString:[[NSNumber numberWithInt:[weblog integerForKey:@"thumbnailHeight"]] stringValue]];
			if ([thumbnailHeightFormCell intValue] <= 0) [thumbnailHeightFormCell setObjectValue:[NSNull null]];
		} else {
			[(NSTextFieldCell *)thumbnailHeightFormCell setPlaceholderString:@"°"];
		}
	} else {
		[(NSTextFieldCell *)thumbnailWidthFormCell setPlaceholderString:@" "];
		[(NSTextFieldCell *)thumbnailHeightFormCell setPlaceholderString:@" "];
	}
	
	[[thumbnailWidthFormCell controlView] setNeedsDisplay:YES];
}

- (void)undoAccountChanges:(NSMutableArray *)someWeblogs
{
	[weblogArrayController setContent:someWeblogs];
}

- (NSMutableArray *)cloneWeblogs:(NSMutableArray *)someWeblogs
{
	NSMutableDictionary *weblog;
	NSMutableArray *clonedWeblogs = [[NSMutableArray alloc] initWithCapacity:[someWeblogs count]];
	NSEnumerator *e = [someWeblogs objectEnumerator];
	
	while (weblog = [e nextObject]) {
		[clonedWeblogs addObject:[NSMutableDictionary dictionaryWithDictionary:weblog]];
	}
	
	return [clonedWeblogs autorelease];
}

- (NSMutableArray *)cloneExportCategories:(NSMutableArray *)someCategories
{
	NSNumber *categoryIndex;
	NSMutableArray *clonedCategories = [[NSMutableArray alloc] initWithCapacity:[someCategories count]];
	NSEnumerator *e = [someCategories objectEnumerator];
	
	while (categoryIndex = [e nextObject]) {
		[clonedCategories addObject:[NSNumber numberWithInt:[categoryIndex intValue]]];
	}
	
	return [clonedCategories autorelease];
}


- (NSMutableArray *)weblogs
{
	return [weblogArrayController content];
}

- (int)weblogCount
{
	return [(NSArray *)[weblogArrayController content] count];
}

- (NSMutableArray *)undoWeblogs { return undoWeblogs; }

- (void)setUndoWeblogs:(NSMutableArray *)anUndoWeblogs
{
    if (undoWeblogs != anUndoWeblogs) {
        [anUndoWeblogs retain];
        [undoWeblogs release];
        undoWeblogs = anUndoWeblogs;
    }
}

- (NSDictionary *)currentWeblog
{
	if ([weblogArrayController selectionIndex] != NSNotFound) {
		return [[self weblogs] objectAtIndex:[weblogArrayController selectionIndex]];
	} else {
		return nil;
	}
}

- (NSString *)currentWeblogId
{
	NSString *weblogId = nil;
	NSDictionary *weblog = [self currentWeblog];
	if (weblog != nil) {
		weblogId = [weblog stringForKey:@"blogId"];
		switch ([weblog integerForKey:@"weblogPlatform"]) {
			case WPBlojsom:
				if (weblogId == nil) {
					weblogId = @"/";
				}
				break;
		}
	}
	
	return weblogId;
}

- (NSMutableArray *)categories { return categories; }

- (void)setCategories:(NSMutableArray *)aCategories
{
    if (categories != aCategories) {
        [aCategories retain];
        [categories release];
        categories = aCategories;
    }
}

- (NSMutableArray *)exportCategories { return exportCategories; }

- (void)setExportCategories:(NSMutableArray *)anExportCategories
{
    if (exportCategories != anExportCategories) {
        [anExportCategories retain];
        [exportCategories release];
        exportCategories = anExportCategories;
    }
}

- (NSArray *)metaWeblogExportCategories
{
	NSEnumerator *e = [[self exportCategories] objectEnumerator];
	NSNumber *categoryIndex;
	NSMutableArray *metaWeblogExportCategories = [NSMutableArray arrayWithCapacity:[[self exportCategories] count]];
	while (categoryIndex = [e nextObject]) {
		[metaWeblogExportCategories addObject:[[[self categories] objectAtIndex:[categoryIndex intValue]] stringForKey:@"categoryName"]];
	}
	
	return metaWeblogExportCategories;
		
}

- (NSArray *)mtExportCategories
{
	NSEnumerator *e = [[self exportCategories] objectEnumerator];
	NSNumber *categoryIndex;
	NSMutableArray *mtExportCategories = [NSMutableArray arrayWithCapacity:[[self exportCategories] count]];
	BOOL isPrimary = YES;
	while (categoryIndex = [e nextObject]) {
		if (isPrimary) {
			[mtExportCategories addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[[self categories] objectAtIndex:[categoryIndex intValue]] stringForKey:@"categoryId"], kCFBooleanTrue, nil] forKeys:[NSArray arrayWithObjects:@"categoryId", @"isPrimary", nil]]];
			isPrimary = NO;
		} else {
			[mtExportCategories addObject:[NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:[[[self categories] objectAtIndex:[categoryIndex intValue]] stringForKey:@"categoryId"], kCFBooleanFalse, nil] forKeys:[NSArray arrayWithObjects:@"categoryId", @"isPrimary", nil]]];
		}
	}
	
	return mtExportCategories;
}


- (NSMutableArray *)undoExportCategories { return undoExportCategories; }

- (void)setUndoExportCategories:(NSMutableArray *)anUndoExportCategories
{
    if (undoExportCategories != anUndoExportCategories) {
        [anUndoExportCategories retain];
        [undoExportCategories release];
        undoExportCategories = anUndoExportCategories;
    }
}

- (NSString *)version { return version; }

- (void)setVersion:(NSString *)aVersion
{
    if (version != aVersion) {
        [aVersion retain];
        [version release];
        version = aVersion;
    }
}
@end

@implementation Photon
// Export Plugin Protocol Methods
- (id)initWithExportImageObj:(id)fp12
{	
    if (self = [super init]) {
		// fp12 is the iPhoto ExportMgr object. This object
		// is the main communication we have with iPhoto.
        exportManager = fp12;
		
		// Setup our lock object
		mProgressLock = [[NSLock alloc] init];
		
		// Setup our category array
		categories = [[NSMutableArray alloc] init];
		
		indexOfSelectedCategory = NSNotFound;
		
		undoWeblogs = [[NSMutableArray alloc] init];
		
		exportCategories = [[NSMutableArray alloc] init];
		
		// Register our custom value transformers
		PhotoEnabledValueTransformer *photoEnabledValueTransformer;
		
		// create an autoreleased instance of our value transformer
		photoEnabledValueTransformer = [[[PhotoEnabledValueTransformer alloc] init] autorelease];
		
		// register it with the name that we refer to it with
		[NSValueTransformer setValueTransformer:photoEnabledValueTransformer
										forName:@"PhotoEnabledValueTransformer"];
		
		ThumbnailEnabledValueTransformer *thumbnailEnabledValueTransformer;
		
		// create an autoreleased instance of our value transformer
		thumbnailEnabledValueTransformer = [[[ThumbnailEnabledValueTransformer alloc] init] autorelease];
		
		// register it with the name that we refer to it with
		[NSValueTransformer setValueTransformer:thumbnailEnabledValueTransformer
										forName:@"ThumbnailEnabledValueTransformer"];

    }
    
    return self;
}

- (id)settingsView
{
    return settingsView;
}

- (id)firstView
{
    return firstView;
}

- (id)lastView
{
    return lastView;
}

- (void)viewWillBeActivated
{
	static BOOL timerCalled;
	if (([[self categories] count] <= 0) && (timerCalled == NO)) {
		timerCalled = YES;
		[[NSRunLoop currentRunLoop] addTimer:[NSTimer timerWithTimeInterval:2.00 target:self selector:@selector(refreshCategories:) userInfo:nil repeats:NO] forMode:NSModalPanelRunLoopMode];
	}
	
	[self syncImageSizes];
}

- (void)viewWillBeDeactivated
{
	
}

- (id)requiredFileType
{
    return @"";
}

- (BOOL)wantsDestinationPrompt
{
    return NO;
}

- (id)getDestinationPath
{
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
}

- (id)defaultFileName
{
    return @"";
}

- (id)defaultDirectory
{
    return [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
}

- (BOOL)treatSingleSelectionDifferently
{
    return NO;
}

- (BOOL)validateUserCreatedPath:(id)fp12
{
    return NO;
}

// Not sure what would cause this method to be called.
// I haven't run into anything with the export manager
// that would call this method.
- (void)clickExport
{

}

// startExport is called when the user clicks the export button.
- (void)startExport:(id)fp12
{	
	if (![self isNetworkConnectionOK]) {
		NSAlert *alert = [NSAlert alertWithMessageText:[self localizedStringForKey:@"NoInternetConnection"] defaultButton:[self localizedStringForKey:@"OK"] alternateButton:nil otherButton:nil informativeTextWithFormat:[self localizedStringForKey:@"NoInternetConnectionExplanation"], [[self currentWeblog] stringForKey:@"weblogName"]];
		[alert runModal];
		
		return;
	}
		
	// If there aren't any weblogs selected then exit.
	if ([[weblogPopUpButton titleOfSelectedItem] isEqualToString:[self localizedStringForKey:@"NoneDefined"]] ) {
		NSAlert *alert = [NSAlert alertWithMessageText:[self localizedStringForKey:@"NoWeblogsSetup"] defaultButton:[self localizedStringForKey:@"OK"] alternateButton:nil otherButton:nil informativeTextWithFormat:[self localizedStringForKey:@"NoWeblogsSetupExplanation"]];
		[alert runModal];
		return;
	}
	
	// If the weblog is defined but the settings aren't filled in then exit.
	if (![self isCurrentWeblogSetup]) {
		NSAlert *alert = [NSAlert alertWithMessageText:[self localizedStringForKey:@"WeblogNotSetup"] defaultButton:[self localizedStringForKey:@"OK"] alternateButton:nil otherButton:nil informativeTextWithFormat:[self localizedStringForKey:@"WeblogNotSetupExplanation"], [[self currentWeblog] stringForKey:@"weblogName"]];
		[alert setShowsHelp:YES];
		[alert setDelegate:self];
		[alert runModal];
		return;
	}
	
	if ([[self password] isEqualToString:@""]) {
		[self requestAuthorization];
	}
	
	if ([[self password] isEqualToString:@""]) {
		return;
	}
	
	// Save the user's preferences
	[self savePreferences];
	
	// Reset exportCancelled to NO so that we can know whether or not the user clicks
	// the Cancel button from the progress sheet.
	exportCancelled = NO;
	
	// Tell the export controller to start the export.
	// The export controller will then call our performExport: in a new thread.
	[[exportManager exportController] startExport:nil];
}

// peformExport is called in a new thread by the export controller.
- (void)performExport:(id)fp12
{
	// Initalize our variables
	NSArray *pathComponents;
	NSData *imageData;
	NSMutableDictionary *imageDict;
	NSDate *takenDate;	
	int imageHeight;
	int imageWidth;
	int thumbnailHeight;
	int thumbnailWidth;
	NSSize imageSize;
	NSSize photoSize;
	NSSize thumbnailSize;
	NSSize thumbnailerPhotoSize;
	NSSize thumbnailerThumbnailSize;
	NSString *tempname;
	int uploadIndex;
	NSMutableDictionary *mediaObject;
	NSMutableDictionary *contentStruct;
	XMLRPCResponse *response;
	NSString *photoName;
	NSString *thumbnailName;
	NSString *photoURL = @"";
	NSString *thumbnailURL = @"";
	NSString *postId;
	NSString *title;
	NSMutableDictionary *photoDict;
	NSEnumerator *entryOptionDestinationEnumerator;
	NSDictionary *entryOption;
	NSString *altTag;
	NSString *titleTag;
	NSArray *entryOptions = [entryOptionViews entryOptions];
	NSMutableString *uploadPath;
	NSArray *exportedCategories = [NSArray array];
	NSArray *keyWordArray;
	NSMutableString *keyWords;
	BOOL usingiPhoto4 = [exportManager respondsToSelector: @selector(imageDictionaryAtIndex:)];
	

	//if ([categoryPopUpButton indexOfSelectedItem] > 0) {
	//	category = [[self categories] objectAtIndex:([categoryPopUpButton indexOfSelectedItem] - 1)];
	//} else {
	//	category = [NSDictionary dictionary];
	//}
	
	NSString *weblogPassword = [self password];

	NSDictionary *weblog = [self currentWeblog];
    XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithHost: [NSURL URLWithString:[weblog stringForKey:@"apiURL"]]];
	[request setUserAgent: version];
	
	int currentItem = 1;
	int totalItems = (int)[exportManager imageCount];	
	id thumbnailer = [exportManager createThumbnailer];
	[exportManager setThumbnailer:thumbnailer outputExtension:@"JPG"];

	switch ([weblog integerForKey:@"weblogPlatform"]) {
		case WPMovableType:
		case WPTypePad:
		case WPWordPress:
			exportedCategories = (NSArray *)[self mtExportCategories];
			break;
			
		case WPBlojsom:
			exportedCategories = (NSArray *)[self metaWeblogExportCategories];
			break;
	}


	// Setup the progress struct to contain the currentItem we are on, the
	// total number of items we are exporting and that we want
	// the progress indicator to not be indeterminate.
	// We are in a different thread than the main program so
	// we need to place a lock before we modify the struct and unlock
	// when we are done.
	[mProgressLock lock];
	mProgress.currentItem = currentItem;
	mProgress.totalItems = totalItems;
	mProgress.indeterminateProgress = NO;
	[mProgressLock unlock];
	
	// Single-post variables
	NSMutableString *overAllContent = nil;
	NSMutableString *overAllExcerpt = nil;
	if ([weblog integerForKey:@"singlePost"] > 0)
	{
		overAllContent = [NSMutableString stringWithFormat:@"<p>%@</p>",
				[singlePostPrologue stringValue]
			];
		overAllExcerpt = [NSMutableString string];
	}
	
	// Loop the items we are exporting.
	for (currentItem = 1; currentItem <= totalItems; currentItem++) {
		// reset the postId for the current item
		postId = nil;
		
		// If the user cancelled the export by clicking the Cancel button
		// in the progress sheet then we need to return.
		if (exportCancelled) {
			return;
		}
		
		// Update the progress struck to contain the current item we are exporting.
		// We need to place a lock before and after the modification because
		// we are in a different thread than the main program which is also
		// reading this struct.
		[mProgressLock lock];
		mProgress.currentItem = currentItem;
		[mProgressLock unlock];
		
		// Do our stuff here.
		uploadIndex = currentItem - 1;
		
		// Get the information about the image from iPhoto
		if (usingiPhoto4) {
			imageDict = [exportManager imageDictionaryAtIndex: uploadIndex];
			
			// Get the keywords for the image
			keyWords = [NSMutableString stringWithString:@""];
			keyWordArray = [imageDict objectForKey:@"KeyWords"];
			int i;
			for(i=0; i < [keyWordArray count]; i++) {
				[keyWords appendFormat:@"%@ ", [[keyWordArray objectAtIndex: i] stringValue]];
			}

			// Get the date the photo was taken
			takenDate = [NSDate dateWithTimeIntervalSince1970:[[imageDict objectForKey:@"Since70Interval"] doubleValue]];
			if (takenDate == nil) {
				takenDate = [NSDate date];
			}
		
		} else {
			imageDict = [NSMutableDictionary dictionary];
			keyWords = [NSMutableString stringWithString: [[exportManager imageKeywordsAtIndex: uploadIndex] componentsJoinedByString:@" "]];
			[imageDict setObject: [exportManager imageCommentsAtIndex: uploadIndex] forKey:@"Annotation"];
			
			@try
			{
				[imageDict setObject: [exportManager imageTitleAtIndex:uploadIndex] forKey:@"Caption"];
			} @catch (NSException *e) {
				NSLog(@"Using iPhoto 6.0");
				[imageDict setObject: [exportManager imageCaptionAtIndex:uploadIndex] forKey:@"Caption"];
			}
			
			// Get the date the photo was taken
			takenDate = [exportManager imageDateAtIndex: uploadIndex];
			if (takenDate == nil) {
				takenDate = [NSDate date];
			}
		}
		
		
		
		// Get the filename of the photo
		pathComponents = [[exportManager imagePathAtIndex:uploadIndex] pathComponents];
		
		imageSize = [exportManager imageSizeAtIndex:uploadIndex];
		
		imageWidth = ([imageWidthFormCell intValue] == 0) ? ([weblog integerForKey:@"imageWidth"] > 0 ) ? [weblog integerForKey:@"imageWidth"] : imageSize.width : [imageWidthFormCell intValue];
		imageHeight = ([imageHeightFormCell intValue] == 0) ? ([weblog integerForKey:@"imageHeight"] > 0) ? [weblog integerForKey:@"imageHeight"] : imageSize.height : [imageHeightFormCell intValue];
		thumbnailWidth = ([thumbnailWidthFormCell intValue] == 0) ? ([weblog integerForKey:@"thumbnailWidth"] > 0) ? [weblog integerForKey:@"thumbnailWidth"] : imageSize.width : [thumbnailWidthFormCell intValue];
		thumbnailHeight = ([thumbnailHeightFormCell intValue] == 0) ? ([weblog integerForKey:@"thumbnailHeight"] > 0) ? [weblog integerForKey:@"thumbnailHeight"] : imageSize.height : [thumbnailHeightFormCell intValue];
		
		// Get the Photo and Thumbnail Size
		if ((imageWidth / [exportManager imageAspectRatioAtIndex:uploadIndex]) > imageHeight) {
			photoSize = NSMakeSize(imageHeight * [exportManager imageAspectRatioAtIndex:uploadIndex], imageHeight);
		} else {
			photoSize = NSMakeSize(imageWidth, imageWidth / [exportManager imageAspectRatioAtIndex:uploadIndex]);
		}
		
		//NSLog(@"expected: %2fx%2f", photoSize.width, photoSize.height);
		
		if ((thumbnailWidth / [exportManager imageAspectRatioAtIndex:uploadIndex]) > thumbnailHeight) {
			thumbnailSize = NSMakeSize(thumbnailHeight * [exportManager imageAspectRatioAtIndex:uploadIndex], thumbnailHeight);
		} else {
			thumbnailSize = NSMakeSize(thumbnailWidth, thumbnailWidth / [exportManager imageAspectRatioAtIndex:uploadIndex]);
		}
		
		// Get the title of the photo. If there isn't one then use the filename.
		if ([[imageDict stringForKey:@"Caption"] isEqualToString:@""]) {
			title = [pathComponents lastObject];
		} else {
			title = [imageDict stringForKey:@"Caption"];
		}
		
		// Set the name to use for the photo once uploaded
		switch ([weblog integerForKey:@"imageNaming"]) {
			case INUseTitle:
				photoName = [title stringByAppendingString:@".jpg"];
				break;
			case INUseDateTaken:
				photoName = [takenDate descriptionWithCalendarFormat: @"%Y-%m-%d-%H-%M-%S.jpg" timeZone: nil locale: nil];
				break;
			default:
				photoName = [pathComponents lastObject];
				break;
		}
		
		// Handle the image upload path
		if ([weblog stringForKey:@"imageUploadPath"] != nil) {
			uploadPath = [NSMutableString stringWithString:[weblog stringForKey:@"imageUploadPath"]];
			
			// Remove any beginning slashes
			if ([uploadPath hasPrefix:@"/"]) {
				[uploadPath deleteCharactersInRange:NSMakeRange(0,1)];
			}
			
			// Add an ending slash if necessary
			if (![uploadPath hasSuffix:@"/"]) {
				[uploadPath appendString:@"/"];
			}
			
			// Concat the uploadPath to the photoName
			@try
			{
				photoName = [NSString stringWithFormat:@"%@%@", 
					[self parameterizedUploadPath:uploadPath usingDate:takenDate albumName:[exportManager albumNameAtIndex:0]], photoName
				];
			} @catch (NSException *e) {
				NSLog(@"Using iPhoto 6.0");
				photoName = [NSString stringWithFormat:@"%@%@", 
					[self parameterizedUploadPath:uploadPath usingDate:takenDate albumName:[exportManager albumName]], photoName
				];
			}
		}
		
		// Set the name to use for the thumbnail once uploaded
		switch ([weblog integerForKey:@"imageNaming"]) {
			case TNUseTitle:
				thumbnailName = [title stringByAppendingString:@".jpg"];
				break;
			case TNUseDateTaken:
				thumbnailName = [takenDate descriptionWithCalendarFormat: @"%Y-%m-%d-%H-%M-%S.jpg" timeZone: nil locale: nil];
				break;
			default:
				thumbnailName = [pathComponents lastObject];
				break;
		}
		
		// Handle the thumbnail upload path
		if ([weblog stringForKey:@"thumbnailUploadPath"] != nil) {
			uploadPath = [NSMutableString stringWithString:[weblog stringForKey:@"thumbnailUploadPath"]];
			
			// Remove any beginning slashes
			if ([uploadPath hasPrefix:@"/"]) {
				[uploadPath deleteCharactersInRange:NSMakeRange(0,1)];
			}
			
			// Add an ending slash if necessary
			if (![uploadPath hasSuffix:@"/"]) {
				[uploadPath appendString:@"/"];
			}
			
			// Concat the uploadPath to the photoName
			@try
			{
				thumbnailName = [NSString stringWithFormat:@"%@%@", 
						[self parameterizedUploadPath:uploadPath usingDate:takenDate albumName:[exportManager albumNameAtIndex:0]], 
						thumbnailName
					];
			} @catch (NSException *e) {
				NSLog(@"Using iPhoto 6.0");
				thumbnailName = [NSString stringWithFormat:@"%@%@", 
						[self parameterizedUploadPath:uploadPath usingDate:takenDate albumName:[exportManager albumName]], 
						thumbnailName
					];
			}
		}
			
		// Generate a temporary filename that will be used when resizing the images.
		tempname = [NSString stringWithFormat:@"%@/ptn.%@", NSTemporaryDirectory(), [[NSProcessInfo processInfo] globallyUniqueString]];
		
		// If the user chose to export the photo then resize and upload the photo
		if ([entryOptionViews entryOptionForSource:EOSPhoto] != nil) {
			
			// Resize the photo
			[exportManager setThumbnailer:thumbnailer maxBytes:0 maxWidth:(int)photoSize.width maxHeight:(int)photoSize.height];
			[exportManager thumbnailer:thumbnailer createThumbnail:[exportManager imagePathAtIndex:uploadIndex] dest:tempname];
			thumbnailerPhotoSize = [self lastThumbnailSize:thumbnailer];
			
			//NSLog(@"actual: %2fx%2f", thumbnailerPhotoSize.width, thumbnailerPhotoSize.height);
			
			// Get the resized photo
			imageData = [NSData dataWithContentsOfFile:tempname];
			
			// Delete the resized photo from the filesystem.
			[[NSFileManager defaultManager] removeFileAtPath:tempname handler:nil];
			
			mediaObject = [[NSMutableDictionary alloc] init];
			[mediaObject setObject:photoName forKey:@"name"];
			[mediaObject setObject:@"image/jpeg" forKey:@"type"];
			[mediaObject setObject:imageData forKey:@"bits"];
			[mediaObject setObject:takenDate forKey:@"dateCreated"];
			
			NSArray *params = [NSArray arrayWithObjects: [self currentWeblogId], [weblog stringForKey:@"userName"], weblogPassword, mediaObject, nil];
			//NSLog(@"Current URL %@", [weblog stringForKey:@"apiURL"]);
			
			[request setMethod:@"metaWeblog.newMediaObject" withObjects:params];
			[mediaObject release];
			//NSLog(@"Log 1");
			//NSLog(@"This is the request 1: %@", ([[request source] hasSuffix:@"</medthodCall>"]) ? @"YEY" : @"BOO");
			response = [XMLRPCConnection sendSynchronousXMLRPCRequest:request];
			if (response != nil) {
				if ([response isFault]) {
					//NSLog(@"Photon: XML-RPC Fault for photo metaWeblog.newMediaObject: %@", [response fault]);
					[mProgressLock lock];
					mProgress.currentItem = totalItems;
					mProgress.message = [[NSString alloc] initWithFormat:@"Server Error: %@", [response code]];
					[mProgressLock unlock];
					break;
				}else {
					photoURL = [[response object] objectForKey:@"url"];
					//NSLog(@"Response: %@", [response object]);
				}
			} else{
				//NSLog(@"Photon: Response object is nil for photo metaWeblog.newMediaObject");
				[mProgressLock lock];
				mProgress.currentItem = totalItems;
				mProgress.message = [[NSString alloc] initWithFormat:@"Server Error"];
				[mProgressLock unlock];
				break;
			}
			
		}
		
		// If Requested create and upload the thumbnail
		if ([entryOptionViews entryOptionForSource:EOSThumbnail] != nil) {
		
			// Resize the thumbnail
			[exportManager setThumbnailer:thumbnailer maxBytes:0 maxWidth:(int)thumbnailSize.width maxHeight:(int)thumbnailSize.height];
			[exportManager thumbnailer:thumbnailer createThumbnail:[exportManager imagePathAtIndex:uploadIndex] dest:tempname];
			thumbnailerThumbnailSize = [self lastThumbnailSize:thumbnailer];
			
			// Get the resized thumbnail
			imageData = [NSData dataWithContentsOfFile:tempname];
			
			// Remote the resized thumbnail from the filesystem
			[[NSFileManager defaultManager] removeFileAtPath:tempname handler:nil];
			
			
			mediaObject = [[NSMutableDictionary alloc] init];
			if ([weblog integerForKey:@"modifyThumbnailName"] > 0) {
				[mediaObject setObject:[NSString stringWithFormat:@"%@-thumbnail.jpg", [thumbnailName substringWithRange:NSMakeRange(0, [thumbnailName length] - 4)]] forKey:@"name"];
			} else {
				[mediaObject setObject:thumbnailName forKey:@"name"];
			}
			
			[mediaObject setObject:@"image/jpeg" forKey:@"type"];
			[mediaObject setObject:imageData forKey:@"bits"];
			[mediaObject setObject:takenDate forKey:@"dateCreated"];
			
			[request setMethod:@"metaWeblog.newMediaObject" withObjects:[NSArray arrayWithObjects: [self currentWeblogId], [weblog stringForKey:@"userName"], weblogPassword, mediaObject, nil]];
			[mediaObject release];
			//NSLog(@"Log 2");
			//NSLog(@"This is the request: %@", request);
			response = [XMLRPCConnection sendSynchronousXMLRPCRequest:request];
			if (response != nil) {
				if ([response isFault]) {
					//NSLog(@"Photon: XML-RPC Fault for thumbnail metaWeblog.newMediaObject: %@", [response fault]);
					[mProgressLock lock];
					mProgress.currentItem = totalItems;
					mProgress.message = [[NSString alloc] initWithFormat:@"Server Error: %@", [response code]];
					[mProgressLock unlock];
					break;
				}else {
					thumbnailURL = [[response object] objectForKey:@"url"];
					//NSLog(@"Response: %@", [response object]);
				}
			} else{
				//NSLog(@"Photon: Response object is nil for thumbnail metaWeblog.newMediaObject");
				[mProgressLock lock];
				mProgress.currentItem = totalItems;
				mProgress.message = [[NSString alloc] initWithFormat:@"Server Error"];
				[mProgressLock unlock];
				break;
			}
			
			
		}
		
		// Initialize and populate the dictionary that will hold all of the photo information
		photoDict = [NSMutableDictionary dictionary];
		[photoDict setObject:[takenDate descriptionWithCalendarFormat: @"%Y-%m-%d %H:%M:%S" timeZone: nil locale: nil] forKey:@"dateTaken"];
		[photoDict setObject:photoName forKey:@"filename"];
		
		@try
		{
			[photoDict setObject:[[exportManager albumNameAtIndex:0] stringByEscapingHTMLEntities] forKey:@"albumName"];
		} @catch (NSException *e) {
			NSLog(@"Using iPhoto 6.0");
			[photoDict setObject:[[exportManager albumName] stringByEscapingHTMLEntities] forKey:@"albumName"];
		}
		[photoDict setObject:[NSString stringWithFormat:@"%@", [[imageDict stringForKey:@"Annotation"] stringByEscapingHTMLEntities]] forKey:@"comments"];
		[photoDict setObject:[title stringByEscapingHTMLEntities] forKey:@"title"];
		[photoDict setObject:[keyWords stringByEscapingHTMLEntities] forKey:@"keyWords"];
		
		// Get the alt and title tags that are used by the photoURL and thumbnailURLs
		if ([entryOptionViews entryOptionForDestination:EODAltAttribute] != nil) {
			altTag = [self entryOptionSource:[[entryOptionViews entryOptionForDestination:EODAltAttribute] integerForKey:@"source"] fromDictionary:photoDict];
		} else {
			altTag = title;
		}
		if ([entryOptionViews entryOptionForDestination:EODTitleAttribute] != nil) {
			titleTag = [NSString stringWithFormat:@" title=\"%@\"", [[self entryOptionSource:[[entryOptionViews entryOptionForDestination:EODTitleAttribute] integerForKey:@"source"] fromDictionary:photoDict] stringByEscapingHTMLEntities]];
		} else {
			titleTag = @"";
		}
		//NSLog(@"SinglePost: %d", [weblog integerForKey:@"singlePost"]);
		// If one picture per post
		if ([weblog integerForKey:@"singlePost"] <= 0)
		{
		
			[photoDict setObject:[NSString stringWithFormat:@"<img alt=\"%@\"%@ src=\"%@\" width=\"%d\" height=\"%d\" />", [altTag stringByEscapingHTMLEntities], titleTag, photoURL, (int)thumbnailerPhotoSize.width, (int)thumbnailerPhotoSize.height] forKey:@"photoURL"];
			[photoDict setObject:[NSString stringWithFormat:@"<img alt=\"%@\"%@ src=\"%@\" width=\"%d\" height=\"%d\" />", [altTag stringByEscapingHTMLEntities], titleTag, thumbnailURL, (int)thumbnailerThumbnailSize.width, (int)thumbnailerThumbnailSize.height] forKey:@"thumbnailURL"];
			
			
			// Create and post the entry for the photo
			contentStruct = [[NSMutableDictionary alloc] init];

			// Enumerate the options for the entry and build the contentStruct
			// NSLog(@"Entry: %@", entryOptions);
			entryOptionDestinationEnumerator = [entryOptions objectEnumerator];
			
			while (entryOption = [entryOptionDestinationEnumerator nextObject]) {
				// If the entry option destination is a contentStruct element then populate the contentStruct
				if ([self entryOptionDestination:[[entryOption objectForKey:@"destination"] intValue]] != nil) {
					[contentStruct setObject:[self entryOptionSource:[[entryOption objectForKey:@"source"] intValue] fromDictionary:photoDict] forKey:[self entryOptionDestination:[[entryOption objectForKey:@"destination"] intValue]]];
				}
			}
			
			if ([weblog integerForKey:@"usePhotoDateForEntryDate"] > 0) {
				[contentStruct setObject:takenDate forKey:@"dateCreated"];
			}
			
			if ([categoryPopUpButton indexOfSelectedItem] > 0) { 
				switch ([weblog integerForKey:@"weblogPlatform"]) {
					case WPMovableType:
					case WPTypePad:
					case WPWordPress:
						//NSLog(@"Content Struct: %@", contentStruct);
						[request setMethod:@"metaWeblog.newPost" withObjects:[NSArray arrayWithObjects: [self currentWeblogId], [weblog stringForKey:@"userName"], weblogPassword, contentStruct, kCFBooleanTrue, nil]];
						break;
						
					case WPBlojsom:
						[contentStruct setObject:exportedCategories forKey:@"categories"];
						[request setMethod:@"metaWeblog.newPost" withObjects:[NSArray arrayWithObjects: [exportedCategories objectAtIndex:0], [weblog stringForKey:@"userName"], weblogPassword, contentStruct, kCFBooleanTrue, nil]];
						break;
				}
			} else {
				[request setMethod:@"metaWeblog.newPost" withObjects:[NSArray arrayWithObjects: [self currentWeblogId], [weblog stringForKey:@"userName"], weblogPassword, contentStruct, kCFBooleanTrue, nil]];
			}
			
			[contentStruct release];
			//NSLog(@"Log 3");
			//NSLog(@"This is the request: %@", request);
			response = [XMLRPCConnection sendSynchronousXMLRPCRequest:request];
			if (response != nil) {
				if ([response isFault]) {
					NSLog(@"Photon: XML-RPC Fault for metaWeblog.newPost: %@", [response fault]);
					[mProgressLock lock];
					mProgress.currentItem = totalItems;
					mProgress.message = [[NSString alloc] initWithFormat:@"Server Error: %@", [response code]];
					[mProgressLock unlock];
					break;
				}else {
					postId = [response object];
					//NSLog(@"Response: %@", [response object]);
				}
			} else{
				NSLog(@"Photon: Response object is nil for metaWeblog.newPost");
				[mProgressLock lock];
				mProgress.currentItem = totalItems;
				mProgress.message = [[NSString alloc] initWithFormat:@"Server Error"];
				[mProgressLock unlock];
				break;
			}
			
			// Set the post category if necessary
			if (([categoryPopUpButton indexOfSelectedItem] > 0) && (postId != nil)) {
				switch ([weblog integerForKey:@"weblogPlatform"]) {
					case WPMovableType:
					case WPTypePad:
					case WPWordPress:
						[request setMethod:@"mt.setPostCategories" withObjects:[NSArray arrayWithObjects: postId, [weblog stringForKey:@"userName"], weblogPassword, exportedCategories, nil]];
						//NSLog(@"Log 4");
						//NSLog(@"This is the request: %@", request);
						response = [XMLRPCConnection sendSynchronousXMLRPCRequest:request];
						if (response != nil) {
							if ([response isFault]) {
								NSLog(@"Photon: XML-RPC Fault for metaWeblog.setPostCategories: %@", [response fault]);
								[mProgressLock lock];
								mProgress.currentItem = totalItems;
								mProgress.message = [[NSString alloc] initWithFormat:@"Server Error: %@", [response code]];
								[mProgressLock unlock];
								break;
							}else {
								//NSLog(@"Response: %@", [response object]);
							}
						} else{
							NSLog(@"Photon: Response object is nil for metaWeblog.setPostCategories");
							[mProgressLock lock];
							mProgress.currentItem = totalItems;
							mProgress.message = [[NSString alloc] initWithFormat:@"Server Error"];
							[mProgressLock unlock];
							break;
						}
							
							
						[request setMethod:@"mt.publishPost" withObjects:[NSArray arrayWithObjects: postId, [weblog stringForKey:@"userName"], weblogPassword, nil]];
						//NSLog(@"Log 5");
						//NSLog(@"This is the request: %@", request);
						response = [XMLRPCConnection sendSynchronousXMLRPCRequest:request];
						if (response != nil) {
							if ([response isFault]) {
								NSLog(@"Photon: XML-RPC Fault for mt.publishPost: %@", [response fault]);
								[mProgressLock lock];
								mProgress.currentItem = totalItems;
								mProgress.message = [[NSString alloc] initWithFormat:@"Server Error: %@", [response code]];
								[mProgressLock unlock];
								break;
							}else {
								//NSLog(@"Response: %@", [response object]);
							}
						} else{
							NSLog(@"Photon: Response object is nil for mt.publishPost");
							[mProgressLock lock];
							mProgress.currentItem = totalItems;
							mProgress.message = [[NSString alloc] initWithFormat:@"Server Error"];
							[mProgressLock unlock];
							break;
						}
						
						break;
				}
				
			}
		}
		else // if one post for all pictures
		{
			[overAllContent appendFormat:@"<img alt=\"%@\"%@ src=\"%@\" width=\"%d\" height=\"%d\" />", 
					[altTag stringByEscapingHTMLEntities], titleTag, photoURL, 
					(int)thumbnailerPhotoSize.width, (int)thumbnailerPhotoSize.height
			];
			
			// Append the comments as caption
			[overAllContent appendFormat:@"<p align=\"center\">%@</p><p>&nbsp;</p>", 
					[NSString stringWithFormat:@"%@", 
						[[imageDict stringForKey:@"Annotation"] stringByEscapingHTMLEntities]] 
			];
			
			[overAllExcerpt appendFormat:@"<img alt=\"%@\"%@ src=\"%@\" width=\"%d\" height=\"%d\" /><br/>", 
				[altTag stringByEscapingHTMLEntities], titleTag, thumbnailURL, 
				(int)thumbnailerThumbnailSize.width, (int)thumbnailerThumbnailSize.height
			];
		}
		
	}
	
	if ([weblog integerForKey:@"singlePost"] > 0) 
	{
	
		[photoDict setObject:overAllContent forKey:@"photoURL"];
		[photoDict setObject:overAllExcerpt forKey:@"thumbnailURL"];
		
		
		// Create and post the entry for the photo
		contentStruct = [[NSMutableDictionary alloc] init];

		// Enumerate the options for the entry and build the contentStruct
		//NSLog(@"Entry: %@", entryOptions);
		entryOptionDestinationEnumerator = [entryOptions objectEnumerator];
		
		while (entryOption = [entryOptionDestinationEnumerator nextObject]) {
			// If the entry option destination is a contentStruct element then populate the contentStruct
			if ([self entryOptionDestination:[[entryOption objectForKey:@"destination"] intValue]] != nil) {
				[contentStruct setObject:[self entryOptionSource:[[entryOption objectForKey:@"source"] intValue] fromDictionary:photoDict] forKey:[self entryOptionDestination:[[entryOption objectForKey:@"destination"] intValue]]];
			}
		}
		
		// Force contentStruct's title value as the singlePostTitle's value
		[contentStruct setObject:[singlePostTitle stringValue] forKey:@"title"];
		
		if ([weblog integerForKey:@"usePhotoDateForEntryDate"] > 0) {
			[contentStruct setObject:takenDate forKey:@"dateCreated"];
		}
		
		if ([categoryPopUpButton indexOfSelectedItem] > 0) { 
			switch ([weblog integerForKey:@"weblogPlatform"]) {
				case WPMovableType:
				case WPTypePad:
				case WPWordPress:
					//NSLog(@"Content Struct: %@", contentStruct);
					[request setMethod:@"metaWeblog.newPost" withObjects:[NSArray arrayWithObjects: [self currentWeblogId], [weblog stringForKey:@"userName"], weblogPassword, contentStruct, kCFBooleanTrue, nil]];
					break;
					
				case WPBlojsom:
					[contentStruct setObject:exportedCategories forKey:@"categories"];
					[request setMethod:@"metaWeblog.newPost" withObjects:[NSArray arrayWithObjects: [exportedCategories objectAtIndex:0], [weblog stringForKey:@"userName"], weblogPassword, contentStruct, kCFBooleanTrue, nil]];
					break;
			}
		} else {
			[request setMethod:@"metaWeblog.newPost" withObjects:[NSArray arrayWithObjects: [self currentWeblogId], [weblog stringForKey:@"userName"], weblogPassword, contentStruct, kCFBooleanTrue, nil]];
		}
		
		[contentStruct release];
		//NSLog(@"Log 6");
		//NSLog(@"This is the request: %@", request);
		response = [XMLRPCConnection sendSynchronousXMLRPCRequest:request];
		if (response != nil) {
			if ([response isFault]) {
				NSLog(@"Photon: XML-RPC Fault for metaWeblog.newPost: %@", [response fault]);
				[mProgressLock lock];
				mProgress.currentItem = totalItems;
				mProgress.message = [[NSString alloc] initWithFormat:@"Server Error: %@", [response code]];
				[mProgressLock unlock];
				return;
			}else {
				postId = [response object];
				//NSLog(@"Response: %@", [response object]);
			}
		} else{
			NSLog(@"Photon: Response object is nil for metaWeblog.newPost");
			[mProgressLock lock];
			mProgress.currentItem = totalItems;
			mProgress.message = [[NSString alloc] initWithFormat:@"Server Error"];
			[mProgressLock unlock];
			return;
		}
		
		// Set the post category if necessary
		if (([categoryPopUpButton indexOfSelectedItem] > 0) && (postId != nil)) {
			switch ([weblog integerForKey:@"weblogPlatform"]) {
				case WPMovableType:
				case WPTypePad:
				case WPWordPress:
					[request setMethod:@"mt.setPostCategories" withObjects:[NSArray arrayWithObjects: postId, [weblog stringForKey:@"userName"], weblogPassword, exportedCategories, nil]];
					NSLog(@"Log 7");
					NSLog(@"This is the request: %@", request);
					response = [XMLRPCConnection sendSynchronousXMLRPCRequest:request];
					if (response != nil) {
						if ([response isFault]) {
							NSLog(@"Photon: XML-RPC Fault for metaWeblog.setPostCategories: %@", [response fault]);
							[mProgressLock lock];
							mProgress.currentItem = totalItems;
							mProgress.message = [[NSString alloc] initWithFormat:@"Server Error: %@", [response code]];
							[mProgressLock unlock];
							break;
						}else {
							//NSLog(@"Response: %@", [response object]);
						}
					} else{
						NSLog(@"Photon: Response object is nil for metaWeblog.setPostCategories");
						[mProgressLock lock];
						mProgress.currentItem = totalItems;
						mProgress.message = [[NSString alloc] initWithFormat:@"Server Error"];
						[mProgressLock unlock];
						break;
					}
						
						
					[request setMethod:@"mt.publishPost" withObjects:[NSArray arrayWithObjects: postId, [weblog stringForKey:@"userName"], weblogPassword, nil]];
					//NSLog(@"Log 8");
					//NSLog(@"This is the request: %@", request);
					response = [XMLRPCConnection sendSynchronousXMLRPCRequest:request];
					if (response != nil) {
						if ([response isFault]) {
							NSLog(@"Photon: XML-RPC Fault for mt.publishPost: %@", [response fault]);
							[mProgressLock lock];
							mProgress.currentItem = totalItems;
							mProgress.message = [[NSString alloc] initWithFormat:@"Server Error: %@", [response code]];
							[mProgressLock unlock];
							break;
						}else {
							//NSLog(@"Response: %@", [response object]);
						}
					} else{
						NSLog(@"Photon: Response object is nil for mt.publishPost");
						[mProgressLock lock];
						mProgress.currentItem = totalItems;
						mProgress.message = [[NSString alloc] initWithFormat:@"Server Error"];
						[mProgressLock unlock];
						break;
					}
					
					break;
			}
			
		}
	}

		
	[thumbnailer release];
	
	// We are done exporting so we need to let the progress
	// struct know we are done by setting the shouldStop property to YES.
	// This will cause the progress sheet and the export dialog to 
	// go away.
	// We need to place a lock before and after the modification because
	// we are in a different thread than the main program which is also
	// reading this struct.
	[mProgressLock lock];
	if (![mProgress.message hasPrefix:@"Server Error"]) {
		mProgress.shouldStop = YES;
	}
	[mProgressLock unlock];
	
}

// progress is called by the export controller during the export process.
// The export controller will call lockProgress before calling this method
// and will call unlockProgress after it has called this method.
// lockProgress and unlockProgress should place a lock and unlock 
// so that we don't have to worry about thread locking in this method.
- (CDAnonymousStruct1 *)progress
{
	// Create a message that will be displayed in the progress sheet.
	// Note:	We have to do this with a string that will not be released by us
	//			as the export controller will be releasing this string.
	
	if (![mProgress.message hasPrefix:@"Server Error"]) {
		NSString *message = [[NSString alloc] initWithFormat:@"Photo %d of %d", mProgress.currentItem, mProgress.totalItems];
		mProgress.message = message;
	}

	return &mProgress;
}

// lockProgress is called by the export controller before it makes
// a call to our progress method.
- (void)lockProgress
{
	// Place our lock
	[mProgressLock lock];
}

// unlockProgress is called by the export controller after it makes
// a call to our progress method.
- (void)unlockProgress
{
	// Release our lock
	[mProgressLock unlock];
}


// cancelExport is called when the user clicks the Cancel
// button in the progress sheet.
- (void)cancelExport
{
	// Set our internal variable so that we know
	// that the user decided to cancel the export.
    exportCancelled = YES;
}

- (id)name
{
    return @"Photon";
}

- (id)description
{
    return @"Plugin for creating PhotoBlogs";
}

- (IBAction)showAccountSheet:(id)sender
{
	// Reset the accountChanged variable
	accountChanged = NO;
	
	[self setPreviousPassword:[self password]];
	
	// Save the current weblogs so that they can be undone later
	[self setUndoWeblogs:[self cloneWeblogs:[self weblogs]]];
	
	// Set entry options for the weblog
	[entryOptionViews removeAllEntryOptionViews];
	[self loadEntryOptionViews];
	
	// If there is already an account defined then load the password for it,
	// otherwise add a new blank account so that it is ready for user input.
	if ([[self weblogs] count] > 0) {
		[passwordSecureTextField setStringValue:[self password]];
		previousWeblogIndex = [weblogPopUpButton indexOfSelectedItem];
	} else {
		[self addAccount:self];
		previousWeblogIndex = NSNotFound;
	}
	
    [NSApp beginSheet: accountSheet
	   modalForWindow: [settingsView window]
		modalDelegate: self
	   didEndSelector: nil
		  contextInfo: nil];
	
    [NSApp runModalForWindow: accountSheet];
    // Sheet is up here.
	
    [NSApp endSheet: accountSheet];
    [accountSheet orderOut: [settingsView window]];
}

- (IBAction)showAccountHelp:(id)sender
{
	AHGotoPage((CFStringRef)@"Photon Help", (CFStringRef)@"helpdocs/Adding_a_weblog_account.html", (CFStringRef)@"MyApp001");
}

- (IBAction)closeAccountSheet:(id)sender
{
	//NSLog(@"%@", [[undoWeblogs objectAtIndex:0] stringForKey:@"weblogName"]);
	// Undo the user's changes
	[self undoAccountChanges:undoWeblogs];
	
	// If there aren't any weblogs defined then add a None defined to the
	// weblog popup
	if ([[self weblogs] count] <= 0) {
		[weblogPopUpButton addItemWithTitle:[self localizedStringForKey:@"NoneDefined"]];
		[[NSRunLoop currentRunLoop] addTimer:[NSTimer timerWithTimeInterval:2.00 target:self selector:@selector(refreshCategories:) userInfo:nil repeats:NO] forMode:NSModalPanelRunLoopMode];
	} else if (accountChanged == YES) {
		[[NSRunLoop currentRunLoop] addTimer:[NSTimer timerWithTimeInterval:2.00 target:self selector:@selector(refreshCategories:) userInfo:nil repeats:NO] forMode:NSModalPanelRunLoopMode];
	}
	
	[NSApp stopModal];
}

- (IBAction)showCategorySheet:(id)sender
{
	if (!categorySheet)
        [NSBundle loadNibNamed: @"Category" owner: self];
	
    [NSApp beginSheet: categorySheet
	   modalForWindow: [settingsView window]
		modalDelegate: self
	   didEndSelector: nil
		  contextInfo: nil];
	
	@try
	{
		[categoryNameTextField setStringValue:[exportManager albumNameAtIndex:0]];
	} @catch (NSException *e) {
		NSLog(@"Using iPhoto 6.0");
		[categoryNameTextField setStringValue:[exportManager albumName]];
	}
	
    [NSApp runModalForWindow: categorySheet];
    // Sheet is up here.
	
    [NSApp endSheet: categorySheet];
    [categorySheet orderOut: [settingsView window]];
}

- (IBAction)closeCategorySheet:(id)sender
{
	[NSApp stopModal];
}

- (IBAction)refreshCategories:(id)sender
{
	NSEnumerator *categoryEnumerator;
	NSDictionary *category;
	NSString *categoryName;
	NSMenuItem *categoryMenuItem;
	
	if (([self weblogCount] <= 0) || (![self isCurrentWeblogSetup])) { 
		[categoryPopUpButton removeAllItems];
		[categoryPopUpButton addItemWithTitle:[self localizedStringForKey:@"Default"]];
		[categoryPopUpButton display];
		
		return; 
	}
			
	[self setCategories:[[NSMutableArray alloc] init]];
	indexOfSelectedCategory = NSNotFound;
	[self setExportCategories:[[NSMutableArray alloc] init]];
	
	NSString *weblogPassword;
	
	if ([[self password] isEqualToString:@""]) {
		[self requestAuthorization];
	}
	
	if ([[self password] isEqualToString:@""]) {
		[categoryPopUpButton removeAllItems];
		[categoryPopUpButton addItemWithTitle:[self localizedStringForKey:@"Default"]];
		[categoryPopUpButton display];
		return;
	} else {
		weblogPassword = [self password];
	}
	
	[offlineAlertButton setHidden:YES];
	[[offlineAlertButton superview] display];
	[self mouseExited:nil];
	
	[refreshCategoryProgressIndicator setUsesThreadedAnimation:YES];
	[refreshCategoryProgressIndicator startAnimation:self];
	
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]]; 
	
	if ([self isNetworkConnectionOK]) {
		[offlineAlertButton setHidden:YES];
		if (offlineTrackingTag) {
			[offlineAlertButton removeTrackingRect:offlineTrackingTag];
		}
		offlineTrackingTag = 0;
		[[offlineAlertButton superview] display];
	} else {
		[refreshCategoryProgressIndicator stopAnimation:self];
		[offlineAlertButton setHidden:NO];
		if (!offlineTrackingTag) {
			offlineTrackingTag = [offlineAlertButton addTrackingRect:[offlineAlertButton bounds] owner:self userData:nil assumeInside:NO];
		}
		return;
	}

	[categoryPopUpButton setEnabled:NO];
	[categoryPopUpButton removeAllItems];
	[categoryPopUpButton addItemWithTitle:[self localizedStringForKey:@"Retrieving"]];
	[categoryPopUpButton display];
	
	NSDictionary *weblog = [self currentWeblog];
	
	NSLog(@"Weblog info: %@", weblog);
	
    XMLRPCRequest *request = [[XMLRPCRequest alloc] initWithHost: [NSURL URLWithString:[weblog stringForKey:@"apiURL"]]];
	
	switch ([weblog integerForKey:@"weblogPlatform"]) {
		case WPMovableType:
		case WPTypePad:
		case WPWordPress:
			[request setMethod:@"mt.getCategoryList" withObjects:[NSArray arrayWithObjects: [self currentWeblogId], [weblog stringForKey:@"userName"], weblogPassword, nil]];
			break;
		case WPBlojsom:
			[request setMethod:@"metaWeblog.getCategories" withObjects:[NSArray arrayWithObjects: [self currentWeblogId], [weblog stringForKey:@"userName"], weblogPassword, nil]];
			break;
	}
	
	[request setUserAgent: version];

    XMLRPCResponse *response = [XMLRPCConnection sendSynchronousXMLRPCRequest:request];
	
	if (response != nil) {
        if ([response isFault]) {
			[categoryPopUpButton removeAllItems];
			[categoryPopUpButton addItemWithTitle:[self localizedStringForKey:@"Default"]];
			[categoryPopUpButton display];
			
			NSLog(@"Fault: %@", [response fault]);
			NSAlert *alert = [NSAlert alertWithMessageText:[self localizedStringForKey:@"CategoryRetrievalFailed"] defaultButton:[self localizedStringForKey:@"OK"] alternateButton:nil otherButton:nil informativeTextWithFormat:[self localizedStringForKey:@"CategoryRetrievalFailedExplanation"], [weblog stringForKey:@"weblogName"], [response fault]];
			[alert runModal];
        }else {
			[categoryPopUpButton removeAllItems];
			[categoryPopUpButton addItemWithTitle:[self localizedStringForKey:@"Default"]];
			

			switch ([weblog integerForKey:@"weblogPlatform"]) {
				case WPMovableType:
				case WPTypePad:
				case WPWordPress:
					[self setCategories:[response object]];
					break;
						
				case WPBlojsom:
					categoryEnumerator = [[response object] keyEnumerator];
					while (categoryName = [categoryEnumerator nextObject]) {
						[[self categories] addObject:[NSDictionary dictionaryWithObject:categoryName forKey:@"categoryName"]];
					}
					break;
			}
			
			// Add the categories to the popup button and the array controller.
			categoryEnumerator = [[self categories] objectEnumerator];
			while (category = [categoryEnumerator nextObject]) {
				categoryMenuItem = [[NSMenuItem alloc] init];
				[categoryMenuItem setTitle:[category stringForKey:@"categoryName"]];
				[[categoryPopUpButton menu] addItem:categoryMenuItem];
				[categoryMenuItem release];
			}
        }
    } else{
        NSLog(@"Unable to parse response.");
		[categoryPopUpButton removeAllItems];
		[categoryPopUpButton addItemWithTitle:[self localizedStringForKey:@"Default"]];
		[categoryPopUpButton display];
    }
	
	if (![[categoryNameTextField stringValue] isEqualToString:@""]) {
		if ([weblog integerForKey:@"weblogPlatform"] == WPBlojsom) {
			[categoryPopUpButton selectItemWithTitle:[NSString stringWithFormat:@"%@/", [categoryNameTextField stringValue]]];
		} else {
			[categoryPopUpButton selectItemWithTitle:[categoryNameTextField stringValue]];
		}
	}
	
	if (([categoryPopUpButton indexOfSelectedItem] <= 0) && ([[self categories] count] > 0)) {
		[categoryPopUpButton selectItemAtIndex:0];
	} else if (([categoryPopUpButton indexOfSelectedItem] > 0) && ([[self categories] count] > 0)) {
		[self selectCategory:self];
	}
	
	[categoryPopUpButton setAutoenablesItems:NO];
	categoryMenuItem = [[NSMenuItem alloc] init];
	[[categoryPopUpButton menu] addItem:[NSMenuItem separatorItem]];
	
	[categoryMenuItem setTitle:[self localizedStringForKey:@"SelectMultiple"]];
	[categoryMenuItem setTarget:self];
	[categoryMenuItem setAction:@selector(showCategoriesSheet:)];
	
	if (([[self categories] count] < 2) || ([weblog integerForKey:@"weblogPlatform"] == WPBlojsom)) {
		[categoryMenuItem setEnabled:NO];
	}
	
	[[categoryPopUpButton menu] addItem:categoryMenuItem];
	[categoryMenuItem release];
	
	[refreshCategoryProgressIndicator stopAnimation:self];
	[categoryPopUpButton setEnabled:YES];
}

- (IBAction)saveAccount:(id)sender
{	
	BOOL shouldRefreshCategories = NO;
	int weblogIndex;
	int noNameWeblogCount = 0;
	NSDictionary *weblog = [self currentWeblog];
	
	if ((![[weblog stringForKey:@"userName"] isEqual:@""]) && (![[passwordSecureTextField stringValue] isEqual:@""]) && ([weblog integerForKey:@"storePasswordInKeychain"] > 0)) {
        PTWKeychain *keychain = [[PTWKeychain alloc] init];
		// Add or replace the existing keychain password.
        [keychain addGenericPassword:[passwordSecureTextField stringValue] forAccount:[weblog stringForKey:@"userName"] forService:[NSString stringWithFormat:@"Photon: %@", [weblog stringForKey:@"weblogURL"]] replaceExisting:YES];
		[keychain release];
	}
	
	if (![[passwordSecureTextField stringValue] isEqual:@""]) {
		[self setPassword:[passwordSecureTextField stringValue]];
	} else {
		[self setPassword:@""];
	}
	
	// If there are any accounts without a name add a default name to them
	for (weblogIndex = 0; weblogIndex < [self weblogCount]; weblogIndex++) {
		if ([[[self weblogs] objectAtIndex:weblogIndex] stringForKey:@"weblogName"] == nil) {
			if (noNameWeblogCount <= 0) {
				[[[self weblogs] objectAtIndex:weblogIndex] setValue:[self localizedStringForKey:@"NewWeblog"] forKey:@"weblogName"];
			} else {
				[[[self weblogs] objectAtIndex:weblogIndex] setValue:[NSString stringWithFormat:@"%@ %d", [self localizedStringForKey:@"NewWeblog"], noNameWeblogCount] forKey:@"weblogName"];
			}
			noNameWeblogCount++;
		}
		
	}
	
	[self savePreferences];
	[self syncImageSizes];
	[NSApp stopModal];
	
	// If there were any changes that could affect the categories then refresh the categories
	if (previousWeblogIndex != NSNotFound) {
		NSDictionary *previousWeblog = [[self undoWeblogs] objectAtIndex:previousWeblogIndex];
		
		if (![[previousWeblog stringForKey:@"apiURL"] isEqualToString:[weblog stringForKey:@"apiURL"]]) {
			shouldRefreshCategories = YES;
		} else if (![[previousWeblog stringForKey:@"userName"] isEqualToString:[weblog stringForKey:@"userName"]]) {
			shouldRefreshCategories = YES;
		} else if (![[previousWeblog stringForKey:@"blogId"] isEqualToString:[weblog stringForKey:@"blogId"]]) {
			shouldRefreshCategories = YES;
		} else if ([previousWeblog integerForKey:@"weblogPlatform"] != [weblog integerForKey:@"weblogPlatform"]) {
			shouldRefreshCategories = YES;
		} else if ([previousWeblog integerForKey:@"storePasswordInKeychain"] != [weblog integerForKey:@"storePasswordInKeychain"]) {
			shouldRefreshCategories = YES;
		} else if (![[self previousPassword] isEqualToString:[self password]]) {
			shouldRefreshCategories = YES;
		}
	} else {
		shouldRefreshCategories = YES;
	}
	
	if (accountChanged == YES) {
		shouldRefreshCategories = YES;
	}
	
	if (shouldRefreshCategories) {
		[[NSRunLoop currentRunLoop] addTimer:[NSTimer timerWithTimeInterval:2.00 target:self selector:@selector(refreshCategories:) userInfo:nil repeats:NO] forMode:NSModalPanelRunLoopMode];
	}
}

- (IBAction)createCategory:(id)sender
{
	BOOL didCreateCategory = NO;
	NSDictionary *weblog = [self currentWeblog];
	
	// If the weblog is defined but the settings aren't filled in then exit.
	if (![self isCurrentWeblogSetup]) {
		NSAlert *alert = [NSAlert alertWithMessageText:[self localizedStringForKey:@"WeblogNotSetup"] defaultButton:[self localizedStringForKey:@"OK"] alternateButton:nil otherButton:nil informativeTextWithFormat:[self localizedStringForKey:@"WeblogNotSetupExplanation"], [[self currentWeblog] stringForKey:@"weblogName"]];
		[alert setShowsHelp:YES];
		[alert setDelegate:self];
		[alert runModal];
		return;
	}
	
	[createCategoryProgressTextField setStringValue:[NSString stringWithFormat:[self localizedStringForKey:@"CreatingCategory"], [categoryNameTextField stringValue]]];
	[createCategoryProgressTextField display];
	[createCategoryProgressIndicator setUsesThreadedAnimation:YES];
	[createCategoryProgressIndicator startAnimation:self];
	
	if (![self isNetworkConnectionOK]) {
		[createCategoryProgressIndicator stopAnimation:self];
		NSAlert *alert = [NSAlert alertWithMessageText:[self localizedStringForKey:@"NoInternetConnection"] defaultButton:[self localizedStringForKey:@"OK"] alternateButton:nil otherButton:nil informativeTextWithFormat:[self localizedStringForKey:@"NoInternetCreateCategory"], [weblog stringForKey:@"weblogName"]];
		[alert runModal];
		
		return;
	}
	
	if ([[categoryNameTextField stringValue] isEqualToString:@""]) {
		[createCategoryProgressIndicator stopAnimation:self];
		[createCategoryProgressTextField setStringValue:@""];
		
		NSAlert *alert = [NSAlert alertWithMessageText:[self localizedStringForKey:@"CategoryNameRequired"] defaultButton:[self localizedStringForKey:@"OK"] alternateButton:nil otherButton:nil informativeTextWithFormat:[self localizedStringForKey:@"CategoryNameRequiredExplanation"]];
		[alert runModal];
		
		return;
	}
	
	switch ([weblog integerForKey:@"weblogPlatform"]) {
		case WPMovableType:
			didCreateCategory = [self createMTCategory:[categoryNameTextField stringValue]];
			break;
		case WPTypePad:
			didCreateCategory = [self createTypePadCategory:[categoryNameTextField stringValue]];
			break;
		case WPWordPress:
			didCreateCategory = [self createWordPressCategory:[categoryNameTextField stringValue]];
			break;
		case WPBlojsom:
			didCreateCategory = [self createBlojsomCategory:[categoryNameTextField stringValue]];
			break;
	}
	
	[NSApp stopModal];
	[createCategoryProgressIndicator stopAnimation:self];
	[createCategoryProgressTextField setStringValue:@""];
	[createCategoryProgressTextField display];
	
	if (didCreateCategory) {
		[self refreshCategories:nil];
	}
}

- (IBAction)autodiscover:(id)sender
{
	NSURLRequest *request;
	NSError *error;
	NSURLResponse *response;
	NSData *responseData;
	NSURL *requestURL;
	NSURL *rsdURL;
	AGRegex *regex;
	AGRegexMatch *match;
	NSString *responseString;

	[autodiscoverProgressIndicator usesThreadedAnimation];
	[autodiscoverProgressIndicator startAnimation:self];
	
	NSDictionary *weblog = [self currentWeblog];
		
	if (![[weblog stringForKey:@"weblogURL"] hasPrefix: @"http://"] && ![[weblog stringForKey:@"weblogURL"] hasPrefix: @"https://"]) {
        [weblogArrayController setValue:[NSString stringWithFormat: @"http://%@", [weblog stringForKey:@"weblogURL"]] forKeyPath:@"selection.weblogURL"];
	}
	
	requestURL = [NSURL URLWithString:[weblog stringForKey:@"weblogURL"]];
	
	if (requestURL != nil) {
		request = [NSURLRequest requestWithURL:requestURL];

		responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
		
		if (responseData != nil) {
			responseString = [responseData stringUsingEncoding:NSUTF8StringEncoding];
			if (responseString == nil) {
				responseString = [responseData stringUsingEncoding:NSASCIIStringEncoding];
			}

			if (responseString != nil) {
				regex = [[AGRegex alloc] initWithPattern:@"<\\s*link.*type\\s*=\\s*\\\"*(application/rsd\\+xml).*href\\s*=\\s*\\\"*([^\\s\\b\\\"]+).*>" options:AGRegexCaseInsensitive];
				match = [regex findInString:responseString];
																																	
				if ([match count] > 1) {
					rsdURL = [NSURL URLWithString:[match groupAtIndex:2]];
					
					if (rsdURL != nil) {
						request = [NSURLRequest requestWithURL:rsdURL];
						responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
						
						if (responseData != nil) {
							
							responseString = [responseData stringUsingEncoding:NSUTF8StringEncoding];
							if (responseString == nil) {
								responseString = [responseData stringUsingEncoding:NSASCIIStringEncoding];
							}
							
							if (responseString != nil) {
								
								regex = [[AGRegex alloc] initWithPattern:@"<\\s*api.*name\\s*=\\s*\\\"*(metaweblog).*preferred\\s*=\\s*\\\"*(true|false).*\\s*apiLink\\s*=\\s*\\\"*([^\\s\\b\\\"]+).*\\s*blogID\\s*=\\\"*([^\\s\\b\\\"]*)\\\".*>" options:AGRegexCaseInsensitive];
								match = [regex findInString:responseString];
																																																						  
								if ([match count] > 1) {
									[weblogArrayController setValue:[match groupAtIndex:3] forKeyPath:@"selection.apiURL"];
									[weblogArrayController setValue:[match groupAtIndex:4] forKeyPath:@"selection.blogId"];

									regex = [[AGRegex alloc] initWithPattern:@"<\\s*engineLink\\s*>\\s*([^\\s\\b<]+)\\s*" options:AGRegexCaseInsensitive];
									match = [regex findInString:responseString];
									if ([match count] > 1) {
										if ( [[match groupAtIndex:1] rangeOfString:@"movabletype" options:NSCaseInsensitiveSearch].location != NSNotFound) {
											[weblogArrayController setValue:[NSNumber numberWithInt:1] forKeyPath:@"selection.weblogPlatform"];
										} else if ([[match groupAtIndex:1] rangeOfString:@"typepad" options:NSCaseInsensitiveSearch].location != NSNotFound) {
											[weblogArrayController setValue:[NSNumber numberWithInt:2] forKeyPath:@"selection.weblogPlatform"];
										} else if ([[match groupAtIndex:1] rangeOfString:@"blojsom" options:NSCaseInsensitiveSearch].location != NSNotFound) {
											[weblogArrayController setValue:[NSNumber numberWithInt:3] forKeyPath:@"selection.weblogPlatform"];
										}
										
									}
								}
							}
						}
					}
				}
			}
		}
	}

	[autodiscoverProgressIndicator stopAnimation:self];
}

- (IBAction)selectCategory:(id)sender
{
	int indexOfSelectedItem = [categoryPopUpButton indexOfSelectedItem];
	
	if ((indexOfSelectedItem > 0) && (indexOfSelectedItem <= [[self categories] count])) {
		indexOfSelectedCategory = indexOfSelectedItem - 1;
		[[self exportCategories] removeAllObjects];
		[[self exportCategories] addObject:[NSNumber numberWithInt:indexOfSelectedCategory]];
		
		if ([categoryPopUpButton indexOfItemWithTitle:[self localizedStringForKey:@"Multiple"]] != -1) {
			[categoryPopUpButton removeItemWithTitle:[self localizedStringForKey:@"Multiple"]];
		}
	} else {
		indexOfSelectedCategory = NSNotFound;
	}
}

- (IBAction)showCategoriesSheet:(id)sender
{
	[NSApp beginSheet: categoriesSheet
	   modalForWindow: [settingsView window]
		modalDelegate: self
	   didEndSelector: nil
		  contextInfo: nil];
	
	// Save the current export categories so that they can be undone later
	[self setUndoExportCategories:[self cloneExportCategories:[self exportCategories]]];
	
	[categoryTableView reloadData];
	
	if (indexOfSelectedCategory != NSNotFound) {
		[categoryTableView scrollRowToVisible:indexOfSelectedCategory];
	}
	
	[NSApp runModalForWindow: categoriesSheet];
	// Sheet is up here.
	
	[NSApp endSheet: categoriesSheet];
	[categoriesSheet orderOut: [settingsView window]];
}

- (IBAction)closeCategoriesSheet:(id)sender
{
	[self setExportCategories:undoExportCategories];
	
	if ([[self exportCategories] count] == 0) {
		[categoryPopUpButton selectItemAtIndex:0];
		
		if ([categoryPopUpButton indexOfItemWithTitle:[self localizedStringForKey:@"Multiple"]] != -1) {
			[categoryPopUpButton removeItemWithTitle:[self localizedStringForKey:@"Multiple"]];
		}
	} else if ([[self exportCategories] count] == 1) {
		[categoryPopUpButton selectItemAtIndex:[[[self exportCategories] lastObject] intValue] + 1];
		
		if ([categoryPopUpButton indexOfItemWithTitle:[self localizedStringForKey:@"Multiple"]] != -1) {
			[categoryPopUpButton removeItemWithTitle:[self localizedStringForKey:@"Multiple"]];
		}
	} else {
		[categoryPopUpButton addItemWithTitle:[self localizedStringForKey:@"Multiple"]];
		[categoryPopUpButton selectItemWithTitle:[self localizedStringForKey:@"Multiple"]];
	}
	
	[NSApp stopModal];
}

- (IBAction)useSelectedCategories:(id)sender
{
	indexOfSelectedCategory = NSNotFound;
	
	if ([[self exportCategories] count] == 0) {
		[categoryPopUpButton selectItemAtIndex:0];
		
		if ([categoryPopUpButton indexOfItemWithTitle:[self localizedStringForKey:@"Multiple"]] != -1) {
			[categoryPopUpButton removeItemWithTitle:[self localizedStringForKey:@"Multiple"]];
		}
	} else if ([[self exportCategories] count] == 1) {
		[categoryPopUpButton selectItemAtIndex:[[[self exportCategories] lastObject] intValue] + 1];

		if ([categoryPopUpButton indexOfItemWithTitle:[self localizedStringForKey:@"Multiple"]] != -1) {
			[categoryPopUpButton removeItemWithTitle:[self localizedStringForKey:@"Multiple"]];
		}
	} else {
		[categoryPopUpButton addItemWithTitle:[self localizedStringForKey:@"Multiple"]];
		[categoryPopUpButton selectItemWithTitle:[self localizedStringForKey:@"Multiple"]];
	}
	
	[NSApp stopModal];
}

- (IBAction)showPasswordSheet:(id)sender
{
	[NSApp beginSheet: passwordSheet
	   modalForWindow: [settingsView window]
		modalDelegate: self
	   didEndSelector: nil
		  contextInfo: nil];
	
	if ([[self currentWeblog] stringForKey:@"userName"] == nil) {
		[[settingsView window] makeFirstResponder:tempUserNameTextField];
	} else {
		[[settingsView window] makeFirstResponder:tempPasswordSecureTextField];
	}
	
	[tempPasswordSecureTextField setStringValue:@""];
	
	[NSApp runModalForWindow: passwordSheet];
	// Sheet is up here.
	
	[NSApp endSheet: passwordSheet];
	[passwordSheet orderOut: [settingsView window]];
}

- (IBAction)cancelPasswordSheet:(id)sender
{
	[NSApp stopModal];
}

- (IBAction)savePasswordSheet:(id)sender
{
	NSDictionary *weblog = [self currentWeblog];
	if (![[tempPasswordSecureTextField stringValue] isEqualToString:@""]) {
		[self setPassword:[tempPasswordSecureTextField stringValue]];
		
		if ((![[weblog stringForKey:@"userName"] isEqual:@""]) && ([weblog integerForKey:@"storePasswordInKeychain"] > 0)) {
			PTWKeychain *keychain = [[PTWKeychain alloc] init];
			// Add or replace the existing keychain password.
			[keychain addGenericPassword:[tempPasswordSecureTextField stringValue] forAccount:[weblog stringForKey:@"userName"] forService:[NSString stringWithFormat:@"Photon: %@", [weblog stringForKey:@"weblogURL"]] replaceExisting:YES];
			[keychain release];
		}
	}
	
	[NSApp stopModal];
	[self savePreferences];
}

- (void)awakeFromNib
{
	static BOOL mainNibIsAwake;
	NSNotificationCenter *nc;
	
	if (mainNibIsAwake == NO) {
		mainNibIsAwake = YES;
		[offlineAlertButton setToolTip:[self localizedStringForKey:@"WorkingOffline"]];
		[[imageUploadPathFormCell controlView] setToolTip:[self localizedStringForKey:@"CustomUploadPath"]];
		[[thumbnailUploadPathFormCell controlView] setToolTip:[self localizedStringForKey:@"CustomUploadPath"]];
		
		[self loadPreferences];
		
		[self setVersion:[NSString stringWithFormat:@"Photon v%@", [[[NSBundle bundleWithIdentifier:@"com.daikini.Photon"] infoDictionary] objectForKey:@"CFBundleVersion"]]];
		
		[versionTextField setStringValue:[self version]];
		
		// If there aren't any weblogs defined then add a None defined to the
		// weblog popup
		if ([[self weblogs] count] <= 0) {
			[weblogPopUpButton addItemWithTitle:[self localizedStringForKey:@"NoneDefined"]];
		}
		
		nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self 
			   selector:@selector(entryOptionChanged:)
				   name:@"PhotonEntryOptionChanged"
				 object:nil];
		
	}
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	return;
	
	/*
	id form = [aNotification object];
	int formTag = [[aNotification object] tag];
	int formCellTag = [form indexOfSelectedItem];
	float aspectRatio = [self imageAspectRatioAtIndex:0];

	// If the form is for Thumbnails
	if (formTag == 100) {
		// Width is being modified
		if (formCellTag == 0) {
			if ([thumbnailWidthFormCell objectValue] == nil) {
				[thumbnailHeightFormCell setObjectValue:[NSNull null]];
			} else {
				[thumbnailHeightFormCell setIntValue:round([thumbnailWidthFormCell floatValue] / aspectRatio)];
			}
		// Height is being modified
		} else if (formCellTag == 1) {
			if ([thumbnailHeightFormCell objectValue] == nil) {
				[thumbnailWidthFormCell setObjectValue:[NSNull null]];
			} else {
				[thumbnailWidthFormCell setIntValue:round([thumbnailHeightFormCell floatValue] * aspectRatio)];
			}
		}
		
	// If the form is for the image
	} else if (formTag == 200) {
		// Width is being modified
		if (formCellTag == 0) {
			if ([imageWidthFormCell objectValue] == nil) {
				[imageHeightFormCell setObjectValue:[NSNull null]];
			} else {
				[imageHeightFormCell setIntValue:round([imageWidthFormCell floatValue] / aspectRatio)];
			}
			// Height is being modified
		} else if (formCellTag == 1) {
			if ([imageHeightFormCell objectValue] == nil) {
				[imageWidthFormCell setObjectValue:[NSNull null]];
			} else {
				[imageWidthFormCell setIntValue:round([imageHeightFormCell floatValue] * aspectRatio)];
			}
		}
	}
	 */
}

- (BOOL)selectionShouldChangeInTableView:(NSTableView *)aTableView
{
	NSDictionary *weblog = [self currentWeblog];
	
	if ((![[weblog stringForKey:@"userName"] isEqual:@""]) && (![[passwordSecureTextField stringValue] isEqual:@""]) && ([weblog integerForKey:@"storePasswordInKeychain"] > 0)) {
        PTWKeychain *keychain = [[PTWKeychain alloc] init];
		// Add or replace the existing keychain password.
        [keychain addGenericPassword:[passwordSecureTextField stringValue] forAccount:[weblog stringForKey:@"userName"] forService:[NSString stringWithFormat:@"Photon: %@", [weblog stringForKey:@"weblogURL"]] replaceExisting:YES];
		[keychain release];
	}
	
	return YES;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	NSDictionary *weblog = [self currentWeblog];
	if ([weblog integerForKey:@"storePasswordInKeychain"] > 0) {
		[self setPassword:[self keychainPasswordForUserName:[weblog stringForKey:@"userName"] weblogURL:[weblog stringForKey:@"weblogURL"]]];
	} else {
		[self setPassword:@""];
	}
	
	[passwordSecureTextField setStringValue:[self password]];
	
	[entryOptionViews removeAllEntryOptionViews];
	[self loadEntryOptionViews];
	accountChanged = YES;
}

- (IBAction)changeAccount:(id)sender
{
	NSDictionary *weblog = [self currentWeblog];
	if ([weblog integerForKey:@"storePasswordInKeychain"] > 0) {
		[self setPassword:[self keychainPasswordForUserName:[weblog stringForKey:@"userName"] weblogURL:[weblog stringForKey:@"weblogURL"]]];
	} else {
		[self setPassword:@""];
	}
	[self refreshCategories:self];
}

- (IBAction)addAccount:(id)sender
{
	[weblogArrayController add:self];
	
	// Set some default values for the new account
	[weblogArrayController setValue:[NSNumber numberWithInt:INUseFilename] forKeyPath:@"selection.imageNaming"];
	[weblogArrayController setValue:[NSNumber numberWithInt:TNUseFilename] forKeyPath:@"selection.thumbnailNaming"];
	[weblogArrayController setValue:[NSNumber numberWithInt:1] forKeyPath:@"selection.modifyThumbnailName"];
	[weblogArrayController setValue:[NSNumber numberWithInt:0] forKeyPath:@"selection.weblogPlatform"];
	[weblogArrayController setValue:[NSNumber numberWithInt:640] forKeyPath:@"selection.imageWidth"];
	[weblogArrayController setValue:[NSNumber numberWithInt:480] forKeyPath:@"selection.imageHeight"];
	[weblogArrayController setValue:[NSNumber numberWithInt:240] forKeyPath:@"selection.thumbnailWidth"];
	[weblogArrayController setValue:[NSNumber numberWithInt:180] forKeyPath:@"selection.thumbnailHeight"];
	
	[entryOptionViews removeAllEntryOptionViews];
	[entryOptionViews addEntryOptionViewWithSource:EOSTitle destination:EODEntryTitle relativeTo:nil];
	[entryOptionViews addEntryOptionViewWithSource:EOSPhoto destination:EODEntryBody relativeTo:nil];
	[entryOptionViews addEntryOptionViewWithSource:EOSThumbnail destination:EODEntryExcerpt relativeTo:nil];
}

- (IBAction)removeAccount:(id)sender
{
	[weblogArrayController remove:self];
	
	// If there aren't any weblogs defined then add a None defined to the
	// weblog popup
	if ([[self weblogs] count] <= 0) {
		[weblogPopUpButton addItemWithTitle:[self localizedStringForKey:@"NoneDefined"]];
	}
}

- (void)mouseEntered:(NSEvent *)anEvent
{
	NSImage *highlightImage = [[NSImage alloc] initWithContentsOfFile:[NSBundle pathForResource:@"offlineAlert_highlighted" ofType:@"tiff" inDirectory:[[NSBundle bundleWithIdentifier:@"com.daikini.Photon"] bundlePath]]];
	[offlineAlertButton setImage:highlightImage];
	[highlightImage release];
}

- (void)mouseExited:(NSEvent *)anEvent
{
	NSImage *regularImage = [[NSImage alloc] initWithContentsOfFile:[NSBundle pathForResource:@"offlineAlert" ofType:@"tiff" inDirectory:[[NSBundle bundleWithIdentifier:@"com.daikini.Photon"] bundlePath]]];
	[offlineAlertButton setImage:regularImage];
	[regularImage release];
}


// Categories table view datasource
- (int)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return [[self categories] count];
}

- (id)tableView:(NSTableView *)aTableView
objectValueForTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex
{
	NSString *identifier = [aTableColumn identifier];
	
	if ([identifier isEqualToString:@"exportCategory"]) {
		return [exportCategories indexOfObject:[NSNumber numberWithInt:rowIndex]] != NSNotFound ? [NSNumber numberWithInt:NSOnState] : [NSNumber numberWithInt:NSOffState];
	} else {
		return [[[self categories] objectAtIndex:rowIndex] stringForKey:@"categoryName"];
	}
}

- (void)tableView:(NSTableView *)aTableView
 setObjectValue:(id)anObject
 forTableColumn:(NSTableColumn *)aTableColumn
			row:(int)rowIndex
{
	NSString *identifier = [aTableColumn identifier];
	
	if ([identifier isEqualToString:@"exportCategory"]) {
		if ([anObject boolValue]) {
			[exportCategories addObject:[NSNumber numberWithInt:rowIndex]];
		} else {
			[exportCategories removeObject:[NSNumber numberWithInt:rowIndex]];
		}
	}
}

- (BOOL)alertShowHelp:(NSAlert *)anAlert
{
	AHGotoPage((CFStringRef)@"Photon Help", (CFStringRef)@"helpdocs/Whats_an_Access_Point_and_whats_my_Blog_ID.html", (CFStringRef)@"MyApp001");
	return YES;
}

- (IBAction)showTemplateSheet:(id)sender
{
    [NSApp beginSheet: templateSheet
	   modalForWindow: accountSheet
		modalDelegate: self
	   didEndSelector: nil
		  contextInfo: nil];
	
    [NSApp runModalForWindow: templateSheet];
    // Sheet is up here.
	
    [NSApp endSheet: templateSheet];
    [templateSheet orderOut: accountSheet];
}

- (IBAction)closeTemplateSheet:(id)sender
{
	[NSApp stopModal];
}
- (void)dealloc
{
	// Release our lock object
	[mProgressLock release];
	
	[categories release];

	[undoWeblogs release];
	
	[exportCategories release];
	
	[super dealloc];
}

- (BOOL) handlesMovieFiles
{
	return NO;
}

@end

/*
@implementation XMLRPCRequest ( PhotonCategory )

- (void) setWordpressRequest:(BOOL)isWP
{
	[_encoder setWP:isWP];
}

@end

@implementation XMLRPCEncoder ( PhotonCategory )

- (NSString *)encode
{
	NSMutableString *buffer = [NSMutableString stringWithFormat: @"%@<methodCall>", ];
	
	[buffer appendFormat: @"<methodName>%@</methodName>", _method];
	
	if (_objects != nil)
	{
		NSEnumerator *enumerator = [_objects objectEnumerator];
		id object = nil;
		
		[buffer appendString: @"<params>"];
		
		while (object = [enumerator nextObject])
		{
			[buffer appendString: @"<param>"];
			[buffer appendString: [self encodeObject: object]];
			[buffer appendString: @"</param>"];
		}
		
		[buffer appendString: @"</params>"];
	}
	
	[buffer appendString: @"</methodCall>"];
	
	return buffer;
}
*/

@end