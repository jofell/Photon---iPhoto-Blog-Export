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
// XMLRPCResponse.m
// 
// Created by Eric Czarny on Wednesday, January 14, 2004.
// Copyright (c) 2007 Divisible by Zero.
// 

#import "XMLRPCResponse.h"
#import "XMLRPCDecoder.h"

@implementation XMLRPCResponse

- (id)initWithData: (NSData *)data
{
	if (data == nil)
	{
		return nil;
	}

	if (self = [super init])
	{
		XMLRPCDecoder *decoder = [[[XMLRPCDecoder alloc] initWithData: data] autorelease];
		
		if (decoder == nil)
		{
			return nil;
		}
	
		_data = [[NSData alloc] initWithData: data];
		_source = [[NSString alloc] initWithData: data encoding: NSISOLatin1StringEncoding];
		_object = [[decoder decode] retain];
		
		if (_object == nil)
		{
			_isParseError = TRUE;
		}
		else
		{
			_isParseError = FALSE;
		}
		
		_isFault = [decoder isFault];
	}
	
	return self;
}

#pragma mark -

- (BOOL)isFault
{
	return _isFault;
}

- (NSNumber *)code
{
	if (_isFault)
	{
		return [_object objectForKey: @"faultCode"];
	}
	
	return nil;
}

- (NSString *)fault
{
	if (_isFault)
	{
		return [_object objectForKey: @"faultString"];
	}
	
	return nil;
}

#pragma mark -

- (BOOL)isParseError
{
	return _isParseError;
}

#pragma mark -

- (id)object
{
	return _object;
}

#pragma mark -

- (NSString *)source
{
	return _source;
}

- (int)length
{
	return [_data length];
}

#pragma mark -

- (void)dealloc
{
	[_data autorelease];
	[_source autorelease];
	[_object autorelease];
	
	[super dealloc];
}

@end
