//
//  NDJSONCore.c
//  NDJSON
//
//  Created by Nathan Day on 1/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <string.h>
#include <ctype.h>
#import "NDJSONCore.h"
#import "NDJSON.h"

static NSString * const kErrorCodeStrings[] = 
{
	@"General",
	@"BadToken",
	@"BadFormat",
	@"BadEscapeSequence",
	@"TrailingGarbage",
	@"Memory",
	@"PrematureEnd",
	@"BadNumber"
};

static const size_t		kBufferSize = 64;

NSString	* const NDJSONErrorDomain = @"NDJSONError";

static const struct NDBytesBuffer	NDBytesBufferInit = {NULL,0,0};

static void setUpRespondsTo( struct NDJSONContext * aContext );

static uint8_t currentChar( struct NDJSONContext * aContext );
static uint8_t nextChar( struct NDJSONContext * aContext );
static uint8_t nextCharIgnoreWhiteSpace( struct NDJSONContext * aContext );
static uint8_t skipWhiteSpace( struct NDJSONContext * aContext );
static void backUp( struct NDJSONContext * aContext );

static BOOL extendsBytesOfLen( struct NDBytesBuffer * aBuffer, NSUInteger aLen );
static BOOL appendByte( struct NDBytesBuffer * aBuffer, uint8_t aBytes );
static BOOL truncateByte( struct NDBytesBuffer * aBuffer, uint8_t aBytes );
static uint8_t topByte( struct NDBytesBuffer * aBuffer );
static BOOL appendBytesOfLen( struct NDBytesBuffer * aBuffer, uint8_t * aBytes, NSUInteger aLen );
static void freeByte( struct NDBytesBuffer * aBuffer );

static BOOL unknownParsing( struct NDJSONContext * aContext );
static BOOL parseObject( struct NDJSONContext * aContext );
static BOOL parseArray( struct NDJSONContext * aContext );
static BOOL parseKey( struct NDJSONContext * aContext );
static BOOL parseString( struct NDJSONContext * aContext );
static BOOL parseText( struct NDJSONContext * aContext, BOOL aIsKey, BOOL aIsQuotesTerminated );
static BOOL parseNumber( struct NDJSONContext * aContext );
static BOOL parseTrue( struct NDJSONContext * aContext );
static BOOL parseFalse( struct NDJSONContext * aContext );
static BOOL parseNull( struct NDJSONContext * aContext );

static void foundError( struct NDJSONContext * aContext, NDJSONErrorCode aCode );

BOOL contextWithNullTermiantedString( struct NDJSONContext * aContext, NDJSON * aParser, const char * aString, id<NDJSONDelegate> aDelegate )
{
	if( aDelegate != nil )
	{
		aContext->position = 0;
		aContext->length = NSUIntegerMax;
		aContext->bytes = (uint8_t*)aString;
		aContext->complete = NO;
		aContext->useBackUpByte = NO;
		aContext->parser = aParser;
		aContext->delegate = aDelegate;
		aContext->inputStream = NULL;
		if( aContext->delegate != nil )
			setUpRespondsTo( aContext );
	}
	return aContext->delegate != nil;
}

BOOL contextWithBytes( struct NDJSONContext * aContext, NDJSON * aParser, const uint8_t * aBytes, NSUInteger aLen, id<NDJSONDelegate> aDelegate )
{
	if( aDelegate != nil )
	{
		aContext->position = 0;
		aContext->length = aLen;
		aContext->bytes = (uint8_t*)aBytes;
		aContext->complete = NO;
		aContext->useBackUpByte = NO;
		aContext->parser = aParser;
		aContext->delegate = aDelegate;
		aContext->inputStream = NULL;

		if( aContext->delegate != nil )
			setUpRespondsTo( aContext );
	}
	return aContext->delegate != nil;
}

BOOL contextWithInputStream( struct NDJSONContext * aContext, NDJSON * aParser, NSInputStream * aStream, id<NDJSONDelegate> aDelegate )
{
	if( aDelegate != nil )
	{
		aContext->position = 0;
		aContext->length = 0;
		aContext->bytes = malloc(kBufferSize);
		aContext->complete = NO;
		aContext->useBackUpByte = NO;
		aContext->parser = aParser;
		aContext->delegate = aDelegate;
		aContext->inputStream = [aStream retain];
		if( aContext->delegate != nil )
			setUpRespondsTo( aContext );
	}
	return aContext->delegate != nil;
}

