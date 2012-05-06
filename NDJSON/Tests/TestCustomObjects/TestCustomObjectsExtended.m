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
    [aTestGroup addTest:[self testCustomObjectsSimpleWithName:@"Extended Test"
                                             jsonSourceString:@"{child:{every_child:[{name:\"Beta Object\"}],ignoredValue:20},doubleValue:3.1415,ignoredValue:10}"
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
	return [NSString stringWithFormat:@"json:\n%@\n\nresult:\n%@\n\n", jsonSourceString, self.lastResult];
}

- (id)run
{
	NSError						* theError = nil;
	NDJSONParser		* theJSON = [[NDJSONParser alloc] initWithRootClass:rootClass rootCollectionClass:Nil];
	
	self.lastResult = [theJSON propertyListForJSONString:jsonSourceString error:&theError];
	self.error = theError;
	
	[theJSON release];
	return lastResult;
}

@end

@implementation ChildBeta
@synthesize     name;

@end

@implementation ChildAlpha
@synthesize     everyChild;
+ (NSSet *)ignoreSetJSONParser:(NDJSONParser *)aParser
{
    static NSSet       * kIgnoreSet = nil;
    if( kIgnoreSet == nil )
        kIgnoreSet = [[NSSet alloc] initWithObjects:@"ignoredValue", nil];
    return kIgnoreSet;
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
        kNamesForKeys = [[NSDictionary alloc] initWithObjectsAndKeys:@"doubleValue", @"value", nil];
    return kNamesForKeys;
}

+ (NSDictionary *)classesForPropertyNamesJSONParser:(NDJSONParser *)aParser
{
    static NSDictionary     * kClassesForKeys = nil;
    if( kClassesForKeys == nil )
        kClassesForKeys = [[NSDictionary alloc] initWithObjectsAndKeys:[ChildAlpha class], @"child", nil];
    return kClassesForKeys;
}

@end
