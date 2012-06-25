//
//  TestMechanismChange.m
//  NDJSON
//
//  Created by Nathan Day on 6/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestMechanismChange.h"
#import "NDJSONParser.h"
#import "TestProtocolBase.h"
#import "Utility.h"
#import "ChangeParseFromEventToPropertyList.h"
#import "ChangeParseFromEventToCustom.h"

@interface TestMechanismChange ()
@end

@interface TestSubElement : TestProtocolBase
{
	Class						class;
	NSString					* jsonString;
	id							expectedResult;
	NDJSONOptionFlags			options;
}
- (id)initWithClass:(Class)aClass;

@property(readonly)			Class				class;
@property(readonly)			NSString			* jsonString;
@property(readonly)			id					expectedResult;
@property(readonly)			NDJSONOptionFlags	options;
@end

@implementation TestMechanismChange

- (NSString *)testDescription { return @"Test input with string, all bytes are available, tests ability to recongnize all kinds of JSON"; }

- (void)willLoad
{
	TestSubElement	* theTestSubElements[] = {
						[[TestSubElement alloc] initWithClass:[ChangeParseFromEventToPropertyList class]],
						[[TestSubElement alloc] initWithClass:[ChangeParseFromEventToCustom class]]
					};
	for( NSUInteger i = 0; i < sizeof(theTestSubElements)/sizeof(*theTestSubElements); i++ )
	{
		[self addTest:theTestSubElements[i]];
		[theTestSubElements[i] release], theTestSubElements[i] = nil;

	}
	[super willLoad];
}

@end

@implementation TestSubElement

@synthesize		class,
				expectedResult,
				jsonString,
				options;

#pragma mark - manually implemented properties

- (NSString *)details
{
	return [NSString stringWithFormat:@"json:\n%@\n\nresult:\n%@\n\nexpected result:\n%@\n\n", self.jsonString, self.lastResult, self.expectedResult];
}

#pragma mark - creation and destruction

- (id)initWithClass:(Class)aClass
{
	if( (self = [super initWithName:[aClass name]]) != nil )
	{
		class = [aClass retain];
		jsonString = [[aClass jsonString] copy];
		expectedResult = [[aClass expectedResult] retain];
		options = [aClass options];
	}
	return self;
}

- (void)dealloc
{
	[class release];
	[jsonString release];
	[expectedResult release];
	[super dealloc];
}

#pragma mark - execution

- (id)run
{
	NSError								* theError = nil;
	NDJSON								* theJSON = [[NDJSON alloc] init];
	id									theResult = [[[self class] alloc] init];

	[theJSON setJSONString:self.jsonString];
	theJSON.delegate = theResult;
	if( [theJSON parseWithOptions:self.options] )
		self.lastResult = theResult;
	self.error = theError;
	[theResult release];
	[theJSON release];
	return self.lastResult;
}

#pragma mark - NSObject overridden methods

- (NSString *)description { return [NSString stringWithFormat:@"%@, name: %@", [self class], self.name]; }

@end
