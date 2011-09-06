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
		
		int didStartDocument	: 1;
		int didEndDocument		: 1;
		int didStartArray		: 1;
		int didEndArray			: 1;
		int didStartObject		: 1;
		int didEndObject		: 1;
		int foundKey			: 1;
		int foundString			: 1;
		int foundInteger		: 1;
		int foundFloat			: 1;
		int foundBool			: 1;
		int foundNULL			: 1;
		int foundError			: 1;
	}						respondsTo;
};

BOOL contextWithNullTermiantedString( struct NDJSONContext *, NDJSON * aParser, const char *, id<NDJSONDelegate> );
BOOL contextWithBytes( struct NDJSONContext *, NDJSON * aParser, const uint8_t *, NSUInteger, id<NDJSONDelegate> );
BOOL contextWithInputStream( struct NDJSONContext *, NDJSON *, NSInputStream *, id<NDJSONDelegate> );
void freeContext( struct NDJSONContext * );


BOOL beginParsing( struct NDJSONContext * aContext );
NDJSONContainer currentContainer( struct NDJSONContext * aContext );