void freeContext( struct NDJSONContext * aContext )
{
	[aContext->inputStream release];
}


/*
	do this once so we don't waste time sending the same message to get the same answer
	Could ad code to look up the IMPs for the messages, and the use NULL values for them to determine whether to send the call
 */
void setUpRespondsTo( struct NDJSONContext * aContext )
{
	NSObject		* theDelegate = (NSObject*)aContext->delegate;
	aContext->delegateMethod.didStartDocument = [theDelegate respondsToSelector:@selector(jsonParserDidStartDocument:)]
											? [theDelegate methodForSelector:@selector(jsonParserDidStartDocument:)]
											: NULL;
	aContext->delegateMethod.didEndDocument = [theDelegate respondsToSelector:@selector(jsonParserDidEndDocument:)]
										? [theDelegate methodForSelector:@selector(jsonParserDidEndDocument:)]
										: NULL;
	aContext->delegateMethod.didStartArray = [theDelegate respondsToSelector:@selector(jsonParserDidStartArray:)]
										? [theDelegate methodForSelector:@selector(jsonParserDidStartArray:)]
										: NULL;
	aContext->delegateMethod.didEndArray = [theDelegate respondsToSelector:@selector(jsonParserDidEndArray:)]
										? [theDelegate methodForSelector:@selector(jsonParserDidEndArray:)]
										: NULL;
	aContext->delegateMethod.didStartObject = [theDelegate respondsToSelector:@selector(jsonParserDidStartObject:)]
										? [theDelegate methodForSelector:@selector(jsonParserDidStartObject:)]
										: NULL;
	aContext->delegateMethod.didEndObject = [theDelegate respondsToSelector:@selector(jsonParserDidEndObject:)]
										? [theDelegate methodForSelector:@selector(jsonParserDidEndObject:)]
										: NULL;
	aContext->delegateMethod.foundKey = [theDelegate respondsToSelector:@selector(jsonParser:foundKey:)]
									? [theDelegate methodForSelector:@selector(jsonParser:foundKey:)]
									: NULL;
	aContext->delegateMethod.foundString = [theDelegate respondsToSelector:@selector(jsonParser:foundString:)]
										? [theDelegate methodForSelector:@selector(jsonParser:foundString:)]
										: NULL;
	aContext->delegateMethod.foundInteger = [theDelegate respondsToSelector:@selector(jsonParser:foundInteger:)]
										? [theDelegate methodForSelector:@selector(jsonParser:foundInteger:)]
										: NULL;
	aContext->delegateMethod.foundFloat = [theDelegate respondsToSelector:@selector(jsonParser:foundFloat:)]
										? [theDelegate methodForSelector:@selector(jsonParser:foundFloat:)]
										: NULL;
	aContext->delegateMethod.foundBool = [theDelegate respondsToSelector:@selector(jsonParser:foundBool:)]
										? [theDelegate methodForSelector:@selector(jsonParser:foundBool:)]
										: NULL;
	aContext->delegateMethod.foundNULL = [theDelegate respondsToSelector:@selector(jsonParserFoundNULL)]
										? [theDelegate methodForSelector:@selector(jsonParserFoundNULL)]
										: NULL;
	aContext->delegateMethod.foundError = [theDelegate respondsToSelector:@selector(jsonParser:error:)]
										? [theDelegate methodForSelector:@selector(jsonParser:error:)]
										: NULL;
}

uint8_t currentChar( struct NDJSONContext * aContext )
{
	uint8_t	theResult = '\0';
	if( aContext->position >= aContext->length )
	{
		if( aContext->inputStream != nil && (aContext->length = [aContext->inputStream read:aContext->bytes maxLength:kBufferSize]) > 0 )
			aContext->position = 0;
		else
			aContext->complete = YES;
	}

	if( !aContext->complete )
		theResult = aContext->bytes[aContext->position];
	return theResult;
}

uint8_t nextChar( struct NDJSONContext * aContext )
{
	if( !aContext->useBackUpByte )
	{
		aContext->backUpByte = currentChar( aContext );
		if( aContext->backUpByte != '\0' )
			aContext->position++;
	}
	else
		aContext->useBackUpByte = NO;
	return aContext->backUpByte;
}

uint8_t nextCharIgnoreWhiteSpace( struct NDJSONContext * aContext )
{
	uint8_t		theResult;
	do
		theResult = nextChar( aContext );
	while( isspace(theResult) );
	return theResult;
}

