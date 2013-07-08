//
//  NDJSONCoreDataDeserializer.h
//  NDJSON
//
//  Created by Nathan Day on 8/07/2013.
//  Copyright (c) 2013 Nathan Day. All rights reserved.
//

#import "NDJSONDeserializer.h"

@interface NDJSONDeserializer (NDJSONCoreDataDeserializer)

- (id)initWithRootEntityName:(NSString *)rootEntityName inManagedObjectContext:(NSManagedObjectContext *)context;
- (id)initWithRootEntity:(NSEntityDescription *)rootEntity inManagedObjectContext:(NSManagedObjectContext *)context;

@end

#pragma mark - NDJSONCoreDataDeserializer interface
@interface NDJSONCoreDataDeserializer : NDJSONExtendedDeserializer

//- (id)initWithRootEntityName:(NSString *)rootEntityName inManagedObjectContext:(NSManagedObjectContext *)context;
- (id)initWithRootEntity:(NSEntityDescription *)rootEntity inManagedObjectContext:(NSManagedObjectContext *)context;

/**
 CoreData context used to insert NSManagedObjects into.
 */
@property(readonly,nonatomic)	NSManagedObjectContext	* managedObjectContext;
/**
 Entity Description used create the root JSON object
 */
@property(readonly,nonatomic)	NSEntityDescription		* rootEntity;

- (NSEntityDescription *)entityDescriptionForName:(NSString *)name;

@end

