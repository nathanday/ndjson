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

//#define NDJSONSupportUTF8Only

#ifdef NDJSONDebug
#define NDJSONLog(...) NSLog(__VA_ARGS__)
#else
#define NDJSONLog(...)
#endif

#ifndef NDJSONSupportUTF8Only
static uint16_t		k16BitLittleEndianBOM = 0xFEFF,
					k16BitBigEndianBOM = 0xFFFE;
static uint32_t		k32BitLittleEndianBOM = 0x0000FEFF,
					k32BitBigEndianBOM = 0xFFFE0000;
#endif

@protocol NDJSONDelegate;

static NSString		* const kContentTypeHTTPHeaderKey = @"Content-Type";

struct NDBytesBuffer
{
	uint8_t			* bytes;
	NSUInteger		length,
					capacity;
};

typedef BOOL (*_ReturnBoolMethodIMP)( id, SEL, id, ...);

static const size_t		kBufferSize = 2048;

NSString	* const NDJSONErrorDomain = @"NDJSONError";

static const struct NDBytesBuffer	NDBytesBufferInit = {NULL,0,0};
static BOOL extendsBytesOfLen( struct NDBytesBuffer * aBuffer, NSUInteger aLen );
static BOOL appendByte( struct NDBytesBuffer * aBuffer, uint32_t aBytes );
static BOOL appendCharacter( struct NDBytesBuffer * aBuffer, unsigned int aValue );
static BOOL truncateByte( struct NDBytesBuffer * aBuffer, uint32_t aBytes );
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

static BOOL parseInputData( NDJSON * self );
static BOOL parseInputStream( NDJSON * self );
static BOOL parseInputString( NDJSON * self );
static BOOL parseURLRequest( NDJSON * self );

static BOOL parseJSONUnknown( NDJSON * self );
static BOOL parseJSONObject( NDJSON * self );
static BOOL parseJSONArray( NDJSON * self );
static BOOL parseJSONKey( NDJSON * self );
static BOOL parseJSONString( NDJSON * self );
static BOOL parseJSONText( NDJSON * self, struct NDBytesBuffer * valueBuffer, BOOL aIsKey, BOOL aIsQuotesTerminated );
static BOOL parseJSONNumber( NDJSON * self );
static BOOL parseJSONTrue( NDJSON * self );
static BOOL parseJSONFalse( NDJSON * self );
static BOOL parseJSONNull( NDJSON * self );
static BOOL skipNextValue( NDJSON * self );
static void foundError( NDJSON * self, NDJSONErrorCode aCode );

enum CharacterWordSize
{
	kCharacterWord8 = 0,			// the values for these enums is important
	kCharacterWord16 = 1,
	kCharacterWord32 = 2
};

enum CharacterEndian
{
	kUnknownEndian,
	kLittleEndian,
	kBigEndian
};

static BOOL getCharacterWordSizeAndEndianFromNSStringEncoding( enum CharacterWordSize * aWordSize, enum CharacterEndian * anEndian, NSStringEncoding anEncoding )
{
	BOOL		theResult = YES;
	NSCParameterAssert( aWordSize != NULL );
	NSCParameterAssert( anEndian != NULL );
	switch( anEncoding )
	{
	case NSASCIIStringEncoding:
	case NSNEXTSTEPStringEncoding:
	case NSJapaneseEUCStringEncoding:
	case NSUTF8StringEncoding:
	case NSISOLatin1StringEncoding:
	case NSSymbolStringEncoding:
	case NSNonLossyASCIIStringEncoding:
	case NSShiftJISStringEncoding:
	case NSISOLatin2StringEncoding:
	case NSMacOSRomanStringEncoding:
	case NSWindowsCP1251StringEncoding:
	case NSWindowsCP1252StringEncoding:
	case NSWindowsCP1253StringEncoding:
	case NSWindowsCP1254StringEncoding:
	case NSWindowsCP1250StringEncoding:
	case NSISO2022JPStringEncoding:
		*aWordSize = kCharacterWord8;
		*anEndian = kLittleEndian;	
		break;
//	case NSUnicodeStringEncoding:
	case NSUTF16StringEncoding:
		*aWordSize = kCharacterWord16;
		*anEndian = kUnknownEndian;
		break;
	case NSUTF16BigEndianStringEncoding:
		*aWordSize = kCharacterWord16;
		*anEndian = kBigEndian;	
		break;
	case NSUTF16LittleEndianStringEncoding:
		*aWordSize = kCharacterWord16;
		*anEndian = kLittleEndian;	
		break;
	case NSUTF32StringEncoding:
		*aWordSize = kCharacterWord32;
		*anEndian = kUnknownEndian;
		break;
	case NSUTF32BigEndianStringEncoding:
		*aWordSize = kCharacterWord32;
		*anEndian = kBigEndian;	
		break;
	case NSUTF32LittleEndianStringEncoding:
		*aWordSize = kCharacterWord32;
		*anEndian = kLittleEndian;	
		break;
	}
	return theResult;
}

