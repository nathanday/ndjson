//
//  NDJSON.m
//  NDJSON
//
//  Created by Nathan Day on 31/08/11.
//  Copyright 2011 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NDJSON.h"
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <string.h>
#include <ctype.h>

//#define NDJSONDebug
//#define NDJSONPrintStream

#ifdef NDJSONDebug
#define NDJSONLog(...) NSLog(__VA_ARGS__)
#else
#define NDJSONLog(...)
#endif

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

typedef BOOL (*returnBoolMethodIMP)( id, SEL, id);

static const size_t		kBufferSize = 64;

NSString	* const NDJSONErrorDomain = @"NDJSONError";

static const struct NDBytesBuffer	NDBytesBufferInit = {NULL,0,0};
static BOOL extendsBytesOfLen( struct NDBytesBuffer * aBuffer, NSUInteger aLen );
static BOOL appendByte( struct NDBytesBuffer * aBuffer, uint8_t aBytes );
static BOOL appendCharacter( struct NDBytesBuffer * aBuffer, unsigned int aValue );
static BOOL truncateByte( struct NDBytesBuffer * aBuffer, uint8_t aBytes );
static void freeByte( struct NDBytesBuffer * aBuffer );

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

static BOOL parseUnknown( NDJSON * self );
static BOOL parseObject( NDJSON * self );
static BOOL parseArray( NDJSON * self );
static BOOL parseKey( NDJSON * self );
static BOOL parseString( NDJSON * self );
static BOOL parseText( NDJSON * self, BOOL aIsKey, BOOL aIsQuotesTerminated );
static BOOL parseNumber( NDJSON * self );
static BOOL parseTrue( NDJSON * self );
static BOOL parseFalse( NDJSON * self );
static BOOL parseNull( NDJSON * self );
static BOOL skipNextValue( NDJSON * self );
static void foundError( NDJSON * self, NDJSONErrorCode aCode );

@interface NDJSON ()
{
	__weak id<NDJSONDelegate>	delegate;
	NSUInteger					position,
								length;
	uint8_t						* bytes;				// may represent the entire JSON document or just a part of
	uint8_t						backUpByte;
	BOOL						complete,
								useBackUpByte;
	struct
	{
		int							strictJSONOnly		: 1;
	}							options;
	NSInputStream				* inputStream;
	NSData						* inputData;
	struct NDBytesBuffer		containers;
	struct
	{
		IMP						didStartDocument,
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
	}							delegateMethod;
}

- (void)setUpRespondsTo;

@end

@implementation NDJSON

@synthesize		delegate;

#pragma mark - manually implemented properties

- (void)setDelegate:(id<NDJSONDelegate>)aDelegate
{
	delegate = aDelegate;
	[self setUpRespondsTo];
}

#pragma mark - creation and destruction etc

- (id)init { return [self initWithDelegate:nil]; }

- (id)initWithDelegate:(id<NDJSONDelegate>)aDelegate
{
	if( (self = [super init]) != nil )
	{
		delegate = aDelegate;
		[self setUpRespondsTo];
	}

	return self;
}

#pragma mark - parsing methods

- (BOOL)parseJSONString:(NSString *)aString options:(NDJSONOptionFlags)anOptions error:(NSError **)anError { return [self setJSONString:aString error:anError] && [self parseWithOptions:anOptions]; }
- (BOOL)parseJSONData:(NSData *)aData options:(NDJSONOptionFlags)anOptions error:(NSError **)anError { return [self setJSONData:aData error:anError] && [self parseWithOptions:anOptions]; }
- (BOOL)parseContentsOfFile:(NSString *)aPath options:(NDJSONOptionFlags)anOptions error:(NSError **)anError { return [self setContentsOfFile:aPath error:anError] && [self parseWithOptions:anOptions]; }
- (BOOL)parseContentsOfURL:(NSURL *)aURL options:(NDJSONOptionFlags)anOptions error:(NSError **)anError { return [self setContentsOfURL:aURL error:anError] && [self parseWithOptions:anOptions]; }
- (BOOL)parseURLRequest:(NSURLRequest *)aURLRequest options:(NDJSONOptionFlags)anOptions error:(NSError **)anError { return [self setURLRequest:aURLRequest error:anError] && [self parseWithOptions:anOptions]; }
- (BOOL)parseInputStream:(NSInputStream *)aStream options:(NDJSONOptionFlags)anOptions error:(NSError **)anError { return [self setInputStream:aStream error:anError] && [self parseWithOptions:anOptions]; }

