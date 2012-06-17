//
//  TestNDJSONCoreData.m
//  NDJSON
//
//  Created by Nathan Day on 6/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestNDJSONCoreData.h"
#import "NDJSONParser.h"
#import "TestProtocolBase.h"
#import "CoreDataController.h"
#import <CoreData/CoreData.h>

@interface TestNDJSONCoreData ()
{
	CoreDataController			* coreDataController;
}

@property(readonly,nonatomic)		CoreDataController			* coreDataController;

- (id)creatExpectedValueInManagedObjectContext:(NSManagedObjectContext *)context;
@end

@interface TestCoreDataItem : TestProtocolBase
{
	NSPersistentStoreCoordinator	* persistentStoreCoordinator;
	NSString						* jsonString;
	id								expectedResult;
}
+ (id)testStringWithName:(NSString *)name jsonString:(NSString *)json expectedResult:(id)expectedResult inPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)persistentStoreCoordinator;
- (id)initWithName:(NSString *)name jsonString:(NSString *)json expectedResult:(id)result inPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)persistentStoreCoordinator;

@property(readonly)		NSManagedObjectContext		* managedObjectContext;
@property(readonly)	NSPersistentStoreCoordinator	* persistentStoreCoordinator;
@property(readonly)			NSString				* jsonString;
@property(readonly)			id						expectedResult;
@end

@implementation TestNDJSONCoreData

- (CoreDataController *)coreDataController
{
	if( coreDataController == nil )
		coreDataController = [[CoreDataController alloc] initWithDataBaseName:@"SampleCoreData"];
	return coreDataController;
}

- (NSString *)testDescription { return @"Test input with different string encodings"; }


- (id)creatExpectedValueInManagedObjectContext:(NSManagedObjectContext *)aContext
{
	JSONRoot		* theResult = [NSEntityDescription insertNewObjectForEntityForName:@"Root" inManagedObjectContext:aContext];
	JSONChildAlpha	* theChildA = [NSEntityDescription insertNewObjectForEntityForName:@"ChildAlpha" inManagedObjectContext:aContext];
	JSONChildBeta	* theChildB[] = {
		[NSEntityDescription insertNewObjectForEntityForName:@"ChildBeta" inManagedObjectContext:aContext],
		[NSEntityDescription insertNewObjectForEntityForName:@"ChildBeta" inManagedObjectContext:aContext]
	};
	JSONChildGama	* theChildC[] = {
		[NSEntityDescription insertNewObjectForEntityForName:@"ChildGama" inManagedObjectContext:aContext],
		[NSEntityDescription insertNewObjectForEntityForName:@"ChildGama" inManagedObjectContext:aContext]
	};
	NSMutableSet	* theChildren = [[NSMutableSet alloc] initWithObjects:theChildB count:sizeof(theChildB)/sizeof(*theChildB)];

	theResult.stringValue = @"Root String Value";
	theResult.integerValue = 42;
	[theResult setAlphaObject:theChildA];
	[theResult setBetaObject:theChildren];
	[theChildren release];

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
	
	if( ![aContext save:&theError] )
		NSLog( @"Error: %@", theError );

	return theResult;
}

- (void)willLoad
{
	static NSString			* const kTestJSONString = @"{\"stringValue\":\"Root String Value\",\"integerValue\":42,\"alphaObject\":{\"stringAlphaValue\":\"String Alpha Value\",\"booleanAlphaValue\":true},\"betaObject\":[{\"stringBetaValue\":\"String Beta Value One\",\"floatBetaValue\":3.14,\"subChildC\":{\"stringGamaValue\":\"String Gama Value A\"}},{\"stringBetaValue\":\"String Beta Value Two\",\"floatBetaValue\":2.71,\"subChildC\":{\"stringGamaValue\":\"String Gama Value B\"}}]}";
	NDJSONParser			* theJSON = [[NDJSONParser alloc] init];
	id						theExptedResult = [theJSON objectForJSONString:kTestJSONString options:NDJSONOptionNone error:NULL];
	NSParameterAssert(theExptedResult != nil);
	[theJSON release];
	[self addTest:[TestCoreDataItem testStringWithName:@"Core Data" jsonString:kTestJSONString expectedResult:[self creatExpectedValueInManagedObjectContext:self.coreDataController.managedObjectContext] inPersistentStoreCoordinator:self.coreDataController.persistentStoreCoordinator]];
	[super willLoad];
}

@end

@implementation TestCoreDataItem

@synthesize		expectedResult,
				jsonString;

@synthesize		persistentStoreCoordinator;

#pragma mark - manually implemented properties

- (NSManagedObjectContext *)managedObjectContext
{
	static NSString				* const kManagedObjectContextKey = @"NDJSONManagedObjectContext";
	NSManagedObjectContext		* theResult = [[[NSThread currentThread] threadDictionary] objectForKey:kManagedObjectContextKey];

	if( theResult == nil )
	{
		theResult = [[NSManagedObjectContext alloc] init];
		[theResult setPersistentStoreCoordinator:self.persistentStoreCoordinator];
		[[[NSThread currentThread] threadDictionary] setObject:theResult forKey:kManagedObjectContextKey];
		[theResult release];
	}
	return theResult;
}


- (NSString *)details
{
	return [NSString stringWithFormat:@"json:\n%@\n\nresult:\n%@\n\nexpected result:\n%@\n\n", self.jsonString, self.lastResult, self.expectedResult];
}

#pragma mark - creation and destruction

+ (id)testStringWithName:(NSString *)aName jsonString:(NSString *)aJSON expectedResult:(id)aResult inPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)aPersistentStoreCoordinator
{
	return [[[self alloc] initWithName:aName jsonString:aJSON expectedResult:aResult inPersistentStoreCoordinator:aPersistentStoreCoordinator] autorelease];
}
- (id)initWithName:(NSString *)aName jsonString:(NSString *)aJSON expectedResult:(id)aResult inPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)aPersistentStoreCoordinator
{
	if( (self = [super initWithName:aName]) != nil )
	{
		jsonString = [aJSON retain];
		expectedResult = [aResult retain];
		persistentStoreCoordinator = [aPersistentStoreCoordinator retain];
	}
	return self;
}

- (void)dealloc
{
	[jsonString release];
	[expectedResult release];
	[super dealloc];
}

#pragma mark - execution

- (id)run
{
	NSError				* theError = nil;
	NDJSONParser		* theJSON = [[NDJSONParser alloc] initWithRootEntityName:@"Root" inManagedObjectContext:self.managedObjectContext];
	id					theResult = [theJSON objectForJSONString:self.jsonString options:NDJSONOptionNone error:&theError];
	self.lastResult = theResult;
	self.error = theError;
	[theJSON release];
	return self.lastResult;
}

#pragma mark - NSObject overridden methods

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@, name: %@", [self class], self.name];
}


@end

