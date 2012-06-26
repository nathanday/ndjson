/*
	NDCoreDataController.m
	NDJSON

	Created by Nathan Day on 8/08/11.
	Copyright 2011 Nathan Day. All rights reserved.
 */

#import "NDCoreDataController.h"

NSString			* const kPersistentStoreCoordinatorCreationFailureNotification = @"PersistentStoreCoordinatorCreationFailure";

@interface NDCoreDataController ()
{
	NSMutableDictionary				* managedObjectContextDictionary;
	NSManagedObjectModel			* managedObjectModel;
	NSPersistentStoreCoordinator	* persistentStoreCoordinator;
	NSURL							* location;
	NSString						* dataBaseName;
	BOOL							clean;
}

@property(readonly,nonatomic)	NSManagedObjectModel		* managedObjectModel;
@property(readonly,nonatomic)	NSURL						* location;

@end

@implementation NDCoreDataController

@synthesize		dataBaseName,
				location;

- (NSURL *)dataBaseURL
{
	return [[self.location URLByAppendingPathComponent:self.dataBaseName] URLByAppendingPathExtension:@"sqlite"];
}

- (id)initWithDataBaseName:(NSString *)aName location:(NSURL *)aLocation clean:(BOOL)aFlag
{
	NSParameterAssert( aName != nil );
	NSParameterAssert( aLocation != nil );
    if( (self = [super init]) != nil )
	{
		location = [aLocation copy];
		dataBaseName = [aName retain];
		clean = aFlag;
	}
    
    return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[dataBaseName release];
	[managedObjectContextDictionary release];
	[managedObjectModel release];
	[persistentStoreCoordinator release];
    [super dealloc];
}

- (void)managedObjectContextDidSaveNotification:(NSNotification *)aNotification
{
	NSManagedObjectContext		* theManagedObjectContext = self.managedObjectContext;
	if( [aNotification object] == theManagedObjectContext )
	{
		[theManagedObjectContext lock];
		[theManagedObjectContext mergeChangesFromContextDidSaveNotification:aNotification];
		[theManagedObjectContext unlock];
	}
}

#pragma mark - utility methods

- (NSArray *)allEntriesNamed:(NSString *)aName predicate:(NSPredicate *)aPredicate
{
	NSManagedObjectContext		* theManagedObjectContext = self.managedObjectContext;
	NSFetchRequest				* theFetchRequest = [[NSFetchRequest alloc] init];
	NSError						* theError = nil;
	NSArray						* theEntityArray = nil;
	
	[theFetchRequest setEntity:[NSEntityDescription entityForName:aName inManagedObjectContext:theManagedObjectContext]];
	[theFetchRequest setIncludesPropertyValues:YES];
	if( aPredicate != nil )
		[theFetchRequest setPredicate:aPredicate];
	
	theEntityArray = [theManagedObjectContext executeFetchRequest:theFetchRequest error:&theError];
	
	if( theError != nil )
	{
		NSLog( @"Error: %@", theError );
	}
	
	[theFetchRequest release];

	return theEntityArray;
}

- (void)removeAllEntriesNamed:(NSString *)aName predicate:(NSPredicate *)aPredicate
{
	NSManagedObjectContext	* theManagedObjectContext = self.managedObjectContext;
	NSFetchRequest			* theFetchRequest = [[NSFetchRequest alloc] init];
	NSError					* theError = nil;
	NSArray					* theEntityArray = nil;
	
	[theFetchRequest setEntity:[NSEntityDescription entityForName:aName inManagedObjectContext:theManagedObjectContext]];
	[theFetchRequest setIncludesPropertyValues:NO];
	if( aPredicate != nil )
		[theFetchRequest setPredicate:aPredicate];

	theEntityArray = [theManagedObjectContext executeFetchRequest:theFetchRequest error:&theError];
	
	[theFetchRequest release];
	for( NSManagedObject * theEntity in theEntityArray )
		[theManagedObjectContext deleteObject:theEntity];
}

#pragma mark - Core Data stack

/**
 Returns the managed object context for the current thread.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *)managedObjectContext
{
	NSManagedObjectContext		* theResult = nil;
	@synchronized(self)
	{
		if( managedObjectContextDictionary == nil)
			managedObjectContextDictionary = [[NSMutableDictionary alloc] init];
		theResult = [managedObjectContextDictionary objectForKey:[NSValue valueWithPointer:[NSThread currentThread]]];
		if( theResult == nil )
		{
			NSPersistentStoreCoordinator * theCoordinator = [self persistentStoreCoordinator];
			if (theCoordinator != nil)
			{
				theResult = [[NSManagedObjectContext alloc] init];
				[managedObjectContextDictionary setObject:theResult forKey:[NSValue valueWithPointer:[NSThread currentThread]]];
				[theResult setPersistentStoreCoordinator:theCoordinator];
				[[NSNotificationCenter defaultCenter] addObserver:self
														 selector:@selector(managedObjectContextDidSaveNotification:)
															 name:NSManagedObjectContextDidSaveNotification
														   object:nil];
			}
		}
	}
    return theResult;
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
		if( clean )
		{
			[self deletePersistentStore];
			clean = NO;
		}
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

- (BOOL)deletePersistentStore
{
	NSError		* theError = nil;
	BOOL		theResult = [[NSFileManager defaultManager] removeItemAtURL:self.dataBaseURL error:&theError];
	if( !theResult )
		NSLog( @"Failed to delete database file, error: %@", theError);
	return theResult;
}

@end
