//
//  TestGroup.m
//  NDJSON
//
//  Created by Nathan Day on 6/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestGroup.h"

@interface TestGroup ()
{
	NSString		* name;
	NSArray			* everyTestName;
	NSDictionary	* testGroupByName;
}

@end


@implementation TestGroup

@synthesize		everyTestName,
				testGroupByName;

+ (NSRegularExpression *)uncammelCaseRegularExpression
{
	static volatile NSRegularExpression		* kRegularExpression = nil;
	if( kRegularExpression == nil )
	{
		@synchronized( self )
		{
			if( kRegularExpression == nil )
			{
				NSError		* theError = nil;
				kRegularExpression = [[NSRegularExpression alloc] initWithPattern:@"[A-Z]" options:0 error:&theError];
				if( kRegularExpression == nil )
					NSLog( @"Error: %@", theError );
			}
		}
	}
	return (NSRegularExpression*)kRegularExpression;
}

+ (NSString *)uncammelCaseString:(NSString *)aString
{
	NSRegularExpression		* theRegularExpression = [[self class] uncammelCaseRegularExpression];
	NSString				* theResult = [theRegularExpression stringByReplacingMatchesInString:aString options:0 range:NSMakeRange(0,aString.length) withTemplate:@" $0"];
	
	if( [theResult hasPrefix:@"Test "] )
		theResult = [theResult substringFromIndex:5];
	else if( [theResult hasPrefix:@" "] )
		theResult = [theResult substringFromIndex:1];
	return theResult;
}

#pragma mark - creation and destruction

- (id)init
{
	NSAssert( [self isKindOfClass:[TestGroup class]], @"The class %@ is abstract.", NSStringFromClass([self class]) );
	return [super init];
}

- (void)dealloc
{
	[name release];
	[everyTestName release];
	[testGroupByName release];
    [super dealloc];
}

- (NSString	*)name
{
	if( name == nil )
		name = [[TestGroup uncammelCaseString:NSStringFromClass([self class])] retain];
	return name;
}

- (NSString	*)testDescription
{
	NSAssert(NO, @"The method %@ is abstract", NSStringFromSelector(_cmd));
	return nil;
}

- (NSArray *)testInstances
{
	NSAssert(NO, @"The method %@ is abstract", NSStringFromSelector(_cmd));
	return NULL;
}

- (void)willLoad
{
	NSMutableArray			* theNames = [[NSMutableArray alloc] init];
	for( id<TestProtocol> theTest in self.testInstances )
	{
		[theNames addObject:theTest.name];
	}
	everyTestName = theNames;
}


- (NSArray *)testGroupForName:(NSString*)aName { return [self.testGroupByName objectForKey:aName]; }

@end
