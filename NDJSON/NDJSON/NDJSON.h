//
//  NDJSON.h
//  NDJSON
//
//  Created by Nathan Day on 31/08/11.
//  Copyright 2011 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NDJSONCore.h"

@class		NDJSON;

@protocol NDJSONDelegate <NSObject>

@optional
- (void)jsonParserDidStartDocument:(NDJSON *)parser;
- (void)jsonParserDidEndDocument:(NDJSON *)parser;
- (void)jsonParserDidStartArray:(NDJSON *)parser;
- (void)jsonParserDidEndArray:(NDJSON *)parser;
- (void)jsonParserDidStartObject:(NDJSON *)parser;
- (void)jsonParserDidEndObject:(NDJSON *)parser;
- (void)jsonParser:(NDJSON *)parser foundKey:(NSString *)aValue;
- (void)jsonParser:(NDJSON *)parser foundString:(NSString *)aValue;
- (void)jsonParser:(NDJSON *)parser foundInteger:(NSInteger)aValue;
- (void)jsonParser:(NDJSON *)parser foundFloat:(double)aValue;
- (void)jsonParser:(NDJSON *)parser foundBool:(BOOL)aValue;
- (void)jsonParserFoundNULL:(NDJSON *)parser;
- (void)jsonParser:(NDJSON *)parser error:(NSError *)error;
@end

@interface NDJSON : NSObject

@property(assign)		id<NDJSONDelegate>	delegate;
@property(readonly)		NSDictionary		* templateDictionary;
@property(readonly)		NDJSONContainer		currentContainer;
@property(readonly)		NSString 			* currentKey;

- (id)initWithDelegate:(id<NDJSONDelegate>)delegate;

- (BOOL)parseJSONString:(NSString *)string error:(NSError **)error;
- (BOOL)parseContentsOfFile:(NSString *)path error:(NSError **)error;
- (BOOL)parseContentsOfURL:(NSURL *)url error:(NSError **)error;
- (BOOL)parseContentsOfURLRequest:(NSURLRequest *)urlRequest error:(NSError **)error;
- (BOOL)parseInputStream:(NSInputStream *)stream error:(NSError **)error;

//- (BOOL)asynchronousParseContentsOfURLRequest:(NSURLRequest *)urlRequest error:(NSError **)error;
//- (BOOL)asynchronousParseInputStream:(NSInputStream *)stream error:(NSError **)error;

@end
