//
//  TestInitWithParent.m
//  NDJSON
//
//  Created by Nathan Day on 29/04/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import "TestInitWithParent.h"
#import "NDJSONDeserializer.h"
#import "NSObject+TestUtilities.h"

@class TestInitRoot;

@interface TestSetParentChild : NSObject
{
	NSString		* __strong _name;
	NSUInteger		_integer;
	TestInitRoot	* __unsafe_unretained _parent;
}

@property(copy,nonatomic)     NSString			* name;
@property(assign,nonatomic)		NSUInteger		integer;
@property(assign,nonatomic)		TestInitRoot	* parent;

@end

@interface TestInitRoot : NSObject
{
	NSArray			* _everyChild;
	NSUInteger		_integer;
}
@property(retain,nonatomic)     NSArray					* everyChild;
@property(retain,nonatomic)     TestSetParentChild		* child;
@property(assign,nonatomic)		NSUInteger				integer;
@end

@implementation TestInitWithParent

+ (void)addTestsToTestGroup:(TestGroup *)aTestGroup
{
    [aTestGroup addTest:[self testCustomObjectsSimpleWithName:@"initWithJSONParent: single children only"
                                             jsonSourceString:@"{\"name\":\"parent\",\"integer\":42,\"child\":{\"name\":\"child\",\"integer\":92}}"
                                                    multipleChildren:NO]];
    [aTestGroup addTest:[self testCustomObjectsSimpleWithName:@"initWithJSONParent: children array"
                                             jsonSourceString:@"{\"name\":\"parent\",\"integer\":42,\"children\":[{\"name\":\"child A\",\"integer\":92},{\"name\":\"child B\",\"integer\":134}]}"
                                                    multipleChildren:YES]];
}

+ (id)testCustomObjectsSimpleWithName:(NSString *)aName jsonSourceString:(NSString *)aSource multipleChildren:(BOOL)aMultipleChildren
{
    return [[self alloc] initWithName:aName jsonSourceString:aSource multipleChildren:aMultipleChildren];
}

- (id)initWithName:(NSString *)aName jsonSourceString:(NSString *)aSource multipleChildren:(BOOL)aMultipleChildren
{
    if( (self = [self initWithName:aName]) != nil )
    {
        multipleChildren = aMultipleChildren;
        jsonSourceString = [aSource copy];
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
	NDJSONParser			* theJSON = [[NDJSONParser alloc] initWithJSONString:jsonSourceString];
	NDJSONDeserializer		* theJSONParser = [[NDJSONDeserializer alloc] initWithRootClass:[TestInitRoot class] rootCollectionClass:Nil];
	self.lastResult = [theJSONParser objectForJSON:theJSON options:NDJSONOptionConvertKeysToMedialCapitals error:&theError];
	self.error = theError;
	return lastResult;
}

- (id)expectedResult
{
	TestInitRoot			* theResult = [[TestInitRoot alloc] init];
	if( multipleChildren )
	{
		TestSetParentChild		* theTestSetParentChild1 = [[TestSetParentChild alloc] init],
								* theTestSetParentChild2 = [[TestSetParentChild alloc] init];

		theTestSetParentChild1.name = @"Child A";
		theTestSetParentChild1.integer = 92;
		theTestSetParentChild2.name = @"Child B";
		theTestSetParentChild2.integer = 134;
	}
	return theResult;
}

@end

@implementation TestSetParentChild
@synthesize		name = _name,
				integer = _integer,
				parent = _parent;

- (void)jsonDeserializer:(NDJSONDeserializer *)aParser setParent:(id)aParent
{
	NSParameterAssert([aParent isKindOfClass:[TestInitRoot class]]);
	_parent = aParent;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"{name:%@,integer:%lu,parent:%p}", self.name, (unsigned long)self.integer,self.parent];
}

- (BOOL)isEqual:(id)anObject
{
	TestSetParentChild		* theObject = (TestSetParentChild*)anObject;
	return [theObject isKindOfClass:[TestSetParentChild class]]
				&& [self.name isEqualToString:theObject.name]
				&& self.integer == theObject.integer
				&& self.parent == theObject.parent;
}

NDJSONParentPropertyName(@"parent");

@end

@implementation TestInitRoot

@synthesize     everyChild = _everyChild,
				integer = _integer;

- (NSString *)description { return [NSString stringWithFormat:@"{child:[%@],doubleValue:%lu}", self.everyChild, self.integer]; }

- (BOOL)isEqual:(id)anObject
{
	TestInitRoot		* theTestInitRoot = anObject;
	return [theTestInitRoot isKindOfClass:[TestInitRoot class]]
				&& self.integer == theTestInitRoot.integer
				&& [self.everyChild isEqualToArray:theTestInitRoot.everyChild];
}

- (void)setChild:(TestSetParentChild *)aChild
{
	_everyChild = [[NSArray alloc] initWithObjects:aChild, nil];
}

- (TestSetParentChild *)child
{
	NSParameterAssert(_everyChild.count == 1);
	return [_everyChild lastObject];
}

@end
