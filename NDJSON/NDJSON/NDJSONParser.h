//
//  NDJSONParser.h
//  NDJSON
//
//  Created by Nathan Day on 31/08/11.
//  Copyright 2011 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>

@class			NDJSON;

extern NSString		* const NDJSONBadCollectionClassException,
					* const NDJSONAttributeNameUserInfoKey;

@interface NDJSONParser : NSObject

@property(readonly,nonatomic)	Class		rootClass,
											rootCollectionClass;
/**
	determines if the parser will fail if an attempt to setValue:forKey: fails because the property does not exist.
 */
@property(assign,nonatomic)		BOOL		ignoreUnknownPropertyName;
/**
	determines if object keys are converted to medial capitals (cammel case) with the first character converted to cammel case, for example Cammel-case becomes cammelCase. can be used with *removeIsAdjective*
 */
@property(assign,nonatomic)		BOOL		convertKeysToMedialCapital;
/**
	determines if _is_ prefix is removed from object keys, for example isPrefix becoms Prefix. Can be used with *convertKeysToMedialCapital*
 */
@property(assign,nonatomic)		BOOL		removeIsAdjective;
@property(readonly,nonatomic)	id			currentContainer;
@property(readonly,nonatomic)	NSString	* currentProperty;

- (id)init;
- (id)initWithRootClass:(Class)rootClass;
- (id)initWithRootClass:(Class)rootClass rootCollectionClass:(Class)rootCollectionClass;

- (id)propertyListForJSONString:(NSString *)string error:(NSError **)error;
- (id)propertyListForContentsOfFile:(NSString *)path error:(NSError **)error;
- (id)propertyListForContentsOfURL:(NSURL *)url error:(NSError **)error;
- (id)propertyListForContentsOfURLRequest:(NSURLRequest *)urlRequest error:(NSError **)error;
- (id)propertyListForInputStream:(NSInputStream *)stream error:(NSError **)error;

- (id)propertyListForJSONParser:(NDJSON *)parser;

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
