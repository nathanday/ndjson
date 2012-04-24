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

@property(readonly,nonatomic)	Class	rootClass,
										rootCollectionClass;

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

#define NDJSONParserIgnoreSet(...) - (NSSet *)ignoreSetJSONParser:(NDJSONParser *)aParser { return [NSSet setWithObjects:__VA_ARGS__,nil]; }
#define NDJSONParserConsiderSet(...) - (NSSet *)considerSetJSONParser:(NDJSONParser *)aParser { return [NSSet setWithObjects:__VA_ARGS__,nil]; }

@interface NSObject (NDJSONParser)

- (Class)jsonParser:(NDJSONParser *)aParser classForPropertyName:(NSString *)name;
- (Class)jsonParser:(NDJSONParser *)aParser collectionClassForPropertyName:(NSString *)name;

- (NSSet *)ignoreSetJSONParser:(NDJSONParser *)aParser;
- (NSSet *)considerSetJSONParser:(NDJSONParser *)aParser;

- (NSString *)jsonStringJSONParser:(NDJSONParser *)aParser;

@end