static NSStringEncoding stringEncodingFromHTTPContentTypeString( CFStringRef aContentType )
{
	NSStringEncoding		theResult = NSUTF8StringEncoding;
	if( CFStringHasPrefix( aContentType, CFSTR("text/") ) || CFStringHasPrefix( aContentType, CFSTR("application/json") ) )
	{
		CFRange		theCharSetRange = CFStringFind( aContentType, CFSTR("charset="), 0 );
		if( theCharSetRange.location != NSNotFound )
		{
			CFRange					theEncodingStringRange = CFRangeMake( theCharSetRange.location+theCharSetRange.length,
																			CFStringGetLength(aContentType)-theCharSetRange.location-theCharSetRange.length );
			CFStringRef				theEncodingString = CFStringCreateWithSubstring( kCFAllocatorDefault, aContentType, theEncodingStringRange );
			CFStringEncoding		theEncoding = CFStringConvertIANACharSetNameToEncoding ( theEncodingString );
			CFRelease(theEncodingString);
			theResult = CFStringConvertEncodingToNSStringEncoding(theEncoding);
		}
		else
			NSLog( @"Unable to find 'charset=' in HTTP Content Type string" );
	}
	else
		NSLog( @"HTTP Content Type unknown" );
	return theResult;
}

enum JSONInputType
{
	kJSONNoInputType,
	kJSONDataInputType,
	kJSONStringInputType,
	kJSONStreamInputType,
	kJSONURLRequestType
};

