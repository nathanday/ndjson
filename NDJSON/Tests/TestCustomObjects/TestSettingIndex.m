//
//  TestSettingIndex.m
//  NDJSON
//
//  Created by Nathan Day on 22/04/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import "TestSettingIndex.h"
#import "NDJSONDeserializer.h"
#import "NSObject+TestUtilities.h"

@interface IndexClass : NSObject
{
	NSString	* name;
	NSUInteger	index;
}
@property(retain,nonatomic)	NSString		* name;
@property(readonly,nonatomic) NSUInteger	index;

+ (id)withName:(NSString *)name index:(NSUInteger)index;
- (id)initWithName:(NSString *)name index:(NSUInteger)index;

@end

@implementation TestSettingIndex

@synthesize			expectedResult;

+ (void)addTestsToTestGroup:(TestGroup *)aTestGroup
{
	NSArray		* theExpectedResult = [NSSet setWithObjects:[IndexClass withName:@"obj-0" index:0],
									   [IndexClass withName:@"obj-1" index:1],
									   [IndexClass withName:@"obj-2" index:2],
									   [IndexClass withName:@"obj-3" index:3],
									   nil];
	[aTestGroup addTest:[self testCustomObjectsSimpleWithName:@"Setting of Index"
											 jsonSourceString:@"[{name:\"obj-0\"},{name:\"obj-1\"},{name:\"obj-2\"},{name:\"obj-3\"}]" expectedResult:theExpectedResult]];
}

+ (id)testCustomObjectsSimpleWithName:(NSString *)aName jsonSourceString:(NSString *)aSource expectedResult:(id)anExpectedResult
{
	return [[self alloc] initWithName:(NSString *)aName jsonSourceString:aSource expectedResult:anExpectedResult];
}
- (id)initWithName:(NSString *)aName jsonSourceString:(NSString *)aSource expectedResult:(id)anExpectedResult
{
	if( (self = [super initWithName:aName]) != nil )
	{
		jsonSourceString = [aSource copy];
		expectedResult = anExpectedResult;
	}
	return self;
}

- (NSString *)details
{
	return [NSString stringWithFormat:@"json:\n%@\n\nresult:\n%@\n\nexpected result:\n%@\n\n", jsonSourceString, [self.lastResult detailedDescription], [self.expectedResult detailedDescription]];
}

- (id)run
{
	NSError					* theError = nil;
	NDJSONParser			* theJSON = [[NDJSONParser alloc] init];
	NDJSONDeserializer		* theJSONParser = [[NDJSONDeserializer alloc] initWithRootClass:[IndexClass class] rootCollectionClass:[NSSet class]];
	[theJSON setJSONString:jsonSourceString];
	self.lastResult = [theJSONParser objectForJSON:theJSON options:NDJSONOptionNone error:&theError];
	self.error = theError;
	return lastResult;
}

@end

@implementation IndexClass

@synthesize name, index;

+ (id)withName:(NSString *)aName index:(NSUInteger)anIndex { return [[self alloc] initWithName:aName index:anIndex]; }
- (id)initWithName:(NSString *)aName index:(NSUInteger)anIndex
{
	if( (self = [super init]) != nil )
	{
		name = [aName copy];
		index = anIndex;
	}
	return self;
}

- (void)jsonParser:(NDJSONDeserializer *)aParser setIndex:(NSUInteger)anIndex { index = anIndex; }
- (NSString *)description { return [NSString stringWithFormat:@"{name:%@,index:%lu}", self.name, self.index]; }

- (BOOL)isEqual:(id)anObject { return [anObject isKindOfClass:[IndexClass class]] && [[anObject name] isEqualToString:self.name] && [anObject index] == self.index; }

@end
