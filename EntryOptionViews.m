#import "EntryOptionViews.h"

@implementation EntryOptionViews

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil) {
		// Add initialization code here
	}
	return self;
}

- (void)drawRect:(NSRect)rect
{
}

- (void)addEntryOptionViewWithSource:(int)aSource destination:(int)aDestination relativeTo:(id)anOtherView
{
	NSData *viewData = [NSArchiver archivedDataWithRootObject:entryOptionView]; 
	NSView *view = [NSUnarchiver unarchiveObjectWithData:viewData];
	NSView *theEntryOptionView;
	int viewIndex;
	
	if (anOtherView != nil) {
		[self addSubview:view positioned:NSWindowAbove relativeTo:anOtherView];
	} else {
		[self addSubview:view];
	}
	
	viewIndex = [[self subviews] indexOfObject:view];
	
	// Set Target/Actions
	theEntryOptionView = [[self subviews] objectAtIndex:viewIndex];

	[[theEntryOptionView viewWithTag:1000] setTarget:self];
	[[theEntryOptionView viewWithTag:1000] setAction:@selector(changeEntryOption:)];
	[[theEntryOptionView viewWithTag:1000] selectItemAtIndex:aSource];
	[[[[theEntryOptionView viewWithTag:1000] menu] itemWithTag:1000] setTarget:delegate];
	[[[[theEntryOptionView viewWithTag:1000] menu] itemWithTag:1000] setAction:@selector(showTemplateSheet:)];
	[[theEntryOptionView viewWithTag:1001] setTarget:self];
	[[theEntryOptionView viewWithTag:1001] setAction:@selector(changeEntryOption:)];
	[[theEntryOptionView viewWithTag:1001] selectItemAtIndex:aDestination];
	[[theEntryOptionView viewWithTag:1001] setAutoenablesItems:NO];
	[[theEntryOptionView viewWithTag:1002] setTarget:self];
	[[theEntryOptionView viewWithTag:1002] setAction:@selector(removeEntryOption:)];
	[[theEntryOptionView viewWithTag:1003] setTarget:self];
	[[theEntryOptionView viewWithTag:1003] setAction:@selector(addEntryOption:)];
	
	// Hide the view. It will be unhidden when it is positioned.
	[theEntryOptionView setHidden:YES];
	
	[self repositionEntryOptionViewsAfterIndex:viewIndex didRemoveOptionView:NO];
	
	[self changeEntryOption:self];
}

- (void)removeEntryOptionViewAtIndex:(int)anIndex
{
	[[[self subviews] objectAtIndex:anIndex] removeFromSuperviewWithoutNeedingDisplay];
	[self repositionEntryOptionViewsAfterIndex:anIndex didRemoveOptionView:YES];
	
	[self changeEntryOption:self];
}

- (void)removeAllEntryOptionViews
{
	while ([[self subviews] count] > 0) {
		[[[self subviews] objectAtIndex:([[self subviews] count] - 1)] removeFromSuperviewWithoutNeedingDisplay];
	}
	[self setNeedsDisplay:YES];
}

- (NSMutableArray *)entryOptions
{
	int viewIndex;
	int viewCount;
	NSView *theEntryOptionView;
	NSMutableArray *theEntryOptions = [NSMutableArray array];
	NSMutableDictionary *theEntryOption;
	
	viewCount = [[self subviews] count];
	
	for (viewIndex = 0; viewIndex < viewCount; viewIndex++) {
		theEntryOptionView = [[self subviews] objectAtIndex:viewIndex];
		theEntryOption = [[NSMutableDictionary alloc] init];
		[theEntryOption setObject:[NSNumber numberWithInt:[[theEntryOptionView viewWithTag:1000] indexOfSelectedItem]] forKey:@"source"];
		[theEntryOption setObject:[NSNumber numberWithInt:[[theEntryOptionView viewWithTag:1001] indexOfSelectedItem]] forKey:@"destination"];
		[theEntryOptions addObject:theEntryOption];
		[theEntryOption release];
	}
	
	//NSLog(@"Entry options: %@", theEntryOptions);
	return theEntryOptions;	
}

