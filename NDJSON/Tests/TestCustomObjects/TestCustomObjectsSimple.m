//
//  TestCustomObjectsSimple.m
//  NDJSON
//
//  Created by Nathan Day on 22/04/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import "TestCustomObjectsSimple.h"
#import "NDJSONParser.h"
#import "NSObject+TestUtilities.h"

@interface TestJSONClassChildA : NSObject

@property(retain,nonatomic)	NSString	* name;
@property(assign,nonatomic)	double		doubleValue;
@property(assign,nonatomic)	NSNumber	* numberValue;

@end

@interface TestJSONClassChildB : NSObject

@property(retain,nonatomic)	NSString	* name;
@property(assign,nonatomic)	NSInteger	integerValue;

@end

@interface TestRootJSONClass : NSObject

@property(retain,nonatomic)	TestJSONClassChildA		* childElement;
@property(retain,nonatomic)	NSSet					* childElements;

@end


@implementation TestCustomObjectsSimple

+ (void)addTestsToTestGroup:(TestGroup *)aTestGroup
{
	static NSString		* kNames[] = {@"Object within Object",@"redundant Value",@"Mapped Value",@"Root Array",@"Simple Number Conversion"},
						* kJSONSource[] = {
		@"{\"childElement\":{\"name\":\"pi\",\"doubleValue\":3.1415,\"numberValue\":42},\"childElements\":[{\"name\":\"One\",\"integerValue\":1}, {\"name\":\"Two\",\"integerValue\":2}, {\"name\":\"Three\",\"integerValue\":3}, {\"name\":\"Four\",\"integerValue\":4}]}",
		@"{\n\t\"childElement\":{\n\t\t\"name\":\"pi\",\n\t\t\"doubleValue\":3.1415,\"numberValue\":42,\n\t\t\"ignoredValue\":\"ignored\"\n\t},\n\t\"childElements\":[\n\t\t{\n\t\t\t\"name\":\"One\",\n\t\t\t\"integerValue\":1\n\t\t}, {\n\t\t\t\"name\":\"Two\",\n\t\t\t\"integerValue\":2\n\t\t}, {\n\t\t\t\"name\":\"three\",\n\t\t\t\"integerValue\":3\n\t\t}, {\n\t\t\t\"name\":\"Four\",\n\t\t\t\"integerValue\":4\n\t\t}\n\t]\n}",
		@"{\t\"childElement\":{\t\"name\":\"pi\",\t\"floatValue\":3.1415},\t\"childElements\":[{\t\"name\":\"One\",\t\"integerValue\":1}, {\t\"name\":\"Two\",\t\"integerValue\":2}, {\t\"name\":\"Three\",\t\"integerValue\":3}, {\t\"name\":\"Four\",\t\"integerValue\":4}]\n\t}",
		@"[\n\t{\n\t\t\"childElement\":{\n\t\t\t\"name\":\"e\",\n\t\t\t\"doubleValue\":2.7182,\"numberValue\":42},\n\t\t\"childElements\":[\n\t\t\t{\t\"name\":\"One\",\t\"integerValue\":1},\n\t\t\t{\t\"name\":\"Two\",\t\"integerValue\":2},\n\t\t\t{\t\"name\":\"Three\",\t\"integerValue\":3},\n\t\t\t{\t\"name\":\"Four\",\t\"integerValue\":4}\n\t\t]\n\t},\n\t{\n\t\t\"childElement\":{\n\t\t\t\"name\":\"pi\",\n\t\t\t\"doubleValue\":3.1415,\"numberValue\":42},\n\t\t\"childElements\":[\n\t\t\t{\t\"name\":\"Five\",\t\"integerValue\":5},\n\t\t\t{\t\"name\":\"Six\",\t\"integerValue\":6},\n\t\t\t{\t\"name\":\"Seven\",\t\"integerValue\":7},\n\t\t\t{\t\"name\":\"Eight\",\t\"integerValue\":8}\n\t\t]\n\t}\n]",
		@"{\"childElement\":{\"name\":\"pi\",\"doubleValue\":3,\"numberValue\":42},\"childElements\":[{\"name\":\"One\",\"integerValue\":1}, {\"name\":\"Two\",\"integerValue\":2.1}, {\"name\":\"Three\",\"integerValue\":true}, {\"name\":\"Four\",\"integerValue\":4}]}"
						};
	Class				kRootClass[] = {[TestRootJSONClass class],[TestRootJSONClass class],[TestRootJSONClass class],[TestRootJSONClass class],[TestRootJSONClass class]},
						kRootCollectionClass[] = {Nil,Nil,Nil,[NSArray class]};
	for( NSUInteger i = 0; i < sizeof(kJSONSource)/sizeof(*kJSONSource); i++ )
	{
		[aTestGroup addTest:[self testCustomObjectsSimpleWithName:kNames[i]
												 jsonSourceString:kJSONSource[i]
														rootClass:kRootClass[i]
											  rootCollectionClass:kRootCollectionClass[i]]];
	}
}

