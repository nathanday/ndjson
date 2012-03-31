//
//  NDJSONCore.h
//  NDJSON
//
//  Created by Nathan Day on 1/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>

#define PRINT_STREAM 0

extern NSString	* const NDJSONErrorDomain;

@class		NDJSON;

typedef enum
{
	NDJSONContainerNone,
	NDJSONContainerArray,
	NDJSONContainerObject
}		NDJSONContainer;

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
NDJSONContainer currentContainer( struct NDJSONContext * aContext );
NSUInteger currentPosition( struct NDJSONContext * aContext );

struct NDJSONGeneratorContext
{
	NSMutableArray		* previousKeys;
	NSMutableArray		* previousObject;
	id					currentObject;
	id					currentKey;
	id					root;
};

/**
 functions used by NDJSONParser to build tree
 */

void initGeneratorContext( struct NDJSONGeneratorContext * context );
void freeGeneratorContext( struct NDJSONGeneratorContext * context );
void pushObject( struct NDJSONGeneratorContext * context, id object );
void popCurrentObject( struct NDJSONGeneratorContext * context );
void setCurrentKey( struct NDJSONGeneratorContext * context, NSString * key );
void pushKeyCurrentKey( struct NDJSONGeneratorContext * context );
void popCurrentKey( struct NDJSONGeneratorContext * context );
void addObject( struct NDJSONGeneratorContext * context, id object );


