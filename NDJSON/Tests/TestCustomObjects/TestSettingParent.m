//
//  TestSettingParent.m
//  NDJSON
//
//  Created by Nathan Day on 29/04/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import "TestSettingParent.h"
#import "NDJSONDeserializer.h"
#import "NSObject+TestUtilities.h"

@class TestSettingParentRoot;

@interface TestSettingChild : NSObject
{
	NSString		* __strong _name;
	NSUInteger		_integer;
	TestSettingParentRoot	* __unsafe_unretained _parent;
}

@property(copy,nonatomic)     NSString				* name;
@property(assign,nonatomic)		NSUInteger			integer;
@property(assign,nonatomic)		TestSettingParentRoot		* parent;


@end

@interface TestSettingParentRoot : NSObject
{
	NSArray			* _everyChild;
	TestSettingChild	* _child;
	NSString		* _name;
}
@property(copy,nonatomic)     NSArray					* everyChild;
@property(retain,nonatomic)     TestSettingChild		* child;
@property(copy,nonatomic)		NSString				* name;

- (BOOL)isShallowEqual:(TestSettingParentRoot *)anObject;

@end

@implementation TestSettingParent

+ (void)addTestsToTestGroup:(TestGroup *)aTestGroup
{
    [aTestGroup addTest:[self testCustomObjectsSimpleWithName:@"Test setting parent"
                                             jsonSourceString:@"{\"name\":\"parent\",\"child\":{\"name\":\"Child A\",\"integer\":42},\"everyChild\":[{\"name\":\"Child B\",\"integer\":92},{\"name\":\"Child C\",\"integer\":134}]}"
                                                    multipleChildren:NO]];
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
	NDJSONDeserializer		* theJSONParser = [[NDJSONDeserializer alloc] initWithRootClass:[TestSettingParentRoot class] rootCollectionClass:Nil];
	self.lastResult = [theJSONParser objectForJSON:theJSON options:NDJSONOptionConvertKeysToMedialCapitals error:&theError];
	self.error = theError;
	return lastResult;
}

- (id)expectedResult
{
	TestSettingParentRoot	* theResult = [[TestSettingParentRoot alloc] init];
	TestSettingChild		* theTestSettingChild1 = [[TestSettingChild alloc] init],
							* theTestSettingChild2 = [[TestSettingChild alloc] init],
							* theTestSettingChild3 = [[TestSettingChild alloc] init];

	NSParameterAssert( theResult != nil );
	NSParameterAssert( theTestSettingChild1 != nil );
	NSParameterAssert( theTestSettingChild2 != nil );
	NSParameterAssert( theTestSettingChild3 != nil );

	theResult.name = @"parent";

	theTestSettingChild1.name = @"Child A";
	theTestSettingChild1.integer = 42;
	theResult.child = theTestSettingChild1;
	theTestSettingChild1.parent = theResult;

	theTestSettingChild2.name = @"Child B";
	theTestSettingChild2.integer = 92;
	theTestSettingChild2.parent = theResult;

	theTestSettingChild3.name = @"Child C";
	theTestSettingChild3.integer = 134;
	theTestSettingChild3.parent = theResult;

	theResult.everyChild = [NSArray arrayWithObjects:theTestSettingChild2, theTestSettingChild3, nil];

	return theResult;
}

@end

@implementation TestSettingChild
@synthesize		name = _name,
				integer = _integer,
				parent = _parent;

NDJSONParentPropertyName(@"parent");

- (void)setParent:(id)aParent
{
	NSParameterAssert([aParent isKindOfClass:[TestSettingParentRoot class]]);
	_parent = aParent;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"{name:%@,integer:%lu,parent:%p}", self.name, (unsigned long)self.integer,self.parent];
}

- (BOOL)isEqual:(id)anObject
{
	TestSettingChild		* theObject = (TestSettingChild*)anObject;
	return [theObject isKindOfClass:[TestSettingChild class]]
				&& [self.name isEqualToString:theObject.name]
				&& self.integer == theObject.integer
				&& [self.parent isShallowEqual:theObject.parent];
}

@end

@implementation TestSettingParentRoot

NDJSONClassesForPropertyNames( [TestSettingChild class], @"everyChild");

@synthesize     everyChild = _everyChild,
				child = _child,
				name = _name;

- (void)setEveryChild:(NSArray *)anEveryChild
{
	NSAssert(anEveryChild.count == 2, @"Got count == %lu", anEveryChild.count);
	NSAssert([[anEveryChild objectAtIndex:0] isKindOfClass:[TestSettingChild class]], @"Got class %@", NSStringFromClass([[anEveryChild objectAtIndex:0] class]));
	NSAssert([[anEveryChild objectAtIndex:1] isKindOfClass:[TestSettingChild class]], @"Got class %@", NSStringFromClass([[anEveryChild objectAtIndex:1] class]));

	_everyChild = [anEveryChild copy];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"{self:%p, name:%@, everyChild:%@,child:%@}", self, self.name, self.everyChild, self.child];
}

- (BOOL)isShallowEqual:(TestSettingParentRoot *)anObject
{
	TestSettingParentRoot		* theObject = anObject;
	return [theObject isKindOfClass:[TestSettingParentRoot class]]
				&& [self.name isEqualToString:theObject.name]
				&& (self.child != nil) == (theObject.child != nil)
				&& self.everyChild.count == theObject.everyChild.count;
}

- (BOOL)isEqual:(id)anObject
{
	TestSettingParentRoot		* theObject = anObject;
	return [self isShallowEqual:theObject]
				&& [self.child isEqual:theObject.child]
				&& [self.everyChild isEqualToArray:theObject.everyChild];
}

@end