- (BOOL)setJSONString:(NSString *)aString error:(__autoreleasing NSError **)anError
{
	NSAssert( aString != nil, @"nil input JSON string" );
	return [self setJSONData:[aString dataUsingEncoding:NSUTF8StringEncoding] error:anError];
}

- (BOOL)setJSONData:(NSData *)aData error:(__autoreleasing NSError **)anError
{
	NSAssert( aData != nil, @"nil input JSON data" );
	position = 0;
	length = aData.length;
	bytes = (uint8_t*)[aData bytes];
	complete = NO;
	useBackUpByte = NO;
	inputStream = NULL;
	inputData = [aData retain];
	return bytes != NULL;
}

- (BOOL)setContentsOfFile:(NSString *)aPath error:(__autoreleasing NSError **)anError
{
	BOOL			theResult = NO;
	NSAssert( aPath != nil, @"nil input JSON path" );
	NSInputStream		* theInputStream = [NSInputStream inputStreamWithFileAtPath:aPath];
	if( theInputStream != nil )
		theResult = [self setInputStream:theInputStream error:anError];
	return theResult;
}

- (BOOL)setContentsOfURL:(NSURL *)aURL error:(__autoreleasing NSError **)anError
{
	BOOL			theResult = NO;
	NSAssert( aURL != nil, @"nil input JSON file url" );
	NSInputStream		* theInputStream = [NSInputStream inputStreamWithURL:aURL];
	if( theInputStream != nil )
		theResult = [self setInputStream:theInputStream error:anError];
	return theResult;
}

- (BOOL)setURLRequest:(NSURLRequest *)aURLRequest error:(__autoreleasing NSError **)anError
{
	BOOL			theResult = NO;
	CFHTTPMessageRef	theMessageRef = CFHTTPMessageCreateRequest( kCFAllocatorDefault, (CFStringRef)aURLRequest.HTTPMethod, (CFURLRef)aURLRequest.URL, kCFHTTPVersion1_1 );
	if ( theMessageRef != NULL )
	{
		CFReadStreamRef		theReadStreamRef = CFReadStreamCreateForHTTPRequest( kCFAllocatorDefault, theMessageRef );
		theResult = [self setInputStream:(NSInputStream*)theReadStreamRef error:anError];
		CFRelease(theReadStreamRef);
		CFRelease(theMessageRef);
	}
	return theResult;
}

- (BOOL)setInputStream:(NSInputStream *)aStream error:(__autoreleasing NSError **)anError
{
	NSAssert( aStream != nil, @"nil input stream" );
	position = 0;
	length = 0;
	bytes = malloc(kBufferSize);
	complete = NO;
	useBackUpByte = NO;
	inputStream = [aStream retain];
	inputData = nil;
	return inputStream != NULL && bytes != NULL;
}

- (BOOL)parseWithOptions:(NDJSONOptionFlags)anOptions
{
	BOOL		theResult = NO;
	if( inputStream != nil || bytes != NULL )
	{
		options.strictJSONOnly = NO;
		containers = NDBytesBufferInit;
		appendByte(&containers, NDJSONContainerNone);
		if( delegateMethod.didStartDocument != NULL )
			delegateMethod.didStartDocument( delegate, @selector(jsonParserDidStartDocument:), self );
		[inputStream open];
		theResult = parseUnknown( self );
		[inputStream close];
		if( !complete && theResult )
			foundError( self, NDJSONTrailingGarbageError );
		
		if( delegateMethod.didEndDocument != NULL )
			delegateMethod.didEndDocument( delegate, @selector(jsonParserDidEndDocument:), self );

		freeByte(&containers);
	}
	[inputStream release], inputStream = nil;
	[inputData release], inputData = nil;
	return theResult;
}

/*
 do this once so we don't waste time sending the same message to get the same answer
 Could ad code to look up the IMPs for the messages, and the use NULL values for them to determine whether to send the call
 */
