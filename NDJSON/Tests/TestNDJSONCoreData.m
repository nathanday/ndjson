//
//  TestNDJSONCoreData.m
//  NDJSON
//
//  Created by Nathan Day on 6/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestNDJSONCoreData.h"
#import "NDJSONDeserializer.h"
#import "TestProtocolBase.h"
#import "JSONRoot.h"
#import "JSONChildAlpha.h"
#import "JSONChildBeta.h"
#import "JSONChildGama.h"
#import "NDCoreDataController.h"
#import <CoreData/CoreData.h>
#import "NSObject+TestUtilities.h"

@interface TestNDJSONCoreData ()
{
	NDCoreDataController			* coreDataController;
}

@property(readonly,nonatomic)		NDCoreDataController			* coreDataController;

- (id)creatExpectedOneValueInCoreDataController:(NDCoreDataController *)coreDataController;
- (id)creatExpectedTwoValueInCoreDataController:(NDCoreDataController *)aCoreDataController;
@end

@interface TestCoreDataItem : TestProtocolBase
{
	NDCoreDataController				* coreDataController;
	NSString						* jsonString;
	id								expectedResult;
}
+ (id)testStringWithName:(NSString *)name jsonString:(NSString *)json expectedResult:(id)expectedResult inCoreDataController:(NDCoreDataController *)coreDataController;
- (id)initWithName:(NSString *)name jsonString:(NSString *)json expectedResult:(id)result inCoreDataController:(NDCoreDataController *)coreDataController;

@property(readonly)		NSManagedObjectContext		* managedObjectContext;
@property(readonly)		NDCoreDataController		* coreDataController;
@property(readonly)		NSString					* jsonString;
@property(readonly)		id							expectedResult;
@end

@implementation TestNDJSONCoreData

- (NDCoreDataController *)coreDataController
{
	if( coreDataController == nil )
		coreDataController = [[NDCoreDataController alloc] initWithDataBaseName:@"SampleCoreData" location:[NSURL fileURLWithPath:NSTemporaryDirectory()] clean:YES];
	return coreDataController;
}

- (NSString *)testDescription { return @"Test of parsing to CoreData NSManageObjects instead of property list objects."; }


- (id)creatExpectedOneValueInCoreDataController:(NDCoreDataController *)aCoreDataController
{
	JSONRoot		* theResult = [NSEntityDescription insertNewObjectForEntityForName:@"Root" inManagedObjectContext:aCoreDataController.managedObjectContext];
	JSONChildAlpha	* theChildA = [NSEntityDescription insertNewObjectForEntityForName:@"ChildAlpha" inManagedObjectContext:aCoreDataController.managedObjectContext];
	JSONChildBeta	* theChildB[] = {
		[NSEntityDescription insertNewObjectForEntityForName:@"ChildBeta" inManagedObjectContext:aCoreDataController.managedObjectContext],
		[NSEntityDescription insertNewObjectForEntityForName:@"ChildBeta" inManagedObjectContext:aCoreDataController.managedObjectContext]
	};
	JSONChildGama	* theChildC[] = {
		[NSEntityDescription insertNewObjectForEntityForName:@"ChildGama" inManagedObjectContext:aCoreDataController.managedObjectContext],
		[NSEntityDescription insertNewObjectForEntityForName:@"ChildGama" inManagedObjectContext:aCoreDataController.managedObjectContext]
	};
	NSMutableSet	* theChildren = [[NSMutableSet alloc] initWithObjects:theChildB count:sizeof(theChildB)/sizeof(*theChildB)];

	theResult.stringValue = @"Root String Value";
	theResult.integerValue = 42;
	[theResult setAlphaObject:theChildA];
	[theResult setBetaObject:theChildren];

	theChildA.stringAlphaValue = @"String Alpha Value";
	theChildA.booleanAlphaValue = true;

	theChildB[0].stringBetaValue = @"String Beta Value One";
	theChildB[0].floatBetaValue = 3.14;
	theChildB[0].subChildC = theChildC[0];

	theChildC[0].stringGamaValue = @"String Gama Value A";

	theChildB[1].stringBetaValue = @"String Beta Value Two";
	theChildB[1].floatBetaValue = 2.71;
	theChildB[1].subChildC = theChildC[1];

	theChildC[1].stringGamaValue = @"String Gama Value B";

	NSError			* theError = nil;
	
	if( ![aCoreDataController.managedObjectContext save:&theError] )
		NSLog( @"Error: %@", theError );

	return theResult;
}

