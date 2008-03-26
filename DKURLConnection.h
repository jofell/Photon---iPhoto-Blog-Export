//
//  DKURLConnection.h
//  wppost
//
//  Created by Jonathan Younger on 8/7/04.
//  Copyright 2004 Daikini Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface DKURLConnection : NSObject {
	BOOL followRedirects;
	NSURLConnection *connection;
	NSMutableData *connectionData;
	NSURLResponse *connectionResponse;
	NSError *connectionError;
	BOOL connectionDidFinishLoading;
	
}

- (NSData *)sendSynchronousRequest:(NSURLRequest *)request followRedirects:(BOOL)flag returningResponse:(NSURLResponse **)response error:(NSError **)error;
@end
