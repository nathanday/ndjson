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
	NSString				* name;
	NSMutableDictionary		* testsByName;
}

@property(readonly)		NSMutableDictionary		* testsByName;
@end

@implementation TestGroup

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

#pragma mark - manually implemented properties

- (NSMutableDictionary *)testsByName
{
	if( testsByName == nil )
		testsByName = [[NSMutableDictionary alloc] init];
	return testsByName;
}

#pragma mark - creation and destruction

- (id)init
{
	NSAssert( [self isKindOfClass:[TestGroup class]], @"The class %@ is abstract.", NSStringFromClass([self class]) );
	return [super init];
}

- (void)dealloc
{
	[testsByName release];
	[name release];
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

- (void)willLoad
{
	for( id<TestProtocol> theTest in self.everyTest )
		[self.testsByName setObject: theTest forKey:theTest.name];
}

- (enum TestOperationState)operationStateForTestNamed:(NSString *)aName
{
	return [[self.testsByName objectForKey:aName] operationState];
}

- (NSArray *)everyTest
{
	NSAssert(NO, @"The method %@ is abstract", NSStringFromSelector(_cmd));
	return NULL;
}

@end
