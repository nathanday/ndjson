//
//  TestJSONRequest.m
//  NDJSON
//
//  Created by Nathan Day on 6/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestJSONRequest.h"
#import "NDJSONDeserializer.h"
#import "NDJSONRequest.h"
#import "TestProtocolBase.h"
#import "NSObject+TestUtilities.h"


@interface TestJSONRequest ()
- (void)addName:(NSString *)aName URLString:(NSString *)aURLString;
@end

@interface TestJSONRequestItem : TestProtocolBase
{
	NSRange			characterRange;
}
- (id)initWithName:(NSString *)aName URLString:(NSString *)URLString;

@property(readonly)			NSURL			* URL;
@property(readonly)			id				expectedResult;
@end

@implementation TestJSONRequest

- (NSString *)testDescription { return @"Test \\u escape sequences and how they are converted into utf-8"; }

- (void)addName:(NSString *)aName URLString:(NSString *)aURLString
{
	TestJSONRequestItem		* theTestJSONRequestItem = [[TestJSONRequestItem alloc] initWithName:aName URLString:aURLString];
	[self addTest:theTestJSONRequestItem];
}

- (void)willLoad
{
	[super willLoad];
	[self addName:@"Remote File" URLString:@"http://fakester.biz/json"];
}

@end

@implementation TestJSONRequestItem

@synthesize		expectedResult,
				URL;

#pragma mark - manually implemented properties

- (NSString *)details
{
	return [NSString stringWithFormat:@"URL:\n%@\n\nresult:\n%@\n\nexpected result:\n%@\n\n", self.URL, [self.lastResult detailedDescription], [self.expectedResult detailedDescription]];
}

- (NSString *)jsonString
{
	NSMutableString			* theResult = [NSMutableString stringWithString:@"{\"result\":\""];
	for( NSUInteger theIndex = characterRange.location; theIndex < characterRange.location+characterRange.length; theIndex++ )
		[theResult appendFormat:@"\\u%04lx",theIndex];
	[theResult appendString:@"\"}"];
	return theResult;
}

- (id)expectedResult
{
	NSMutableString			* theString = [NSMutableString stringWithCapacity:characterRange.length];
	for( unichar theIndex = (unichar)characterRange.location; theIndex < characterRange.location+characterRange.length; theIndex++ )
		[theString appendFormat:@"%C",theIndex];
	return [NSDictionary dictionaryWithObject:theString forKey:@"result"];
}

#pragma mark - creation and destruction

- (id)initWithName:(NSString *)aName URLString:(NSString *)aURLString
{
	if( (self = [super initWithName:aName]) != nil )
		URL = [NSURL URLWithString:aURLString];
	return self;
}

#pragma mark - execution

- (id)run
{
	id		theResult = nil;
	NDJSONDeserializer		* theJSONDeserializer = [[NDJSONDeserializer alloc] init];
	NDJSONMutableRequest	* theRequest = [[NDJSONMutableRequest alloc] initWithDeserializer:theJSONDeserializer];
	NSConditionLock			* theLock = [[NSConditionLock alloc] initWithCondition:NO];
	theRequest.URL = self.URL;
	[theRequest sendAsynchronousWithQueue:[NSOperationQueue mainQueue] responseCompletionHandler:^(NDJSONRequest * aRequest, NDJSONResponse * aResponse) {
		[theLock lock];
		self.lastResult = aResponse.result;
		self.error = aResponse.error;
		[theLock unlockWithCondition:YES];
	}];
	[theLock lockWhenCondition:YES];
	theResult = self.lastResult;
	[theLock unlockWithCondition:NO];
	return theResult;
}

#pragma mark - NSObject overridden methods

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@, name: %@", [self class], self.name];
}


@end

