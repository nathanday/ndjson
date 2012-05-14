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
@property(assign,nonatomic)		BOOL		ignoreUnknownPropertyName;
@property(assign,nonatomic)		BOOL		convertKeysToMedialCapital;
@property(assign,nonatomic)		BOOL		removeIsAdjective;
@property(readonly,nonatomic)	id			currentContainer;
@property(readonly,nonatomic)	id			currentObject;
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

@interface NSObject (NDJSONParser)

+ (NSDictionary *)classesForPropertyNamesJSONParser:(NDJSONParser *)aParser;
+ (NSDictionary *)collectionClassesForPropertyNamesJSONParser:(NDJSONParser *)aParser;

+ (NSSet *)ignoreSetJSONParser:(NDJSONParser *)aParser;
+ (NSSet *)considerSetJSONParser:(NDJSONParser *)aParser;

+ (NSDictionary *)propertyNamesForKeysJSONParser:(NDJSONParser *)aParser;

- (NSString *)jsonStringJSONParser:(NDJSONParser *)aParser;

@end
