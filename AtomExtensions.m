//
//  AtomExtensions.m
//  Atom
//
//  Created by Jonathan Younger on Thu May 06 2004.
//  Copyright (c) 2004 Daikini Software.
//
//  This library is free software; you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2.1 of the License, or (at your option) any later version.

//  This library is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//  Lesser General Public License for more details.

//  You should have received a copy of the GNU Lesser General Public
//  License along with this library; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
//

// Original Base 64 development comments by Dave Winer. 
// Adapted from Kyle Hammond's GSNSDataExtensions
/*	C source code for Base 64 

Here's the C source code for the Base 64 encoder/decoder.

File:
base64.c
Created:
Saturday, April 5, 1997; 1:30:13 PM
Modified: 
Tuesday, April 8, 1997; 7:52:28 AM

 Dave Winer, dwiner@well.com, UserLand Software, 4/7/97
 
 I built this project using Symantec C++ 7.0.4 on a Mac 9500.
 
 We needed a handle-based Base 64 encoder/decoder. Looked around the
 net, found a bunch of code that couldn't easily be adapted to 
 in-memory stuff. Most of them work on files to conserve memory. This
 is inelegant in scripting environments such as Frontier.
 
 Anyway, so I wrote an encoder/decoder. Docs are being maintained 
 on the web, and updates at:
 
 http://www.scripting.com/midas/base64/
 
 If you port this code to another platform please put the result up
 on a website, and send me a pointer. Also send email if you think this
 isn't a compatible implementation of Base 64 encoding.
 
 BTW, I made it easy to port -- layering out the handle access routines.
 Of course there's a small performance penalty for this, and if you don't
 like it, change it. Thanks!
 */

#import "AtomExtensions.h"

// Needed by the sha1 openssl functions
// Must set Header Search Paths = /usr/include/openssl
// Must set Other Linker Flags = -lcrypto -lssl
#import <evp.h>

@implementation NSString (AtomExtensions)
static char gEncodingTable[ 64 ] = {
	'A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P',
	'Q','R','S','T','U','V','W','X','Y','Z','a','b','c','d','e','f',
	'g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v',
	'w','x','y','z','0','1','2','3','4','5','6','7','8','9','+','/'
};

- (NSString *)stringUsingBase64Encoding
{
	return [self stringUsingBase64EncodingWithLineLength:0];
}

- (NSString *)stringUsingBase64EncodingWithLineLength:(int)lineLength
{
	/*
	 Encode the NSString. Some funny stuff about linelength -- it only makes
	 sense to make it a multiple of 4. If it's not a multiple of 4, we make it
	 so (by only checking it every 4 characters). 
	 
	 Further, if it's 0, we don't add any line breaks at all.
	 */

    NSMutableString *result = nil;
    unsigned long textIndex;
    unsigned long textLength;
    long charactersRemaining;
    unsigned char inputBuffer[3], outputBuffer[4];
    short i;
    short charactersOnLine = 0, characterCopy;
    unsigned long index;
	
	
    textIndex = 0;
	
    textLength = [self length];
    result = [NSMutableString stringWithCapacity:textLength];
	
    while (YES) {
        charactersRemaining = textLength - textIndex;
		
        if (charactersRemaining <= 0) {
            break;
		}
		
        for (i = 0; i < 3; i++) {
            index = textIndex + i;
			
            if (index < textLength) {
				inputBuffer[i] = [self characterAtIndex:index];
			} else {
                inputBuffer[i] = 0;
			}
        } // for
		
        outputBuffer[0] = (inputBuffer[0] & 0xFC) >> 2;
        outputBuffer[1] = ((inputBuffer[0] & 0x03) << 4) | ((inputBuffer[1] & 0xF0) >> 4);
        outputBuffer[2] = ((inputBuffer[1] & 0x0F) << 2) | ((inputBuffer[2] & 0xC0) >> 6);
        outputBuffer[3] = inputBuffer[2] & 0x3F;
		
        characterCopy = 4;
		
        switch (charactersRemaining) {
            case 1: 
                characterCopy = 2; 
                break;
				
            case 2: 
                characterCopy = 3; 
                break;
        } // switch
        
        for (i = 0; i < characterCopy; i++) {
            [result appendFormat:@"%c", gEncodingTable[outputBuffer[i]] ];
		}
		
        for (i = characterCopy; i < 4; i++) {
            [result appendFormat:@"%c", '='];
		}
		
        textIndex += 3;
		
        charactersOnLine += 4;
		
        if (lineLength > 0) { // DW 4/8/97 -- 0 means no line breaks 
            if (charactersOnLine >= lineLength) {
                charactersOnLine = 0;
				
                [result appendString:@"\n"];
            }
        }
    } // while
	
	return result;
}

- (NSString *)stringUsingBase64Decoding
{
	return [[self dataUsingBase64Decoding] stringUsingEncoding:NSUTF8StringEncoding];
}

