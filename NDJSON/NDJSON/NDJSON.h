//
//  NDJSON.h
//  NDJSON
//
//  Created by Nathan Day on 31/08/11.
//  Copyright 2011 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString	* const NDJSONErrorDomain;

@protocol		NDJSONDelegate;

@interface NDJSON : NSObject

/**
	The JSON parser’s delegate object.
 */
@property(assign,nonatomic)		id<NDJSONDelegate>	delegate;
/**
	determines whether the JSON source has to adhere to strict JSON or not.

	#Non strict JSON features
	- object keys do not have to be quoted.
	- arrays may have a trailing comment.
 */
@property(assign,nonatomic)			BOOL			strictJSONOnly;

/**
	intialise a *NDJSON* instance with a delegate
 */
- (id)initWithDelegate:(id<NDJSONDelegate>)delegate;

/**
	equivelent to `-[NDJSON setJSONString:error:]` and `-[NDJSON parse]`
 */
- (BOOL)parseJSONString:(NSString *)string error:(NSError **)error;
/**
	equivelent to `-[NDJSON setContentsOfFile:error:]` and `-[NDJSON parse]`
 */
- (BOOL)parseContentsOfFile:(NSString *)path error:(NSError **)error;
/**
	equivelent to `-[NDJSON setContentsOfURL:error:]` and `-[NDJSON parse]`
 */
- (BOOL)parseContentsOfURL:(NSURL *)url error:(NSError **)error;
/**
	equivelent to `-[NDJSON setURLRequest:error:]` and `-[NDJSON parse]`
	Important: URLRequests are not parsed asyncronisly, see `-[NDJSON parse]`.
 */
- (BOOL)parseURLRequest:(NSURLRequest *)urlRequest error:(NSError **)error;
/**
	equivelent to `-[NDJSON parseInputStream:error:]` and `-[NDJSON parse]`
 */
- (BOOL)parseInputStream:(NSInputStream *)stream error:(NSError **)error;

/**
	set a JSON string to parse
 */
- (BOOL)setJSONString:(NSString *)string error:(NSError **)error;
/**
	set a JSON file to parse specified using a string path
 */
- (BOOL)setContentsOfFile:(NSString *)path error:(NSError **)error;
/**
	set a JSON file to parse specified using a file URL
 */
- (BOOL)setContentsOfURL:(NSURL *)url error:(NSError **)error;
/**
	set a JSON URLRequest to parse
	Important: URLRequests are not parsed asyncronisly, see `-[NDJSON parse]`.
 */
- (BOOL)setURLRequest:(NSURLRequest *)urlRequest error:(NSError **)error;
/**
	set an input stream to parse
 */
- (BOOL)setInputStream:(NSInputStream *)stream error:(NSError **)error;

/**
	parses the JSON source set up by one other the set methods, setJSONString:error:, setContentsOfFile:error:, setContentsOfURL:error, setURLRequest:error:
	Important: This method does not return until parsing is complete, this method can be called within another thread as long as you do not change the reciever until after the method has finished.
 */
- (BOOL)parse;

@end

/**
	The NDJSONDelegate protocol defines the optional methods implemented by delegates of NDJSON objects.
 */
@protocol NDJSONDelegate <NSObject>

@optional
/**
	Sent by the parser object to the delegate when it begins parsing a document.
 */
- (void)jsonParserDidStartDocument:(NDJSON *)parser;
/**
	Sent by the parser object to the delegate when it has successfully completed parsing.
 */
- (void)jsonParserDidEndDocument:(NDJSON *)parser;
/**
 Sent by a parser object to its delegate when it encounters a the start of a JSON array.
 */
- (void)jsonParserDidStartArray:(NDJSON *)parser;
/**
	Sent by a parser object to its delegate when it encounters an the of a JSON array. 
 */
- (void)jsonParserDidEndArray:(NDJSON *)parser;
/**
 Sent by a parser object to its delegate when it encounters a the start of a JSON object.
 */
- (void)jsonParserDidStartObject:(NDJSON *)parser;
/**
	Sent by a parser object to its delegate when it encounters an the of a JSON object. 
 */
- (void)jsonParserDidEndObject:(NDJSON *)parser;
/**
	Sent by a parser object to its delegate to give the delegate a chance to tell the parser to skip parsing the value for the current key.
 */
- (BOOL)jsonParserShouldSkipValueForCurrentKey:(NDJSON *)parser;
/**
	Sent by a parser object to its delegate when it encounters a JSON key in the JSON source.
 */
- (void)jsonParser:(NDJSON *)parser foundKey:(NSString *)aValue;
/**
	Sent by a parser object to its delegate when it encounters a JSON string in the JSON source.
 */
- (void)jsonParser:(NDJSON *)parser foundString:(NSString *)aValue;
/**
	Sent by a parser object to its delegate when it encounters a JSON integer number in the JSON source.
	An integer is a number in JSON which does not contain a decimal place
 */
- (void)jsonParser:(NDJSON *)parser foundInteger:(NSInteger)aValue;
/**
	Sent by a parser object to its delegate when it encounters a JSON float number in the JSON source.
	An float is a number in JSON which contains a decimal place
 */
- (void)jsonParser:(NDJSON *)parser foundFloat:(double)aValue;
/**
	Sent by a parser object to its delegate when it encounters a JSON boolean in the JSON source.
 */
- (void)jsonParser:(NDJSON *)parser foundBool:(BOOL)aValue;
/**
	Sent by a parser object to its delegate when it encounters a JSON NULL in the JSON source.
 */
- (void)jsonParserFoundNULL:(NDJSON *)parser;
/**
	Sent by a parser object to its delegate when it encounters an error in the JSON source.
 */
- (void)jsonParser:(NDJSON *)parser error:(NSError *)error;

@end

