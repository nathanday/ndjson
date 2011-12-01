//
//  NDJSONCore.h
//  NDJSON
//
//  Created by Nathan Day on 1/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>

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
void freeContext( struct NDJSONContext * );


BOOL beginParsing( struct NDJSONContext * aContext );
NDJSONContainer currentContainer( struct NDJSONContext * aContext );

