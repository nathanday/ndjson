/*
	CoreDataController.h
	How High

	Created by Nathan Day on 8/08/11.
	Copyright 2011 Nathan Day. All rights reserved.
 */

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "JSONRoot.h"
#import "JSONChildAlpha.h"
#import "JSONChildBeta.h"
#import "JSONChildGama.h"

extern NSString		* const kPersistentStoreCoordinatorCreationFailureNotification;

@interface CoreDataController : NSObject

@property(nonatomic, readonly)	NSManagedObjectContext			* managedObjectContext;
@property(nonatomic, readonly)	NSPersistentStoreCoordinator	* persistentStoreCoordinator;
@property(nonatomic, readonly)	NSString						* dataBaseName;
@property(nonatomic, readonly)	NSURL							* dataBaseURL;

- (id)initWithDataBaseName:(NSString *)name;

- (NSArray *)allEntriesNamed:(NSString *)name predicate:(NSPredicate *)predicate;
- (void)removeAllEntriesNamed:(NSString *)name predicate:(NSPredicate *)predicate;

@end
