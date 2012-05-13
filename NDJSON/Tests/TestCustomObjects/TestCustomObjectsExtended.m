//
//  TestCustomObjectsExtended.m
//  NDJSON
//
//  Created by Nathan Day on 29/04/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import "TestCustomObjectsExtended.h"
#import "NDJSONParser.h"

@interface ChildBeta : NSObject
@property(retain,nonatomic)     NSString * name;

@end

@interface ChildAlpha : NSObject
@property(retain,nonatomic)     NSSet       * everyChild;
@end

@interface RootAlpha : NSObject
@property(retain,nonatomic)     id      child;
@property(assign,nonatomic)     double  value;
@end

@implementation TestCustomObjectsExtended

+ (void)addTestsToTestGroup:(TestGroup *)aTestGroup
{
    [aTestGroup addTest:[self testCustomObjectsSimpleWithName:@"Extended Test One"
                                             jsonSourceString:@"{doubleValue:3.1415,ignoredValueA:10,child:{every_child:[{name:\"Beta Object 1\"},{name:\"Beta Object 2\"}],ignoredValueB:20}}"
                                                    rootClass:[RootAlpha class]]];
    [aTestGroup addTest:[self testCustomObjectsSimpleWithName:@"Extended Test Two"
                                             jsonSourceString:@"{child:{every_child:[{name:\"Beta Object 1\"},{name:\"Beta Object 2\"}],ignoredValueA:20},doubleValue:3.1415,ignoredValueB:10}"
                                                    rootClass:[RootAlpha class]]];
}

+ (id)testCustomObjectsSimpleWithName:(NSString *)aName jsonSourceString:(NSString *)aSource rootClass:(Class)aRootClass
{
    return [[[self alloc] initWithName:aName jsonSourceString:aSource rootClass:aRootClass] autorelease];
}

- (id)initWithName:(NSString *)aName jsonSourceString:(NSString *)aSource rootClass:(Class)aRootClass
{
    if( (self = [self initWithName:aName]) != nil )
    {
        rootClass = aRootClass;
        jsonSourceString = [aSource copy];
    }
    return self;
}

- (NSString *)details
{
	return [NSString stringWithFormat:@"json:\n%@\n\nresult:\n%@\n\nexpected result:\n%@\n\n", jsonSourceString, self.lastResult, self.expectedResult];
}

- (id)run
{
	NSError						* theError = nil;
	NDJSONParser		* theJSON = [[NDJSONParser alloc] initWithRootClass:rootClass rootCollectionClass:Nil];
	theJSON.convertKeysToMedialCapital = YES;
	
	self.lastResult = [theJSON propertyListForJSONString:jsonSourceString error:&theError];
	self.error = theError;
	
	[theJSON release];
	return lastResult;
}

- (id)expectedResult
{
	RootAlpha		* theResult = [[RootAlpha alloc] init];
	ChildAlpha		* theChildAlpha = [[ChildAlpha alloc] init];
	ChildBeta		* theChildBeta1 = [[ChildBeta alloc] init],
					* theChildBeta2 = [[ChildBeta alloc] init];

	theResult.child = theChildAlpha;
	theResult.value = 3.1415;
	theChildAlpha.everyChild = [NSSet setWithObjects:theChildBeta1, theChildBeta2, nil];
	theChildBeta1.name = @"Beta Object 1";
	theChildBeta2.name = @"Beta Object 2";
	[theChildAlpha release];
	[theChildBeta1 release];
	[theChildBeta2 release];
	return [theResult autorelease];
}

@end

@implementation ChildBeta
@synthesize     name;

- (NSString *)description { return [NSString stringWithFormat:@"{name:\"%@\"}", self.name]; }

@end

@implementation ChildAlpha
@synthesize     everyChild;
+ (NSSet *)ignoreSetJSONParser:(NDJSONParser *)aParser
{
    static NSSet       * kIgnoreSet = nil;
    if( kIgnoreSet == nil )
        kIgnoreSet = [[NSSet alloc] initWithObjects:@"ignoredValueB", nil];
    return kIgnoreSet;
}

+ (NSDictionary *)collectionClassesForPropertyNamesJSONParser:(NDJSONParser *)aParser
{
    static NSDictionary     * kClassesForKeys = nil;
    if( kClassesForKeys == nil )
		kClassesForKeys = [NSDictionary dictionaryWithObjectsAndKeys:[NSSet class], @"everyChild", nil];
	return kClassesForKeys;
}

+ (NSDictionary *)classesForPropertyNamesJSONParser:(NDJSONParser *)aParser
{
    static NSDictionary     * kClassesForKeys = nil;
    if( kClassesForKeys == nil )
        kClassesForKeys = [[NSDictionary alloc] initWithObjectsAndKeys:[ChildBeta class], @"everyChild", nil];
    return kClassesForKeys;
}

- (NSString *)description
{
	NSMutableString		* theEveryChild = nil;
	for( id theChild in self.everyChild )
	{
		if( theEveryChild == nil )
			theEveryChild = [NSMutableString stringWithFormat:@"%@",theChild];
		else
			[theEveryChild appendFormat:@",%@",theChild];
	}
	return [NSString stringWithFormat:@"{everyChild:[%@]}", theEveryChild ? theEveryChild : @""];
}

@end

@implementation RootAlpha

@synthesize     child,
                value;

+ (NSSet *)considerSetJSONParser:(NDJSONParser *)aParser
{
    static NSSet       * kConsiderSet = nil;
    if( kConsiderSet == nil )
        kConsiderSet = [[NSSet alloc] initWithObjects:@"child", @"doubleValue", nil];
    return kConsiderSet;
}

+ (NSDictionary *)propertyNamesForKeysJSONParser:(NDJSONParser *)aParser
{
    static NSDictionary     * kNamesForKeys = nil;
    if( kNamesForKeys == nil )
        kNamesForKeys = [[NSDictionary alloc] initWithObjectsAndKeys:@"value", @"doubleValue", nil];
    return kNamesForKeys;
}

+ (NSDictionary *)classesForPropertyNamesJSONParser:(NDJSONParser *)aParser
{
    static NSDictionary     * kClassesForKeys = nil;
    if( kClassesForKeys == nil )
        kClassesForKeys = [[NSDictionary alloc] initWithObjectsAndKeys:[ChildAlpha class], @"child", nil];
    return kClassesForKeys;
}

- (NSString *)description { return [NSString stringWithFormat:@"{child:%@,doubleValue:%.4f}", self.child, self.value]; }

@end
