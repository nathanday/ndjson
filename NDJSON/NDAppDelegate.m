//
//  NDAppDelegate.m
//  NDJSON
//
//  Created by Nathan Day on 5/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "NDAppDelegate.h"
#import "TestGroup.h"

static NSString		* const kTestClassNamesFileName = @"TestClassNames",
					* const kClassNamesKey = @"ClassNames";

@interface NDAppDelegate ()
{
	NSMutableData			* onOffFlags;
	NSArray					* everyTestGroup;
	NSMutableDictionary		* checkForTestGroups;
}

@property(readonly)		NSArray					* everyTestGroup;
@property(readonly)		NSMutableDictionary		* checkForTestGroups;

@end

@implementation NDAppDelegate

@synthesize		window,
				checkForTestGroups;

#pragma mark - manually implemented properties

- (NSArray *)everyTestGroup
{
	if( everyTestGroup == nil )
	{
		NSMutableArray		* theEveryTest = [[NSMutableArray alloc] init];
		NSString			* thePath = [[NSBundle mainBundle] pathForResource:kTestClassNamesFileName ofType:@"plist"];
		NSAssert( thePath != nil, @"Failed to get path for property list %@", kTestClassNamesFileName );
		NSDictionary		* theTestProps = [[NSDictionary alloc] initWithContentsOfFile:thePath];
		
		NSArray				* theClassNames = [theTestProps objectForKey:kClassNamesKey];
		NSParameterAssert( theClassNames != nil );
		
		onOffFlags = [[NSMutableData alloc] initWithCapacity:everyTestGroup.count];

		checkForTestGroups = [[NSMutableDictionary alloc] initWithCapacity:theEveryTest.count];

		for( NSString * theClassName in theClassNames )
		{
			TestGroup		* theTest = [[NSClassFromString(theClassName) alloc] init];
			[theTest willLoad];
			[theEveryTest addObject:theTest];
			[theTest release];
			[checkForTestGroups setObject:[NSNumber numberWithBool:YES] forKey:theTest.name];
		}
		everyTestGroup = theEveryTest;
	}
	return everyTestGroup;
		
}

- (void)dealloc
{
	[everyTestGroup release];
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Insert code here to initialize your application
}

#pragma mark - Action handling methods

- (IBAction)clearLogs:(NSButton *)aSender
{
}

- (IBAction)runTests:(NSButton *)aSender
{
}

- (IBAction)checkAllTests:(NSButton *)aSender
{
}

- (IBAction)uncheckAllTests:(NSButton *)aSender
{
}

#pragma mark - NSOutlineViewDataSource protocol methods

- (id)outlineView:(NSOutlineView *)anOutlineView child:(NSInteger)anIndex ofItem:(id)anItem
{
	id		theResult = nil;
	if( anItem == nil )
		theResult = [self.everyTestGroup objectAtIndex:anIndex];
	else if( [anItem isKindOfClass:[TestGroup class]] )
		theResult = [[anItem testInstances] objectAtIndex:anIndex];
	else
		NSLog( @"Unexpected item %@", anItem );
	return theResult;
}

- (NSInteger)outlineView:(NSOutlineView *)anOutlineView numberOfChildrenOfItem:(id)anItem
{
	NSInteger		theCount = 0;
	if( anItem == nil )
		theCount =  self.everyTestGroup.count;
	else if( [anItem isKindOfClass:[TestGroup class]] )
		theCount = [[anItem testInstances] count];
	return theCount;
}

- (BOOL)outlineView:(NSOutlineView *)anOutlineView isItemExpandable:(id)anItem
{
	return [anItem isKindOfClass:[TestGroup class]];
}

- (id)outlineView:(NSOutlineView *)aOutlineView objectValueForTableColumn:(NSTableColumn *)aTableColumn byItem:(id)anItem
{
	id	theResult = nil;
	if( [aTableColumn.identifier isEqual:@"Name"] )
		theResult = [anItem name];
	else if( [aTableColumn.identifier isEqual:@"CheckBox"] )
		theResult = [self.checkForTestGroups objectForKey:[anItem name]];
	return theResult;
}

- (void)outlineView:(NSOutlineView *)aOutlineView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn byItem:(id)anItem
{
	if( [aTableColumn.identifier isEqual:@"CheckBox"] )
		[self.checkForTestGroups setObject:anObject forKey:[anItem name]];
}

#pragma mark - NSOutlineViewDelegate protocol methods
- (void)outlineView:(NSOutlineView *)aOutlineView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn item:(id)anItem
{
	if( [aTableColumn.identifier isEqual:@"Name"] )
	{
		if( [anItem isKindOfClass:[TestGroup class]] )
			[aCell setFont:[NSFont fontWithDescriptor:[[aCell font] fontDescriptor] size:12.0]];
		else
			[aCell setFont:[NSFont fontWithDescriptor:[[aCell font] fontDescriptor] size:10.0]];
	}
}

@end
