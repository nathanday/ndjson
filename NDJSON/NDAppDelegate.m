//
//  NDAppDelegate.m
//  NDJSON
//
//  Created by Nathan Day on 5/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "NDAppDelegate.h"
#import "TestGroup.h"
#import "TestOperation.h"

static NSString		* const kTestClassNamesFileName = @"TestClassNames",
					* const kClassNamesKey = @"ClassNames";

static NSString		* const kInitedStateImageName = @"Initial",
					* const kExecutingStateImageName = @"InProgress",
					* const kFinishedStateImageName = @"Complete",
					* const kErrorStateImageName = @"Error";

static NSString		* const kNameColumnIdentifier = @"Name",
					* const kStateColumnIdentifier = @"State",
					* const kCheckBoxColumnIdentifier = @"CheckBox";

@interface TestGroupChecks : NSObject
{
@private
	NSMutableDictionary		* checkForTest;
	NSMutableDictionary		* stateForTest;
	BOOL					groupCheck;
}

@property(readonly)	NSMutableDictionary		* checkForTest;
@property(readonly)	NSMutableDictionary		* stateForTest;
@property(assign)	NSNumber				* value;
@property (assign)		BOOL				running;

+ (TestGroupChecks *)testGroupChecksWithBool:(BOOL)value;
- (TestGroupChecks *)initWithBool:(BOOL)value;
- (NSNumber *)valueForTestName:(NSString *)name;
- (void)setValue:(NSNumber *)value forTestName:(NSString *)name;
- (enum TestOperationState)stateForTestName:(NSString *)name;
- (void)setState:(enum TestOperationState)aValue forTestName:(NSString *)name;

@end

@interface NDAppDelegate ()
{
	NSMutableData			* onOffFlags;
	NSArray					* everyTestGroup;
	NSMutableDictionary		* checkForTestGroups;
	NSOperationQueue		* queue;
	NSUInteger				testsToComplete;
	BOOL					showErrorsOnly;
}

@property(readonly)		NSArray					* everyTestGroup;
@property(retain)		NSMutableDictionary		* checkForTestGroups;
@property(readonly)		NSOperationQueue		* queue;

- (void)startedTest:(id<TestProtocol>)test;
- (void)finshedTest:(id<TestProtocol>)test;
- (void)finishedAllTests;
- (void)updateStateColumn;

- (void)runTest:(id<TestProtocol>)aTest waitUntilFinished:(BOOL)aFlag;

@end

@implementation NDAppDelegate

@synthesize		window,
				checkForTestGroups,
				showErrorsOnly;

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
		NSMutableDictionary	* theCheckForTestGroups = [[NSMutableDictionary alloc] initWithCapacity:theEveryTest.count];
		NSParameterAssert( theClassNames != nil );
		
		onOffFlags = [[NSMutableData alloc] initWithCapacity:theEveryTest.count];

		for( NSString * theClassName in theClassNames )
		{
			TestGroup		* theTest = [[NSClassFromString(theClassName) alloc] init];
			[theTest willLoad];
			[theEveryTest addObject:theTest];
			[theTest release];
			[theCheckForTestGroups setObject:[TestGroupChecks testGroupChecksWithBool:YES] forKey:theTest.name];
		}
		self.checkForTestGroups = theCheckForTestGroups;
		[theCheckForTestGroups release];
		everyTestGroup = theEveryTest;
	}
	return everyTestGroup;
		
}

- (NSArray *)everyCheckedTest
{
	__block NSMutableArray		* theResult = [NSMutableArray array];
	[self.everyTestGroup enumerateObjectsUsingBlock:^(id anObject, NSUInteger anIndex, BOOL *aStop )
	 {
		 TestGroup		* theGroup = (TestGroup*)anObject;
		 [theGroup.everyTest enumerateObjectsUsingBlock:^(id anObject, NSUInteger anIndex, BOOL *aStop)
		  {
			  if( [[[self.checkForTestGroups objectForKey:[theGroup name]] valueForTestName:[anObject name]] boolValue] )
				  [theResult addObject:anObject];
		  }];

	 }];
	return [[theResult copy] autorelease];
}

- (NSOperationQueue *)queue
{
	if( queue == nil )
		queue = [[NSOperationQueue alloc] init];
	return queue;
}

- (void)setShowErrorsOnly:(BOOL)aFlag
{
	showErrorsOnly = aFlag;
	errorsOnlyCheckBoxButton.state = showErrorsOnly ? NSOnState : NSOffState;
}

