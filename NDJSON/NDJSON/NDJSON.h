//
//  NDJSON.h
//  NDJSON
//
//  Created by Nathan Day on 31/08/11.
//  Copyright 2011 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol		NDJSONDelegate;

@interface NDJSON : NSObject

@property(readonly,nonatomic)		NSUInteger		position;

@property(assign,nonatomic)		id<NDJSONDelegate>	delegate;

- (id)initWithDelegate:(id<NDJSONDelegate>)delegate;

- (BOOL)parseJSONString:(NSString *)string error:(NSError **)error;
- (BOOL)parseContentsOfFile:(NSString *)path error:(NSError **)error;
- (BOOL)parseContentsOfURL:(NSURL *)url error:(NSError **)error;
- (BOOL)parseContentsOfURLRequest:(NSURLRequest *)urlRequest error:(NSError **)error;
- (BOOL)parseInputStream:(NSInputStream *)stream error:(NSError **)error;

- (BOOL)setJSONString:(NSString *)string error:(NSError **)error;
- (BOOL)setContentsOfFile:(NSString *)path error:(NSError **)error;
- (BOOL)setContentsOfURL:(NSURL *)url error:(NSError **)error;
- (BOOL)setContentsOfURLRequest:(NSURLRequest *)urlRequest error:(NSError **)error;
- (BOOL)setInputStream:(NSInputStream *)stream error:(NSError **)error;

- (BOOL)parse;

@end

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