+ (id)testCustomObjectsSimpleWithName:(NSString *)aName jsonSourceString:(NSString *)aSource rootClass:(Class)aRootClass rootCollectionClass:(Class)aRootCollectionClass
{
	return [[self alloc] initWithName:(NSString *)aName jsonSourceString:aSource rootClass:aRootClass rootCollectionClass:aRootCollectionClass];
}
- (id)initWithName:(NSString *)aName jsonSourceString:(NSString *)aSource rootClass:(Class)aRootClass rootCollectionClass:(Class)aRootCollectionClass
{
	if( (self = [super initWithName:aName]) != nil )
	{
		rootClass = aRootClass;
		rootCollectionClass = aRootCollectionClass;
		jsonSourceString = [aSource copy];
	}
	return self;
}

- (NSString *)details
{
	return [NSString stringWithFormat:@"json:\n%@\n\nresult:\n%@\n\n", jsonSourceString, [self.lastResult detailedDescription]];
}

- (id)run
{
	NSError				* theError = nil;
	NDJSON				* theJSON = [[NDJSON alloc] init];
	NDJSONParser		* theJSONParser = [[NDJSONParser alloc] initWithRootClass:rootClass rootCollectionClass:rootCollectionClass];
	[theJSON setJSONString:jsonSourceString];
	self.lastResult = [theJSONParser objectForJSON:theJSON options:NDJSONOptionNone error:&theError];
	self.error = theError;
	return lastResult;
}

@end

@implementation TestRootJSONClass

@synthesize		childElement,
childElements;

- (NSString *)description { return [NSString stringWithFormat:@"{childElement:%@,childElements:%@}",self.childElement,self.childElements]; }

- (BOOL)isEqual:(id)anObject
{
	return [anObject isKindOfClass:[TestRootJSONClass class]] && [[anObject childElement] isEqual:self.childElement];
}

+ (NSDictionary *)classesForPropertyNamesJSONParser:(NDJSONParser *)aParser
{
	static NSDictionary		* kResult = nil;
	if( kResult == nil )
		kResult = [[NSDictionary alloc] initWithObjectsAndKeys:[TestJSONClassChildB class], @"childElements", nil];
	return kResult;
}

@end

@implementation TestJSONClassChildA

@synthesize name, doubleValue, numberValue;

- (NSString *)description { return [NSString stringWithFormat:@"{name:%@,doubleValue:%.4f,numberValue:%@}", self.name, self.doubleValue,self.numberValue]; }

- (BOOL)isEqual:(id)anObject
{
	return [anObject isKindOfClass:[TestJSONClassChildA class]] && [[anObject name] isEqualToString:self.name] && [anObject doubleValue] == self.doubleValue && [[anObject numberValue] isEqualToNumber:self.numberValue];
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