#pragma mark - creation destruction

- (void)dealloc
{
	[everyTestGroup release];
    [super dealloc];
}

#pragma mark - NSApplicationDelegate methods

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Insert code here to initialize your application
}

#pragma mark - Action handling methods

- (IBAction)clearLogs:(NSButton *)aSender
{
	[logTextView setString:@""];
}

- (IBAction)detailsForSelectedTest:(NSButton *)aSender
{
	[testsOutlineView.selectedRowIndexes enumerateIndexesUsingBlock:^(NSUInteger anIndex, BOOL * aStop )
	{
		id<TestProtocol>		theItem = [testsOutlineView itemAtRow:anIndex];
		if( [theItem conformsToProtocol:@protocol(TestProtocol)] )
		{
			if( theItem.operationState == kTestOperationStateInitial )
				[self runTest:theItem waitUntilFinished:YES];
			[self logMessage:[NSString stringWithFormat:@"details for '%@'\n\n%@", theItem.name, theItem.details]];
		}
	}];
}

- (IBAction)runTests:(NSButton *)aSender
{
	NSCalendar			* theGregorian = [[NSCalendar alloc]
							 initWithCalendarIdentifier:NSGregorianCalendar];
	NSDateComponents	* theHourComps = [theGregorian components:NSWeekdayCalendarUnit fromDate:[NSDate date]];
	[self logMessage:[NSString stringWithFormat:@"%02d:%02d:%02d\n-----------------------------------------------------------", theHourComps.hour, theHourComps.minute, theHourComps.second]];
	[runStopButton setTitle:NSLocalizedString(@"Stop", @"Text for run/stop button when tests are running")];
	[self.queue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];
	for( id<TestProtocol> theTest in self.everyCheckedTest )
		[self runTest:theTest waitUntilFinished:NO];
}

- (IBAction)checkAllTests:(NSButton *)aSender
{
	for( TestGroup * theGroup in self.everyTestGroup )
	{
		[[self.checkForTestGroups objectForKey:[theGroup name]] setValue:[NSNumber numberWithBool:YES]];
		 for( id<TestProtocol> theTest in theGroup.everyTest )
			  [[self.checkForTestGroups objectForKey:[theGroup name]] setValue:[NSNumber numberWithBool:YES] forTestName:[theTest name]];
		 
	}
	[testsOutlineView setNeedsDisplay:YES];
}

- (IBAction)uncheckAllTests:(NSButton *)aSender
{
	for( TestGroup * theGroup in self.everyTestGroup )
	{
		[[self.checkForTestGroups objectForKey:[theGroup name]] setValue:[NSNumber numberWithBool:NO]];
		for( id<TestProtocol> theTest in theGroup.everyTest )
			[[self.checkForTestGroups objectForKey:[theGroup name]] setValue:[NSNumber numberWithBool:NO] forTestName:[theTest name]];
		
	}
	[testsOutlineView setNeedsDisplay:YES];
}

- (IBAction)clearAll:(id)aSender
{
	for( TestGroup * theGroup in self.everyTestGroup )
	{
		for( id<TestProtocol> theTest in theGroup.everyTest )
			[theTest setOperationState:kTestOperationStateInitial];
		
	}
	[testsOutlineView setNeedsDisplay:YES];
}

- (IBAction)errorsOnlyAction:(NSButton *)aSender
{
	self.showErrorsOnly = aSender.state == NSOnState;
}

- (void)logMessage:(NSString *)aMessage
{
	logTextView.string = [logTextView.string stringByAppendingFormat:@"%@\n", aMessage];
}

- (void)runTest:(id<TestProtocol>)aTest waitUntilFinished:(BOOL)aFlag
{
	TestOperation	* theTestOpp = [[TestOperation alloc] initWithTestProtocol:aTest];
	[theTestOpp setBeginningBlock:^{[self startedTest:aTest];}];
	[theTestOpp setCompletionBlock:^{[self finshedTest:aTest];}];
	[self.queue addOperation:theTestOpp];
	[theTestOpp release];
	if( aFlag )
		[self.queue waitUntilAllOperationsAreFinished];
}

#pragma mark - NSOutlineViewDataSource protocol methods

- (id)outlineView:(NSOutlineView *)anOutlineView child:(NSInteger)anIndex ofItem:(id)anItem
{
	id		theResult = nil;
	if( anItem == nil )
		theResult = [self.everyTestGroup objectAtIndex:anIndex];
	else if( [anItem isKindOfClass:[TestGroup class]] )
		theResult = [[anItem everyTest] objectAtIndex:anIndex];
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
		theCount = [[anItem everyTest] count];
	return theCount;
}

