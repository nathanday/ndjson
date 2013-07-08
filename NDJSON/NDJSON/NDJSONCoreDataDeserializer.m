//
//  NDJSONCoreDataDeserializer.m
//  NDJSON
//
//  Created by Nathan Day on 8/07/2013.
//  Copyright (c) 2013 Nathan Day. All rights reserved.
//

#import "NDJSONCoreDataDeserializer.h"

@interface NDJSONCoreDataDeserializer ()
{
	NSManagedObjectContext			* managedObjectContext;
	NSEntityDescription				* rootEntity;
	NSManagedObjectModel			* managedObjectModel;
}
@property(readonly,nonatomic)	NSManagedObjectModel		* managedObjectModel;
@property(retain,nonatomic)		NSEntityDescription			* currentEntityDescription;

@end


@implementation NDJSONDeserializer (NDJSONCoreDataDeserializer)

- (id)initWithRootEntityName:(NSString *)aRootEntityName inManagedObjectContext:(NSManagedObjectContext *)aManagedObjectContext
{
	NSParameterAssert( aRootEntityName != nil );
	NSParameterAssert( aManagedObjectContext != nil );
	return [self initWithRootEntity:[[aManagedObjectContext.persistentStoreCoordinator.managedObjectModel entitiesByName] objectForKey:aRootEntityName] inManagedObjectContext:aManagedObjectContext];
}

- (id)initWithRootEntity:(NSEntityDescription *)aRootEntity inManagedObjectContext:(NSManagedObjectContext *)aManagedObjectContext
{
	NSParameterAssert( aRootEntity != nil );
	NSParameterAssert( aManagedObjectContext != nil );
	[self release];
	return [[NDJSONCoreDataDeserializer alloc] initWithRootEntity:aRootEntity inManagedObjectContext:aManagedObjectContext];
}

@end


@implementation NDJSONCoreDataDeserializer

@synthesize		currentEntityDescription,
				managedObjectContext,
				rootEntity;

- (NSEntityDescription *)currentEntityDescription
{
	NSManagedObject		* theCurrentContainer = self.currentObject;
	return theCurrentContainer.entity;
}

- (NSManagedObjectModel *)managedObjectModel
{
	if( managedObjectModel == nil )
		managedObjectModel = [self.managedObjectContext.persistentStoreCoordinator.managedObjectModel retain];
	return managedObjectModel;
}

#pragma mark - creation and destruction
- (id)initWithRootEntity:(NSEntityDescription *)aRootEntity inManagedObjectContext:(NSManagedObjectContext *)aManagedObjectContext
{
	if( (self = [super init]) != nil )
	{
		managedObjectContext = [aManagedObjectContext retain];
		rootEntity = [aRootEntity retain];
	}
	return self;
}

- (void)dealloc
{
	[managedObjectContext release];
	[rootEntity release];
	[managedObjectModel release];
	[super dealloc];
}

- (NSEntityDescription *)entityDescriptionForName:(NSString *)aName { return [[self.managedObjectModel entitiesByName] objectForKey:aName]; }

- (void)jsonParserDidStartDocument:(NDJSONParser *)aJSON
{
	self.currentEntityDescription = nil;
	[super jsonParserDidStartDocument:aJSON];
}

- (void)jsonParserDidEndDocument:(NDJSONParser *)aJSON
{
	self.currentEntityDescription = nil;
	[super jsonParserDidEndDocument:aJSON];
}

- (void)jsonParserDidStartArray:(NDJSONParser *)aJSON
{
	NSMutableSet		* theSet = [[NSMutableSet alloc] init];
	pushContainerForJSONDeserializer( self, theSet, NO );
	self.currentProperty = nil;
	[theSet release];
}

- (void)jsonParserDidStartObject:(NDJSONParser *)aJSON
{
	NSEntityDescription			* theEntityDesctipion = nil;
	NSManagedObject				* theNewObject = nil;
	NSEntityDescription			* theCurrentEntityDescription = self.currentEntityDescription;
	if( theCurrentEntityDescription != nil )
	{
		NSRelationshipDescription		* theRelationshipDescription = [[theCurrentEntityDescription relationshipsByName] objectForKey:self.currentContainerPropertyName];
		theEntityDesctipion = theRelationshipDescription.destinationEntity;
	}
	else
		theEntityDesctipion = self.rootEntity;

	theNewObject = [[NSManagedObject alloc] initWithEntity:theEntityDesctipion insertIntoManagedObjectContext:self.managedObjectContext];

	pushContainerForJSONDeserializer( self, theNewObject, YES );
	self.currentProperty = nil;
	[theNewObject release];
}

- (BOOL)sonParser:(NDJSONParser *)aJSON shouldSkipValueForKey:(NSString *)key
{
	NSEntityDescription		* theEntityDescription = self.currentEntityDescription;
	return [theEntityDescription.propertiesByName objectForKey:self.currentProperty] != nil;
}

@end
