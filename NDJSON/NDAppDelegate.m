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
}

@property(readonly)		NSArray					* everyTestGroup;

@end

@implementation NDAppDelegate

@synthesize		window;

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

		for( NSString * theClassName in theClassNames )
		{
			TestGroup		* theTest = [[NSClassFromString(theClassName) alloc] init];
			[theEveryTest addObject:theTest];
			[theTest release];
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

#pragma mark - NSOutlineViewDataSource protocol methods

#pragma mark - NSOutlineViewDelegate protocol methods

@end