- (BOOL)outlineView:(NSOutlineView *)anOutlineView isItemExpandable:(id)anItem
{
	return [anItem isKindOfClass:[TestGroup class]];
}

- (id)outlineView:(NSOutlineView *)anOutlineView objectValueForTableColumn:(NSTableColumn *)aTableColumn byItem:(id)anItem
{
	id	theResult = nil;
	if( [aTableColumn.identifier isEqual:kNameColumnIdentifier] )
		theResult = [anItem name];
	else if( [aTableColumn.identifier isEqual:kStateColumnIdentifier] )
	{
		if( [anItem respondsToSelector:@selector(operationState)] )
		{
			switch( [anItem operationState] )
			{
			case kTestOperationStateInitial:
				theResult = NSLocalizedString(@"Initial", @"State displayed for kTestOperationStateInitial, showing that the test has not run yet." );
				break;
			case kTestOperationStateExecuting:
				theResult = NSLocalizedString(@"Executing", @"State displayed for kTestOperationStateExecuting, showing that the test is currently in progress" );
				break;
			case kTestOperationStateFinished:
				theResult = NSLocalizedString(@"Complete", @"State displayed for kTestOperationStateFinished, showing that the test was completed error free." );
				break;
			case kTestOperationStateError:
				theResult = NSLocalizedString(@"Error", @"State displayed for kTestOperationStateError, showing that the test was completed with and error result" );
				break;
			case kTestOperationStateException:
				theResult = NSLocalizedString(@"Exception", @"State displayed for kTestOperationStateException, showing that the test was not completed because an exception was thrown." );
				break;
			}
		}
	}
	else if( [aTableColumn.identifier isEqual:kCheckBoxColumnIdentifier] )
	{
		if( [anItem conformsToProtocol:@protocol(TestProtocol)] )
			theResult = [[self.checkForTestGroups objectForKey:[[anItem testGroup] name]] valueForTestName:[anItem name]];
		else
			theResult = [[self.checkForTestGroups objectForKey:[anItem name]] value];
	}
	return theResult;
}

- (void)outlineView:(NSOutlineView *)anOutlineView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn byItem:(id)anItem
{
	if( [aTableColumn.identifier isEqual:kCheckBoxColumnIdentifier] )
	{
		if( [anItem conformsToProtocol:@protocol(TestProtocol)] )
		{
			[[self.checkForTestGroups objectForKey:[[anItem testGroup] name]] setValue:anObject forTestName:[anItem name]];
		}
		else
		{
			[[self.checkForTestGroups objectForKey:[anItem name]] setValue:anObject];
			[anOutlineView setNeedsDisplay];
		}
	}
}

#pragma mark - NSOutlineViewDelegate protocol methods
- (void)outlineView:(NSOutlineView *)anOutlineView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn item:(id)anItem
{
	if( [aTableColumn.identifier isEqual:kNameColumnIdentifier] )
	{
		if( [anItem isKindOfClass:[TestGroup class]] )
			[aCell setFont:[NSFont fontWithDescriptor:[[aCell font] fontDescriptor] size:12.0]];
		else
			[aCell setFont:[NSFont fontWithDescriptor:[[aCell font] fontDescriptor] size:10.0]];
	}
	else if( [aTableColumn.identifier isEqual:kStateColumnIdentifier] )
	{
		if( [anItem respondsToSelector:@selector(operationState)] )
		{
			NSColor		* theTextColor = nil;
			switch( [anItem operationState] )
			{
				default:
				case kTestOperationStateInitial:
					theTextColor = [NSColor blackColor];
					break;
				case kTestOperationStateExecuting:
					theTextColor = [NSColor blueColor];
					break;
				case kTestOperationStateFinished:
					theTextColor = [NSColor colorWithDeviceHue:0.3333 saturation:1.0 brightness:0.75 alpha:1.0];
					break;
				case kTestOperationStateError:
				case kTestOperationStateException:
					theTextColor = [NSColor redColor];
					break;
			}
			[aCell setTextColor:theTextColor];
		}
	}
}