- (NSData *)dataUsingBase64Decoding
{
	NSMutableData *decodedData;
	unsigned long textIndex;
	unsigned long textLength;
	unsigned char ch;
	unsigned char inputBuffer[3], outputBuffer[4];
	short i, indexInBuffer;
	BOOL shouldIgnore;
	BOOL isEndOfText = NO;
	
	textLength = [self length];
	decodedData = [NSMutableData dataWithCapacity:textLength];
	
	textIndex = 0;
	indexInBuffer = 0;
	
	while (YES) {
		if (textIndex >= textLength) {
			break;
		}
		
		ch = [self characterAtIndex:textIndex++];
		
		shouldIgnore = NO;
		
		if ((ch >= 'A') && (ch <= 'Z')) {
			ch = ch - 'A';
		} else if ((ch >= 'a') && (ch <= 'z')) {
			ch = ch - 'a' + 26;
		} else if ((ch >= '0') && (ch <= '9')) {
			ch = ch - '0' + 52;
		} else if (ch == '+') {
			ch = 62;
		} else if (ch == '=') { // no op -- can't ignore this one 
			isEndOfText = YES;
		} else if (ch == '/') {
			ch = 63;
		} else {
			shouldIgnore = YES;
		}
		
		if (!shouldIgnore) {
			short	charactersInBuffer = 3;
			BOOL	shouldBreak = NO;
			
			if (isEndOfText) {
				if (indexInBuffer == 0) {
					break;
				}
				
				if ((indexInBuffer == 1) || (indexInBuffer == 2)) {
					charactersInBuffer = 1;
				} else {
					charactersInBuffer = 2;
				}
				
				indexInBuffer = 3;
				
				shouldBreak = YES;
			}
			
			inputBuffer[indexInBuffer++] = ch;
			
			if (indexInBuffer == 4) {
				indexInBuffer = 0;
				
				outputBuffer[0] = (inputBuffer[0] << 2) | ((inputBuffer[1] & 0x30) >> 4);
				
				outputBuffer[1] = ((inputBuffer[1] & 0x0F) << 4) | ((inputBuffer[2] & 0x3C) >> 2);
				
				outputBuffer[2] = ((inputBuffer[2] & 0x03) << 6) | (inputBuffer[3] & 0x3F);
				
				for (i = 0; i < charactersInBuffer; i++) {
					[decodedData appendBytes:&outputBuffer[i] length:1 ];
				}
			}
			
			if (shouldBreak) {
				break;
			}
		}
		
	} // while
	
	return decodedData;
}

- (NSString *)stringUsingMD5HexadecimalHash
{
	int i;
    NSString *rawString = [self stringUsingMD5RawHash];
	int stringLength = [rawString length];
	NSMutableString *hexString = [NSMutableString stringWithCapacity:stringLength];
	
    for(i=0; i < stringLength; i++) {
        [hexString appendFormat:@"%02x", [rawString characterAtIndex:i]];
    }
	
    return hexString;
}

- (NSString *)stringUsingMD5RawHash
{
	// these are structs and arrays used by the evp message digest functions 
    EVP_MD_CTX mdctx; 
    const EVP_MD *md;
    unsigned char md_value[EVP_MAX_MD_SIZE]; 
    int md_len;
    
    OpenSSL_add_all_digests(); 
    // create a MD5 digest 
    md = EVP_get_digestbyname("md5"); 
    EVP_DigestInit(&mdctx, md); 
    EVP_DigestUpdate(&mdctx, [self UTF8String], strlen([self UTF8String])); 
    EVP_DigestFinal(&mdctx, md_value, &md_len);
    
	// Must use NSASCIIStringEncoding encoding or it won't work
    return [[[NSString alloc] initWithData:[NSData dataWithBytes:md_value length:md_len] encoding:NSASCIIStringEncoding] autorelease];
	
}

- (NSString *)stringUsingSHA1HexadecimalHash
{
    int i;
    NSString *rawString = [self stringUsingSHA1RawHash];
	int stringLength = [rawString length];
	NSMutableString *hexString = [NSMutableString stringWithCapacity:stringLength];

    for(i=0; i < stringLength; i++) {
        [hexString appendFormat:@"%02x", [rawString characterAtIndex:i]];
    }
	
    return hexString;
}

- (NSString *)stringUsingSHA1RawHash
{
	// these are structs and arrays used by the evp message digest functions 
    EVP_MD_CTX mdctx; 
    const EVP_MD *md;
    unsigned char md_value[EVP_MAX_MD_SIZE]; 
    int md_len;
    
    OpenSSL_add_all_digests(); 
    // create a SHA digest 
    md = EVP_get_digestbyname("sha1"); 
    EVP_DigestInit(&mdctx, md); 
    EVP_DigestUpdate(&mdctx, [self cString], [self cStringLength]); 
    EVP_DigestFinal(&mdctx, md_value, &md_len);
    
	// Must use NSASCIIStringEncoding encoding or it won't work
    return [[[NSString alloc] initWithData:[NSData dataWithBytes:md_value length:md_len] encoding:NSASCIIStringEncoding] autorelease];
}

