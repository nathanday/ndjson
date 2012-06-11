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
	NSMutableArray			* everyTest;
}

@property(readonly)		NSMutableDictionary		* testsByName;
@end

@implementation TestGroup

@synthesize name;

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
	[everyTest release];
    [super dealloc];
}

- (enum TestOperationState)operationState
{
	enum TestOperationState		theResult = kTestOperationStateInitial;
	for( id<TestProtocol> theTest in self.everyTest )
	{
		enum TestOperationState		theState = theTest.operationState;
		if( theState > theResult )
			theResult = theState;
	}
	return theResult;
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

- (NSMutableArray *)everyTest
{
	if( everyTest == nil )
		everyTest = [[NSMutableArray alloc] init];
	return everyTest;
}

- (void)addTest:(id<TestProtocol>)aTest
{
	[self.everyTest addObject:aTest];
	aTest.testGroup = self;
}

@end