uint8_t skipWhiteSpace( struct NDJSONContext * aContext )
{
	BOOL		theEnd = NO;
	uint8_t		theResult;
	do
	{
		theResult = currentChar( aContext );
		if( isspace(theResult) && theResult != '\0' )
			aContext->position++;
		else
			theEnd = YES;
	}
	while( !theEnd );
	return theResult;
}

void backUp( struct NDJSONContext * aContext )
{
	aContext->useBackUpByte = YES;
}

BOOL beginParsing( struct NDJSONContext * aContext )
{
	BOOL		theResult = YES;
	aContext->containers = NDBytesBufferInit;
	appendByte(&aContext->containers, NDJSONContainerNone);
	if( aContext->delegateMethod.didStartDocument != NULL )
		aContext->delegateMethod.didStartDocument( aContext->delegate, @selector(jsonParserDidStartDocument:), aContext->parser );
	[aContext->inputStream open];
	theResult = unknownParsing( aContext );
	[aContext->inputStream close];
	if( !aContext->complete && theResult )
		foundError(aContext, NDJSONTrailingGarbageError );

	if( aContext->delegateMethod.didEndDocument != NULL )
		aContext->delegateMethod.didEndDocument( aContext->delegate, @selector(jsonParserDidEndDocument:), aContext->parser );
	freeByte(&aContext->containers);
	return theResult;
}

NDJSONContainer currentContainer( struct NDJSONContext * aContext )
{
	return (NDJSONContainer)topByte(&aContext->containers);
}

BOOL unknownParsing( struct NDJSONContext * aContext )
{
	BOOL		theResult = YES;
	uint8_t		theChar = nextCharIgnoreWhiteSpace( aContext );
	switch (theChar)
	{
		case '{':
			theResult = parseObject( aContext );
			break;
		case '[':
			theResult = parseArray( aContext );
			break;
		case '"':
			theResult = parseString( aContext );
			break;
		case '0' ... '9':
		case '-':
			backUp(aContext);
			theResult = parseNumber( aContext );
			break;
		case 't':
			theResult = parseTrue( aContext );
			break;
		case 'f':
			theResult = parseFalse( aContext );
			break;
		case 'n':
			theResult = parseNull( aContext );
			break;
		default:
			foundError(aContext, NDJSONBadFormatError );
			break;
	}
	
	if( theResult )
		theResult = skipWhiteSpace(aContext) != '\0';
	return theResult;
}

BOOL parseArray( struct NDJSONContext * aContext )
{
	BOOL				theResult = YES;
	BOOL				theEnd = NO;
	NSUInteger			theCount = 0;
	appendByte(&aContext->containers, NDJSONContainerArray);
	if( aContext->delegateMethod.didStartArray != NULL )
		aContext->delegateMethod.didStartArray( aContext->delegate, @selector(jsonParserDidStartArray:), aContext->parser );
	
	if( nextCharIgnoreWhiteSpace(aContext) == ']' )
		theEnd = YES;
	else
		backUp(aContext);
	
	while( !theEnd && (theResult = unknownParsing( aContext )) == YES )
	{
		uint8_t		theChar = nextCharIgnoreWhiteSpace(aContext);
		theCount++;
		switch( theChar )
		{
			case ']':
				theEnd = YES;
				break;
			case ',':
				break;
			default:
				foundError( aContext, NDJSONBadFormatError );
				backUp(aContext);
				goto erorOut;
				break;
		}
	}
	if( theEnd )
	{
		NSCParameterAssert(truncateByte(&aContext->containers, NDJSONContainerArray));
		if( aContext->delegateMethod.didEndArray != NULL )
			aContext->delegateMethod.didEndArray( aContext->delegate, @selector(jsonParserDidEndArray:), aContext->parser );
	}
erorOut:
	return theResult;
}

