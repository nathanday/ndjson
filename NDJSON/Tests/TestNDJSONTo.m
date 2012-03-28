//
//  TestNDJSONTo.m
//  NDJSON
//
//  Created by Nathan Day on 25/03/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import "TestNDJSONTo.h"
#import "TestProtocolBase.h"
#import "NDJSONTo.h"

@interface TestJSONClassChildA : NSObject

@property(retain,nonatomic)	NSString	* name;
@property(assign,nonatomic)	double		doubleValue;

@end

@interface TestJSONClassChildB : NSObject

@property(retain,nonatomic)	NSString	* name;
@property(assign,nonatomic)	NSUInteger	integerValue;

@end

@interface TestRootJSONClass : NSObject

@property(retain,nonatomic)	TestJSONClassChildA		* childElement;
@property(retain,nonatomic)	NSMutableArray				* childArray;

@end

@interface TestNDJSONToItem : TestProtocolBase
{
	NSString	* jsonSourceString;
	Class		rootClass;
}
+ (id)testNDJSONToItemWithName:(NSString *)name class:(Class)class jsonSourceString:(NSString *)source;
- (id)initWithName:(NSString *)name class:(Class)class jsonSourceString:(NSString *)source;

@end

@implementation TestNDJSONTo

- (NSString	*)name { return @"Test NDJSONTo"; }

- (void)willLoad
{
	[self addTest:[TestNDJSONToItem testNDJSONToItemWithName:@"Object within Object" class:[TestRootJSONClass class] jsonSourceString:@"{childElement:{name:\"3.1415\",doubleValue:3.1415},childArray:[{name:\"1\",integerValue:1},{name:\"2\",integerValue:2},{name:\"3\",integerValue:3},{name:\"4\",integerValue:4}]}"]];
	[self addTest:[TestNDJSONToItem testNDJSONToItemWithName:@"redundant Value" class:[TestRootJSONClass class] jsonSourceString:@"{childElement:{name:\"3.1415\",doubleValue:3.1415,ignoredValue:\"ignored\"},childArray:[{name:\"1\",integerValue:1},{name:\"2\",integerValue:2},{name:\"3\",integerValue:3},{name:\"4\",integerValue:4}]}"]];
	[self addTest:[TestNDJSONToItem testNDJSONToItemWithName:@"Mapped Value" class:[TestRootJSONClass class] jsonSourceString:@"{childElement:{name:\"3.1415\",floatValue:3.1415},childArray:[{name:\"1\",integerValue:1},{name:\"2\",integerValue:2},{name:\"3\",integerValue:3},{name:\"4\",integerValue:4}]}"]];
}

@end

@implementation TestNDJSONToItem

+ (id)testNDJSONToItemWithName:(NSString *)aName class:(Class)aClass jsonSourceString:(NSString *)aSource
{
	return [[[self alloc] initWithName:(NSString *)aName class:aClass jsonSourceString:aSource] autorelease];
}
- (id)initWithName:(NSString *)aName class:(Class)aClass jsonSourceString:(NSString *)aSource
{
	if( (self = [super initWithName:aName]) != nil )
	{
		rootClass = aClass;
		jsonSourceString = [aSource copy];
	}
	return self;
}

- (void)dealloc
{
	[jsonSourceString release];
	[super dealloc];
}

- (NSString *)details
{
	TestRootJSONClass		* theRoot = [[TestRootJSONClass alloc] init];
	TestJSONClassChildA	* theChild = [[TestJSONClassChildA alloc] init];
	theChild.name = @"3.1415";
	theChild.doubleValue = 3.1415;
	theRoot.childElement = theChild;
	theRoot.childArray = [NSMutableArray array];
	for( NSUInteger i = 1; i <= 4; i++ )
	{
		TestJSONClassChildB	* theChildB = [[TestJSONClassChildB alloc] init];
		theChildB.name = [NSString stringWithFormat:@"%lu", i];
		theChildB.integerValue = i;
		[theRoot.childArray addObject:theChildB];
	}
	return [NSString stringWithFormat:@"json:\n%@\n\nresult:\n%@\n\nexpected result:\n%@\n\n", jsonSourceString, self.lastResult, theRoot];
}

- (id)run
{
	NSError			* theError = nil;
	NDJSONTo		* theJSON = [[NDJSONTo alloc] initWithRootClass:[TestRootJSONClass class]];
	
	self.lastResult = [theJSON propertyListForJSONString:jsonSourceString error:&theError];
	self.error = theError;
	
	[theJSON release];
	return lastResult;
}

@end

@implementation TestRootJSONClass

@synthesize		childElement,
				childArray;

- (NSString *)description { return [NSString stringWithFormat:@"{childElement:%@,childArray:%@}",self.childElement,self.childArray]; }

- (BOOL)isEqual:(id)anObject
{
	return [anObject isKindOfClass:[TestRootJSONClass class]] && [[anObject childElement] isEqual:self.childElement];
}

- (Class)classForPropertyName:(NSString *)aName
{
	Class		theResult = nil;
	if( [aName isEqualToString:@"childArray"] )
		theResult = [TestJSONClassChildB class];
	return theResult;
}

@end

@implementation TestJSONClassChildA

@synthesize name, doubleValue;

- (NSString *)description { return [NSString stringWithFormat:@"{name:%@,doubleValue:%.4f}", self.name, self.doubleValue]; }

- (BOOL)isEqual:(id)anObject
{
	return [anObject isKindOfClass:[TestJSONClassChildA class]] && [[anObject name] isEqualToString:self.name] && [anObject doubleValue] == self.doubleValue;
}

- (void)setValue:(id)aValue forUndefinedKey:(NSString *)aKey
{
	if( [aKey isEqualToString:@"floatValue"] )
		[self setValue:aValue forKey:@"doubleValue"];
}

@end


@implementation TestJSONClassChildB

@synthesize name, integerValue;

- (NSString *)description { return [NSString stringWithFormat:@"{name:%@,integerValue:%lu}", self.name, self.integerValue]; }

- (BOOL)isEqual:(id)anObject
{
	return [anObject isKindOfClass:[TestJSONClassChildB class]] && [[anObject name] isEqualToString:self.name] && [anObject integerValue] == self.integerValue;
}

@end