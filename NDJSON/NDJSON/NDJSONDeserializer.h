/*
	NDJSONDeserializer.h 

	Created by Nathan Day on 31.02.12 under a MIT-style license. 
	Copyright (c) 2012 Nathan Day

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
 */

#import <Foundation/Foundation.h>
#import "NDJSONParser.h"

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
 If a parsed JSON primative doesn't match the destination property type, this option tell NDJSONDeserializer to attempt to convert it.
 */
	NDJSONOptionCovertPrimitiveJSONTypes = 1<<19
};

/**
 The *NDJSONDeserializer* class provides methods that convert a JSON document into an object tree representation. *NDJSONDeserializer* can either generate property list type objects, *NSDictionary*s, *NSArrays*, *NSStrings* and *NSNumber*s as well as *NSNull* for the JSON value null, or by supplying your own root object and maybe implementing the methods defined in the anyomnous protocol NSObject+NDJSONDeserializer in your own classes, NDJSONDeserializer will generate a tree if your own classes.
 When generating classes of your own type, *NDJSONDeserializer* will determine the correct class type for properties by quering the Objective-C runetime, NSObject+NDJSONDeserializer methods can be used when the information is not avaialable, for example what classes to insert in an array.
 */
@interface NDJSONDeserializer : NSObject

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
- (id)objectForJSON:(NDJSONParser *)parser options:(NDJSONOptionFlags)options error:(NSError **)error;

@end

/**
	NSObject+NDJSONDeserializer is an informal protocol for methods that objects which can be generated from parsing can implement to control how parsing of child onjects and arrays.
	*NDJSONDeserializer* can determine the class types for properties at runtime, but the methods of NSObject+NDJSONDeserializer can be used to override this behavor or help in situations where the type information is not available, for exmaple the class types used for the elements in a JSON array or if the type is *id*.
 */
@interface NSObject (NDJSONDeserializer)

/**
	implemented by classes to override the default mechanism for determining the class type used for a property, if the property is a collection type (array, set etc), then this method is used to determine the types used in the collection, by default an NSDictionat will be used but any method which implements the method setObject:forKey: method.
 */
+ (NSDictionary *)classesForPropertyNamesJSONParser:(NDJSONDeserializer *)aParser;
/**
	implemented by classed to override the default mechanism for determining the class type used for a property collection, by default an NSArray will be used but any mehtod which implements the method addObject: method.
 */
+ (NSDictionary *)collectionClassesForPropertyNamesJSONParser:(NDJSONDeserializer *)aParser;

/**
	return a set of property names to ignore, this can speed up parsing as the parsing will just scan pass the valuing in the JSON.
 */
+ (NSSet *)keysIgnoreSetJSONParser:(NDJSONDeserializer *)aParser;
/**
	return a set of property names to only consider, this can speed up parsing as the parsing will just scan pass the valuing in the JSON.
 */
+ (NSSet *)keysConsiderSetJSONParser:(NDJSONDeserializer *)aParser;

/**
	return a dictionary used to map property names as determined
 */
+ (NSDictionary *)propertyNamesForKeysJSONParser:(NDJSONDeserializer *)aParser;

/**
	returns the name of the property used as an indicies value, useful for CoreDate where one-to-many relationship are store in and unordered sets.
 */
- (void)jsonParser:(NDJSONDeserializer *)parser setIndex:(NSUInteger)index;

//- (NSString *)jsonStringJSONParser:(NDJSONDeserializer *)aParser;

@end

/**
	implements the class method `+[NSObject classesForPropertyNamesJSONParser:]` returning a dictionary with the supplied arguemnts.
 */
#define NDJSONClassesForPropertyNames(...) \
+ (NSDictionary *)classesForPropertyNamesJSONParser:(NDJSONDeserializer *)aParser { \
	static NSDictionary     * kClassesForPropertyName = nil; \
	if( kClassesForPropertyName == nil ) kClassesForPropertyName = [[NSDictionary alloc] initWithObjectsAndKeys:__VA_ARGS__, nil]; \
	return kClassesForPropertyName; \
}

/**
 implements the class method `+[NSObject collectionClassesForPropertyNamesJSONParser:]` returning a dictionary with the supplied arguemnts.
 */
#define NDJSONCollectionClassesForPropertyNames(...) \
+ (NSDictionary *)collectionClassesForPropertyNamesJSONParser:(NDJSONDeserializer *)aParser { \
	static NSDictionary     * kClassesForPropertyName = nil; \
	if( kClassesForPropertyName == nil ) kClassesForPropertyName = [[NSDictionary alloc] initWithObjectsAndKeys:__VA_ARGS__, nil]; \
	return kClassesForPropertyName; \
}

/**
 implements the class method `+[NSObject keysConsiderSetJSONParser:]` returning a set with the supplied arguemnts.
 */
#define NDJSONKeysConsiderSet(...) \
+ (NSSet *)keysConsiderSetJSONParser:(NDJSONDeserializer *)aParser { \
    static NSSet       * kSet = nil; \
    if( kSet == nil ) kSet = [[NSSet alloc] initWithObjects:__VA_ARGS__, nil]; \
	return kSet; \
}

/**
 implements the class method `+[NSObject keysIgnoreSetJSONParser:]` returning a set with the supplied arguemnts.
 */
#define NDJSONKeysIgnoreSet(...) \
+ (NSSet *)keysIgnoreSetJSONParser:(NDJSONDeserializer *)aParser { \
	static NSSet       * kSet = nil; \
	if( kSet == nil ) kSet = [[NSSet alloc] initWithObjects:__VA_ARGS__, nil]; \
	return kSet; \
}

/**
 implements the class method `+[NSObject propertyNamesForKeysJSONParser:]` returning a dictionary with the supplied arguemnts.
 */
#define NDJSONPropertyNamesForKeys(...) \
+ (NSDictionary *)propertyNamesForKeysJSONParser:(NDJSONDeserializer *)aParser { \
    static NSDictionary     * kNamesForKeys = nil; \
    if( kNamesForKeys == nil ) kNamesForKeys = [[NSDictionary alloc] initWithObjectsAndKeys:__VA_ARGS__, nil]; \
	return kNamesForKeys; \
}