- (id)creatExpectedTwoValueInCoreDataController:(NDCoreDataController *)aCoreDataController
{
	JSONRoot		* theResult = [NSEntityDescription insertNewObjectForEntityForName:@"Root" inManagedObjectContext:aCoreDataController.managedObjectContext];
	JSONChildAlpha	* theChildA = [NSEntityDescription insertNewObjectForEntityForName:@"ChildAlpha" inManagedObjectContext:aCoreDataController.managedObjectContext];
	JSONChildBeta	* theChildB[] = {
		[NSEntityDescription insertNewObjectForEntityForName:@"ChildBeta" inManagedObjectContext:aCoreDataController.managedObjectContext],
		[NSEntityDescription insertNewObjectForEntityForName:@"ChildBeta" inManagedObjectContext:aCoreDataController.managedObjectContext]
	};
	JSONChildGama	* theChildC[] = {
		[NSEntityDescription insertNewObjectForEntityForName:@"ChildGama" inManagedObjectContext:aCoreDataController.managedObjectContext],
		[NSEntityDescription insertNewObjectForEntityForName:@"ChildGama" inManagedObjectContext:aCoreDataController.managedObjectContext]
	};
	NSMutableSet	* theChildren = [[NSMutableSet alloc] initWithObjects:theChildB count:sizeof(theChildB)/sizeof(*theChildB)];
	
	theResult.stringValue = @"Root String Value 2";
	theResult.integerValue = 45;
	[theResult setAlphaObject:theChildA];
	[theResult setBetaObject:theChildren];
	
	theChildA.stringAlphaValue = @"String Delta Value";
	theChildA.booleanAlphaValue = true;
	
	theChildB[0].stringBetaValue = @"String Sigma Value One";
	theChildB[0].floatBetaValue = 3.14;
	theChildB[0].subChildC = theChildC[0];
	
	theChildC[0].stringGamaValue = @"String Epsilon Value A";
	
	theChildB[1].stringBetaValue = @"String Sigma Value Two";
	theChildB[1].floatBetaValue = 2.71;
	theChildB[1].subChildC = theChildC[1];
	
	theChildC[1].stringGamaValue = @"String Epsilon Value B";
	
	NSError			* theError = nil;
	
	if( ![aCoreDataController.managedObjectContext save:&theError] )
		NSLog( @"Error: %@", theError );
	
	return [NSSet setWithObjects:[self creatExpectedOneValueInCoreDataController:aCoreDataController], theResult, nil];
}

