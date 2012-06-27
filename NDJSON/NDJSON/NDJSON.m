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

enum CharacterWordSize
{
	kCharacterWord8 = 0,			// the values for these enums is important
	kCharacterWord16 = 1,
	kCharacterWord32 = 2
};

static NSStringEncoding	kNSStringEncodingFromCharacterWordSize[] = { NSUTF8StringEncoding, NSUTF16LittleEndianStringEncoding, NSUTF32LittleEndianStringEncoding };

enum CharacterEndian
{
	kUnknownEndian,
	kLittleEndian,
	kBigEndian
};

struct NDBytesBuffer
{
	uint8_t			* bytes;
	NSUInteger		length,
					capacity;
};

typedef BOOL (*_ReturnBoolMethodIMP)( id, SEL, id, ...);

static const NSUInteger		kBufferSize = 2048;

NSString	* const NDJSONErrorDomain = @"NDJSONError";

static const struct NDBytesBuffer	NDBytesBufferInit = {NULL,0,0};
static BOOL appendBytes( struct NDBytesBuffer * aBuffer, uint32_t aBytes, enum CharacterWordSize aWordSize );
static BOOL appendCharacter( struct NDBytesBuffer * aBuffer, unsigned int aValue, enum CharacterWordSize aWordSize );
//static BOOL truncateByte( struct NDBytesBuffer * aBuffer, uint32_t aBytes );
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
static BOOL parseInputFunctionOrBlock( NDJSON * self );
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
	kJSONStreamFunctionType,
	kJSONStreamBlockType,
	kJSONURLRequestType
};