- (void)setUpRespondsTo
{
	NSObject		* theDelegate = self.delegate;
	delegateMethod.didStartDocument = [theDelegate respondsToSelector:@selector(jsonParserDidStartDocument:)]
										? [theDelegate methodForSelector:@selector(jsonParserDidStartDocument:)]
										: NULL;
	delegateMethod.didEndDocument = [theDelegate respondsToSelector:@selector(jsonParserDidEndDocument:)]
										? [theDelegate methodForSelector:@selector(jsonParserDidEndDocument:)]
										: NULL;
	delegateMethod.didStartArray = [theDelegate respondsToSelector:@selector(jsonParserDidStartArray:)]
										? [theDelegate methodForSelector:@selector(jsonParserDidStartArray:)]
										: NULL;
	delegateMethod.didEndArray = [theDelegate respondsToSelector:@selector(jsonParserDidEndArray:)]
										? [theDelegate methodForSelector:@selector(jsonParserDidEndArray:)]
										: NULL;
	delegateMethod.didStartObject = [theDelegate respondsToSelector:@selector(jsonParserDidStartObject:)]
										? [theDelegate methodForSelector:@selector(jsonParserDidStartObject:)]
										: NULL;
	delegateMethod.didEndObject = [theDelegate respondsToSelector:@selector(jsonParserDidEndObject:)]
										? [theDelegate methodForSelector:@selector(jsonParserDidEndObject:)]
										: NULL;
	delegateMethod.shouldSkipValueForCurrentKey = [theDelegate respondsToSelector:@selector(jsonParserShouldSkipValueForCurrentKey:)]
										? [theDelegate methodForSelector:@selector(jsonParserShouldSkipValueForCurrentKey:)]
										: NULL;
	delegateMethod.foundKey = [theDelegate respondsToSelector:@selector(jsonParser:foundKey:)]
										? [theDelegate methodForSelector:@selector(jsonParser:foundKey:)]
										: NULL;
	delegateMethod.foundString = [theDelegate respondsToSelector:@selector(jsonParser:foundString:)]
										? [theDelegate methodForSelector:@selector(jsonParser:foundString:)]
										: NULL;
	delegateMethod.foundInteger = [theDelegate respondsToSelector:@selector(jsonParser:foundInteger:)]
										? [theDelegate methodForSelector:@selector(jsonParser:foundInteger:)]
										: NULL;
	delegateMethod.foundFloat = [theDelegate respondsToSelector:@selector(jsonParser:foundFloat:)]
										? [theDelegate methodForSelector:@selector(jsonParser:foundFloat:)]
										: NULL;
	delegateMethod.foundBool = [theDelegate respondsToSelector:@selector(jsonParser:foundBool:)]
										? [theDelegate methodForSelector:@selector(jsonParser:foundBool:)]
										: NULL;
	delegateMethod.foundNULL = [theDelegate respondsToSelector:@selector(jsonParserFoundNULL:)]
										? [theDelegate methodForSelector:@selector(jsonParserFoundNULL:)]
										: NULL;
	delegateMethod.foundError = [theDelegate respondsToSelector:@selector(jsonParser:error:)]
										? [theDelegate methodForSelector:@selector(jsonParser:error:)]
										: NULL;
}

static uint32_t integerForHexidecimalDigit( uint8_t d )
{
	uint32_t	r = -1;
	switch (d)
	{
	case '0'...'9':
		r = d-'0';
		break;
	case 'a'...'f':
		r = d-'a'+10;
		break;
	case 'A'...'F':
		r = d-'A'+10;
		break;
	}
	return r;
}

static uint8_t currentChar( NDJSON * self )
{
	uint8_t	theResult = '\0';
	if( self->position >= self->length )
	{
		if( self->inputStream != nil && (self->length = [self->inputStream read:self->bytes maxLength:kBufferSize]) > 0 )
			self->position = 0;
		else
			self->complete = YES;
	}
	
	if( !self->complete )
		theResult = self->bytes[self->position];
	return theResult;
}

static uint8_t nextChar( NDJSON * self )
{
	if( !self->useBackUpByte )
	{
		self->backUpByte = currentChar( self );
		if( self->backUpByte != '\0' )
			self->position++;
#ifdef NDJSONPrintStream
		putc(self->backUpByte, stderr);
#endif
	}
	else
		self->useBackUpByte = NO;
	return self->backUpByte;
}

static uint8_t nextCharIgnoreWhiteSpace( NDJSON * self )
{
	uint8_t		theResult;
	do
		theResult = nextChar( self );
	while( isspace(theResult) );
	return theResult;
}

