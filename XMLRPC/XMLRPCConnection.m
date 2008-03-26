// 
// Copyright (c) 2007 Eric Czarny
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of  this  software  and  associated documentation files (the "Software"), to
// deal  in  the Software without restriction, including without limitation the
// rights  to  use,  copy,  modify,  merge,  publish,  distribute,  sublicense,
// and/or sell copies  of  the  Software,  and  to  permit  persons to whom the
// Software is furnished to do so, subject to the following conditions:
// 
// The  above  copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE  SOFTWARE  IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED,  INCLUDING  BUT  NOT  LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS  OR  COPYRIGHT  HOLDERS  BE  LIABLE  FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY,  WHETHER  IN  AN  ACTION  OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
// IN THE SOFTWARE.
// 

// 
// Cocoa XML-RPC Framework
// XMLRPCConnection.m
// 
// Created by Eric Czarny on Thursday, January 15, 2004.
// Copyright (c) 2007 Divisible by Zero.
// 

#import "XMLRPCConnection.h"
#import "XMLRPCRequest.h"
#import "XMLRPCResponse.h"

NSString *XMLRPCRequestFailedNotification = @"XML-RPC Failed Receiving Response";
NSString *XMLRPCSentRequestNotification = @"XML-RPC Sent Request";
NSString *XMLRPCReceivedResponseNotification = @"XML-RPC Successfully Received Response";

@interface XMLRPCConnection (XMLRPCConnectionPrivate)

- (void)connection: (NSURLConnection *)connection didReceiveData: (NSData *)data;
- (void)connection: (NSURLConnection *)connection didFailWithError: (NSError *)error;
- (void)connectionDidFinishLoading: (NSURLConnection *)connection;

@end

#pragma mark -

@implementation XMLRPCConnection

- (id)initWithXMLRPCRequest: (XMLRPCRequest *)request delegate: (id)delegate
{
	if (self = [super init])
	{
		_connection = [[NSURLConnection alloc] initWithRequest: [request request] delegate: self];
		
		_delegate = delegate;
		
		if (_connection != nil)
		{
			_method = [[NSString alloc] initWithString: [request method]];
			_data = [[NSMutableData alloc] init];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:
				XMLRPCSentRequestNotification object: nil];
		}
		else
		{
			if ([_delegate respondsToSelector: @selector(connection:didFailWithError:forMethod:)])
			{
				[_delegate connection: self didFailWithError: nil forMethod: [request method]];
			}
			
			return nil;
		}
	}
	
	return self;
}

#pragma mark -

+ (XMLRPCResponse *)sendSynchronousXMLRPCRequest: (XMLRPCRequest *)request
{

	NSData *data = [[[NSURLConnection sendSynchronousRequest: [request request] 
		returningResponse: nil error: nil] retain] autorelease];

	if (data != nil)
	{
		return [[[XMLRPCResponse alloc] initWithData: data] autorelease];
	}

	return nil;
}

#pragma mark -

- (void)cancel
{
	[_connection cancel];
	[_connection autorelease];
}

#pragma mark -

- (void)dealloc
{
	[_method autorelease];
	[_data autorelease];
	
	[super dealloc];
}

@end

#pragma mark -

@implementation XMLRPCConnection (XMLRPCConnectionPrivate)

- (void)connection: (NSURLConnection *)connection didReceiveData: (NSData *)data
{
	[_data appendData: data];
}

- (void)connection: (NSURLConnection *)connection didFailWithError: (NSError *)error
{			
	if ([_delegate respondsToSelector: @selector(connection:didFailWithError:forMethod:)])
	{
		[_delegate connection: self didFailWithError: error forMethod: _method];
	}
		
	[[NSNotificationCenter defaultCenter] postNotificationName:
			XMLRPCRequestFailedNotification object: nil];
		
	[connection autorelease];
}

- (void)connectionDidFinishLoading: (NSURLConnection *)connection
{
	XMLRPCResponse *response = [[XMLRPCResponse alloc] initWithData: _data];
	
	if ([_delegate respondsToSelector: @selector(connection:didReceiveResponse:forMethod:)])
	{
		[_delegate connection: self didReceiveResponse: response forMethod: _method];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:
			XMLRPCReceivedResponseNotification object: nil];
			
	[connection autorelease];
}

@end
