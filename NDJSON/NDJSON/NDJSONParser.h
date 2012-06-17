//
//  NDJSONParser.h
//  NDJSON
//
//  Created by Nathan Day on 31/08/11.
//  Copyright 2011 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NDJSON.h"

extern NSString		* const NDJSONBadCollectionClassException;
extern NSString		* const NDJSONUnrecongnisedPropertyNameException;

extern NSString		* const NDJSONAttributeNameUserInfoKey;
extern NSString		* const NDJSONObjectUserInfoKey;
extern NSString		* const NDJSONPropertyNameUserInfoKey;

enum {
//	NDJSONOptionNone = 0,				// defined in NDJSON
//	NDJSONOptionStrict = 1<<0,			// defined in NDJSON
/**
	determines if the parser will fail if an attempt to setValue:forKey: fails because the property does not exist.
 */
	NDJSONOptionIgnoreUnknownProperties = 1<<16,
/**
	determines if object keys are converted to medial capitals (cammelCase) with the first character converted to cammel case, for example Cammel-case becomes cammelCase. can be used with *removeIsAdjective*
 */
	NDJSONOptionConvertKeysToMedialCapitals = 1<<17,
/**
	determines if _is_ prefix is removed from object keys, for example isPrefix becoms Prefix. Can be used with *convertKeysToMedialCapital*
 */
	NDJSONOptionConvertRemoveIsAdjective = 1<<18,
/**
 If a parsed JSON primative doesn't match the destination property type, this option tell NDJSONParser to attempt to convert it.
 */
	NDJSONOptionCovertPrimitiveJSONTypes = 1<<19
};

/**
 The *NDJSONParser* class provides methods that convert a JSON document into an object tree representation. *NDJSONParser* can either generate property list type objects, *NSDictionary*s, *NSArrays*, *NSStrings* and *NSNumber*s as well as *NSNull* for the JSON value null, or by supplying your own root object and maybe implementing the methods defined in the anyomnous protocol NSObject+NDJSONParser in your own classes, NDJSONParser will generate a tree if your own classes.
 When generating classes of your own type, *NDJSONParser* will determine the correct class type for properties by quering the Objective-C runetime, NSObject+NDJSONParser methods can be used when the information is not avaialable, for example what classes to insert in an array.
 */
@interface NDJSONParser : NSObject

/**
	Class used for root JSON object
 */
@property(readonly,nonatomic)	Class					rootClass;
/**
 Class used for root JSON arrays
 */
@property(readonly,nonatomic)	Class					rootCollectionClass;

/**
 CoreData context used to insert NSManagedObjects into.
 */
@property(readonly,nonatomic)	NSManagedObjectContext	* managedObjectContext;
/**
 Entity Description used create the root JSON object
 */
@property(readonly,nonatomic)	NSEntityDescription		* rootEntity;

/**
	initalize with the classes type to represent the root JSON object, if the root of the JSON document is an array, the the class type is what is used for the objects within the array.
 */
- (id)initWithRootClass:(Class)rootClass;
/**
	initalize with the classes type to represent the root JSON object and the class type used for root collection type (array, set etc), if the root of the JSON document is an array then the root collection class is used and the class type is what is used for the objects within the array.
 */
- (id)initWithRootClass:(Class)rootClass rootCollectionClass:(Class)rootCollectionClass;

- (id)initWithRootEntityName:(NSString *)rootEntityName inManagedObjectContext:(NSManagedObjectContext *)context;

- (id)initWithRootEntity:(NSEntityDescription *)rootEntity inManagedObjectContext:(NSManagedObjectContext *)context;

/**
	return the root object generted from the parsers output.
 */
- (id)objectForJSONParser:(NDJSON *)parser options:(NDJSONOptionFlags)options error:(NSError **)error;

@end

/**
	NSObject+NDJSONParser is an informal protocol for methods that objects which can be generated from parsing can implement to control how parsing of child onjects and arrays.
	*NDJSONParser* can determine the class types for properties at runtime, but the methods of NSObject+NDJSONParser can be used to override this behavor or help in situations where the type information is not available, for exmaple the class types used for the elements in a JSON array or if the type is *id*.
 */