static uint8_t skipWhiteSpace( NDJSON * self )
{
	BOOL		theEnd = NO;
	uint8_t		theResult;
	do
	{
		theResult = currentChar( self );
		if( isspace(theResult) && theResult != '\0' )
			self->position++;
		else
			theEnd = YES;
	}
	while( !theEnd );
	return theResult;
}

static void backUp( NDJSON * self ) { self->useBackUpByte = YES; }

BOOL parseUnknown( NDJSON * self )
{
	BOOL		theResult = YES;
	uint8_t		theChar = nextCharIgnoreWhiteSpace( self );
	switch (theChar)
	{
	case '{':
		theResult = parseObject( self );
		break;
	case '[':
		theResult = parseArray( self );
		break;
	case '"':
		theResult = parseString( self );
		break;
	case '0' ... '9':
	case '-':
		backUp(self);
		theResult = parseNumber( self );
		break;
	case 't':
		theResult = parseTrue( self );
		break;
	case 'f':
		theResult = parseFalse( self );
		break;
	case 'n':
		theResult = parseNull( self );
		break;
	default:
		foundError(self, NDJSONBadFormatError );
		theResult = NO;
		break;
	}
	
	if( theResult )
		skipWhiteSpace(self);
	return theResult;
}

BOOL parseArray( NDJSON * self )
{
	BOOL				theResult = YES;
	BOOL				theEnd = NO;
	NSUInteger			theCount = 0;
	appendByte(&self->containers, NDJSONContainerArray);
	if( self->delegateMethod.didStartArray != NULL )
		self->delegateMethod.didStartArray( self->delegate, @selector(jsonParserDidStartArray:), self );
	
	if( nextCharIgnoreWhiteSpace(self) == ']' )
		theEnd = YES;
	else
		backUp(self);
	
	while( !theEnd && (theResult = parseUnknown( self )) == YES )
	{
		uint8_t		theChar = nextCharIgnoreWhiteSpace(self);
		theCount++;
		switch( theChar )
		{
		case ']':
			theEnd = YES;
			break;
		case ',':
			if( !self->options.strictJSONOnly )		// allow trailing comma
			{
				if( nextCharIgnoreWhiteSpace(self) == ']' )
					theEnd = YES;
				else
					backUp(self);
			}
			break;
		default:
			foundError( self, NDJSONBadFormatError );
			backUp(self);
			goto erorOut;
			break;
		}
	}
	if( theEnd )
	{
		NSCParameterAssert(truncateByte(&self->containers, NDJSONContainerArray));
		if( self->delegateMethod.didEndArray != NULL )
			self->delegateMethod.didEndArray( self->delegate, @selector(jsonParserDidEndArray:), self );
	}
erorOut:
	return theResult;
}

BOOL parseObject( NDJSON * self )
{
	BOOL				theResult = YES;
	BOOL				theEnd = NO;
	NSUInteger			theCount = 0;
	
	appendByte( &self->containers, NDJSONContainerObject );
	if( self->delegateMethod.didStartObject != NULL )
		self->delegateMethod.didStartObject( self->delegate, @selector(jsonParserDidStartObject:), self );
	
	if( nextCharIgnoreWhiteSpace(self) == '}' )
		theEnd = YES;
	else
		backUp(self);
	
	while( !theEnd )
	{
		if( (theResult = parseKey(self)) )
		{
			BOOL				theSkipParsingValue = NO;
			if( self->delegateMethod.shouldSkipValueForCurrentKey != NULL )
				theSkipParsingValue = ((returnBoolMethodIMP)self->delegateMethod.shouldSkipValueForCurrentKey)( self->delegate, @selector(jsonParserShouldSkipValueForCurrentKey:), self );
			
			if( (nextCharIgnoreWhiteSpace(self) == ':') == YES )
			{
				if( theSkipParsingValue )
					theResult = skipNextValue( self );
				else 
					theResult = parseUnknown( self );
				
				if( theResult == YES )
				{
					uint8_t		theChar = nextCharIgnoreWhiteSpace(self);
					theCount++;
					switch( theChar )
					{
					case '\0':
					case '}':
						theEnd = YES;
						break;
					case ',':
						break;
					default:
						foundError( self, NDJSONBadFormatError );
						break;
					}
				}
				else
					foundError( self, NDJSONBadFormatError );
			}
			else
				foundError( self, NDJSONBadFormatError );
		}
		else
			foundError( self, NDJSONBadFormatError );
	}
	if( theEnd )
	{
		if( self->delegateMethod.didEndObject != NULL )
			self->delegateMethod.didEndObject( self->delegate, @selector(jsonParserDidEndObject:), self );
		NSCParameterAssert(truncateByte(&self->containers, NDJSONContainerObject));
	}
	
	return theResult;
}

