//
//  TestAutoConversion.m
//  NDJSON
//
//  Created by Nathan Day on 29/04/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import "TestAutoConversion.h"
#import "NDJSONDeserializer.h"
#import "NSObject+TestUtilities.h"

@class TestAutoConversionRoot;

@interface TestAutoConversionChild : NSObject
{
	NSString		* __strong _name;
	NSUInteger		_integer;
}

@property(copy,nonatomic)     NSString				* name;
@property(assign,nonatomic)		NSUInteger			integer;

@end

@interface TestAutoConversionRoot : NSObject
{
	NSArray				* _everyChild;
	NSString			* _name;
}
@property(copy,nonatomic)     NSArray					* everyChild;
@property(copy,nonatomic)		NSString				* name;

- (BOOL)isShallowEqual:(TestAutoConversionRoot *)anObject;

@end

@implementation TestAutoConversion

+ (void)addTestsToTestGroup:(TestGroup *)aTestGroup
{
    [aTestGroup addTest:[self testCustomObjectsSimpleWithName:@"Test converting none array to array or set"
                                             jsonSourceString:@"{\"name\":\"parent\",\"everyChild\":{\"name\":\"Child A\",\"integer\":42}}"
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
	NDJSONDeserializer		* theJSONParser = [[NDJSONDeserializer alloc] initWithRootClass:[TestAutoConversionRoot class] rootCollectionClass:Nil];
	self.lastResult = [theJSONParser objectForJSON:theJSON options:NDJSONOptionConvertKeysToMedialCapitals|NDJSONOptionConvertToArrayTypeIfRequired error:&theError];
	self.error = theError;
	return lastResult;
}

- (id)expectedResult
{
	TestAutoConversionRoot	* theResult = [[TestAutoConversionRoot alloc] init];
	TestAutoConversionChild		* theTestAutoConversionChild1 = [[TestAutoConversionChild alloc] init];

	NSParameterAssert( theResult != nil );
	NSParameterAssert( theTestAutoConversionChild1 != nil );

	theResult.name = @"parent";

	theTestAutoConversionChild1.name = @"Child A";
	theTestAutoConversionChild1.integer = 42;

	theResult.everyChild = [NSArray arrayWithObjects:theTestAutoConversionChild1, nil];

	return theResult;
}

@end

@implementation TestAutoConversionChild
@synthesize		name = _name,
				integer = _integer;

- (NSString *)description
{
	return [NSString stringWithFormat:@"{name:%@,integer:%lu}", self.name, (unsigned long)self.integer];
}

- (BOOL)isEqual:(id)anObject
{
	TestAutoConversionChild		* theObject = (TestAutoConversionChild*)anObject;
	return [theObject isKindOfClass:[TestAutoConversionChild class]]
				&& [self.name isEqualToString:theObject.name]
				&& self.integer == theObject.integer;
}

@end

@implementation TestAutoConversionRoot

NDJSONClassesForPropertyNames( [TestAutoConversionChild class], @"everyChild");

@synthesize     everyChild = _everyChild,
				name = _name;

- (void)setEveryChild:(NSArray *)anEveryChild
{
	NSAssert( [anEveryChild isKindOfClass:[NSArray class]], @"attempted to set everyChild to a %@ instead of an %@", NSStringFromClass([anEveryChild class]), NSStringFromClass([NSArray class]) );
	NSAssert( [[anEveryChild lastObject] isKindOfClass:[TestAutoConversionChild class]], @"attempted to set everyChild to an array of %@ instead of an %@", NSStringFromClass([[anEveryChild lastObject] class]), NSStringFromClass([TestAutoConversionChild class]) );
	NSAssert(anEveryChild.count == 1, @"Got count == %lu", anEveryChild.count);
	NSAssert([[anEveryChild objectAtIndex:0] isKindOfClass:[TestAutoConversionChild class]], @"Got class %@", NSStringFromClass([[anEveryChild objectAtIndex:0] class]));

	_everyChild = [anEveryChild copy];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"{self:%p, name:%@, everyChild:%@}", self, self.name, self.everyChild];
}

- (BOOL)isShallowEqual:(TestAutoConversionRoot *)anObject
{
	TestAutoConversionRoot		* theObject = anObject;
	return [theObject isKindOfClass:[TestAutoConversionRoot class]]
				&& [self.name isEqualToString:theObject.name]
				&& self.everyChild.count == theObject.everyChild.count;
}

- (BOOL)isEqual:(id)anObject
{
	TestAutoConversionRoot		* theObject = anObject;
	return [self isShallowEqual:theObject]
				&& [self.everyChild isEqualToArray:theObject.everyChild];
}

@end