@interface NSObject (NDJSONParser)

/**
	implemented by classes to override the default mechanism for determining the class type used for a property, if the property is a collection type (array, set etc), then this method is used to determine the types used in the collection, by default an NSDictionat will be used but any method which implements the method setObject:forKey: method.
 */
+ (NSDictionary *)classesForPropertyNamesJSONParser:(NDJSONParser *)aParser;
/**
	implemented by classed to override the default mechanism for determining the class type used for a property collection, by default an NSArray will be used but any mehtod which implements the method addObject: method.
 */
+ (NSDictionary *)collectionClassesForPropertyNamesJSONParser:(NDJSONParser *)aParser;

/**
	return a set of property names to ignore, this can speed up parsing as the parsing will just scan pass the valuing in the JSON.
 */
+ (NSSet *)keysIgnoreSetJSONParser:(NDJSONParser *)aParser;
/**
	return a set of property names to only consider, this can speed up parsing as the parsing will just scan pass the valuing in the JSON.
 */
+ (NSSet *)keysConsiderSetJSONParser:(NDJSONParser *)aParser;

/**
	return a dictionary used to map property names as determined
 */
+ (NSDictionary *)propertyNamesForKeysJSONParser:(NDJSONParser *)aParser;

//- (NSString *)jsonStringJSONParser:(NDJSONParser *)aParser;

@end

/*
	implements the class method `+[NSObject classesForPropertyNamesJSONParser:]` returning a dictionary with the supplied arguemnts.
 */
#define NDJSONClassesForPropertyNames(...) \
+ (NSDictionary *)classesForPropertyNamesJSONParser:(NDJSONParser *)aParser { \
	static NSDictionary     * kClassesForPropertyName = nil; \
	if( kClassesForPropertyName == nil ) kClassesForPropertyName = [[NSDictionary alloc] initWithObjectsAndKeys:__VA_ARGS__, nil]; \
	return kClassesForPropertyName; \
}

/*
 implements the class method `+[NSObject collectionClassesForPropertyNamesJSONParser:]` returning a dictionary with the supplied arguemnts.
 */
#define NDJSONCollectionClassesForPropertyNames(...) \
+ (NSDictionary *)collectionClassesForPropertyNamesJSONParser:(NDJSONParser *)aParser { \
	static NSDictionary     * kClassesForPropertyName = nil; \
	if( kClassesForPropertyName == nil ) kClassesForPropertyName = [[NSDictionary alloc] initWithObjectsAndKeys:__VA_ARGS__, nil]; \
	return kClassesForPropertyName; \
}

/*
 implements the class method `+[NSObject keysConsiderSetJSONParser:]` returning a set with the supplied arguemnts.
 */
#define NDJSONKeysConsiderSet(...) \
+ (NSSet *)keysConsiderSetJSONParser:(NDJSONParser *)aParser { \
    static NSSet       * kSet = nil; \
    if( kSet == nil ) kSet = [[NSSet alloc] initWithObjects:__VA_ARGS__, nil]; \
	return kSet; \
}

/*
 implements the class method `+[NSObject keysIgnoreSetJSONParser:]` returning a set with the supplied arguemnts.
 */
#define NDJSONKeysIgnoreSet(...) \
+ (NSSet *)keysIgnoreSetJSONParser:(NDJSONParser *)aParser { \
	static NSSet       * kSet = nil; \
	if( kSet == nil ) kSet = [[NSSet alloc] initWithObjects:__VA_ARGS__, nil]; \
	return kSet; \
}

/*
 implements the class method `+[NSObject propertyNamesForKeysJSONParser:]` returning a dictionary with the supplied arguemnts.
 */
#define NDJSONPropertyNamesForKeys(...) \
+ (NSDictionary *)propertyNamesForKeysJSONParser:(NDJSONParser *)aParser { \
    static NSDictionary     * kNamesForKeys = nil; \
    if( kNamesForKeys == nil ) kNamesForKeys = [[NSDictionary alloc] initWithObjectsAndKeys:__VA_ARGS__, nil]; \
	return kNamesForKeys; \
}