BOOL parseKey( NDJSON * self )
{
	BOOL			theResult = YES;
	if( nextCharIgnoreWhiteSpace(self) == '"' )
		theResult = parseText( self, YES, YES );
	else if( !self->options.strictJSONOnly )				// keys don't have to be quoted
	{
		backUp(self);
		theResult = parseText( self, YES, NO );
	}
	else
		foundError( self, NDJSONBadFormatError );
	return theResult;
}

BOOL parseString( NDJSON * self ) { return parseText( self, NO, YES ); }

BOOL parseText( NDJSON * self, BOOL aIsKey, BOOL aIsQuotesTerminated )
{
	BOOL					theResult = YES,
							theEnd = NO;
	struct NDBytesBuffer	theBuffer = NDBytesBufferInit;
	
	while( theResult  && !theEnd)
	{
		uint8_t		theChar = nextChar(self);
		switch( theChar )
		{
		case '\0':
			theResult = NO;
			break;
		case '\\':
		{
			theChar = nextChar(self);
			switch( theChar )
			{
			case '\0':
				theResult = NO;
				break;
			case '"':
			case '\\':
				if( !appendByte( &theBuffer, theChar ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case '/':
				if( !appendByte( &theBuffer, theChar ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case 'b':
				if( !appendByte( &theBuffer, '\b' ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case 'f':
				if( !appendByte( &theBuffer, '\b' ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case 'n':
				if( !appendByte( &theBuffer, '\n' ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case 'r':
				if( !appendByte( &theBuffer, '\r' ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case 't':
				if( !appendByte( &theBuffer, '\t' ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case 'u':
			{
				uint32_t			theCharacterValue = 0;
				for( int i = 0; i < 4; i++ )
				{
					uint8_t		theChar = nextChar(self);
					if( theChar == 0 )
						break;
					int			theDigitValue = integerForHexidecimalDigit( theChar );
					if( theDigitValue >= 0 )
						theCharacterValue = (theCharacterValue << 4) + integerForHexidecimalDigit( theChar );
					else
						break;
				}
				if( !appendCharacter( &theBuffer, theCharacterValue) )
					foundError( self, NDJSONMemoryErrorError );
			}
				break;
			default:
				foundError( self, NDJSONBadEscapeSequenceError );
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
				backUp(self);
			}
			else if( !appendByte( &theBuffer, theChar ) )
				foundError( self, NDJSONMemoryErrorError );
			break;
		}
	}
	if( theEnd )
	{
		NSString	* theValue = [[NSString alloc] initWithBytes:theBuffer.bytes length:theBuffer.length encoding:NSUTF8StringEncoding];
		if( aIsKey )
		{
			NDJSONLog( @"Found key: '%@'", theValue );
			if( self->delegateMethod.foundKey != NULL )
				self->delegateMethod.foundKey( self->delegate, @selector(jsonParser:foundKey:), self, theValue );
		}
		else
		{
			if( self->delegateMethod.foundString != NULL )
				self->delegateMethod.foundString( self->delegate, @selector(jsonParser:foundString:), self, theValue );
		}
		[theValue release];
	}
	else
		foundError( self, NDJSONBadFormatError );
	freeByte( &theBuffer );
	return theResult;
}

BOOL parseNumber( NDJSON * self )
{
	BOOL			theNegative = NO;
	BOOL			theEnd = NO,
	theResult = YES;
	long long		theIntegerValue = 0,
	theDecimalValue = 0,
	theExponentValue = 0;
	int				theDecimalPlaces = 1;
	
	if( nextChar(self) == '-' )
		theNegative = YES;
	else
		backUp(self);
	
	while( !theEnd && theResult )
	{
		uint8_t		theChar = nextChar(self);
		switch( theChar )
		{
		case '\0':
			theEnd = YES;
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
			theChar = nextChar(self);
			if( theChar == '+' || theChar == '-' )
				theExponentNegative = (theChar == '-');
			else if( theChar >= '0' && theChar <= '9' )
				theExponentValue = (theChar - '0');
			else
			{
				theEnd = YES;
				foundError( self, NDJSONBadNumberError );
			}
			
			while( !theEnd && theResult )
			{
				theChar = nextChar(self);
				switch( theChar )
				{
//				case '\0':
//					theEnd = YES;
//					break;
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
		double	theValue = ((double)theIntegerValue) + ((double)theDecimalValue)*pow(10.0,theDecimalPlaces);
		if( theExponentValue != 0 )
			theValue *= pow(10,theExponentValue);
		if( theNegative )
			theValue = -theValue;
		if( self->delegateMethod.foundFloat != NULL )
			self->delegateMethod.foundFloat( self->delegate, @selector(jsonParser:foundFloat:), self, theValue );
	}
	else if( theDecimalPlaces > 0 )
	{
		if( theNegative )
			theIntegerValue = -theIntegerValue;
		if( self->delegateMethod.foundInteger != NULL )
			self->delegateMethod.foundInteger( self->delegate, @selector(jsonParser:foundInteger:), self, theIntegerValue );
	}
	else
		foundError(self, NDJSONBadNumberError );
	
	if( theResult )
		backUp( self );
	return theResult;
}

BOOL parseTrue( NDJSON * self )
{
	BOOL		theResult = YES;
	uint8_t		theChar;
	if( (theChar = nextChar(self)) == 'r' && (theChar = nextChar(self)) == 'u' && (theChar = nextChar(self)) == 'e' )
	{
		if( self->delegateMethod.foundBool != NULL )
			self->delegateMethod.foundBool( self->delegate, @selector(jsonParser:foundBool:), self, YES );
	}
	else if( theChar == '\0' )
		theResult = NO;
	else
		foundError( self, NDJSONBadTokenError );
	return theResult;
}

BOOL parseFalse( NDJSON * self )
{
	BOOL		theResult = YES;
	uint8_t		theChar;
	if( (theChar = nextChar(self)) == 'a' && (theChar = nextChar(self)) == 'l' && (theChar = nextChar(self)) == 's' && (theChar = nextChar(self)) == 'e' )
	{
		if( self->delegateMethod.foundBool != NULL )
			self->delegateMethod.foundBool( self->delegate, @selector(jsonParser:foundBool:), self, NO );
	}
	else if( theChar == '\0' )
		theResult = NO;
	else
		foundError( self, NDJSONBadTokenError );
	return theResult;
}

BOOL parseNull( NDJSON * self )
{
	BOOL		theResult = YES;
	uint8_t		theChar;
	if( (theChar = nextChar(self)) == 'u' && (theChar = nextChar(self)) == 'l' && (theChar = nextChar(self)) == 'l' )
	{
		if( self->delegateMethod.foundNULL != NULL )
			self->delegateMethod.foundNULL( self->delegate, @selector(jsonParserFoundNULL:), self );
	}
	else if( theChar == '\0' )
		theResult = NO;
	else
		foundError( self, NDJSONBadTokenError );
	return theResult;
}

BOOL skipNextValue( NDJSON * self )
{
	NSUInteger		theBracesDepth = 0,
	theBracketsDepth = 0;
	BOOL			theInQuotes = NO;
	BOOL			theEnd = NO;
	uint8_t			theChar = '\n';
	
	while( !theEnd )
	{
		switch( (theChar = nextCharIgnoreWhiteSpace( self )) )
		{
		case '{':
			theBracesDepth++;
			break;
		case '}':
			if( theBracesDepth > 0 )
				theBracesDepth--;
			else
			{
				backUp(self);
				theEnd = YES;
			}
			break;
		case '[':
			theBracketsDepth++;
			break;
		case ']':
			if( theBracketsDepth > 0 )
				theBracketsDepth--;
			else
			{
				backUp(self);
				theEnd = YES;
			}
			break;
		case ',':
			if( theBracesDepth == 0 && theBracketsDepth == 0 )
			{
				backUp(self);
				theEnd = YES;
			}
			break;
		case '\0':
			theEnd = YES;
			break;
		case '"':
			while( (theChar = nextCharIgnoreWhiteSpace( self )) != '"' )
			{
				if( theChar == '\\' )
					theChar = nextChar(self);
			}
			break;
		default:
			break;
		}
	}
	
	return theChar != '\0' && theBracesDepth == 0 && theBracketsDepth == 0 && theInQuotes == NO;
}

void foundError( NDJSON * self, NDJSONErrorCode aCode )
{
	NSMutableDictionary		* theUserInfo = [[NSMutableDictionary alloc] initWithObjectsAndKeys:kErrorCodeStrings[aCode],NSLocalizedDescriptionKey, nil];
	NSUInteger				thePos = self->position > 5 ? self->position - 5 : 5,
	theLen = self->length - thePos < 10 ? self->length - thePos : 10;
	NSString				* theString = nil;
	switch (aCode)
	{
	default:
	case NDJSONGeneralError:
		break;
	case NDJSONBadTokenError:
	{
		theString = [[NSString alloc] initWithFormat:@"Bad token at pos %lu, %*s", self->position, (int)theLen, self->bytes];
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
	if( self->delegateMethod.foundError != NULL )
		self->delegateMethod.foundError( self->delegate, @selector(jsonParser:error:), self, [NSError errorWithDomain:NDJSONErrorDomain code:aCode userInfo:theUserInfo] );
	[theUserInfo release];
}

@end

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

BOOL appendCharacter( struct NDBytesBuffer * aBuffer, uint32_t aValue )
{
	if( aValue > 0x3ffffff )				// 1111110x	10xxxxxx	10xxxxxx	10xxxxxx	10xxxxxx	10xxxxxx
	{
		if( !appendByte( aBuffer, ((aValue>>31) & 0xf) | 0xfc ) )
			return NO;
		if( !appendByte( aBuffer, ((aValue>>30) & 0x3f) | 0x80 ) )
			return NO;
		if( !appendByte( aBuffer, ((aValue>>24) & 0x3f) | 0x80 ) )
			return NO;
		if( !appendByte( aBuffer, ((aValue>>18) & 0x3f) | 0x80 ) )
			return NO;
		if( !appendByte( aBuffer, ((aValue>>12) & 0x3f) | 0x80 ) )
			return NO;
		if( !appendByte( aBuffer, ((aValue>>6) & 0x3f) | 0x80 ) )
			return NO;
	}
	else if( aValue > 0x1fffff )			// 111110xx	10xxxxxx	10xxxxxx	10xxxxxx	10xxxxxx
	{
		if( !appendByte( aBuffer, ((aValue>>24) & 0x3f) | 0x80 ) )
			return NO;
		if( !appendByte( aBuffer, ((aValue>>18) & 0x3f) | 0x80 ) )
			return NO;
		if( !appendByte( aBuffer, ((aValue>>12) & 0x3f) | 0x80 ) )
			return NO;
		if( !appendByte( aBuffer, ((aValue>>6) & 0x3f) | 0x80 ) )
			return NO;
	}
	else if( aValue > 0xffff )				// 11110xxx	10xxxxxx	10xxxxxx	10xxxxxx
	{
		if( !appendByte( aBuffer, ((aValue>>18) & 0x3f) | 0x80 ) )
			return NO;
		if( !appendByte( aBuffer, ((aValue>>12) & 0x3f) | 0x80 ) )
			return NO;
		if( !appendByte( aBuffer, ((aValue>>6) & 0x3f) | 0x80 ) )
			return NO;
	}
	else if( aValue > 0x7ff )				// 1110xxxx	10xxxxxx	10xxxxxx
	{
		if( !appendByte( aBuffer, ((aValue>>12) & 0xf) | 0xE0 ) )
			return NO;
		if( !appendByte( aBuffer, ((aValue>>6) & 0x3f) | 0x80 ) )
			return NO;
		if( !appendByte( aBuffer, (aValue & 0x3f) | 0x80 ) )
			return NO;
	}
	else if( aValue > 0x7f )				// 110xxxxx	10xxxxxx
	{
		if( !appendByte( aBuffer, ((aValue>>6) & 0x1f) | 0xc0 ) )
			return NO;
		if( !appendByte( aBuffer, (aValue & 0x3f) | 0x80 ) )
			return NO;
	}
	else									// 0xxxxxxx
	{
		if( !appendByte( aBuffer, aValue & 0x7f ) )
			return NO;
	}
	return YES;
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

/*
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
*/

void freeByte( struct NDBytesBuffer * aBuffer )
{
	free(aBuffer->bytes);
	aBuffer->bytes = NULL;
	aBuffer->length = 0;
	aBuffer->capacity = 0;
}