BOOL parseObject( struct NDJSONContext * aContext )
{
	BOOL				theResult = YES;
	BOOL				theEnd = NO;
	NSUInteger			theCount = 0;
	appendByte(&aContext->containers, NDJSONContainerObject);
	if( aContext->delegateMethod.didStartObject != NULL )
		aContext->delegateMethod.didStartObject( aContext->delegate, @selector(jsonParserDidStartObject:), aContext->parser );
	
	if( nextCharIgnoreWhiteSpace(aContext) == '}' )
		theEnd = YES;
	else
		backUp(aContext);
	
	while( !theEnd )
	{
		if( (theResult = parseKey(aContext)) )
		{
			if( (nextCharIgnoreWhiteSpace(aContext) == ':') == YES )
			{
				if( (theResult = unknownParsing( aContext )) == YES )
				{
					uint8_t		theChar = nextCharIgnoreWhiteSpace(aContext);
					theCount++;
					switch( theChar )
					{
						case '}':
							theEnd = YES;
							break;
						case ',':
							break;
						default:
							foundError( aContext, NDJSONBadFormatError );
							break;
					}
				}
				else
					foundError( aContext, NDJSONBadFormatError );
			}
			else
				foundError( aContext, NDJSONBadFormatError );
		}
		else
			foundError( aContext, NDJSONBadFormatError );
	}
	if( theEnd )
	{
		if( aContext->delegateMethod.didEndObject != NULL )
			aContext->delegateMethod.didEndObject( aContext->delegate, @selector(jsonParserDidEndObject:), aContext->parser );
		NSCParameterAssert(truncateByte(&aContext->containers, NDJSONContainerObject));
	}
	
	return theResult;
}

BOOL parseKey( struct NDJSONContext * aContext )
{
	BOOL			theResult = YES;
	if( nextCharIgnoreWhiteSpace(aContext) == '"' )
		theResult = parseText( aContext, YES, YES );
	else
	{
		backUp(aContext);
		theResult = parseText( aContext, YES, NO );
		foundError( aContext, NDJSONBadFormatError );
	}
	return theResult;
}

BOOL parseString( struct NDJSONContext * aContext )
{
	return parseText( aContext, NO, YES );
}

BOOL parseText( struct NDJSONContext * aContext, BOOL aIsKey, BOOL aIsQuotesTerminated )

{
	BOOL					theResult = YES,
	theEnd = NO;
	struct NDBytesBuffer	theBuffer = NDBytesBufferInit;
	
	while( theResult  && !theEnd)
	{
		uint8_t		theChar = nextChar(aContext);
		switch( theChar )
		{
		case '\0':
			theResult = NO;
			break;
		case '\\':
		{
			theChar = nextChar(aContext);
			switch( theChar )
			{
			case '\0':
				theResult = NO;
				break;
			case '"':
			case '\\':
				if( !appendByte( &theBuffer, theChar ) )
					foundError( aContext, NDJSONMemoryErrorError );
				break;
			case '/':
				if( !appendByte( &theBuffer, theChar ) )
					foundError( aContext, NDJSONMemoryErrorError );
				break;
			case 'b':
				if( !appendByte( &theBuffer, '\b' ) )
					foundError( aContext, NDJSONMemoryErrorError );
				break;
			case 'f':
				if( !appendByte( &theBuffer, '\b' ) )
					foundError( aContext, NDJSONMemoryErrorError );
				break;
			case 'n':
				if( !appendByte( &theBuffer, '\n' ) )
					foundError( aContext, NDJSONMemoryErrorError );
				break;
			case 'r':
				if( !appendByte( &theBuffer, '\r' ) )
					foundError( aContext, NDJSONMemoryErrorError );
				break;
			case 't':
				if( !appendByte( &theBuffer, '\t' ) )
					foundError( aContext, NDJSONMemoryErrorError );
				break;
				/*					case 'u':
				 if( !appendByte( &theBuffer, '\u' ) )
				 foundError( aContext, NDJSONMemoryErrorError );
				 break;
				 */
			default:
				foundError( aContext, NDJSONBadEscapeSequenceError );
				break;
			}
			break;
		}
		case '"':
			theEnd = YES;
			break;
		default:
			if( !aIsQuotesTerminated && isspace(theChar) )
				theEnd = YES;
			else if( !aIsQuotesTerminated && theChar == ':' )
			{
				theEnd = YES;
				backUp(aContext);
			}
			else if( !appendByte( &theBuffer, theChar ) )
				foundError( aContext, NDJSONMemoryErrorError );
			break;
		}
	}
	if( theEnd )
	{
		NSString	* theValue = [[NSString alloc] initWithBytes:theBuffer.bytes length:theBuffer.length encoding:NSUTF8StringEncoding];
		if( aIsKey )
		{
			if( aContext->delegateMethod.foundKey != NULL )
				aContext->delegateMethod.foundKey( aContext->delegate, @selector(jsonParser:foundKey:), aContext->parser, theValue );
		}
		else
		{
			if( aContext->delegateMethod.foundString != NULL )
				aContext->delegateMethod.foundString( aContext->delegate, @selector(jsonParser:foundString:), aContext->parser, theValue );
		}
	}
	else
		foundError( aContext, NDJSONBadFormatError );
	freeByte( &theBuffer );
	return theResult;
}

