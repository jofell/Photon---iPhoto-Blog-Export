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
// XMLRPCDecoder.m
// 
// Created by Eric Czarny on Wednesday, January 14, 2004.
// Copyright (c) 2007 Divisible by Zero.
// 

#import "XMLRPCDecoder.h"
#import "NSDataAdditions.h"

@interface XMLRPCDecoder (XMLRPCDecoderPrivate)

- (CFXMLTreeRef)getTreeFromParent: (CFXMLTreeRef)parent name: (NSString *)name;
- (NSString *)getNameFromTree: (CFXMLTreeRef)tree;
- (NSString *)getElementFromTree: (CFXMLTreeRef)tree;

#pragma mark -

- (NSArray *)decodeArray: (CFXMLTreeRef)tree;
- (NSDictionary *)decodeDictionary: (CFXMLTreeRef)tree;

#pragma mark -

- (id)decodeObject: (CFXMLTreeRef)tree;

#pragma mark -

- (NSNumber *)decodeNumber: (CFXMLTreeRef)tree isDouble: (BOOL)flag;
- (CFBooleanRef)decodeBool: (CFXMLTreeRef)tree;
- (NSString *)decodeString: (CFXMLTreeRef)tree;
- (NSDate *)decodeDate: (CFXMLTreeRef)tree;
- (NSData *)decodeData: (CFXMLTreeRef)tree;

@end

#pragma mark -

@implementation XMLRPCDecoder

- (id)initWithData: (NSData *)data
{
	if (data == nil)
	{
		return nil;
	}

	if (self = [super init])
	{
		_parent = CFXMLTreeCreateFromData(kCFAllocatorDefault, (CFDataRef)data,
			NULL, kCFXMLParserSkipWhitespace, kCFXMLNodeCurrentVersion);
			
		if (_parent == nil)
		{
			return nil;
		}
		
		_isFault = FALSE;
	}
	
	return self;
}

#pragma mark -

- (id)decode
{
	CFXMLTreeRef child, parent = [self getTreeFromParent: _parent name: @"methodResponse"];
	
	if (parent == nil)
	{
		return nil;
	}
	
	child = [self getTreeFromParent: parent name: @"params"];
	
	if (child != nil)
	{
		child = [self getTreeFromParent: child name: @"param"];
		
		if (child == nil)
		{
			return nil;
		}
		
		child = [self getTreeFromParent: child name: @"value"];
		
		if (child == nil)
		{
			return nil;
		}
	}
	else
	{
		child = [self getTreeFromParent: parent name: @"fault"];
		
		if (child == nil)
		{
			return nil;
		}
		
		child = [self getTreeFromParent: child name: @"value"];
		
		if (child == nil)
		{
			return nil;
		}
		
		_isFault = TRUE;
	}
	
	return [self decodeObject: child];
}

#pragma mark -

- (BOOL)isFault
{
	return _isFault;
}

#pragma mark -

- (void)dealloc
{
	if (_parent != nil)
	{
		CFRelease(_parent);
	}
	
	[super dealloc];
}

@end

#pragma mark -

@implementation XMLRPCDecoder (XMLRPCDecoderPrivate)

- (CFXMLTreeRef)getTreeFromParent: (CFXMLTreeRef)parent name: (NSString *)name
{
	CFXMLTreeRef child;
	NSString *string;
	int index;
	
	for (index = CFTreeGetChildCount(parent) - 1; index >= 0; index--)
	{
		child = CFTreeGetChildAtIndex(parent, index);
		string = (NSString *)CFXMLNodeGetString(CFXMLTreeGetNode(child));
		
		if ([string isEqualToString: name])
		{
			return child;
		}
	}
	
	return nil;
}

- (NSString *)getNameFromTree: (CFXMLTreeRef)tree
{
	CFXMLNodeRef node = CFXMLTreeGetNode(tree);
	
	if (node == nil)
	{
		return nil;
	}
	
	return (NSString *)CFXMLNodeGetString(node);
}

- (NSString *)getElementFromTree: (CFXMLTreeRef)tree
{
	NSMutableString *buffer = [NSMutableString string];
	int index;
	
	for (index = 0; index < CFTreeGetChildCount(tree); index++)
	{
		CFXMLNodeRef node = CFXMLTreeGetNode(CFTreeGetChildAtIndex(tree, index));
		NSString *string = (NSString *)CFXMLNodeGetString(node);
		
		if (string != nil)
		{
			if (CFXMLNodeGetTypeCode(node) == kCFXMLNodeTypeEntityReference)
			{
				if ([string isEqualToString: @"lt"])
				{
					string = @"<";
				}
				else if ([string isEqualToString: @"gt"])
				{
					string = @">";
				}
				else if ([string isEqualToString: @"quot"])
				{
					string = @"\"";
				}
				else if ([string isEqualToString: @"amp"])
				{
					string = @"&";
				}
			}
			
			[buffer appendString: string];
		}
	}
	
	return (NSString *)buffer;
}

