/*
 NDJSON.h
 
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

typedef enum
{
	NDJSONValueNone,
	NDJSONValueArray,
	NDJSONValueObject,
	NDJSONValueString,
	NDJSONValueInteger,
	NDJSONValueFloat,
	NDJSONValueBoolean,
	NDJSONValueNull
}		NDJSONValueType;

typedef enum
{
	NDJSONGeneralError,
	NDJSONBadTokenError,
	NDJSONBadFormatError,
	NDJSONBadEscapeSequenceError,
	NDJSONTrailingGarbageError,
	NDJSONMemoryErrorError,
	NDJSONPrematureEndError,
	NDJSONBadNumberError
}		NDJSONErrorCode;

typedef NSUInteger		NDJSONOptionFlags;

typedef NSInteger (*NDJSONDataStreamProc)(uint8_t ** aBuffer, void * aContext );
typedef NSInteger (^NDJSONDataStreamBlock)(uint8_t ** aBuffer);

enum {
	NDJSONOptionNone = 0,
/**
	 determines whether the JSON source has to adhere to strict JSON or not.
	 
	 #Non strict JSON features
	 - object keys do not have to be quoted.
	 - arrays may have a trailing comment.
 */
	NDJSONOptionStrict = 1<<0
};

extern NSString	* const NDJSONErrorDomain;

@protocol		NDJSONDelegate;

/**
 Instances of this class parse JSON documents in an event-driven manner. An NDJSON notifies its delegate about the JSON items (objects, arrays, strings, integers, floats, booleans and nulls) that it encounters as it processes an JSON document. It does not itself do anything with those parsed items except report them. It also reports parsing errors. NDJSON does not need to have the entire source JSON document in memory.
 */
@interface NDJSON : NSObject

/**
	The JSON parser’s delegate object. The delegate must conform to the NDJSONDelegate Protocol protocol.
 */
@property(assign,nonatomic)		id<NDJSONDelegate>	delegate;

/**
	key for the current JSON value, if the value is contained within an array, then the currentKey is for the array.
 */
@property(readonly,nonatomic)	NSString			* currentKey;
/**
	intialise a *NDJSON* instance with a delegate
 */
- (id)initWithDelegate:(id<NDJSONDelegate>)delegate;

/**
 equivelent to `-[NDJSON setJSONString:error:]` and `-[NDJSON parseWithOptions:]`
 */
- (BOOL)parseJSONString:(NSString *)string options:(NDJSONOptionFlags)options error:(NSError **)error;
/**
 equivelent to `-[NDJSON setJSONData:error:]` and `-[NDJSON parseWithOptions:]`
 */
- (BOOL)parseJSONData:(NSData *)data options:(NDJSONOptionFlags)options error:(NSError **)error;
/**
	equivelent to `-[NDJSON setContentsOfFile:error:]` and `-[NDJSON parseWithOptions:]`
 */
- (BOOL)parseContentsOfFile:(NSString *)path encoding:(NSStringEncoding)encoding options:(NDJSONOptionFlags)options error:(NSError **)error;
/**
	equivelent to `-[NDJSON setContentsOfURL:error:]` and `-[NDJSON parseWithOptions:]`
 */
- (BOOL)parseContentsOfURL:(NSURL *)url encoding:(NSStringEncoding)encoding options:(NDJSONOptionFlags)options error:(NSError **)error;
/**
	equivelent to `-[NDJSON setURLRequest:error:]` and `-[NDJSON parseWithOptions:]`
	Important: URLRequests are not parsed asyncronisly, see `-[NDJSON parseWithOptions:]`.
 */
- (BOOL)parseURLRequest:(NSURLRequest *)urlRequest options:(NDJSONOptionFlags)options error:(NSError **)error;
/**
	equivelent to `-[NDJSON parseInputStream:error:]` and `-[NDJSON parseWithOptions:]`
 */
- (BOOL)parseInputStream:(NSInputStream *)stream encoding:(NSStringEncoding)encoding options:(NDJSONOptionFlags)options error:(NSError **)error;

- (BOOL)parseSourceFunction:(NDJSONDataStreamProc)function context:(void*)context encoding:(NSStringEncoding)encoding options:(NDJSONOptionFlags)options error:(NSError **)error;

/**
 set a JSON string to parse
 */
- (BOOL)setJSONString:(NSString *)string error:(NSError **)error;
/**
 set a JSON UTF8 string data to parse
 */
- (BOOL)setJSONData:(NSData *)data encoding:(NSStringEncoding)encoding error:(NSError **)error;
/**
	set a JSON file to parse specified using a string path
 */
- (BOOL)setContentsOfFile:(NSString *)path encoding:(NSStringEncoding)encoding error:(NSError **)error;
/**
	set a JSON file to parse specified using a file URL
 */
- (BOOL)setContentsOfURL:(NSURL *)url encoding:(NSStringEncoding)encoding error:(NSError **)error;
/**
	set a JSON URLRequest to parse
	Important: URLRequests are not parsed asyncronisly, see `-[NDJSON parseWithOptions:]`.
 */
- (BOOL)setURLRequest:(NSURLRequest *)urlRequest error:(NSError **)error;
/**
	set an input stream to parse
 */
- (BOOL)setInputStream:(NSInputStream *)stream encoding:(NSStringEncoding)encoding error:(NSError **)error;
/**
	set a function for supplying the data stream
 */
- (BOOL)setSourceFunction:(NDJSONDataStreamProc)function context:(void*)context encoding:(NSStringEncoding)anEncoding error:(NSError **)error;
/**
	set a function for supplying the data stream
 */
- (BOOL)setSourceBlock:(NDJSONDataStreamBlock)block encoding:(NSStringEncoding)anEncoding error:(NSError **)error;
/**
	parses the JSON source set up by one other the set methods, setJSONString:error:, setContentsOfFile:error:, setContentsOfURL:error, setURLRequest:error:
	Important: This method does not return until parsing is complete, this method can be called within another thread as long as you do not change the reciever until after the method has finished.
 */
- (BOOL)parseWithOptions:(NDJSONOptionFlags)options;

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
- (BOOL)sonParser:(NDJSON *)parser shouldSkipValueForKey:(NSString *)key;
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

