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
//	NDJSONOptionStrict = 1<<1,			// defined in NDJSON
/**
	determines if the parser will fail if an attempt to setValue:forKey: fails because the property does not exist.
 */
	NDJSONOptionIgnoreUnknownProperties = 1<<2,
/**
	determines if object keys are converted to medial capitals (cammel case) with the first character converted to cammel case, for example Cammel-case becomes cammelCase. can be used with *removeIsAdjective*
 */
	NDJSONOptionConvertKeysToMedialCapitals = 1<<3,
/**
	determines if _is_ prefix is removed from object keys, for example isPrefix becoms Prefix. Can be used with *convertKeysToMedialCapital*
 */
	NDJSONOptionConvertRemoveIsAdjective = 1<<4
};

/**
 The NDJSONParser class provides methods that convert a JSON document into an object tree representation. NDJSONParser can either generate property list type objects, NSDictionarys, NSArrays, NSStrings and NSNumbers as well as NSNull for the JSON value null, or by supplying your own root object and maybe implementing the methods defined in the anyomnous protocol NSObject+NDJSONParser in your own classes, NDJSONParser will generate a tree if your own classes.
 When generating classes of your own type, NDJSONParser will determine the correct class type for properties by quering the Objective-C runetime, NSObject+NDJSONParser methods can be used when the information is not avaialable, for example what classes to insert in an array.
 */
@interface NDJSONParser : NSObject

@property(readonly,nonatomic)	Class		rootClass;
@property(readonly,nonatomic)	Class		rootCollectionClass;
@property(readonly,nonatomic)	id			currentContainer;
@property(readonly,nonatomic)	NSString	* currentProperty;

- (id)init;
- (id)initWithRootClass:(Class)rootClass;
- (id)initWithRootClass:(Class)rootClass rootCollectionClass:(Class)rootCollectionClass;

- (id)objectForJSONString:(NSString *)string options:(NDJSONOptionFlags)options error:(NSError **)error;
- (id)objectForContentsOfFile:(NSString *)path options:(NDJSONOptionFlags)options error:(NSError **)error;
- (id)objectForContentsOfURL:(NSURL *)url options:(NDJSONOptionFlags)options error:(NSError **)error;
- (id)objectForURLRequest:(NSURLRequest *)urlRequest options:(NDJSONOptionFlags)options error:(NSError **)error;
- (id)objectForInputStream:(NSInputStream *)stream options:(NDJSONOptionFlags)options error:(NSError **)error;

- (id)objectForJSONParser:(NDJSON *)parser options:(NDJSONOptionFlags)options;

@end

/**
	NSObject+NDJSONParser is an informal protocol for methods that objects which can be generated from parsing can implement to control how parsing of child onjects and arrays.
	NDJSONParser can determine the class types for properties at runtime, but the methods of NSObject+NDJSONParser can be used to override this behavor or help in situations where the type information is not available, for exmaple the class types used for the elements in a JSON array or if the type is *id*.
 */
@interface NSObject (NDJSONParser)

+ (NSDictionary *)classesForPropertyNamesJSONParser:(NDJSONParser *)aParser;
+ (NSDictionary *)collectionClassesForPropertyNamesJSONParser:(NDJSONParser *)aParser;

+ (NSSet *)ignoreSetJSONParser:(NDJSONParser *)aParser;
+ (NSSet *)considerSetJSONParser:(NDJSONParser *)aParser;

+ (NSDictionary *)propertyNamesForKeysJSONParser:(NDJSONParser *)aParser;

- (NSString *)jsonStringJSONParser:(NDJSONParser *)aParser;

@end
