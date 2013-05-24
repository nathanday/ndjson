/*
	NDJSONParser.h

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

extern NSString			* const kNDJSONNoInputSourceExpection;

//#define NDJSONSupportUTF8Only
//#define NDJSONDebug
//#define NDJSONPrintStream

typedef enum
{
	NDJSONValueNone,
	NDJSONValueArray,
	NDJSONValueObject,
	NDJSONValueNull,
	NDJSONValueString,
	NDJSONValueInteger,
	NDJSONValueFloat,
	NDJSONValueBoolean
}		NDJSONValueType;

BOOL jsonParserValueIsPrimativeType( NDJSONValueType type );
BOOL jsonParserValueIsNSNumberType( NDJSONValueType type );
BOOL jsonParserValueEquivelentObjectTypes( NDJSONValueType typeA, NDJSONValueType typeB );

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

typedef NSInteger (*NDJSONDataStreamProc)(uint8_t ** aBuffer, void * aContext );
typedef NSInteger (^NDJSONDataStreamBlock)(uint8_t ** aBuffer);

typedef NS_OPTIONS(NSUInteger, NDJSONOptionFlags)
{
	NDJSONOptionNone = 0,
/**
	 determines whether the JSON source has to adhere to strict JSON or not.
	 
	 #Non strict JSON features
	 - object keys do not have to be quoted.
	 - arrays may have a trailing comment.
	 - control characters are allowed in strings (including quoted keys)
 */
	NDJSONOptionStrict = 1<<0,
};

extern NSString	* const NDJSONErrorDomain;

@protocol		NDJSONParserDelegate;

/**
 Instances of this class parse JSON documents in an event-driven manner. An NDJSONParser notifies its delegate about the JSON items (objects, arrays, strings, integers, floats, booleans and nulls) that it encounters as it processes an JSON document. It does not itself do anything with those parsed items except report them. It also reports parsing errors. NDJSONParser does not need to have the entire source JSON document in memory.
 */
@interface NDJSONParser : NSObject

/**
	The JSON parser’s delegate object. The delegate must conform to the NDJSONParserDelegate Protocol protocol.
 */
@property(assign,nonatomic)		id<NDJSONParserDelegate>	delegate;

/**
	key for the current JSON value, if the value is contained within an array, then the currentKey is for the array.
 */
@property(readonly,nonatomic)	NSString			* currentKey;

/**
 Returns the line number of the JSON document being processed by the receiver.
 */
@property(readonly,nonatomic)	NSUInteger			lineNumber;

/**
 set a JSON string to parse
 */
- (id)initWithJSONString:(NSString *)string;
/**
 set a JSON UTF8 string data to parse
 */
- (id)initWithJSONData:(NSData *)data encoding:(NSStringEncoding)encoding;
/**
	set a JSON file to parse specified using a string path
 */
- (id)initWithContentsOfFile:(NSString *)path encoding:(NSStringEncoding)encoding;
/**
	set a JSON file to parse specified using a file URL
 */
- (id)initWithContentsOfURL:(NSURL *)url encoding:(NSStringEncoding)encoding;
/**
	set an input stream to parse
 */
- (id)initWithInputStream:(NSInputStream *)stream encoding:(NSStringEncoding)encoding;
/**
	set a function for supplying the data stream
 */
- (id)initWithSourceFunction:(NDJSONDataStreamProc)function context:(void*)context encoding:(NSStringEncoding)anEncoding;
/**
	set a function for supplying the data stream
 */
- (id)initWithSourceBlock:(NDJSONDataStreamBlock)block encoding:(NSStringEncoding)anEncoding;
/**
	parses the JSON source set up by one other the set methods, setJSONString:error:, setContentsOfFile:error:, setContentsOfURL:error, setURLRequest:error:
	Important: This method does not return until parsing is complete, this method can be called within another thread as long as you do not change the reciever until after the method has finished.
 */
- (BOOL)parseWithOptions:(NDJSONOptionFlags)options;

/**
 Stops the parser object.
 */
- (void)abortParsing;

@end

/**
	The NDJSONParserDelegate protocol defines the optional methods implemented by delegates of NDJSONParser objects.
 */
@protocol NDJSONParserDelegate <NSObject>

@optional
/**
	Sent by the parser object to the delegate when it begins parsing a document.
 */
- (void)jsonParserDidStartDocument:(NDJSONParser *)parser;
/**
	Sent by the parser object to the delegate when it has successfully completed parsing.
 */
- (void)jsonParserDidEndDocument:(NDJSONParser *)parser;
/**
 Sent by a parser object to its delegate when it encounters a the start of a JSON array.
 */
- (void)jsonParserDidStartArray:(NDJSONParser *)parser;
/**
	Sent by a parser object to its delegate when it encounters an the of a JSON array. 
 */
- (void)jsonParserDidEndArray:(NDJSONParser *)parser;
/**
 Sent by a parser object to its delegate when it encounters a the start of a JSON object.
 */
- (void)jsonParserDidStartObject:(NDJSONParser *)parser;
/**
	Sent by a parser object to its delegate when it encounters an the of a JSON object. 
 */
- (void)jsonParserDidEndObject:(NDJSONParser *)parser;
/**
	Sent by a parser object to its delegate to give the delegate a chance to tell the parser to skip parsing the value for the current key.
 */
- (BOOL)jsonParser:(NDJSONParser *)parser shouldSkipValueForKey:(NSString *)key;
/**
	Sent by a parser object to its delegate when it encounters a JSON key in the JSON source.
 */
- (void)jsonParser:(NDJSONParser *)parser foundKey:(NSString *)aValue;
/**
	Sent by a parser object to its delegate when it encounters a JSON string in the JSON source.
 */
- (void)jsonParser:(NDJSONParser *)parser foundString:(NSString *)aValue;
/**
	 Sent by a parser object to its delegate when it encounters a JSON number or boolean in the JSON source.
 */
- (void)jsonParser:(NDJSONParser *)parser foundNumber:(NSNumber *)number;
/**
	Sent by a parser object to its delegate when it encounters a JSON integer number in the JSON source.
	An integer is a number in JSON which does not contain a decimal place
 */
- (void)jsonParser:(NDJSONParser *)parser foundInteger:(NSInteger)aValue;
/**
	Sent by a parser object to its delegate when it encounters a JSON float number in the JSON source.
	An float is a number in JSON which contains a decimal place
 */
- (void)jsonParser:(NDJSONParser *)parser foundFloat:(double)aValue;
/**
	Sent by a parser object to its delegate when it encounters a JSON boolean in the JSON source.
 */
- (void)jsonParser:(NDJSONParser *)parser foundBool:(BOOL)aValue;
/**
	Sent by a parser object to its delegate when it encounters a JSON NULL in the JSON source.
 */
- (void)jsonParserFoundNULL:(NDJSONParser *)parser;
/**
	Sent by a parser object to its delegate when it encounters an error in the JSON source.
 */
- (void)jsonParser:(NDJSONParser *)parser error:(NSError *)error;

@end