@interface NDJSON ()
{
	__weak id<NDJSONDelegate>	delegate;
	NSUInteger					position,
								numberOfBytes;
	uint8_t						* bytes;				// may represent the entire JSON document or just a part of
#ifndef NDJSONSupportUTF8Only
	enum CharacterWordSize		characterWordSize;
	enum CharacterEndian		characterEndian;
#endif
	uint32_t					backUpByte;
	BOOL						complete,
								useBackUpByte;
	struct
	{
		int							strictJSONOnly		: 1;
		int							zipJSON				: 1;
	}							options;
	enum JSONInputType			inputType;
	NSInputStream				* inputStream;
	id							sourceObject;
	struct NDBytesBuffer		containers;
	NSString					* lastKey;
	struct
	{
		IMP						didStartDocument,
									didEndDocument,
									didStartArray,
									didEndArray,
									didStartObject,
									didEndObject,
									shouldSkipValueForKey,
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
- (BOOL)parseWithOptions:(NDJSONOptionFlags)options;

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

- (BOOL)parseJSONString:(NSString *)aString options:(NDJSONOptionFlags)anOptions error:(NSError **)anError { return [self setJSONData:[aString dataUsingEncoding:NSUTF8StringEncoding] encoding:NSUTF8StringEncoding error:anError] && [self parseWithOptions:anOptions]; }
- (BOOL)parseJSONData:(NSData *)aData options:(NDJSONOptionFlags)anOptions error:(NSError **)anError { return [self setJSONData:aData encoding:NSUTF8StringEncoding error:anError] && [self parseWithOptions:anOptions]; }
- (BOOL)parseContentsOfFile:(NSString *)aPath encoding:(NSStringEncoding)anEncoding options:(NDJSONOptionFlags)anOptions error:(NSError **)anError { return [self setContentsOfFile:aPath encoding:anEncoding error:anError] && [self parseWithOptions:anOptions]; }
- (BOOL)parseContentsOfURL:(NSURL *)aURL encoding:(NSStringEncoding)anEncoding options:(NDJSONOptionFlags)anOptions error:(NSError **)anError { return [self setContentsOfURL:aURL encoding:anEncoding error:anError] && [self parseWithOptions:anOptions]; }
- (BOOL)parseURLRequest:(NSURLRequest *)aURLRequest options:(NDJSONOptionFlags)anOptions error:(NSError **)anError { return [self setURLRequest:aURLRequest error:anError] && [self parseWithOptions:anOptions]; }
- (BOOL)parseInputStream:(NSInputStream *)aStream encoding:(NSStringEncoding)anEncoding options:(NDJSONOptionFlags)anOptions error:(NSError **)anError { return [self setInputStream:aStream encoding:anEncoding error:anError] && [self parseWithOptions:anOptions]; }

- (BOOL)setJSONString:(NSString *)aString error:(__autoreleasing NSError **)anError
{
#ifdef NDJSONSupportUTF8Only
	return [self setJSONData:[aString dataUsingEncoding:NSUTF8StringEncoding] encoding:NSUTF8StringEncoding error:anError];
#else
	BOOL		theResult = NO;
	NSAssert( aString != nil, @"nil input JSON string" );
	CFStringEncoding		theStringEncoding = CFStringGetFastestEncoding( (CFStringRef)aString );
	
	position = 0;
	complete = NO;
	useBackUpByte = NO;
	inputStream = NULL;

	switch( theStringEncoding )
	{
		case kCFStringEncodingMacRoman:
		case kCFStringEncodingWindowsLatin1:
		case kCFStringEncodingISOLatin1:
		case kCFStringEncodingNextStepLatin:
		case kCFStringEncodingASCII:
		case kCFStringEncodingUTF8:
		case kCFStringEncodingNonLossyASCII:
			bytes = (uint8_t*)CFStringGetCStringPtr((CFStringRef)aString, theStringEncoding);
			numberOfBytes = aString.length;
			characterWordSize = kCharacterWord8;
			characterEndian = kLittleEndian;
			break;
		case kCFStringEncodingUnicode:
//		case kCFStringEncodingUTF16:
		case kCFStringEncodingUTF16LE:
		case kCFStringEncodingUTF16BE:
			bytes = (uint8_t*)CFStringGetCharactersPtr((CFStringRef)aString);
			numberOfBytes = aString.length<<1;
			characterWordSize = kCharacterWord16;
			characterEndian = kLittleEndian;
			break;
		case kCFStringEncodingUTF32:
		case kCFStringEncodingUTF32BE:
		case kCFStringEncodingUTF32LE:
			break;
	}

	if( bytes != NULL )
	{
		sourceObject = [aString retain];
		inputType = kJSONStringInputType;
		theResult = YES;
	}
	else						// failed to get poiter to string bytes, convert to quickest NSData and use that instead
	{
		NSStringEncoding		theEncoding = CFStringConvertEncodingToNSStringEncoding(theStringEncoding);
		theResult = [self setJSONData:[aString dataUsingEncoding:theEncoding] encoding:theEncoding error:anError];
	}
	return theResult;
#endif
}

- (BOOL)setJSONData:(NSData *)aData encoding:(NSStringEncoding)anEncoding error:(__autoreleasing NSError **)anError
{
	NSAssert( aData != nil, @"nil input JSON data" );
	position = 0;
	numberOfBytes = aData.length;
	bytes = (uint8_t*)[aData bytes];
	complete = NO;
	useBackUpByte = NO;
	inputStream = NULL;
	sourceObject = [aData retain];
	inputType = kJSONDataInputType;
#ifdef NDJSONSupportUTF8Only
	NSAssert( anEncoding <= NSMacOSRomanStringEncoding && anEncoding != NSUnicodeStringEncoding, @"with NDJSONSupportUTF8Only set only 8bit character encodings are supported" );
#else
	getCharacterWordSizeAndEndianFromNSStringEncoding( &characterWordSize, &characterEndian, anEncoding );
#endif
	return bytes != NULL;
}

- (BOOL)setContentsOfFile:(NSString *)aPath encoding:(NSStringEncoding)anEncoding error:(__autoreleasing NSError **)anError
{
	BOOL			theResult = NO;
	NSAssert( aPath != nil, @"nil input JSON path" );
	NSInputStream		* theInputStream = [NSInputStream inputStreamWithFileAtPath:aPath];
	if( theInputStream != nil )
		theResult = [self setInputStream:theInputStream encoding:anEncoding error:anError];
	return theResult;
}

- (BOOL)setContentsOfURL:(NSURL *)aURL encoding:(NSStringEncoding)anEncoding error:(__autoreleasing NSError **)anError
{
	BOOL			theResult = NO;
	NSAssert( aURL != nil, @"nil input JSON file url" );
	NSInputStream		* theInputStream = [NSInputStream inputStreamWithURL:aURL];
	if( theInputStream != nil )
		theResult = [self setInputStream:theInputStream encoding:anEncoding error:anError];
	return theResult;
}

- (BOOL)setURLRequest:(NSURLRequest *)aURLRequest error:(__autoreleasing NSError **)anError
{
	BOOL			theResult = NO;
	CFHTTPMessageRef	theMessageRef = CFHTTPMessageCreateRequest( kCFAllocatorDefault, (CFStringRef)aURLRequest.HTTPMethod, (CFURLRef)aURLRequest.URL, kCFHTTPVersion1_1 );
	inputType = kJSONStreamInputType;
	if ( theMessageRef != NULL )
	{
		CFReadStreamRef		theReadStreamRef = CFReadStreamCreateForHTTPRequest( kCFAllocatorDefault, theMessageRef );
		if( theReadStreamRef != NULL )
		{
			theResult = [self setInputStream:(NSInputStream*)theReadStreamRef encoding:NSUIntegerMax error:anError];
			CFRelease(theReadStreamRef);
		}
		CFRelease(theMessageRef);
	}
	return theResult;
}

- (BOOL)setInputStream:(NSInputStream *)aStream encoding:(NSStringEncoding)anEncoding error:(__autoreleasing NSError **)anError
{
	NSAssert( aStream != nil, @"nil input stream" );
	position = 0;
	numberOfBytes = 0;
	bytes = malloc(kBufferSize);
	complete = NO;
	useBackUpByte = NO;
	inputStream = [aStream retain];
	inputType = kJSONStreamInputType;
	sourceObject = nil;
#ifndef NDJSONSupportUTF8Only
	getCharacterWordSizeAndEndianFromNSStringEncoding( &characterWordSize, &characterEndian, anEncoding );
#endif
	return inputStream != NULL && bytes != NULL;
}

- (BOOL)parseWithOptions:(NDJSONOptionFlags)anOptions
{
	BOOL		theResult = NO;
	self->options.strictJSONOnly = NO;
	self->containers = NDBytesBufferInit;
	appendByte(&self->containers, NDJSONValueNone);
	if( self->delegateMethod.didStartDocument != NULL )
		self->delegateMethod.didStartDocument( self->delegate, @selector(jsonParserDidStartDocument:), self );

	switch( inputType )
	{
	case kJSONDataInputType:
	case kJSONStringInputType:
		theResult = parseInputData( self );
		break;
	case kJSONStreamInputType:
		theResult = parseInputStream( self );
		break;
	case kJSONURLRequestType:
		theResult = parseURLRequest( self );
		break;
	default:
		NSCAssert(NO, @"Input type not set" );
		break;
	}
	
	if( self->delegateMethod.didEndDocument != NULL )
		self->delegateMethod.didEndDocument( self->delegate, @selector(jsonParserDidEndDocument:), self );
	
	[self->lastKey release], self->lastKey = nil;
	freeByte(&self->containers);

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
	delegateMethod.shouldSkipValueForKey = [theDelegate respondsToSelector:@selector(jsonParser:shouldSkipValueForKey:)]
										? [theDelegate methodForSelector:@selector(jsonParser:shouldSkipValueForKey:)]
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

static uint32_t integerForHexidecimalDigit( uint32_t d )
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

static uint32_t currentChar( NDJSON * self )
{
	uint32_t	theResult = '\0';
#ifdef NDJSONSupportUTF8Only
	if( self->position >= self->numberOfBytes )
	{
#else
	if( self->position<<self->characterWordSize >= self->numberOfBytes )
	{
		/*
			if numberOfBytes was not a multiple of character word size then we need to copy the partial word
			to the begining of the buffer and append the next block onto the end, to comple the last character.
		 */
		NSUInteger		theRemainingLen = self->numberOfBytes&((1<<self->characterWordSize)-1);
		if( theRemainingLen > 0 )
			memcpy(self->bytes, self->bytes+self->numberOfBytes-theRemainingLen, theRemainingLen );
#endif
		switch (self->inputType)
		{
		case kJSONStreamInputType:
#ifdef NDJSONSupportUTF8Only
			if( (self->numberOfBytes = [self->inputStream read:self->bytes maxLength:kBufferSize]) > 0 )
#else
			if( (self->numberOfBytes = [self->inputStream read:self->bytes+theRemainingLen maxLength:kBufferSize-theRemainingLen]) > 0 )
#endif
				self->position = 0;
			else
				self->complete = YES;
			break;
		case kJSONURLRequestType:
			break;
		default:
			self->complete = YES;
			break;
		}
	}
	
	if( !self->complete )
	{
#ifdef NDJSONSupportUTF8Only
		theResult = ((uint8_t*)self->bytes)[self->position];
#else
		switch( self->characterWordSize )
		{
		case kCharacterWord8:
			theResult = ((uint8_t*)self->bytes)[self->position];
			break;
		case kCharacterWord16:
			theResult = ((uint16_t*)self->bytes)[self->position];
			if( self->position == 0 )
			{
				if( theResult == k16BitLittleEndianBOM )
				{
					self->characterEndian = kLittleEndian;
					theResult = ' ';
				}
				else if( theResult == k16BitBigEndianBOM )
				{
					self->characterEndian = kBigEndian;
					theResult = 0x2000;
				}
				else if( self->characterEndian == kUnknownEndian )
				{
					if( (theResult & 0xFF00) == 0 )			// first character is most likly < 256
						self->characterEndian = kLittleEndian;
					else if( (theResult & 0x00FF) == 0 )			// first character is most likly < 256
						self->characterEndian = kBigEndian;
					else
						self->characterEndian = kLittleEndian;
				}
			}
			if( self->characterEndian == kBigEndian )
				theResult = EndianU16_BtoN(theResult);
			else
				theResult = EndianU16_LtoN(theResult);
			break;
		case kCharacterWord32:
			theResult = ((uint32_t*)self->bytes)[self->position];
			if( self->position == 0 )
			{
				if( theResult == k32BitLittleEndianBOM )
				{
					self->characterEndian = kLittleEndian;
					theResult = ' ';
				}
				else if( theResult == k32BitBigEndianBOM )
				{
					self->characterEndian = kBigEndian;
					theResult = 0x20000000;
				}
				else if( self->characterEndian == kUnknownEndian )
				{
					if( (theResult & 0xFFFF0000) == 0 )			// first character is most likly < 65536
						self->characterEndian = kLittleEndian;
					else if( (theResult & 0x0000FFFF) == 0 )			// first character is most likly < 65536
						self->characterEndian = kBigEndian;
					else
						self->characterEndian = kLittleEndian;
				}
			}
			if( self->characterEndian == kBigEndian )
				theResult = EndianU32_BtoN(theResult);
			else
				theResult = EndianU32_LtoN(theResult);
			break;
		}
#endif
	}
	return theResult;
}

static uint32_t nextChar( NDJSON * self )
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

static uint32_t nextCharFollowingChar( NDJSON * self, uint32_t aChar )
{
	uint32_t		theResult;
	do
		theResult = nextChar( self );
	while( theResult != '\0' && theResult != aChar );
	
	if( theResult != '\0' )
		theResult = nextChar( self );
	return theResult;
}

static uint32_t nextCharIgnoreWhiteSpace( NDJSON * self )
{
	uint32_t		theResult;
	if( self->options.strictJSONOnly )				// skip white space only
	{
		do
			theResult = nextChar( self );
		while( isspace(theResult) );
	}
	else											// skip comments as well
	{
		do
		{
			theResult = nextChar( self );
			while( theResult == '/' )
			{
				if( currentChar(self) == '/' )		// single line comment
				{
					do
						theResult = nextChar( self );
					while( theResult != '\n' );
				}
				else if( currentChar(self) == '*' )		// multiline commentß
				{
					BOOL		theCommentEnd = NO;
					theResult = nextChar(self);
					while( !theCommentEnd )
					{
						if( theResult == '\0' )
							goto end;
						theResult = nextChar(self);
						if( theResult == '*' && (theResult = nextChar(self)) == '/' )
							theCommentEnd = YES;
					}
					theResult = nextChar(self);
				}
			}
		}
		while( isspace(theResult) );
	}
end:
	return theResult;
}

static void backUp( NDJSON * self ) { self->useBackUpByte = YES; }

BOOL parseInputData( NDJSON * self )
{
	BOOL		theResult = NO;
	NSCParameterAssert( self->bytes != NULL );
	NSCParameterAssert( self->sourceObject != nil );
	theResult = parseJSONUnknown( self );
	if( !self->complete && theResult )
		foundError( self, NDJSONTrailingGarbageError );
	[self->sourceObject release], self->sourceObject = nil;
	return theResult;
}

BOOL parseInputStream( NDJSON * self )
{
	BOOL		theResult = NO;
	NSCParameterAssert( self->inputStream != nil );
	[self->inputStream open];
	theResult = parseJSONUnknown( self );
	if( !self->complete && theResult )
		foundError( self, NDJSONTrailingGarbageError );	
	[self->inputStream close], [self->inputStream release], self->inputStream = nil;
	[self->sourceObject release], self->sourceObject = nil;
	return theResult;
}

BOOL parseURLRequest( NDJSON * self )
{
	BOOL		theResult = NO;
	if( self->inputStream != nil || self->bytes != NULL )
	{
		self->options.strictJSONOnly = NO;
		self->containers = NDBytesBufferInit;
		appendByte(&self->containers, NDJSONValueNone);
		if( self->delegateMethod.didStartDocument != NULL )
			self->delegateMethod.didStartDocument( self->delegate, @selector(jsonParserDidStartDocument:), self );
		if( self->inputStream != nil )
		{
			CFTypeRef theHttpHeaderMessage = NULL;
			[self->inputStream open];
			theHttpHeaderMessage = CFReadStreamCopyProperty( (CFReadStreamRef)self->inputStream, kCFStreamPropertyHTTPResponseHeader );
			if( theHttpHeaderMessage != NULL )
			{
				NSDictionary	* theHeaders = (NSDictionary*)CFHTTPMessageCopyAllHeaderFields(theHttpHeaderMessage);
				getCharacterWordSizeAndEndianFromNSStringEncoding( &self->characterWordSize, &self->characterEndian, stringEncodingFromHTTPContentTypeString( [theHeaders objectForKey:kContentTypeHTTPHeaderKey] ) );
				CFRelease(theHttpHeaderMessage);
			}
		}
		theResult = parseJSONUnknown( self );
		[self->inputStream close];
		if( !self->complete && theResult )
			foundError( self, NDJSONTrailingGarbageError );
		
		if( self->delegateMethod.didEndDocument != NULL )
			self->delegateMethod.didEndDocument( self->delegate, @selector(jsonParserDidEndDocument:), self );
		
		[self->lastKey release], self->lastKey = nil;
		freeByte(&self->containers);
	}
	[self->inputStream release], self->inputStream = nil;
	[self->sourceObject release], self->sourceObject = nil;
	return theResult;
}

BOOL parseJSONUnknown( NDJSON * self )
{
	BOOL		theResult = YES;
	uint32_t	theChar = nextCharIgnoreWhiteSpace( self );
	switch (theChar)
	{
	case '{':
		theResult = parseJSONObject( self );
		break;
	case '[':
		theResult = parseJSONArray( self );
		break;
	case '"':
		theResult = parseJSONString( self );
		break;
	case '0' ... '9':
	case '-':
		backUp(self);
		theResult = parseJSONNumber( self );
		break;
	case 't':
		theResult = parseJSONTrue( self );
		break;
	case 'f':
		theResult = parseJSONFalse( self );
		break;
	case 'n':
		theResult = parseJSONNull( self );
		break;
	default:
		foundError(self, NDJSONBadFormatError );
		theResult = NO;
		break;
	}
	
	return theResult;
}

BOOL parseJSONArray( NDJSON * self )
{
	BOOL				theResult = YES;
	BOOL				theEnd = NO;
	NSUInteger			theCount = 0;
	appendByte(&self->containers, NDJSONValueArray);
	if( self->delegateMethod.didStartArray != NULL )
		self->delegateMethod.didStartArray( self->delegate, @selector(jsonParserDidStartArray:), self );
	
	if( nextCharIgnoreWhiteSpace(self) == ']' )
		theEnd = YES;
	else
		backUp(self);
	
	while( !theEnd && (theResult = parseJSONUnknown( self )) == YES )
	{
		uint32_t		theChar = nextCharIgnoreWhiteSpace(self);
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
			goto errorOut;
			break;
		}
	}
	if( theEnd )
	{
		NSCParameterAssert(truncateByte(&self->containers, NDJSONValueArray));
		if( self->delegateMethod.didEndArray != NULL )
			self->delegateMethod.didEndArray( self->delegate, @selector(jsonParserDidEndArray:), self );
	}
errorOut:
	return theResult;
}

BOOL parseJSONObject( NDJSON * self )
{
	BOOL				theResult = YES;
	BOOL				theEnd = NO;
	NSUInteger			theCount = 0;
	
	appendByte( &self->containers, NDJSONValueObject );
	if( self->delegateMethod.didStartObject != NULL )
		self->delegateMethod.didStartObject( self->delegate, @selector(jsonParserDidStartObject:), self );
	
	if( nextCharIgnoreWhiteSpace(self) == '}' )
		theEnd = YES;
	else
		backUp(self);
	
	while( !theEnd )
	{
		if( (theResult = parseJSONKey(self)) )
		{
			BOOL				theSkipParsingValue = NO;
			if( self->delegateMethod.shouldSkipValueForKey != NULL )
				theSkipParsingValue = ((_ReturnBoolMethodIMP)self->delegateMethod.shouldSkipValueForKey)( self->delegate, @selector(jsonParser:shouldSkipValueForKey:), self, self->lastKey	);		
			if( (nextCharIgnoreWhiteSpace(self) == ':') == YES )
			{
				if( theSkipParsingValue )
					theResult = skipNextValue( self );
				else 
					theResult = parseJSONUnknown( self );
				
				if( theResult == YES )
				{
					uint32_t		theChar = nextCharIgnoreWhiteSpace(self);
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
		NSCParameterAssert(truncateByte(&self->containers, NDJSONValueObject));
	}
	
	return theResult;
}

BOOL parseJSONKey( NDJSON * self )
{
	struct NDBytesBuffer	theBuffer = NDBytesBufferInit;
	BOOL					theResult = YES;
	if( nextCharIgnoreWhiteSpace(self) == '"' )
		theResult = parseJSONText( self, &theBuffer, YES, YES );
	else if( !self->options.strictJSONOnly )				// keys don't have to be quoted
	{
		backUp(self);
		theResult = parseJSONText( self, &theBuffer, YES, NO );
	}
	else
		foundError( self, NDJSONBadFormatError );
	if( theResult != NO )
	{
		[self->lastKey release], self->lastKey = [[NSString alloc] initWithBytes:theBuffer.bytes length:theBuffer.length encoding:NSUTF8StringEncoding];
		NDJSONLog( @"Found key: '%@'", self->lastKey );
		if( self->delegateMethod.foundKey != NULL )
			self->delegateMethod.foundKey( self->delegate, @selector(jsonParser:foundKey:), self, self->lastKey );
	}
	freeByte( &theBuffer );

	return theResult;
}

BOOL parseJSONString( NDJSON * self )
{
	struct NDBytesBuffer	theBuffer = NDBytesBufferInit;
	BOOL					theResult = parseJSONText( self, &theBuffer, NO, YES );
	if( theResult != NO )
	{
		NSString	* theValue = [[NSString alloc] initWithBytes:theBuffer.bytes length:theBuffer.length encoding:NSUTF8StringEncoding];
		if( self->delegateMethod.foundString != NULL )
			self->delegateMethod.foundString( self->delegate, @selector(jsonParser:foundString:), self, theValue );
		[theValue release];
	}
	freeByte( &theBuffer );
	return theResult;
}

BOOL parseJSONText( NDJSON * self, struct NDBytesBuffer * aValueBuffer, BOOL aIsKey, BOOL aIsQuotesTerminated )
{
	BOOL					theResult = YES,
							theEnd = NO;

	NSCParameterAssert(aValueBuffer != NULL);
	
	while( theResult  && !theEnd)
	{
		uint32_t		theChar = nextChar(self);
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
				if( !appendByte( aValueBuffer, theChar ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case '/':
				if( !appendByte( aValueBuffer, theChar ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case 'b':
				if( !appendByte( aValueBuffer, '\b' ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case 'f':
				if( !appendByte( aValueBuffer, '\b' ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case 'n':
				if( !appendByte( aValueBuffer, '\n' ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case 'r':
				if( !appendByte( aValueBuffer, '\r' ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case 't':
				if( !appendByte( aValueBuffer, '\t' ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case 'u':
			{
				uint32_t			theCharacterValue = 0;
				for( int i = 0; i < 4; i++ )
				{
					uint32_t		theChar = nextChar(self);
					if( theChar == 0 )
						break;
					int			theDigitValue = integerForHexidecimalDigit( theChar );
					if( theDigitValue >= 0 )
						theCharacterValue = (theCharacterValue << 4) + integerForHexidecimalDigit( theChar );
					else
						break;
				}
				if( !appendCharacter( aValueBuffer, theCharacterValue) )
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
			else if( !appendByte( aValueBuffer, theChar ) )
				foundError( self, NDJSONMemoryErrorError );
			break;
		}
	}
	if( !theEnd )
		foundError( self, NDJSONBadFormatError );
	return theResult;
}

BOOL parseJSONNumber( NDJSON * self )
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
		uint32_t		theChar = nextChar(self);
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

BOOL parseJSONTrue( NDJSON * self )
{
	BOOL		theResult = YES;
	uint32_t	theChar;
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

BOOL parseJSONFalse( NDJSON * self )
{
	BOOL		theResult = YES;
	uint32_t	theChar;
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

BOOL parseJSONNull( NDJSON * self )
{
	BOOL		theResult = YES;
	uint32_t	theChar;
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
	uint32_t		theChar = '\n';
	
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
				{
					if( (theChar = nextChar(self)) == '\0' )
						break;
				}
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
	theLen = self->numberOfBytes - thePos < 10 ? self->numberOfBytes - thePos : 10;
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

BOOL appendByte( struct NDBytesBuffer * aBuffer, uint32_t aByte )
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

static BOOL truncateByte( struct NDBytesBuffer * aBuffer, uint32_t aBytes )
{
	BOOL	theResult = NO;
	if( aBuffer->length > 0 && aBuffer->bytes[aBuffer->length-1] == aBytes )
	{
		aBuffer->length--;
		theResult = YES;
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