- (void)repositionEntryOptionViewsAfterIndex:(int)anIndex didRemoveOptionView:(BOOL)flag
{
	int viewIndex;
	int animationIndex;
	NSRect bounds = [self bounds]; 
	int viewCount = [[self subviews] count];
	float yPos;

	if (!flag) {
		for (animationIndex = 0; animationIndex < 33; animationIndex += 6) {
			for (viewIndex = anIndex; viewIndex < viewCount; viewIndex++) {
				yPos = round(animationIndex + (viewIndex * 33));
				[[[self subviews] objectAtIndex:viewIndex] setFrameOrigin:NSMakePoint(bounds.origin.x, bounds.size.height - yPos)];
			}
			
			[self display];
		}
		
		// Now that everything is positioned show the added entry option
		[[[self subviews] objectAtIndex:anIndex] setHidden:NO];
		
	} else {
		for (animationIndex = 33; animationIndex >= -3; animationIndex -= 6) {
			for (viewIndex = anIndex; viewIndex < viewCount; viewIndex++) {
				yPos = round(animationIndex + ((viewIndex + 1) * 33));
				[[[self subviews] objectAtIndex:viewIndex] setFrameOrigin:NSMakePoint(bounds.origin.x, bounds.size.height - yPos)];
			}
			
			[self display];
		}
	}
	

	// Enable the add button if there are less than 7 options
	for (viewIndex = 0; viewIndex < viewCount; viewIndex++) {
		[[[[self subviews] objectAtIndex:viewIndex] viewWithTag:1003] setEnabled:(viewCount < 7)];
	}
		
	// Disable the delete button if there is only one option
	if (viewCount > 0) {
		[[[[self subviews] objectAtIndex:0] viewWithTag:1002] setEnabled:(viewCount > 1)];
	}

	[self setNeedsDisplay:YES];
}

- (IBAction)addEntryOption:(id)sender
{
	[self addEntryOptionViewWithSource:2 destination:[self indexOfFirstAvailableEntryDestinationMenuOption] relativeTo:[sender superview]];
}

- (IBAction)removeEntryOption:(id)sender
{
	[self removeEntryOptionViewAtIndex:[[self subviews] indexOfObject:[sender superview]]];
}

- (IBAction)changeEntryOption:(id)sender
{
	[self populateEntryOptionDestinations];
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc postNotificationName:@"PhotonEntryOptionChanged" object:[self entryOptions]];
}

- (NSDictionary *)entryOptionForSource:(int)anEntryOptionSource
{
	NSDictionary *theEntryOption;
	NSEnumerator *e = [[self entryOptions] objectEnumerator];
	
	while(theEntryOption = [e nextObject]) {
		if ([[theEntryOption objectForKey:@"source"] isEqual:[NSNumber numberWithInt:anEntryOptionSource]]) {
			return theEntryOption;
		}
	}
	
	return nil;
}

- (NSDictionary *)entryOptionForDestination:(int)anEntryOptionDestination
{
	NSDictionary *theEntryOption;
	NSEnumerator *e = [[self entryOptions] objectEnumerator];

	while(theEntryOption = [e nextObject]) {
		if ([[theEntryOption objectForKey:@"destination"] isEqual:[NSNumber numberWithInt:anEntryOptionDestination]]) {
			return theEntryOption;
		}
	}

	return nil;
}

- (NSArray *)usedEntryDestinationOptions
{
	NSDictionary *entryOption;
	NSMutableArray *usedEntryDestinationOptions = [[NSMutableArray alloc] init];
	
	// Enumerate all of the currently used entry options and add them to the used option array
	NSEnumerator *e = [[self entryOptions] objectEnumerator];
	
 	while (entryOption = [e nextObject]) {
		[usedEntryDestinationOptions addObject:[entryOption objectForKey:@"destination"]];
	}
	
	return [usedEntryDestinationOptions autorelease];
}

- (void)populateEntryOptionDestinations
{
	int viewIndex;
	int viewCount;
	NSView *theEntryOptionView;
	NSEnumerator *menuItemEnumerator;
	NSMenuItem *menuItem;
	
	// Enumerate the views removing the existing options and add the filtered options
	viewCount = [[self subviews] count];
	
	for (viewIndex = 0; viewIndex < viewCount; viewIndex++) {
		theEntryOptionView = [[self subviews] objectAtIndex:viewIndex];
		
		menuItemEnumerator = [[[theEntryOptionView viewWithTag:1001] itemArray] objectEnumerator];
		
		while (menuItem = [menuItemEnumerator nextObject]) {
			if (([[self usedEntryDestinationOptions] indexOfObject:[NSNumber numberWithInt:[menuItem tag]]] != NSNotFound) && (![[NSNumber numberWithInt:[menuItem tag]] isEqual:[NSNumber numberWithInt:[[theEntryOptionView viewWithTag:1001] indexOfSelectedItem]]])) {
				[menuItem setEnabled:NO];
			} else {
				[menuItem setEnabled:YES];
			}
		}
	}
}

- (int)indexOfFirstAvailableEntryDestinationMenuOption
{
	int index;
	
	for (index = 0; index < 7; index++) {
		if ([[self usedEntryDestinationOptions] indexOfObject:[NSNumber numberWithInt:index]] == NSNotFound) {
			return index;
		}
	}
	
	return NSNotFound;
}
@end
