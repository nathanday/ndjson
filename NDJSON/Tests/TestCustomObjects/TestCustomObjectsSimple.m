//
//  TestCustomObjectsSimple.m
//  NDJSON
//
//  Created by Nathan Day on 22/04/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import "TestCustomObjectsSimple.h"
#import "NDJSONParser.h"

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
@property(retain,nonatomic)	NSSet					* childElements;

@end


@implementation TestCustomObjectsSimple

+ (void)addTestsToTestGroup:(TestGroup *)aTestGroup
{
	static NSString		* kNames[] = {@"Object within Object",@"redundant Value",@"Mapped Value",@"Root Array"},
						* kJSONSource[] = {
		@"{childElement:{name:\"pi\",doubleValue:3.1415},childElements:[{name:\"One\",integerValue:1}, {name:\"Two\",integerValue:2}, {name:\"Three\",integerValue:3}, {name:\"Four\",integerValue:4}]}",
		@"{\n\tchildElement:{\n\t\tname:\"pi\",\n\t\tdoubleValue:3.1415,\n\t\tignoredValue:\"ignored\"\n\t},\n\tchildElements:[\n\t\t{\n\t\t\tname:\"One\",\n\t\t\tintegerValue:1\n\t\t}, {\n\t\t\tname:\"Two\",\n\t\t\tintegerValue:2\n\t\t}, {\n\t\t\tname:\"three\",\n\t\t\tintegerValue:3\n\t\t}, {\n\t\t\tname:\"Four\",\n\t\t\tintegerValue:4\n\t\t}\n\t]\n}",
		@"{childElement:{name:\"pi\",floatValue:3.1415},childElements:[{name:\"One\",integerValue:1}, {name:\"Tow\",integerValue:2}, {name:\"Three\",integerValue:3}, {name:\"Four\",integerValue:4}]\n\t}",
		@"[\n\t{\n\t\tchildElement:{\n\t\t\tname:\"e\",\n\t\t\tdoubleValue:2.7182},\n\t\tchildElements:[\n\t\t\t{name:\"One\",integerValue:1},\n\t\t\t{name:\"Two\",integerValue:2},\n\t\t\t{name:\"Three\",integerValue:3},\n\t\t\t{name:\"Four\",integerValue:4}\n\t\t]\n\t},\n\t{\n\t\tchildElement:{\n\t\t\tname:\"pi\",\n\t\t\tdoubleValue:3.1415},\n\t\tchildElements:[\n\t\t\t{name:\"Five\",integerValue:5},\n\t\t\t{name:\"Six\",integerValue:6},\n\t\t\t{name:\"Seven\",integerValue:7},\n\t\t\t{name:\"Eight\",integerValue:8}\n\t\t]\n\t}\n]"
						};
	Class				kRootClass[] = {[TestRootJSONClass class],[TestRootJSONClass class],[TestRootJSONClass class],[TestRootJSONClass class]},
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
	return [[[self alloc] initWithName:(NSString *)aName jsonSourceString:aSource rootClass:aRootClass rootCollectionClass:aRootCollectionClass] autorelease];
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

- (void)dealloc
{
	[jsonSourceString release];
	[super dealloc];
}

- (NSString *)details
{
	return [NSString stringWithFormat:@"json:\n%@\n\nresult:\n%@\n\n", jsonSourceString, self.lastResult];
}

- (id)run
{
	NSError						* theError = nil;
	NDJSONParser		* theJSON = [[NDJSONParser alloc] initWithRootClass:rootClass rootCollectionClass:rootCollectionClass];
	
	self.lastResult = [theJSON propertyListForJSONString:jsonSourceString error:&theError];
	self.error = theError;
	
	[theJSON release];
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

- (Class)jsonParser:(NDJSONParser *)aParser classForPropertyName:(NSString *)aName
{
	Class		theResult = nil;
	if( [aName isEqualToString:@"childElements"] )
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
