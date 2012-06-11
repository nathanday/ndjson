/*
	CoreDataController.m
	NDJSON

	Created by Nathan Day on 8/08/11.
	Copyright 2011 Nathan Day. All rights reserved.
 */

#import "CoreDataController.h"

NSString			* const kPersistentStoreCoordinatorCreationFailureNotification = @"PersistentStoreCoordinatorCreationFailure";

@interface CoreDataController ()
{
	NSManagedObjectContext			* managedObjectContext;
	NSManagedObjectModel			* managedObjectModel;
	NSPersistentStoreCoordinator	* persistentStoreCoordinator;
	NSString						* dataBaseName;
}

@property(readonly,nonatomic)	NSManagedObjectModel			* managedObjectModel;

@end

@implementation CoreDataController

@synthesize		dataBaseName;

- (NSURL *)dataBaseURL
{
	return [[[NSURL fileURLWithPath:NSTemporaryDirectory()] URLByAppendingPathComponent:self.dataBaseName] URLByAppendingPathExtension:@"sqlite"];
}

- (id)initWithDataBaseName:(NSString *)aName
{
    if( (self = [super init]) != nil )
		dataBaseName = [aName retain];
    
    return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[dataBaseName release];
	[managedObjectContext release];
	[managedObjectModel release];
	[persistentStoreCoordinator release];
    [super dealloc];
}

- (void)managedObjectContextDidSaveNotification:(NSNotification *)aNotification
{
	if( [aNotification object] != self.managedObjectContext )
	{
		[self.managedObjectContext lock];
		[self.managedObjectContext mergeChangesFromContextDidSaveNotification:aNotification];
		[self.managedObjectContext unlock];
	}
}

#pragma mark - utility methods

- (NSArray *)allEntriesNamed:(NSString *)aName predicate:(NSPredicate *)aPredicate
{
	NSFetchRequest		* theFetchRequest = [[NSFetchRequest alloc] init];
	NSError				* theError = nil;
	NSArray				* theEntityArray = nil;
	
	[theFetchRequest setEntity:[NSEntityDescription entityForName:aName inManagedObjectContext:self.managedObjectContext]];
	[theFetchRequest setIncludesPropertyValues:YES];
	if( aPredicate != nil )
		[theFetchRequest setPredicate:aPredicate];
	
	theEntityArray = [self.managedObjectContext executeFetchRequest:theFetchRequest error:&theError];
	
	if( theError != nil )
	{
		NSLog( @"Error: %@", theError );
	}
	
	[theFetchRequest release];

	return theEntityArray;
}

- (void)removeAllEntriesNamed:(NSString *)aName predicate:(NSPredicate *)aPredicate
{
	NSFetchRequest		* theFetchRequest = [[NSFetchRequest alloc] init];
	NSError				* theError = nil;
	NSArray				* theEntityArray = nil;
	
	[theFetchRequest setEntity:[NSEntityDescription entityForName:aName inManagedObjectContext:self.managedObjectContext]];
	[theFetchRequest setIncludesPropertyValues:NO];
	if( aPredicate != nil )
		[theFetchRequest setPredicate:aPredicate];

	theEntityArray = [self.managedObjectContext executeFetchRequest:theFetchRequest error:&theError];
	
	[theFetchRequest release];
	for( NSManagedObject * theEntity in theEntityArray )
		[self.managedObjectContext deleteObject:theEntity];
}

#pragma mark - Core Data stack

/**
 Returns the managed object context for the application.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *)managedObjectContext
{
    if (managedObjectContext == nil)
    {
		NSPersistentStoreCoordinator * theCoordinator = [self persistentStoreCoordinator];
		if (theCoordinator != nil)
		{
			managedObjectContext = [[NSManagedObjectContext alloc] init];
			[managedObjectContext setPersistentStoreCoordinator:theCoordinator];
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(managedObjectContextDidSaveNotification:)
														 name:NSManagedObjectContextDidSaveNotification
													   object:nil];
		}
    }
    return managedObjectContext;
}

/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created from the application's model.
 */
- (NSManagedObjectModel *)managedObjectModel
{
    if (managedObjectModel == nil)
    {
		NSURL	* theModelURL = [[NSBundle mainBundle] URLForResource:self.dataBaseName withExtension:@"momd"];
		managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:theModelURL];    
    }
    return managedObjectModel;
}

/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if(persistentStoreCoordinator == nil )
    {
		NSError		* theError = nil;
		persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
		if( ![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
													  configuration:nil
																URL:self.dataBaseURL
															options:nil
															  error:&theError] )
		{
			NSLog(@"Unresolved error %@, %@", theError, [theError userInfo]);
			[[NSNotificationCenter defaultCenter] postNotificationName:kPersistentStoreCoordinatorCreationFailureNotification
																object:self
															  userInfo:theError.userInfo];
		}    
    }
    return persistentStoreCoordinator;
}

@end
