//
//  PhotonPluginBox.h
//  Photon
//
//  Created by Jonathan Younger on 6/17/04.
//  Copyright 2004 Daikini Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ExportPluginBoxProtocol.h"

/*
@protocol ExportPluginBoxProtocol
- (BOOL)performKeyEquivalent:(id)fp12;
@end
*/
@interface PhotonPluginBox : NSBox <ExportPluginBoxProtocol> {
    IBOutlet id mPlugin;
}

- (BOOL)performKeyEquivalent:(id)fp12;
@end
