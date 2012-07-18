//
//  TestMechanismChange.m
//  NDJSON
//
//  Created by Nathan Day on 6/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestMechanismChange.h"
#import "NDJSONParser.h"
#import "TestProtocolBase.h"
#import "Utility.h"
#import "NDCoreDataController.h"
#import "ChangeParseFromEventToPropertyList.h"
#import "ChangeParseFromEventToCustom.h"
#import "ChangeParseFromEventToCoreData.h"
#import "NSObject+TestUtilities.h"

@interface TestMechanismChange ()
{
	NDCoreDataController			* coreDataController;
}
@property(readonly)			NDCoreDataController			* coreDataController;
@property(readonly)			NSManagedObjectContext		* managedObjectContext;
@end

@interface TestSubElement : TestProtocolBase
{
	Class						class;
	NSString					* jsonString;
	id							expectedResult;
	NDJSONOptionFlags			options;
	NSManagedObjectContext		* managedObjectContext;
}
- (id)initWithClass:(Class)aClass managedObjectContext:(NSManagedObjectContext *)aManagedObjectContext;

@property(readonly)			Class						class;
@property(readonly)			NSString					* jsonString;
@property(readonly)			id							expectedResult;
@property(readonly)			NDJSONOptionFlags			options;
@property(retain)			NSManagedObjectContext		* managedObjectContext;
@end

@implementation TestMechanismChange

- (NSManagedObjectContext *)managedObjectContext
{
	if( coreDataController == nil )
		coreDataController = [[NDCoreDataController alloc] initWithDataBaseName:@"ChangeParseFromEventToCoreData" location:[NSURL fileURLWithPath:NSTemporaryDirectory()] clean:YES];
	return coreDataController.managedObjectContext;
}

- (NSString *)testDescription { return @"Test changing parsing method from event drive to one of the other methods"; }

- (void)willLoad
{
	TestSubElement	* theTestSubElements[] = {
						[[TestSubElement alloc] initWithClass:[ChangeParseFromEventToPropertyList class] managedObjectContext:self.managedObjectContext],
						[[TestSubElement alloc] initWithClass:[ChangeParseFromEventToCustom class] managedObjectContext:self.managedObjectContext],
						[[TestSubElement alloc] initWithClass:[ChangeParseFromEventToCoreData class] managedObjectContext:self.managedObjectContext]
					};
	for( NSUInteger i = 0; i < sizeof(theTestSubElements)/sizeof(*theTestSubElements); i++ )
	{
		[self addTest:theTestSubElements[i]];
		theTestSubElements[i] = nil;
	}
	[super willLoad];
}

@end

@implementation TestSubElement

@synthesize		class,
				expectedResult,
				jsonString,
				options,
				managedObjectContext;

#pragma mark - manually implemented properties

- (NSString *)details
{
	return [NSString stringWithFormat:@"json:\n%@\n\nresult:\n%@\n\nexpected result:\n%@\n\n", self.jsonString, [self.lastResult detailedDescription], [self.expectedResult detailedDescription]];
}

#pragma mark - creation and destruction

- (id)initWithClass:(Class)aClass managedObjectContext:(NSManagedObjectContext *)aManagedObjectContext
{
	NSParameterAssert(aClass != Nil);
	NSParameterAssert(aManagedObjectContext != nil);
	if( (self = [super initWithName:[aClass name]]) != nil )
	{
		class = aClass;
		jsonString = [[aClass jsonString] copy];
		managedObjectContext = aManagedObjectContext;
		expectedResult = [aClass expectedResultForManagedObjectContext:aManagedObjectContext];
		options = [aClass options];
	}
	return self;
}

#pragma mark - execution

- (id)run
{
	NSError		* theError = nil;
	NDJSON		* theJSON = [[NDJSON alloc] init];
	id			theResult = [[[self class] alloc] initWithManagedObjectContext:self.managedObjectContext];

	[theJSON setJSONString:self.jsonString];
	theJSON.delegate = theResult;
	if( [theJSON parseWithOptions:self.options] )
		self.lastResult = theResult;
	self.error = theError;
	return self.lastResult;
}

#pragma mark - NSObject overridden methods

- (NSString *)description { return [NSString stringWithFormat:@"%@, name: %@", [self class], self.name]; }

@end
