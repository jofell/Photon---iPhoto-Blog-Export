//
//  AtomExtensions.h
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

#import <Foundation/Foundation.h>


@interface NSString (AtomExtensions)
- (NSString *)stringUsingBase64Encoding;
- (NSString *)stringUsingBase64EncodingWithLineLength:(int)lineLength;
- (NSString *)stringUsingBase64Decoding;
- (NSData *)dataUsingBase64Decoding;
- (NSString *)stringUsingSHA1HexadecimalHash;
- (NSString *)stringUsingSHA1RawHash;
- (NSString *)stringByUnescapingHTMLEntities;
- (NSString *)stringByEscapingHTMLEntities;
- (NSString *)stringByAddingPercentEscapes;
- (NSString *)stringByReplacingPercentEscapes;
- (NSString *)stringUsingMD5HexadecimalHash;
- (NSString *)stringUsingMD5RawHash;
@end

@interface NSData (AtomExtensions)
- (NSString *)stringUsingEncoding:(NSStringEncoding)encoding;
- (NSString *)stringUsingBase64Encoding;
- (NSString *)stringUsingBase64EncodingWithLineLength:(int)lineLength;
@end