BOOL parseNumber( struct NDJSONContext * aContext )
{
	BOOL			theNegative = NO;
	BOOL			theEnd = NO,
					theResult = YES;
	long long		theIntegerValue = 0,
					theDecimalValue = 0,
					theExponentValue = 0;
	int				theDecimalPlaces = 1;
	
	if( nextChar(aContext) == '-' )
		theNegative = YES;
	else
		backUp(aContext);
	
	while( !theEnd && theResult )
	{
		uint8_t		theChar = nextChar(aContext);
		switch( theChar )
		{
			case '\0':
				theResult = 0;
				break;
			case '0'...'9':
				if( theDecimalPlaces <= 0 )
				{
					theDecimalPlaces--;
					theDecimalValue = theDecimalValue * 10 + (theChar - '0');
				}
				else
					theIntegerValue = theIntegerValue * 10 + (theChar - '0');
				break;
			case 'e':
			case 'E':
			{
				BOOL		theExponentNegative = 0;
				theChar = nextChar(aContext);
				if( theChar == '+' || theChar == '-' )
					theExponentNegative = (theChar == '-');
				else if( theChar >= '0' && theChar <= '9' )
					theExponentValue = (theChar - '0');
				else
				{
					theEnd = YES;
					foundError( aContext, NDJSONBadNumberError );
				}
				
				while( !theEnd && theResult )
				{
					theChar = nextChar(aContext);
					switch( theChar )
					{
						case '\0':
							theResult = NO;
							break;
						case '0'...'9':
							theExponentValue = theExponentValue * 10 + (theChar - '0');
							break;
						default:
							theEnd = YES;
							break;
					}
				}
				if( theExponentNegative )
					theExponentValue = -theExponentValue;
				break;
			}
			case '.':
				if( theDecimalPlaces > 0 )
					theDecimalPlaces = 0;
				else
					theEnd = YES;
				break;
			default:
				theEnd = YES;
				break;
		}
	}
	
	if( theDecimalPlaces < 0 || theExponentValue != 0 )
	{
		double	theValue = ((double)theIntegerValue) + ((double)theDecimalValue)*pow(10,theDecimalPlaces);
		if( theExponentValue != 0 )
			theValue *= pow(10,theExponentValue);
		if( theNegative )
			theValue = -theValue;
		if( aContext->delegateMethod.foundFloat != NULL )
			aContext->delegateMethod.foundFloat( aContext->delegate, @selector(jsonParser:foundFloat:), aContext->parser, theValue );
	}
	else if( theDecimalPlaces > 0 )
	{
		if( theNegative )
			theIntegerValue = -theIntegerValue;
		if( aContext->delegateMethod.foundInteger != NULL )
			aContext->delegateMethod.foundInteger( aContext->delegate, @selector(jsonParser:foundInteger:), aContext->parser, theIntegerValue );
	}
	else
		foundError(aContext, NDJSONBadNumberError );
	
	if( theResult )
		backUp( aContext );
	return theResult;
}

BOOL parseTrue( struct NDJSONContext * aContext )
{
	BOOL		theResult = YES;
	uint8_t		theChar;
	if( (theChar = nextChar(aContext)) == 'r' && (theChar = nextChar(aContext)) == 'u' && (theChar = nextChar(aContext)) == 'e' )
	{
		if( aContext->delegateMethod.foundBool != NULL )
			aContext->delegateMethod.foundBool( aContext->delegate, @selector(jsonParser:foundBool:), aContext->parser, YES );
	}
	else if( theChar == '\0' )
		theResult = NO;
	else
		foundError( aContext, NDJSONBadTokenError );
	return theResult;
}

BOOL parseFalse( struct NDJSONContext * aContext )
{
	BOOL		theResult = YES;
	uint8_t		theChar;
	if( (theChar = nextChar(aContext)) == 'a' && (theChar = nextChar(aContext)) == 'l' && (theChar = nextChar(aContext)) == 's' && (theChar = nextChar(aContext)) == 'e' )
	{
		if( aContext->delegateMethod.foundBool != NULL )
			aContext->delegateMethod.foundBool( aContext->delegate, @selector(jsonParser:foundBool:), aContext->parser, NO );
	}
	else if( theChar == '\0' )
		theResult = NO;
	else
		foundError( aContext, NDJSONBadTokenError );
	return theResult;
}

