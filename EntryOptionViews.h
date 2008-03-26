/* EntryOptionViews */

#import <Cocoa/Cocoa.h>

enum EntryOptionSource {
	EOSPhoto,
	EOSThumbnail,
	EOSTitle,
	EOSAlbumName,
	EOSComments,
	EOSDateTaken,
	EOSFilename,
	EOSKeyWords
};

enum EntryOptionDestination {
	EODEntryTitle,
	EODEntryBody,
	EODEntryExtended,
	EODEntryExcerpt,
	EODKeywords,
	EODAltAttribute,
	EODTitleAttribute
};

@interface EntryOptionViews : NSView
{
	IBOutlet NSView *entryOptionView;
	IBOutlet id delegate;
}

- (void)addEntryOptionViewWithSource:(int)aSource destination:(int)aDestination relativeTo:(id)anOtherView;
- (void)removeEntryOptionViewAtIndex:(int)anIndex;
- (void)removeAllEntryOptionViews;
- (NSMutableArray *)entryOptions;
- (void)repositionEntryOptionViewsAfterIndex:(int)anIndex didRemoveOptionView:(BOOL)flag;
- (IBAction)addEntryOption:(id)sender;
- (IBAction)removeEntryOption:(id)sender;
- (IBAction)changeEntryOption:(id)sender;
- (NSDictionary *)entryOptionForSource:(int)anEntryOptionSource;
- (NSDictionary *)entryOptionForDestination:(int)anEntryOptionDestination;
- (void)populateEntryOptionDestinations;
- (NSArray *)usedEntryDestinationOptions;
- (int)indexOfFirstAvailableEntryDestinationMenuOption;
@end