- (NSString *)stringByUnescapingHTMLEntities
{
	NSMutableString *unescapedString = [NSMutableString stringWithString:self];
	[unescapedString replaceOccurrencesOfString:@"&amp;" withString:@"&" options:0 range:NSMakeRange(0, [unescapedString length])];
	[unescapedString replaceOccurrencesOfString:@"&lt;" withString:@"<" options:0 range:NSMakeRange(0, [unescapedString length])];
	[unescapedString replaceOccurrencesOfString:@"&gt;" withString:@">" options:0 range:NSMakeRange(0, [unescapedString length])];
	[unescapedString replaceOccurrencesOfString:@"&quot;" withString:@"\"" options:0 range:NSMakeRange(0, [unescapedString length])];			
	
	return unescapedString;
}

- (NSString *)stringByEscapingHTMLEntities
{
	int characterIndex;
	int length = [self length];
	unichar character;
	NSMutableString *escapedString = [NSMutableString string];
	
	for (characterIndex = 0; characterIndex < length; characterIndex++) {
		character = [self characterAtIndex:characterIndex];
	
		if (character == '&') {
			[escapedString appendString:@"&amp;"];
		} else if (character == '<') {
			[escapedString appendString:@"&lt;"];
		} else if (character == '>') {
			[escapedString appendString:@"&gt;"];
		} else if (character == '"') {
			[escapedString appendString:@"&quot;"];
		} else if (character >= ' ' && character <= '~') {
			[escapedString appendFormat:@"%c", character];
		} else {
			[escapedString appendFormat:@"&#x%x;", character];
		}
	}

	return escapedString;
}

- (NSString *)stringByAddingPercentEscapes
{
	return [(NSString*)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (CFStringRef)self, NULL, (CFStringRef)@"&", kCFStringEncodingUTF8) autorelease];	
}

- (NSString *)stringByReplacingPercentEscapes
{
	return [(NSString*)CFURLCreateStringByReplacingPercentEscapes(kCFAllocatorDefault, (CFStringRef)self, (CFStringRef) @"") autorelease];	
}
@end

@implementation NSData (AtomExtensions)
- (NSString *)stringUsingEncoding:(NSStringEncoding)encoding
{
	return [[[NSString alloc] initWithData:self encoding:encoding] autorelease];
}

- (NSString *)stringUsingBase64Encoding
{
	return [self stringUsingBase64EncodingWithLineLength:0];
}

- (NSString *)stringUsingBase64EncodingWithLineLength:(int)lineLength
{
	/*
	 Encode the NSData. Some funny stuff about linelength -- it only makes
	 sense to make it a multiple of 4. If it's not a multiple of 4, we make it
	 so (by only checking it every 4 characters). 
	 
	 Further, if it's 0, we don't add any line breaks at all.
	 */
	
	const unsigned char	*bytes = [self bytes];
    NSMutableString *result = nil;
    unsigned long textIndex;
    unsigned long textLength;
    long charactersRemaining;
    unsigned char inputBuffer[3], outputBuffer[4];
    short i;
    short charactersOnLine = 0, characterCopy;
    unsigned long index;
	
	
    textIndex = 0;
	
    textLength = [self length];
    result = [NSMutableString stringWithCapacity:textLength];
	
    while (YES) {
        charactersRemaining = textLength - textIndex;
		
        if (charactersRemaining <= 0) {
            break;
		}
		
        for (i = 0; i < 3; i++) {
            index = textIndex + i;
			
            if (index < textLength) {
                inputBuffer[i] = bytes[index];
			} else {
                inputBuffer[i] = 0;
			}
        } // for
		
        outputBuffer[0] = (inputBuffer[0] & 0xFC) >> 2;
        outputBuffer[1] = ((inputBuffer[0] & 0x03) << 4) | ((inputBuffer[1] & 0xF0) >> 4);
        outputBuffer[2] = ((inputBuffer[1] & 0x0F) << 2) | ((inputBuffer[2] & 0xC0) >> 6);
        outputBuffer[3] = inputBuffer[2] & 0x3F;
		
        characterCopy = 4;
		
        switch (charactersRemaining) {
            case 1: 
                characterCopy = 2; 
                break;
				
            case 2: 
                characterCopy = 3; 
                break;
        } // switch
        
        for (i = 0; i < characterCopy; i++) {
            [result appendFormat:@"%c", gEncodingTable[outputBuffer[i]] ];
		}
		
        for (i = characterCopy; i < 4; i++) {
            [result appendFormat:@"%c", '='];
		}
		
        textIndex += 3;
		
        charactersOnLine += 4;
		
        if (lineLength > 0) { // DW 4/8/97 -- 0 means no line breaks 
            if (charactersOnLine >= lineLength) {
                charactersOnLine = 0;
				
                [result appendString:@"\n"];
            }
        }
    } // while
	
	return result;
}
@end