BOOL parseNull( struct NDJSONContext * aContext )
{
	BOOL		theResult = YES;
	uint8_t		theChar;
	if( (theChar = nextChar(aContext)) == 'u' && (theChar = nextChar(aContext)) == 'l' && (theChar = nextChar(aContext)) == 'l' )
	{
		if( aContext->delegateMethod.foundNULL != NULL )
			aContext->delegateMethod.foundNULL( aContext->delegate, @selector(jsonParserFoundNULL:), aContext->parser );
	}
	else if( theChar == '\0' )
		theResult = NO;
	else
		foundError( aContext, NDJSONBadTokenError );
	return theResult;
}

void foundError( struct NDJSONContext * aContext, NDJSONErrorCode aCode )
{
	NSMutableDictionary		* theUserInfo = [[NSMutableDictionary alloc] initWithObjectsAndKeys:kErrorCodeStrings[aCode],NSLocalizedDescriptionKey, nil];
	NSUInteger				thePos = aContext->position > 5 ? aContext->position - 5 : 5,
							theLen = aContext->length - thePos < 10 ? aContext->length - thePos : 10;
	NSString				* theString = nil;
	switch (aCode)
	{
	default:
	case NDJSONGeneralError:
		break;
	case NDJSONBadTokenError:
	{
		theString = [[NSString alloc] initWithFormat:@"Bad token at pos %lu, %*s", aContext->position, theLen, aContext->bytes];
		[theUserInfo setObject:theString forKey:NSLocalizedFailureReasonErrorKey];
		[theString release];
		break;
					 }
	case NDJSONBadFormatError:
		break;
	case NDJSONBadEscapeSequenceError:
		break;
	case NDJSONTrailingGarbageError:
		break;
	case NDJSONMemoryErrorError:
		break;
	case NDJSONPrematureEndError:
		break;
	}
	if( aContext->delegateMethod.foundError != NULL )
		aContext->delegateMethod.foundError( aContext->delegate, @selector(jsonParser:error:), aContext->parser, [NSError errorWithDomain:NDJSONErrorDomain code:aCode userInfo:theUserInfo] );
	[theUserInfo release];
}

BOOL extendsBytesOfLen( struct NDBytesBuffer * aBuffer, NSUInteger aLen )
{
	BOOL			theResult = YES;
	uint8_t			* theNewBuff = NULL;
	while( aBuffer->length + aLen >= aBuffer->capacity )
	{
		if( aBuffer->capacity == 0 )
			aBuffer->capacity = aLen;
		else
			aBuffer->capacity <<= 1;
	}
	theNewBuff = realloc( aBuffer->bytes , aBuffer->capacity );
	if( theNewBuff != NULL )
		aBuffer->bytes = theNewBuff;
	else
		theResult = NO;
	return theResult;
}

BOOL appendByte( struct NDBytesBuffer * aBuffer, uint8_t aByte )
{
	BOOL	theResult = YES;
	if( aBuffer->length + 1 > aBuffer->capacity )
		theResult = extendsBytesOfLen( aBuffer, 1 );
	
	if( theResult )
	{
		aBuffer->bytes[aBuffer->length] = aByte;
		aBuffer->length++;
	}
	return theResult;
}

static BOOL truncateByte( struct NDBytesBuffer * aBuffer, uint8_t aBytes )
{
	BOOL	theResult = NO;
	if( aBuffer->length > 0 && aBuffer->bytes[aBuffer->length-1] == aBytes )
	{
		aBuffer->length--;
		theResult = YES;
	}
	return theResult;
}

static uint8_t topByte( struct NDBytesBuffer * aBuffer )
{
	uint8_t	theResult = 0;
	if( aBuffer->length > 0  )
		theResult = aBuffer->bytes[aBuffer->length-1];
	return theResult;
}


BOOL appendBytesOfLen( struct NDBytesBuffer * aBuffer, uint8_t * aBytes, NSUInteger aLen )
{
	BOOL	theResult = YES;
	if( aBuffer->length + aLen > aBuffer->capacity )
		theResult = extendsBytesOfLen( aBuffer, aLen );
	
	if( theResult )
	{
		memcpy( aBuffer->bytes+aBuffer->length, aBytes, aLen );
		aBuffer->length += aBuffer->length;
	}
	return theResult;
}

void freeByte( struct NDBytesBuffer * aBuffer )
{
	free(aBuffer->bytes);
	aBuffer->bytes = NULL;
	aBuffer->length = 0;
	aBuffer->capacity = 0;
}