@interface NDJSON ()
{
	__weak id<NDJSONDelegate>	delegate;
	NSUInteger					position,
								numberOfBytes;
	//	uint8_t						* bytes;
	union				// may represent the entire JSON document or just a part of
	{
		uint8_t			* word8;
		uint16_t		* word16;
		uint32_t		* word32;
	}					bytes;
#ifndef NDJSONSupportUTF8Only
	struct
	{
		enum CharacterWordSize		wordSize;
		enum CharacterEndian		endian;
	}							character;
#endif
	uint32_t					backUpByte;
	BOOL						hasSkippedValueForCurrentKey,
								alreadyParsing,
								complete,
								useBackUpByte;
	struct
	{
		int							strictJSONOnly		: 1;
		int							zipJSON				: 1;
	}							options;
	enum JSONInputType			inputType;
	union
	{
		struct
		{
			NSInputStream			* stream;
			id						object;
		};
		NDJSONDataStreamBlock		block;
		struct
		{
			NDJSONDataStreamProc	function;
			void					* context;
		};
	}							source;
	NSString					* currentKey;
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

@synthesize		delegate,
				currentKey;

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
- (BOOL)setJSONString:(NSString *)aString
{
#ifdef NDJSONSupportUTF8Only
	NSError			* theError = nil;
	return [self setJSONData:[aString dataUsingEncoding:NSUTF8StringEncoding] encoding:NSUTF8StringEncoding];
#else
	BOOL		theResult = NO;
	NSAssert( aString != nil, @"nil input JSON string" );
	CFStringEncoding		theStringEncoding = CFStringGetFastestEncoding( (CFStringRef)aString );
	
	position = 0;
	complete = NO;
	useBackUpByte = NO;
	source.stream = NULL;

	switch( theStringEncoding )
	{
		case kCFStringEncodingMacRoman:
		case kCFStringEncodingWindowsLatin1:
		case kCFStringEncodingISOLatin1:
		case kCFStringEncodingNextStepLatin:
		case kCFStringEncodingASCII:
		case kCFStringEncodingUTF8:
		case kCFStringEncodingNonLossyASCII:
			bytes.word8 = (uint8_t*)CFStringGetCStringPtr((CFStringRef)aString, theStringEncoding);
			numberOfBytes = aString.length;
			character.wordSize = kCharacterWord8;
			character.endian = kLittleEndian;
			break;
		case kCFStringEncodingUnicode:
//		case kCFStringEncodingUTF16:
		case kCFStringEncodingUTF16LE:
		case kCFStringEncodingUTF16BE:
			bytes.word8 = (uint8_t*)CFStringGetCharactersPtr((CFStringRef)aString);
			numberOfBytes = aString.length<<1;
			character.wordSize = kCharacterWord16;
			character.endian = kLittleEndian;
			break;
		case kCFStringEncodingUTF32:
		case kCFStringEncodingUTF32BE:
		case kCFStringEncodingUTF32LE:
			break;
	}

	if( bytes.word8 != NULL )
	{
		source.object = [aString retain];
		inputType = kJSONStringInputType;
		theResult = YES;
	}
	else						// failed to get poiter to string bytes.word8, convert to quickest NSData and use that instead
	{
		NSStringEncoding		theEncoding = CFStringConvertEncodingToNSStringEncoding(theStringEncoding);
		theResult = [self setJSONData:[aString dataUsingEncoding:theEncoding] encoding:theEncoding];
	}
	return theResult;
#endif
}

- (BOOL)setJSONData:(NSData *)aData encoding:(NSStringEncoding)anEncoding
{
	NSAssert( aData != nil, @"nil input JSON data" );
	position = 0;
	numberOfBytes = aData.length;
	bytes.word8 = (uint8_t*)[aData bytes];
	complete = NO;
	useBackUpByte = NO;
	source.stream = NULL;
	source.object = [aData retain];
	inputType = kJSONDataInputType;
#ifdef NDJSONSupportUTF8Only
	NSAssert( anEncoding <= NSMacOSRomanStringEncoding && anEncoding != NSUnicodeStringEncoding, @"with NDJSONSupportUTF8Only set only 8bit character encodings are supported" );
#else
	getCharacterWordSizeAndEndianFromNSStringEncoding( &character.wordSize, &character.endian, anEncoding );
#endif
	return bytes.word8 != NULL;
}

- (BOOL)setContentsOfFile:(NSString *)aPath encoding:(NSStringEncoding)anEncoding
{
	BOOL			theResult = NO;
	NSAssert( aPath != nil, @"nil input JSON path" );
	NSInputStream		* theInputStream = [NSInputStream inputStreamWithFileAtPath:aPath];
	if( theInputStream != nil )
		theResult = [self setInputStream:theInputStream encoding:anEncoding];
	return theResult;
}

- (BOOL)setContentsOfURL:(NSURL *)aURL encoding:(NSStringEncoding)anEncoding
{
	BOOL			theResult = NO;
	NSAssert( aURL != nil, @"nil input JSON file url" );
	NSInputStream		* theInputStream = [NSInputStream inputStreamWithURL:aURL];
	if( theInputStream != nil )
		theResult = [self setInputStream:theInputStream encoding:anEncoding];
	return theResult;
}

- (BOOL)setURLRequest:(NSURLRequest *)aURLRequest
{
	BOOL			theResult = NO;
	CFHTTPMessageRef	theMessageRef = CFHTTPMessageCreateRequest( kCFAllocatorDefault, (CFStringRef)aURLRequest.HTTPMethod, (CFURLRef)aURLRequest.URL, kCFHTTPVersion1_1 );
	inputType = kJSONStreamInputType;
	if ( theMessageRef != NULL )
	{
		CFReadStreamRef		theReadStreamRef = CFReadStreamCreateForHTTPRequest( kCFAllocatorDefault, theMessageRef );
		if( theReadStreamRef != NULL )
		{
			theResult = [self setInputStream:(NSInputStream*)theReadStreamRef encoding:NSUIntegerMax];
			CFRelease(theReadStreamRef);
		}
		CFRelease(theMessageRef);
	}
	return theResult;
}

- (BOOL)setInputStream:(NSInputStream *)aStream encoding:(NSStringEncoding)anEncoding
{
	NSAssert( aStream != nil, @"nil input stream" );
	position = 0;
	numberOfBytes = 0;
	bytes.word8 = malloc(kBufferSize);
	complete = NO;
	useBackUpByte = NO;
	source.stream = [aStream retain];
	inputType = kJSONStreamInputType;
	source.object = nil;
#ifndef NDJSONSupportUTF8Only
	getCharacterWordSizeAndEndianFromNSStringEncoding( &character.wordSize, &character.endian, anEncoding );
#endif
	return source.stream != NULL && bytes.word8 != NULL;
}

- (BOOL)setSourceFunction:(NDJSONDataStreamProc)aFunction context:(void*)aContext encoding:(NSStringEncoding)anEncoding;
{
	NSAssert( aFunction != NULL, @"NULL function" );
	position = 0;
	numberOfBytes = 0;
	bytes.word8 = NULL;
	complete = NO;
	useBackUpByte = NO;
	source.function = aFunction;
	source.context = aContext;
	inputType = kJSONStreamFunctionType;
#ifndef NDJSONSupportUTF8Only
	getCharacterWordSizeAndEndianFromNSStringEncoding( &character.wordSize, &character.endian, anEncoding );
#endif
	return source.function != NULL;
}

- (BOOL)setSourceBlock:(NDJSONDataStreamBlock)aBlock encoding:(NSStringEncoding)anEncoding;
{
	NSAssert( aBlock != NULL, @"NULL function" );
	position = 0;
	numberOfBytes = 0;
	bytes.word8 = NULL;
	complete = NO;
	useBackUpByte = NO;
	source.block = [aBlock copy];
	inputType = kJSONStreamBlockType;
#ifndef NDJSONSupportUTF8Only
	getCharacterWordSizeAndEndianFromNSStringEncoding( &character.wordSize, &character.endian, anEncoding );
#endif
	return source.function != NULL;
}

- (BOOL)parseWithOptions:(NDJSONOptionFlags)anOptions
{
	BOOL		theResult = NO;
	BOOL		theAlreadyParsing = alreadyParsing;

	alreadyParsing = YES;
	options.strictJSONOnly = NO;
	if( delegateMethod.didStartDocument != NULL )
		delegateMethod.didStartDocument( delegate, @selector(jsonDidStartDocument:), self );

	switch( inputType )
	{
	case kJSONDataInputType:
	case kJSONStringInputType:
		theResult = parseInputData( self );
		break;
	case kJSONStreamInputType:
		theResult = parseInputStream( self );
		break;
	case kJSONStreamFunctionType:
	case kJSONStreamBlockType:
		theResult = parseInputFunctionOrBlock( self );
		break;
	case kJSONURLRequestType:
		theResult = parseURLRequest( self );
		break;
	default:
		NSCAssert(NO, @"Input type not set" );
		break;
	}

	if( delegateMethod.didEndDocument != NULL )
		delegateMethod.didEndDocument( delegate, @selector(jsonDidEndDocument:), self );

	if( theAlreadyParsing )
		hasSkippedValueForCurrentKey = YES;
	alreadyParsing = theAlreadyParsing;
	
	[currentKey release], currentKey = nil;

	return theResult;
}

/*
 do this once so we don't waste time sending the same message to get the same answer
 Could ad code to look up the IMPs for the messages, and the use NULL values for them to determine whether to send the call
 */
- (void)setUpRespondsTo
{
	NSObject		* theDelegate = self.delegate;
	delegateMethod.didStartDocument = [theDelegate respondsToSelector:@selector(jsonDidStartDocument:)]
										? [theDelegate methodForSelector:@selector(jsonDidStartDocument:)]
										: NULL;
	delegateMethod.didEndDocument = [theDelegate respondsToSelector:@selector(jsonDidEndDocument:)]
										? [theDelegate methodForSelector:@selector(jsonDidEndDocument:)]
										: NULL;
	delegateMethod.didStartArray = [theDelegate respondsToSelector:@selector(jsonDidStartArray:)]
										? [theDelegate methodForSelector:@selector(jsonDidStartArray:)]
										: NULL;
	delegateMethod.didEndArray = [theDelegate respondsToSelector:@selector(jsonDidEndArray:)]
										? [theDelegate methodForSelector:@selector(jsonDidEndArray:)]
										: NULL;
	delegateMethod.didStartObject = [theDelegate respondsToSelector:@selector(jsonDidStartObject:)]
										? [theDelegate methodForSelector:@selector(jsonDidStartObject:)]
										: NULL;
	delegateMethod.didEndObject = [theDelegate respondsToSelector:@selector(jsonDidEndObject:)]
										? [theDelegate methodForSelector:@selector(jsonDidEndObject:)]
										: NULL;
	delegateMethod.shouldSkipValueForKey = [theDelegate respondsToSelector:@selector(json:shouldSkipValueForKey:)]
										? [theDelegate methodForSelector:@selector(json:shouldSkipValueForKey:)]
										: NULL;
	delegateMethod.foundKey = [theDelegate respondsToSelector:@selector(json:foundKey:)]
										? [theDelegate methodForSelector:@selector(json:foundKey:)]
										: NULL;
	delegateMethod.foundString = [theDelegate respondsToSelector:@selector(json:foundString:)]
										? [theDelegate methodForSelector:@selector(json:foundString:)]
										: NULL;
	delegateMethod.foundInteger = [theDelegate respondsToSelector:@selector(json:foundInteger:)]
										? [theDelegate methodForSelector:@selector(json:foundInteger:)]
										: NULL;
	delegateMethod.foundFloat = [theDelegate respondsToSelector:@selector(json:foundFloat:)]
										? [theDelegate methodForSelector:@selector(json:foundFloat:)]
										: NULL;
	delegateMethod.foundBool = [theDelegate respondsToSelector:@selector(json:foundBool:)]
										? [theDelegate methodForSelector:@selector(json:foundBool:)]
										: NULL;
	delegateMethod.foundNULL = [theDelegate respondsToSelector:@selector(jsonFoundNULL:)]
										? [theDelegate methodForSelector:@selector(jsonFoundNULL:)]
										: NULL;
	delegateMethod.foundError = [theDelegate respondsToSelector:@selector(json:error:)]
										? [theDelegate methodForSelector:@selector(json:error:)]
										: NULL;
}

static uint32_t integerForHexidecimalDigit( uint32_t d )
{
	uint32_t	r = UINT32_MAX;
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
	if( self->position<<self->character.wordSize >= self->numberOfBytes )
	{
		/*
			if numberOfBytes was not a multiple of character word size then we need to copy the partial word
			to the begining of the buffer and append the next block onto the end, to comple the last character.
		 */
		NSUInteger		theRemainingLen = self->numberOfBytes&((1<<self->character.wordSize)-1);
		if( theRemainingLen > 0 )
			memcpy(self->bytes.word8, self->bytes.word8+self->numberOfBytes-theRemainingLen, theRemainingLen );
#endif
		switch (self->inputType)
		{
		case kJSONStreamInputType:
#ifdef NDJSONSupportUTF8Only
			self->numberOfBytes = [self->source.stream read:self->bytes.word8 maxLength:kBufferSize];
#else
			self->numberOfBytes = (NSUInteger)[self->source.stream read:self->bytes.word8+theRemainingLen maxLength:kBufferSize-theRemainingLen];
#endif
			break;
		case kJSONStreamFunctionType:
#ifdef NDJSONSupportUTF8Only
			self->numberOfBytes = self->source.function(&self->bytes.word8, self->source.context);
#else
			self->numberOfBytes = (NSUInteger)self->source.function(&self->bytes.word8+theRemainingLen, self->source.context);
#endif
			break;
		case kJSONStreamBlockType:
#ifdef NDJSONSupportUTF8Only
			self->numberOfBytes = self->source.block(&self->bytes.word8);
#else
			self->numberOfBytes = (NSUInteger)self->source.block(&self->bytes.word8+theRemainingLen);
#endif
			break;
		case kJSONURLRequestType:
			break;
		default:
			self->complete = YES;
			break;
		}
		if( self->numberOfBytes > 0 )
			self->position = 0;
		else
			self->complete = YES;
	}
	
	if( !self->complete )
	{
#ifdef NDJSONSupportUTF8Only
		theResult = self->bytes.word8[self->position];
#else
		switch( self->character.wordSize )
		{
		case kCharacterWord8:
			theResult = self->bytes.word8[self->position];
			break;
		case kCharacterWord16:
			theResult = self->bytes.word16[self->position];
			if( self->position == 0 )
			{
				if( theResult == k16BitLittleEndianBOM )
				{
					self->character.endian = kLittleEndian;
					theResult = ' ';
				}
				else if( theResult == k16BitBigEndianBOM )
				{
					self->character.endian = kBigEndian;
					theResult = 0x2000;
				}
				else if( self->character.endian == kUnknownEndian )
				{
					if( (theResult & 0xFF00) == 0 )			// first character is most likly < 256
						self->character.endian = kLittleEndian;
					else if( (theResult & 0x00FF) == 0 )			// first character is most likly < 256
						self->character.endian = kBigEndian;
					else
						self->character.endian = kLittleEndian;
				}
			}
			if( self->character.endian == kBigEndian )
				theResult = CFSwapInt16BigToHost((uint16_t)theResult);
			else
				theResult = CFSwapInt16HostToLittle((uint16_t)theResult);
			break;
		case kCharacterWord32:
			theResult = self->bytes.word32[self->position];
			if( self->position == 0 )
			{
				if( theResult == k32BitLittleEndianBOM )
				{
					self->character.endian = kLittleEndian;
					theResult = ' ';
				}
				else if( theResult == k32BitBigEndianBOM )
				{
					self->character.endian = kBigEndian;
					theResult = 0x20000000;
				}
				else if( self->character.endian == kUnknownEndian )
				{
					if( (theResult & 0xFFFF0000) == 0 )			// first character is most likly < 65536
						self->character.endian = kLittleEndian;
					else if( (theResult & 0x0000FFFF) == 0 )			// first character is most likly < 65536
						self->character.endian = kBigEndian;
					else
						self->character.endian = kLittleEndian;
				}
			}
			if( self->character.endian == kBigEndian )
				theResult = CFSwapInt32BigToHost(theResult);
			else
				theResult = CFSwapInt32HostToLittle(theResult);
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
		putc((int)self->backUpByte, stderr);
#endif
	}
	else
		self->useBackUpByte = NO;
	return self->backUpByte;
}
/*
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
*/
static uint32_t nextCharIgnoreWhiteSpace( NDJSON * self )
{
	uint32_t		theResult;
	if( self->options.strictJSONOnly )				// skip white space only
	{
		do
			theResult = nextChar( self );
		while( isspace((int)theResult) );
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
		while( isspace((int)theResult) );
	}
end:
	return theResult;
}

static void backUp( NDJSON * self ) { self->useBackUpByte = YES; }

BOOL parseInputData( NDJSON * self )
{
	BOOL		theResult = NO;
	NSCParameterAssert( self->bytes.word8 != NULL );
	NSCParameterAssert( self->source.object != nil );
	theResult = parseJSONUnknown( self );
	[self->source.object release], self->source.object = nil;
	return theResult;
}

BOOL parseInputStream( NDJSON * self )
{
	BOOL		theResult = NO;
	NSCParameterAssert( self->source.stream != nil );
	[self->source.stream open];
	theResult = parseJSONUnknown( self );
	[self->source.stream close], [self->source.stream release], self->source.stream = nil;
	[self->source.object release], self->source.object = nil;
	return theResult;
}

BOOL parseInputFunctionOrBlock( NDJSON * self )
{
	BOOL		theResult = NO;
	NSCParameterAssert( self->source.block != nil || self->source.function != nil );
	theResult = parseJSONUnknown( self );
	return theResult;
}
	
BOOL parseURLRequest( NDJSON * self )
{
	BOOL		theResult = NO;
	if( self->source.stream != nil || self->bytes.word8 != NULL )
	{
		self->options.strictJSONOnly = NO;
		if( self->delegateMethod.didStartDocument != NULL )
			self->delegateMethod.didStartDocument( self->delegate, @selector(jsonDidStartDocument:), self );
		if( self->source.stream != nil )
		{
			CFTypeRef theHttpHeaderMessage = NULL;
			[self->source.stream open];
			theHttpHeaderMessage = CFReadStreamCopyProperty( (CFReadStreamRef)self->source.stream, kCFStreamPropertyHTTPResponseHeader );
			if( theHttpHeaderMessage != NULL )
			{
				NSDictionary	* theHeaders = (NSDictionary*)CFHTTPMessageCopyAllHeaderFields(theHttpHeaderMessage);
				getCharacterWordSizeAndEndianFromNSStringEncoding( &self->character.wordSize, &self->character.endian, stringEncodingFromHTTPContentTypeString( [theHeaders objectForKey:kContentTypeHTTPHeaderKey] ) );
				CFRelease(theHttpHeaderMessage);
			}
		}
		theResult = parseJSONUnknown( self );
		[self->source.stream close];

		if( self->delegateMethod.didEndDocument != NULL )
			self->delegateMethod.didEndDocument( self->delegate, @selector(jsonDidEndDocument:), self );
		
		[self->currentKey release], self->currentKey = nil;
	}
	[self->source.stream release], self->source.stream = nil;
	[self->source.object release], self->source.object = nil;
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
	if( self->delegateMethod.didStartArray != NULL )
		self->delegateMethod.didStartArray( self->delegate, @selector(jsonDidStartArray:), self );
	
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
		if( self->delegateMethod.didEndArray != NULL )
			self->delegateMethod.didEndArray( self->delegate, @selector(jsonDidEndArray:), self );
	}
errorOut:
	return theResult;
}

BOOL parseJSONObject( NDJSON * self )
{
	BOOL				theResult = YES;
	BOOL				theEnd = NO;
	NSUInteger			theCount = 0;
	
	if( self->delegateMethod.didStartObject != NULL )
		self->delegateMethod.didStartObject( self->delegate, @selector(jsonDidStartObject:), self );
	
	if( nextCharIgnoreWhiteSpace(self) == '}' )
		theEnd = YES;
	else
		backUp(self);
	
	while( !theEnd )
	{
		if( (theResult = parseJSONKey(self)) )
		{
			if( (nextCharIgnoreWhiteSpace(self) == ':') == YES )
			{
				BOOL	theSkipParsingValueForCurrentKey = NO;

				if( self->delegateMethod.foundKey != NULL )
					self->delegateMethod.foundKey( self->delegate, @selector(json:foundKey:), self, self->currentKey );

				if( self->delegateMethod.shouldSkipValueForKey != NULL )
					theSkipParsingValueForCurrentKey = ((_ReturnBoolMethodIMP)self->delegateMethod.shouldSkipValueForKey)( self->delegate, @selector(json:shouldSkipValueForKey:), self, self->currentKey	);

				if( theSkipParsingValueForCurrentKey )
					theResult = skipNextValue(self);
				else if( !self->hasSkippedValueForCurrentKey )
					theResult = parseJSONUnknown( self );
				else
				{
					self->hasSkippedValueForCurrentKey = NO;
					theResult = YES;
				}

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
			self->delegateMethod.didEndObject( self->delegate, @selector(jsonDidEndObject:), self );
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
		[self->currentKey release], self->currentKey = [[NSString alloc] initWithBytes:theBuffer.bytes length:theBuffer.length encoding:kNSStringEncodingFromCharacterWordSize[self->character.wordSize]];
		NDJSONLog( @"Found key: '%@'", self->currentKey );
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
		NSString	* theValue = [[NSString alloc] initWithBytes:theBuffer.bytes length:theBuffer.length encoding:kNSStringEncodingFromCharacterWordSize[self->character.wordSize]];
		if( self->delegateMethod.foundString != NULL )
			self->delegateMethod.foundString( self->delegate, @selector(json:foundString:), self, theValue );
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
			case '/':
				if( !appendBytes( aValueBuffer, theChar, self->character.wordSize ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case 'b':
				if( !appendCharacter( aValueBuffer, '\b', self->character.wordSize ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case 'f':
				if( !appendCharacter( aValueBuffer, '\f', self->character.wordSize ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case 'n':
				if( !appendCharacter( aValueBuffer, '\n', self->character.wordSize ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case 'r':
				if( !appendCharacter( aValueBuffer, '\r', self->character.wordSize ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case 't':
				if( !appendCharacter( aValueBuffer, '\t', self->character.wordSize ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case 'u':
			{
				uint32_t			theCharacterValue = 0;
				for( int i = 0; i < 4; i++ )
				{
					uint32_t		theHexChar = nextChar(self);
					if( theHexChar == 0 )
						break;
					uint32_t		theDigitValue = integerForHexidecimalDigit( theHexChar );
					if( theDigitValue <= 0xF )
						theCharacterValue = (theCharacterValue << 4) + integerForHexidecimalDigit( theHexChar );
					else
						break;
				}
				if( !appendCharacter( aValueBuffer, theCharacterValue, self->character.wordSize) )
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
		case ':':
			if( !aIsQuotesTerminated  )
			{
				theEnd = YES;
				backUp(self);
			}
			else if( !appendBytes( aValueBuffer, theChar, self->character.wordSize ) )
				foundError( self, NDJSONMemoryErrorError );
			break;
		case '\t': case '\n': case '\v': case '\f': case '\r': case ' ':
			if( !aIsQuotesTerminated )
				theEnd = YES;
			else if( !appendBytes( aValueBuffer, theChar, self->character.wordSize ) )
				foundError( self, NDJSONMemoryErrorError );
			break;
		default:
			if( !appendBytes( aValueBuffer, theChar, self->character.wordSize ) )
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
			self->delegateMethod.foundFloat( self->delegate, @selector(json:foundFloat:), self, theValue );
	}
	else if( theDecimalPlaces > 0 )
	{
		if( theNegative )
			theIntegerValue = -theIntegerValue;
		if( self->delegateMethod.foundInteger != NULL )
			self->delegateMethod.foundInteger( self->delegate, @selector(json:foundInteger:), self, theIntegerValue );
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
			self->delegateMethod.foundBool( self->delegate, @selector(json:foundBool:), self, YES );
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
			self->delegateMethod.foundBool( self->delegate, @selector(json:foundBool:), self, NO );
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
			self->delegateMethod.foundNULL( self->delegate, @selector(jsonFoundNULL:), self );
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
		theString = [[NSString alloc] initWithFormat:@"Bad token at pos %lu, %*s", self->position, (int)theLen, self->bytes.word8];
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
		self->delegateMethod.foundError( self->delegate, @selector(json:error:), self, [NSError errorWithDomain:NDJSONErrorDomain code:aCode userInfo:theUserInfo] );
	[theUserInfo release];
}

@end

static BOOL extendsBytesOfLen( struct NDBytesBuffer * aBuffer, NSUInteger aLen )
{
	BOOL			theResult = YES;
	uint8_t			* theNewBuff = NULL;
	while( aBuffer->length + aLen >= aBuffer->capacity )
	{
		if( aBuffer->capacity == 0 )
			aBuffer->capacity = 0x10;
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

BOOL appendBytes( struct NDBytesBuffer * aBuffer, uint32_t aByte, enum CharacterWordSize aWordSize )
{
	BOOL	theResult = YES;
	if( aBuffer->length >= aBuffer->capacity )
	{
#ifdef NDJSONSupportUTF8Only
		theResult = extendsBytesOfLen( aBuffer, 1 );
#else
		theResult = extendsBytesOfLen( aBuffer, 1<<aWordSize );
#endif
	}

	if( theResult )
	{
#ifdef NDJSONSupportUTF8Only
		aBuffer->bytes[aBuffer->length] = (uint8_t)aByte;
		aBuffer->length++;
#else
		memcpy( aBuffer->bytes+aBuffer->length, &aByte, 1<<aWordSize );
		aBuffer->length += 1<<aWordSize;
#endif
	}
	return theResult;
}

BOOL appendCharacter( struct NDBytesBuffer * aBuffer, uint32_t aValue, enum CharacterWordSize aWordSize )
{
	switch (aWordSize)
	{
	case kCharacterWord8:
		if( aValue > 0x3ffffff )				// 1111110x	10xxxxxx	10xxxxxx	10xxxxxx	10xxxxxx	10xxxxxx
		{
			if( !appendBytes( aBuffer, ((aValue>>31) & 0xf) | 0xfc, kCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, ((aValue>>30) & 0x3f) | 0x80, kCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, ((aValue>>24) & 0x3f) | 0x80, kCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, ((aValue>>18) & 0x3f) | 0x80, kCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, ((aValue>>12) & 0x3f) | 0x80, kCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, ((aValue>>6) & 0x3f) | 0x80, kCharacterWord8 ) )
				return NO;
		}
		else if( aValue > 0x1fffff )			// 111110xx	10xxxxxx	10xxxxxx	10xxxxxx	10xxxxxx
		{
			if( !appendBytes( aBuffer, ((aValue>>24) & 0x3f) | 0x80, kCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, ((aValue>>18) & 0x3f) | 0x80, kCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, ((aValue>>12) & 0x3f) | 0x80, kCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, ((aValue>>6) & 0x3f) | 0x80, kCharacterWord8 ) )
				return NO;
		}
		else if( aValue > 0xffff )				// 11110xxx	10xxxxxx	10xxxxxx	10xxxxxx
		{
			if( !appendBytes( aBuffer, ((aValue>>18) & 0x3f) | 0x80, kCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, ((aValue>>12) & 0x3f) | 0x80, kCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, ((aValue>>6) & 0x3f) | 0x80, kCharacterWord8 ) )
				return NO;
		}
		else if( aValue > 0x7ff )				// 1110xxxx	10xxxxxx	10xxxxxx
		{
			if( !appendBytes( aBuffer, ((aValue>>12) & 0xf) | 0xE0, kCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, ((aValue>>6) & 0x3f) | 0x80, kCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, (aValue & 0x3f) | 0x80, kCharacterWord8 ) )
				return NO;
		}
		else if( aValue > 0x7f )				// 110xxxxx	10xxxxxx
		{
			if( !appendBytes( aBuffer, ((aValue>>6) & 0x1f) | 0xc0, kCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, (aValue & 0x3f) | 0x80, kCharacterWord8 ) )
				return NO;
		}
		else									// 0xxxxxxx
		{
			if( !appendBytes( aBuffer, aValue & 0x7f, kCharacterWord8 ) )
				return NO;
		}
		break;
	case kCharacterWord16:
		if( aValue > 0x10ffff || (aValue >= 0Xd800 && aValue <= 0xdfff) )
		{
			NSLog( @"Bad unicode code point %x", aValue );
			return NO;
		}
		else if( aValue > 0xffff )
		{
			if( !appendBytes( aBuffer, (uint16_t)((aValue-0x10000)>>10)+0xd800, kCharacterWord16 )
				   && !appendBytes( aBuffer, (uint16_t)((aValue-0x10000)&0x3ff)+0xdc00, kCharacterWord16 ) )
				return NO;
		}
		else
		{
			if( !appendBytes( aBuffer, aValue & 0xffff, kCharacterWord16 ) )
				return NO;
		}
		break;
	case kCharacterWord32:
		if( !appendBytes( aBuffer, aValue, kCharacterWord32 ) )
			return NO;
		break;
	}
	return YES;
}

void freeByte( struct NDBytesBuffer * aBuffer )
{
	free(aBuffer->bytes);
	aBuffer->bytes = NULL;
	aBuffer->length = 0;
	aBuffer->capacity = 0;
}


