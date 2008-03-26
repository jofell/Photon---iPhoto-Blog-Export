//
//  DKURLConnection.m
//  wppost
//
//  Created by Jonathan Younger on 8/7/04.
//  Copyright 2004 Daikini Software. All rights reserved.
//

#import "DKURLConnection.h"


@implementation DKURLConnection
- (NSData *)sendSynchronousRequest:(NSURLRequest *)request followRedirects:(BOOL)flag returningResponse:(NSURLResponse **)response error:(NSError **)error
{
	followRedirects = flag;
	connectionData = [[NSMutableData alloc] init];
	connection = [NSURLConnection connectionWithRequest:request delegate:self];

	
	while(connectionDidFinishLoading == NO) {
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
	}
	
	*response = connectionResponse;
	return [connectionData autorelease];
	
}

-(NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse
{
	if (followRedirects) {
		return request;
	} else {
		return nil;
	}
}

-(void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	//NSLog(@"received response: %@", [(NSHTTPURLResponse *)response allHeaderFields]);
	connectionResponse = response;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	//NSLog(@"received data");
	[connectionData appendData:data];
}

-(void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	//NSLog(@"connectionDidFinishLoading");
	connectionDidFinishLoading = YES;
}
@end