#pragma mark -

- (NSArray *)decodeArray: (CFXMLTreeRef)tree
{
	CFXMLTreeRef parent = [self getTreeFromParent: tree name: @"data"];
	NSMutableArray *array = [NSMutableArray array];
	int index;
	
	if (parent == nil)
	{
		return nil;
	}
	
	for (index = 0; index < CFTreeGetChildCount(parent); index++)
	{
		CFXMLTreeRef child = CFTreeGetChildAtIndex(parent, index);
		NSString *name = [self getNameFromTree: child];
		
		if (![name isEqualToString: @"value"])
		{
			continue;
		}
		
		id value = [self decodeObject: child];
		
		if (value != nil)
		{
			[array addObject: value];
		}
	}
	
	return (NSArray *)array;
}

- (NSDictionary *)decodeDictionary: (CFXMLTreeRef)tree
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
	int index;
	
	for (index = 0; index < CFTreeGetChildCount(tree); index++)
	{
		CFXMLTreeRef child, parent = CFTreeGetChildAtIndex(tree, index);
		NSString *name = [self getNameFromTree: parent];
		
		if (![name isEqualToString: @"member"])
		{
			continue;
		}
		
		child = [self getTreeFromParent: parent name: @"name"];
		
		if (child == nil)
		{
			continue;
		}
		
		name = [self getElementFromTree: child];
		child = [self getTreeFromParent: parent name: @"value"];
		
		if (child == nil)
		{
			continue;
		}
		
		id object = [self decodeObject: child];
		
		if ((object != nil) && (name != nil) && ![name isEqualToString: @""])
		{
			[dictionary setObject: object forKey: name];
		}
	}
	
	return (NSDictionary *)dictionary;
}

#pragma mark -

- (id)decodeObject: (CFXMLTreeRef)tree
{
	CFXMLTreeRef child = CFTreeGetChildAtIndex(tree, 0);
	NSString *name = nil;
	
	if (child == nil)
	{
		return nil;
	}
	
	name = [self getNameFromTree: child];
	
	if ([name isEqualToString: @"array"])
	{
		return [self decodeArray: child];
	}
	else if ([name isEqualToString: @"struct"])
	{
		return [self decodeDictionary: child];
	}
	else if ([name isEqualToString: @"int"] || [name isEqualToString: @"i4"])
	{
		return [self decodeNumber: child isDouble: NO];
	}
	else if ([name isEqualToString: @"double"])
	{
		return [self decodeNumber: child isDouble: YES];
	}
	else if ([name isEqualToString: @"boolean"])
	{
		return (id)[self decodeBool: child];
	}
	else if ([name isEqualToString: @"string"])
	{
		return [self decodeString: child];
	}
	else if ([name isEqualToString: @"dateTime.iso8601"])
	{
		return [self decodeDate: child];
	}
	else if ([name isEqualToString: @"base64"])
	{
		return [self decodeData: child];
	}
	else
	{
		return [self decodeString: tree];
	}
}

#pragma mark -

- (NSNumber *)decodeNumber: (CFXMLTreeRef)tree isDouble: (BOOL)flag
{
	NSString *element = [self getElementFromTree: tree];
	
	if (flag)
	{
		return [NSNumber numberWithInt: [element intValue]];
	}
	else
	{
		return [NSNumber numberWithDouble: [element intValue]];
	}
}

- (CFBooleanRef)decodeBool: (CFXMLTreeRef)tree
{
	NSString *element = [self getElementFromTree: tree];
	
	if ([element isEqualToString: @"1"])
	{
		return kCFBooleanTrue;
	}
	
	return kCFBooleanFalse;
}

- (NSString *)decodeString: (CFXMLTreeRef)tree
{
	return [self getElementFromTree: tree];
}

- (NSDate *)decodeDate: (CFXMLTreeRef)tree
{
	NSString *element = [self getElementFromTree: tree];
	NSCalendarDate *date = [NSCalendarDate dateWithString: element 
		calendarFormat: @"%Y%m%dT%H:%M:%S" locale: nil];
	
	return date;
}

- (NSData *)decodeData: (CFXMLTreeRef)tree
{
	NSString *element = [self getElementFromTree: tree];
	
	return [NSData base64DataFromString: element];
}

@end
