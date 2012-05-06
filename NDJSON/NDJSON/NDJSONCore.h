//
//  NDJSONCore.h
//  NDJSON
//
//  Created by Nathan Day on 1/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>

#define NDJSONDebug
//#define NDJSONPrintStream

extern NSString	* const NDJSONErrorDomain;

@class		NDJSON;

typedef enum
{
	NDJSONContainerNone,
	NDJSONContainerArray,
	NDJSONContainerObject
}		NDJSONContainerType;

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

@protocol NDJSONDelegate;

struct NDBytesBuffer
{
	uint8_t			* bytes;
	NSUInteger		length,
					capacity;
};

struct NDJSONContext
{
	NSUInteger				position,
							length;
	uint8_t					* bytes;
	uint8_t					backUpByte;
	BOOL					complete,
							useBackUpByte;
	BOOL					skipParsingValue;
	BOOL					convertKeysToMedialCapital,
							removeIsAdjective;
	NDJSON					* parser;
	id<NDJSONDelegate>		delegate;
	NSInputStream			* inputStream;
	struct NDBytesBuffer	containers;
	struct
	{
		
		IMP		didStartDocument,
				didEndDocument,
				didStartArray,
				didEndArray,
				didStartObject,
				didEndObject,
				shouldSkipValueForCurrentKey,
				foundKey,
				foundString,
				foundInteger,
				foundFloat,
				foundBool,
				foundNULL,
				foundError;
	}						delegateMethod;
};

BOOL contextWithNullTermiantedString( struct NDJSONContext *, NDJSON * aParser, const char *, id<NDJSONDelegate> );
BOOL contextWithBytes( struct NDJSONContext *, NDJSON * aParser, const uint8_t *, NSUInteger, id<NDJSONDelegate> );
BOOL contextWithInputStream( struct NDJSONContext *, NDJSON *, NSInputStream *, id<NDJSONDelegate> );
void setDelegateForContext( struct NDJSONContext *, id<NDJSONDelegate> );
void freeContext( struct NDJSONContext * );

BOOL beginParsing( struct NDJSONContext * aContext );
NDJSONContainerType currentContainerType( struct NDJSONContext * aContext );
NSUInteger indexOfHighestContainerType( struct NDJSONContext * aContext, NDJSONContainerType aType );
NSUInteger currentPosition( struct NDJSONContext * aContext );

struct NDJSONGeneratorContext
{
	NSMutableArray		* previousKeys;
	NSMutableArray		* previousContainer;
	id					currentContainer;
	id					currentKey;
	id					root;
};

/**
 functions used by NDJSONParser to build tree
 */

void initGeneratorContext( struct NDJSONGeneratorContext * context );
void freeGeneratorContext( struct NDJSONGeneratorContext * context );
id currentContainer( struct NDJSONGeneratorContext * context );
void pushContainer( struct NDJSONGeneratorContext * context, id container );
void popCurrentContainer( struct NDJSONGeneratorContext * context );
id currentKey( struct NDJSONGeneratorContext * context );
void setCurrentKey( struct NDJSONGeneratorContext * context, NSString * key );
void resetCurrentKey( struct NDJSONGeneratorContext * context );
void pushKeyCurrentKey( struct NDJSONGeneratorContext * context );
void popCurrentKey( struct NDJSONGeneratorContext * context );
void addContainer( struct NDJSONGeneratorContext * context, id container );