- (void)willLoad
{
	static NSString		* const kTestJSONString1 = @"{\"stringValue\":\"Root String Value\",\"integerValue\":42,\"alphaObject\":{\"stringAlphaValue\":\"String Alpha Value\",\"booleanAlphaValue\":true},\"betaObject\":[{\"stringBetaValue\":\"String Beta Value One\",\"floatBetaValue\":3.14,\"subChildC\":{\"stringGamaValue\":\"String Gama Value A\"}},{\"stringBetaValue\":\"String Beta Value Two\",\"floatBetaValue\":2.71,\"subChildC\":{\"stringGamaValue\":\"String Gama Value B\"}}]}",
				* const kTestJSONString2 = @"[{\"stringValue\":\"Root String Value\",\"integerValue\":42,\"alphaObject\":{\"stringAlphaValue\":\"String Alpha Value\",\"booleanAlphaValue\":true},\"betaObject\":[{\"stringBetaValue\":\"String Beta Value One\",\"floatBetaValue\":3.14,\"subChildC\":{\"stringGamaValue\":\"String Gama Value A\"}},{\"stringBetaValue\":\"String Beta Value Two\",\"floatBetaValue\":2.71,\"subChildC\":{\"stringGamaValue\":\"String Gama Value B\"}}]},{\"stringValue\":\"Root String Value 2\",\"integerValue\":45,\"alphaObject\":{\"stringAlphaValue\":\"String Delta Value\",\"booleanAlphaValue\":true},\"betaObject\":[{\"stringBetaValue\":\"String Sigma Value One\",\"floatBetaValue\":3.14,\"subChildC\":{\"stringGamaValue\":\"String Epsilon Value A\"}},{\"stringBetaValue\":\"String Sigma Value Two\",\"floatBetaValue\":2.71,\"subChildC\":{\"stringGamaValue\":\"String Epsilon Value B\"}}]}]",
				* const kTestJSONString3 = @"{\"otherStringValue\":\"Root String Value\",\"integerValue\":42,\"alphaObject\":{\"stringAlphaValue\":\"String Alpha Value\",\"booleanAlphaValue\":true},\"betaObject\":[{\"stringBetaValue\":\"String Beta Value One\",\"floatBetaValue\":\"3.14\",\"subChildC\":\"String Gama Value A\"},{\"stringBetaValue\":\"String Beta Value Two\",\"floatBetaValue\":\"2.71\",\"subChildC\":\"String Gama Value B\"}]}";
	[self addTest:[TestCoreDataItem testStringWithName:@"Object Root" jsonString:kTestJSONString1 expectedResult:[self creatExpectedOneValueInCoreDataController:self.coreDataController] inCoreDataController:self.coreDataController]];
	[self addTest:[TestCoreDataItem testStringWithName:@"Array Root" jsonString:kTestJSONString2 expectedResult:[self creatExpectedTwoValueInCoreDataController:self.coreDataController] inCoreDataController:self.coreDataController]];
	[self addTest:[TestCoreDataItem testStringWithName:@"Type Conversion" jsonString:kTestJSONString3 expectedResult:[self creatExpectedOneValueInCoreDataController:self.coreDataController] inCoreDataController:self.coreDataController]];
	[super willLoad];
}

@end

@implementation TestCoreDataItem

@synthesize		expectedResult,
				jsonString;

@synthesize		coreDataController;

#pragma mark - manually implemented properties

- (NSManagedObjectContext *)managedObjectContext { return self.coreDataController.managedObjectContext; }


- (NSString *)details
{
	return [NSString stringWithFormat:@"json:\n%@\n\nresult:\n%@\n\nexpected result:\n%@\n\n", self.jsonString, [self.lastResult detailedDescription], [self.expectedResult detailedDescription]];
}

#pragma mark - creation and destruction

+ (id)testStringWithName:(NSString *)aName jsonString:(NSString *)aJSON expectedResult:(id)aResult inCoreDataController:(NDCoreDataController *)aCoreDataController
{
	return [[self alloc] initWithName:aName jsonString:aJSON expectedResult:aResult inCoreDataController:aCoreDataController];
}
- (id)initWithName:(NSString *)aName jsonString:(NSString *)aJSON expectedResult:(id)aResult inCoreDataController:(NDCoreDataController *)aCoreDataController
{
	if( (self = [super initWithName:aName]) != nil )
	{
		jsonString = [aJSON copy];
		expectedResult = aResult;
		coreDataController = aCoreDataController;
	}
	return self;
}

#pragma mark - execution

- (id)run
{
	NSError				* theError = nil;
	NDJSON				* theJSON = [[NDJSON alloc] init];
	NDJSONDeserializer		* theJSONParser = [[NDJSONDeserializer alloc] initWithRootEntityName:@"Root" inManagedObjectContext:self.managedObjectContext];
	[theJSON setJSONString:self.jsonString];
	id					theResult = [theJSONParser objectForJSON:theJSON options:NDJSONOptionCovertPrimitiveJSONTypes error:&theError];
	self.lastResult = theResult;
	self.error = theError;
	if( ![self.managedObjectContext save:&theError] )
	{
		NSLog( @"Failed to context, error: %@", theError );
		self.error = theError;
	}
	return self.lastResult;
}

#pragma mark - NSObject overridden methods

- (NSString *)description { return [NSString stringWithFormat:@"%@, name: %@", [self class], self.name]; }


@end

