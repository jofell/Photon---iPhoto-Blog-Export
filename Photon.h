//
//  Photon.h
//  Photon
//
//  Created by Jonathan Younger on Thu Apr 22 2004.
//  Copyright (c) 2004 Daikini Software. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EntryOptionViews.h"
#import "ExportMgr.h"
#import "ExportPluginProtocol.h"

enum ImageNaming {
	INUseFilename,
	INUseTitle,
	INUseDateTaken
};

enum ThumbnailNaming {
	TNUseFilename,
	TNUseTitle,
	TNUseDateTaken
};

enum WeblogPlatform {
	WPMovableType = 1,
	WPTypePad = 2,
	WPBlojsom = 3,
	WPWordPress = 4
};

typedef struct {
    unsigned long currentItem;
    unsigned long totalItems;
    id message;
    char indeterminateProgress;
    char shouldCancel;
    char shouldStop;
} CDAnonymousStruct1;

/*
@protocol ExportPluginProtocol
- (id)initWithExportImageObj:(id)fp12;
- (id)settingsView;
- (id)firstView;
- (id)lastView;
- (void)viewWillBeActivated;
- (void)viewWillBeDeactivated;
- (id)requiredFileType;
- (BOOL)wantsDestinationPrompt;
- (id)getDestinationPath;
- (id)defaultFileName;
- (id)defaultDirectory;
- (BOOL)treatSingleSelectionDifferently;
- (BOOL)validateUserCreatedPath:(id)fp12;
- (void)clickExport;
- (void)startExport:(id)fp12;
- (void)performExport:(id)fp12;
- (CDAnonymousStruct1 *)progress;
- (void)lockProgress;
- (void)unlockProgress;
- (void)cancelExport;
- (id)name;
- (id)description;
@end
*/
@interface Photon : NSObject <ExportPluginProtocol> {
	// iPhoto Export Plugin Form Elements on Panel
	IBOutlet id firstView;
    IBOutlet id lastView;
    IBOutlet id settingsView;
	
	// Panel Form Elements
	IBOutlet NSPopUpButton *weblogPopUpButton;
	IBOutlet NSPopUpButton *categoryPopUpButton;
	IBOutlet NSProgressIndicator *refreshCategoryProgressIndicator;
	IBOutlet NSFormCell *thumbnailWidthFormCell;
	IBOutlet NSFormCell *thumbnailHeightFormCell;
	IBOutlet NSFormCell *imageWidthFormCell;
	IBOutlet NSFormCell *imageHeightFormCell;
	IBOutlet NSTextField *versionTextField;
	IBOutlet NSArrayController *weblogArrayController;
	IBOutlet NSButton *offlineAlertButton;
    
	// Account Form Elements
	IBOutlet NSWindow *accountSheet;
	IBOutlet NSSecureTextField *passwordSecureTextField;
	IBOutlet EntryOptionViews *entryOptionViews;
	IBOutlet NSView *entryOptionsView;
	IBOutlet NSFormCell *imageUploadPathFormCell;
	IBOutlet NSFormCell *thumbnailUploadPathFormCell;
	IBOutlet NSProgressIndicator *autodiscoverProgressIndicator;
	
	// Category Form Elements
	IBOutlet NSWindow *categorySheet;
	IBOutlet NSTextField *categoryNameTextField;
	IBOutlet NSProgressIndicator *createCategoryProgressIndicator;
	IBOutlet NSTextField *createCategoryProgressTextField;
	
	// Password Form Elements
	IBOutlet NSWindow *passwordSheet;
	IBOutlet NSSecureTextField *tempPasswordSecureTextField;
	IBOutlet NSTextField *tempUserNameTextField;
	
	// Categories Form Elements
	IBOutlet NSWindow *categoriesSheet;
	IBOutlet NSTableView *categoryTableView;
	
	// Custom Template Elements
	IBOutlet NSWindow *templateSheet;
	
	// Single-post options
	IBOutlet NSTextField *singlePostTitle;
	IBOutlet NSTextField *singlePostPrologue;
	
	// Instance variables
	ExportMgr *exportManager;
	CDAnonymousStruct1 mProgress;
	NSLock *mProgressLock;
	BOOL exportCancelled;
	NSMutableArray *categories;
	NSString *version;	
	NSMutableArray *undoWeblogs;
	NSTrackingRectTag offlineTrackingTag;
	NSMutableArray *exportCategories;
	NSMutableArray *undoExportCategories;
	int indexOfSelectedCategory;
	BOOL accountChanged;
	int previousWeblogIndex;
	NSString *password;
	NSString *previousPassword;
}

// Export Plugin Protocol methods
- (id)initWithExportImageObj:(id)fp12;
- (id)settingsView;
- (id)firstView;
- (id)lastView;
- (void)viewWillBeActivated;
- (void)viewWillBeDeactivated;
- (id)requiredFileType;
- (BOOL)wantsDestinationPrompt;
- (id)getDestinationPath;
- (id)defaultFileName;
- (id)defaultDirectory;
- (BOOL)treatSingleSelectionDifferently;
- (BOOL)validateUserCreatedPath:(id)fp12;
- (void)clickExport;
- (void)startExport:(id)fp12;
- (void)performExport:(id)fp12;
- (CDAnonymousStruct1 *)progress;
- (void)lockProgress;
- (void)unlockProgress;
- (void)cancelExport;
- (id)name;
- (id)description;

	// Photon methods
- (IBAction)showAccountSheet:(id)sender;
- (IBAction)showAccountHelp:(id)sender;
- (IBAction)closeAccountSheet:(id)sender;
- (IBAction)showCategorySheet:(id)sender;
- (IBAction)closeCategorySheet:(id)sender;
- (IBAction)refreshCategories:(id)sender;
- (IBAction)saveAccount:(id)sender;
- (IBAction)createCategory:(id)sender;
- (IBAction)autodiscover:(id)sender;
- (IBAction)showPasswordSheet:(id)sender;
- (IBAction)cancelPasswordSheet:(id)sender;
- (IBAction)savePasswordSheet:(id)sender;
- (IBAction)changeAccount:(id)sender;
- (IBAction)addAccount:(id)sender;
- (IBAction)removeAccount:(id)sender;
- (IBAction)showCategoriesSheet:(id)sender;
- (IBAction)closeCategoriesSheet:(id)sender;
- (IBAction)useSelectedCategories:(id)sender;
- (IBAction)selectCategory:(id)sender;
- (IBAction)showTemplateSheet:(id)sender;
- (IBAction)closeTemplateSheet:(id)sender;
- (void)mouseExited:(NSEvent *)anEvent;
- (void)mouseEntered:(NSEvent *)anEvent;
- (void)awakeFromNib;
- (void)dealloc;
@end

/*
@interface XMLRPCRequest ( PhotonCategory )

- (void) setWordpressRequest:(BOOL)isWP;

@end

@interface XMLRPCEncoder ( PhotonCategory )
{
	BOOL wpFormat;
}
@end
*/