- (NSString *)outlineView:(NSOutlineView *)anOutlineView toolTipForCell:(NSCell *)aCell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)aTableColumn item:(id)anItem mouseLocation:(NSPoint)mouseLocation
{
	NSString	* theResult = @"Turn test on or off";;
	if( [aTableColumn.identifier isEqual:kNameColumnIdentifier] )
		theResult = [self outlineView:anOutlineView objectValueForTableColumn:aTableColumn byItem:anItem];
	return theResult;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)aNotification
{
	detailsButton.enabled = testsOutlineView.selectedRow > -1;
}

#pragma mark - NSSplitViewDelegate methods

- (BOOL)splitView:(NSSplitView *)aSplitView shouldAdjustSizeOfSubview:(NSView *)aSubview
{
	BOOL		theResult = YES;
	if( [self.window inLiveResize] && [testsOutlineView isDescendantOf:aSubview] )
		theResult = NO;
	return theResult;
}

- (CGFloat)splitView:(NSSplitView *)aSplitView constrainMinCoordinate:(CGFloat)aProposedMin ofSubviewAt:(NSInteger)aDividerIndex
{
	return 239;
}

- (BOOL)splitView:(NSSplitView *)aSplitView canCollapseSubview:(NSView *)aSubview { return NO; }

#pragma mark - Private

- (void)startedTest:(id<TestProtocol>)aTest
{
	@synchronized(self.queue)
	{
		testsToComplete++;
	}
	[[self.checkForTestGroups objectForKey:[[aTest testGroup] name]] setState:aTest.operationState forTestName:aTest.name];
	[self performSelectorOnMainThread:@selector(updateStateColumn) withObject:nil waitUntilDone:NO];
}

- (void)finshedTest:(id<TestProtocol>)aTest
{
	@synchronized(self.queue)
	{
		testsToComplete--;
		NSLog( @"Test %@ finshed", aTest.name );
		if( aTest.hasError )
			NSLog(@"%@", aTest.error );
		if( testsToComplete == 0 )
			[self finishedAllTests];
	}
	[[self.checkForTestGroups objectForKey:[[aTest testGroup] name]]  setState:aTest.operationState forTestName:aTest.name];
	[self performSelectorOnMainThread:@selector(updateStateColumn) withObject:nil waitUntilDone:NO];
}

- (void)finishedAllTests
{
	[runStopButton setTitle:NSLocalizedString(@"Run", @"Text for run/stop button when tests are NOT running")];
}

- (void)updateStateColumn
{
	NSParameterAssert( [NSThread mainThread] == [NSThread currentThread] );
/*
	NSRect	theColumnRect = [testsOutlineView rectOfColumn:[testsOutlineView columnWithIdentifier:kStateColumnIdentifier]];
	[testsOutlineView setNeedsDisplayInRect:theColumnRect];
*/
	[testsOutlineView setNeedsDisplay:YES];
}

@end

@implementation TestGroupChecks
@synthesize		checkForTest,
				stateForTest,
				running;
+ (TestGroupChecks *)testGroupChecksWithBool:(BOOL)aValue { return [[[self alloc] initWithBool:aValue] autorelease]; }
- (TestGroupChecks *)initWithBool:(BOOL)aValue
{
	if( (self = [super init]) != nil )
	{
		checkForTest = [[NSMutableDictionary alloc] init];
		stateForTest = [[NSMutableDictionary alloc] init];
		groupCheck = aValue;
	}
	return self;
}
- (void)dealloc
{
    [checkForTest release];
	[stateForTest release];
    [super dealloc];
}
- (NSNumber *)value { return [NSNumber numberWithBool:groupCheck]; }
- (void)setValue:(NSNumber *)aValue
{
	groupCheck = [aValue boolValue];
	[self.checkForTest removeAllObjects];
	
}
- (NSNumber *)valueForTestName:(NSString *)aName
{
	NSNumber		* theResult = [self.checkForTest objectForKey:aName];
	return theResult != nil ? theResult : self.value;
}
- (void)setValue:(NSNumber *)aValue forTestName:(NSString *)aName
{
	[self.checkForTest setObject:aValue forKey:aName];
}

- (enum TestOperationState)stateForTestName:(NSString *)aName
{
	@synchronized(self.stateForTest)
	{
		NSNumber		* theResult = [self.stateForTest objectForKey:aName];
		return theResult != nil ? (enum TestOperationState)theResult.integerValue : kTestOperationStateInitial;
	}
}

- (void)setState:(enum TestOperationState)aValue forTestName:(NSString *)aName
{
	@synchronized(self.stateForTest)
	{
		[self.stateForTest setObject:[NSNumber numberWithUnsignedInteger:aValue] forKey:aName];
	}
}

@end
