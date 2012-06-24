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

@interface TestMechanismChange ()
@end

@interface TestSubElement : TestProtocolBase
{
	NSString					* jsonString;
	id							expectedResult;
	NDJSONOptionFlags			options;
}
- (id)initWithClass:(Class)aClass;
- (id)initWithName:(NSString *)name jsonString:(NSString *)json expectedResult:(id)result options:(NDJSONOptionFlags)options;

@property(readonly)			NSString			* jsonString;
@property(readonly)			id					expectedResult;
@property(readonly)			NDJSONOptionFlags	options;
@end

@implementation TestMechanismChange

- (NSString *)testDescription { return @"Test input with string, all bytes are available, tests ability to recongnize all kinds of JSON"; }

- (void)willLoad
{
	TestSubElement		* theTestSubElement = [[TestSubElement alloc] initWithClass:[ChangeParseFromEventToPropertyList class]];
	[self addTest:theTestSubElement];
	[theTestSubElement release];
	[super willLoad];
}

@end

@implementation TestSubElement

@synthesize		expectedResult,
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
	return [self initWithName:[aClass name] jsonString:[aClass jsonString] expectedResult:[aClass expectedResult] options:[aClass options]];
}
- (id)initWithName:(NSString *)aName jsonString:(NSString *)aJSON expectedResult:(id)aResult options:(NDJSONOptionFlags)anOptions
{
	if( (self = [super initWithName:aName]) != nil )
	{
		jsonString = [aJSON copy];
		expectedResult = [aResult retain];
		options = anOptions;
	}
	return self;
}

- (void)dealloc
{
	[jsonString release];
	[expectedResult release];
	[super dealloc];
}

#pragma mark - execution

- (id)run
{
	NSError								* theError = nil;
	NDJSON								* theJSON = [[NDJSON alloc] init];
	ChangeParseFromEventToPropertyList	* theResult = [[ChangeParseFromEventToPropertyList alloc] init];

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
