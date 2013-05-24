/*
	NDJSONParser.m

	Created by Nathan Day on 31/08/11.
	Copyright 2011 Nathan Day. All rights reserved.
 */

//#define NDJSONDebug
//#define NDJSONPrintStream

#import <Foundation/Foundation.h>
#import "NDJSONParser.h"
#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <string.h>
#include <ctype.h>

NSString			* const kNDJSONNoInputSourceExpection = @"NDJSONNoInputSource";

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

BOOL jsonParserValueIsPrimativeType( NDJSONValueType aType )
{
	switch( aType )
	{
	case NDJSONValueNone:
	case NDJSONValueArray:
	case NDJSONValueObject:
		return NO;
	case NDJSONValueString:
	case NDJSONValueInteger:
	case NDJSONValueFloat:
	case NDJSONValueBoolean:
	case NDJSONValueNull:
		return YES;
	}
}

BOOL jsonParserValueIsNSNumberType( NDJSONValueType aType )
{
	switch( aType )
	{
	case NDJSONValueNone:
	case NDJSONValueArray:
	case NDJSONValueObject:
	case NDJSONValueString:
	case NDJSONValueNull:
		return NO;
	case NDJSONValueInteger:
	case NDJSONValueFloat:
	case NDJSONValueBoolean:
		return YES;
	}
}

BOOL jsonParserValueEquivelentObjectTypes( NDJSONValueType aTypeA, NDJSONValueType aTypeB )
{
	BOOL		theResult = NO;
	switch( aTypeA )
	{
	case NDJSONValueNone:
		theResult = aTypeB == NDJSONValueNone;
		break;
	case NDJSONValueArray:
		theResult = aTypeB == NDJSONValueArray;
		break;
	case NDJSONValueObject:
		theResult = aTypeB == NDJSONValueObject;
		break;
	case NDJSONValueString:
		theResult = aTypeB == NDJSONValueString;
		break;
	case NDJSONValueInteger:
	case NDJSONValueFloat:
	case NDJSONValueBoolean:
		theResult = (aTypeB == NDJSONValueInteger || aTypeB == NDJSONValueFloat || aTypeB == NDJSONValueBoolean);
		break;
	case NDJSONValueNull:
		theResult = aTypeB == NDJSONValueNull;
		break;
	}
	return theResult;
}

@protocol NDJSONParserDelegate;

static NSString		* const kContentTypeHTTPHeaderKey = @"Content-Type";

enum NDJSONCharacterWordSize
{
	kNDJONCharacterWord8 = 0,			// the values for these enums is important
	kNDJSONCharacterWord16 = 1,
	kNDJSONCharacterWord32 = 2
};

#ifndef NDJSONSupportUTF8Only
static NSStringEncoding	kNSStringEncodingFromCharacterWordSize[] = { NSUTF8StringEncoding, NSUTF16LittleEndianStringEncoding, NSUTF32LittleEndianStringEncoding };
#endif

enum NDJSONCharacterEndian
{
	kNDJSONUnknownEndian,
	kNDJSONLittleEndian,
	kNDJSONBigEndian
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
static BOOL appendBytes( struct NDBytesBuffer * aBuffer, uint32_t aBytes, enum NDJSONCharacterWordSize aWordSize );
static BOOL appendCharacter( struct NDBytesBuffer * aBuffer, unsigned int aValue, enum NDJSONCharacterWordSize aWordSize );
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

static BOOL parseInputData( NDJSONParser * self );
static BOOL parseInputStream( NDJSONParser * self );
static BOOL parseInputFunctionOrBlock( NDJSONParser * self );
static BOOL parseURLRequest( NDJSONParser * self );

static BOOL parseJSONUnknown( NDJSONParser * self );
static BOOL parseJSONObject( NDJSONParser * self );
static BOOL parseJSONArray( NDJSONParser * self );
static BOOL parseJSONKey( NDJSONParser * self );
static BOOL parseJSONString( NDJSONParser * self );
static BOOL parseJSONText( NDJSONParser * self, struct NDBytesBuffer * valueBuffer, BOOL aIsKey, BOOL aIsQuotesTerminated );
static BOOL parseJSONNumber( NDJSONParser * self );
static BOOL parseJSONTrue( NDJSONParser * self );
static BOOL parseJSONFalse( NDJSONParser * self );
static BOOL parseJSONNull( NDJSONParser * self );
static BOOL skipNextValue( NDJSONParser * self );
static void foundError( NDJSONParser * self, NDJSONErrorCode aCode );

#ifdef NDJSONSupportUTF8Only
static BOOL is8BitWordSizeForNSStringEncoding( NSStringEncoding anEncoding )
{
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
		return YES;;
	default:
		return NO;
	}
}
#else
static BOOL getCharacterWordSizeAndEndianFromNSStringEncoding( enum NDJSONCharacterWordSize * aWordSize, enum NDJSONCharacterEndian * anEndian, NSStringEncoding anEncoding )
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
		*aWordSize = kNDJONCharacterWord8;
		*anEndian = kNDJSONLittleEndian;
		break;
//	case NSUnicodeStringEncoding:
	case NSUTF16StringEncoding:
		*aWordSize = kNDJSONCharacterWord16;
		*anEndian = kNDJSONUnknownEndian;
		break;
	case NSUTF16BigEndianStringEncoding:
		*aWordSize = kNDJSONCharacterWord16;
		*anEndian = kNDJSONBigEndian;
		break;
	case NSUTF16LittleEndianStringEncoding:
		*aWordSize = kNDJSONCharacterWord16;
		*anEndian = kNDJSONLittleEndian;
		break;
	case NSUTF32StringEncoding:
		*aWordSize = kNDJSONCharacterWord32;
		*anEndian = kNDJSONUnknownEndian;
		break;
	case NSUTF32BigEndianStringEncoding:
		*aWordSize = kNDJSONCharacterWord32;
		*anEndian = kNDJSONBigEndian;
		break;
	case NSUTF32LittleEndianStringEncoding:
		*aWordSize = kNDJSONCharacterWord32;
		*anEndian = kNDJSONLittleEndian;
		break;
	}
	return theResult;
}

#endif

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

@interface NDJSONParser ()
{
	id<NDJSONParserDelegate>		__weak _delegate;
	NSUInteger						_position,
									_numberOfBytes,
									_lineNumber;
	uint8_t							* _inputBytes;
	union				// may represent the entire JSON document or just a part of
	{
		uint8_t							* word8;
		uint16_t						* word16;
		uint32_t						* word32;
	}								_bytes;
	BOOL							_ownsBytes;
#ifndef NDJSONSupportUTF8Only
	struct
	{
		enum NDJSONCharacterWordSize	wordSize;
		enum NDJSONCharacterEndian		endian;
	}								_character;
#endif
	uint32_t						_backUpByte;
	BOOL							_hasSkippedValueForCurrentKey,
									_alreadyParsing,
									_complete,
									_useBackUpByte,
									_abort;
	struct
	{
		int								strictJSONOnly		: 1;
	}								_options;
	enum JSONInputType				_inputType;
	union
	{
		id								object;
		NDJSONDataStreamBlock			block;
		struct
		{
			NDJSONDataStreamProc		function;
			void						* context;
		};
	}								_source;
	NSString						* __strong _currentKey;
	struct
	{
		IMP								didStartDocument,
										didEndDocument,
										didStartArray,
										didEndArray,
										didStartObject,
										didEndObject,
										shouldSkipValueForKey,
										foundKey,
										foundString,
										foundNumber,
										foundInteger,
										foundFloat,
										foundBool,
										foundNULL,
										foundError;
	}								_delegateMethod;
}

- (void)setUpRespondsTo;
- (BOOL)parseWithOptions:(NDJSONOptionFlags)options;

@property(readwrite,nonatomic,retain)	NSString			* currentKey;

@end

@implementation NDJSONParser

@synthesize		delegate = _delegate,
				currentKey = _currentKey,
				lineNumber = _lineNumber;

#pragma mark - manually implemented properties

- (void)setDelegate:(id<NDJSONParserDelegate>)aDelegate
{
	_delegate = aDelegate;
	[self setUpRespondsTo];
}

#pragma mark - creation and destruction etc

- (void)dealloc
{
	if( _ownsBytes == YES )
		free( _bytes.word8 );
	[super dealloc];
}

- (id)init
{
	if( (self = [super init]) != nil )
	{
		_position = 0;
		_numberOfBytes = 0;
		_lineNumber = 0;
		_complete = NO;
		_abort = NO;
		_useBackUpByte = NO;
		_source.object = NULL;
		_source.function = NULL;
		_source.context = NULL;
		_inputType = kJSONNoInputType;
		_inputBytes = NULL;
		_bytes.word8 = NULL;
		_bytes.word16 = NULL;
		_bytes.word32 = NULL;
		_currentKey = nil;
	}
	return self;
}

#pragma mark - parsing methods
- (id)initWithJSONString:(NSString *)aString
{
	NSAssert( aString != nil, @"nil input JSON string" );
#ifdef NDJSONSupportUTF8Only
	return [self initWithJSONData:[aString dataUsingEncoding:NSUTF8StringEncoding] encoding:NSUTF8StringEncoding];
#else
	if( (self = [self init]) != nil )
	{
		CFStringEncoding		theStringEncoding = CFStringGetFastestEncoding( (CFStringRef)aString );
		switch( theStringEncoding )
		{
		case kCFStringEncodingMacRoman:
		case kCFStringEncodingWindowsLatin1:
		case kCFStringEncodingISOLatin1:
		case kCFStringEncodingNextStepLatin:
		case kCFStringEncodingASCII:
		case kCFStringEncodingUTF8:
		case kCFStringEncodingNonLossyASCII:
			_bytes.word8 = _inputBytes = (uint8_t*)CFStringGetCStringPtr((CFStringRef)aString, theStringEncoding);
			_ownsBytes = NO;
			_numberOfBytes = aString.length;
			_character.wordSize = kNDJONCharacterWord8;
			_character.endian = kNDJSONLittleEndian;
			break;
		case kCFStringEncodingUnicode:
	//	case kCFStringEncodingUTF16:
		case kCFStringEncodingUTF16LE:
		case kCFStringEncodingUTF16BE:
			_bytes.word8 = _inputBytes = (uint8_t*)CFStringGetCharactersPtr((CFStringRef)aString);
			_ownsBytes = NO;
			_numberOfBytes = aString.length<<1;
			_character.wordSize = kNDJSONCharacterWord16;
			_character.endian = kNDJSONLittleEndian;
			break;
		case kCFStringEncodingUTF32:
		case kCFStringEncodingUTF32BE:
		case kCFStringEncodingUTF32LE:
			break;
		}

		if( _bytes.word8 != NULL )
		{
			_source.object = [aString retain];
			_inputType = kJSONStringInputType;
		}
		else
		{
			[self release];
			self = nil;
		}
	}
	return self;
#endif
}

- (id)initWithJSONData:(NSData *)aData encoding:(NSStringEncoding)anEncoding
{
	NSAssert( aData != nil, @"nil input JSON data" );
	if( (self = [self init]) != nil )
	{
		_numberOfBytes = aData.length;
		_ownsBytes = NO;
		_bytes.word8 = _inputBytes = (uint8_t*)[aData bytes];
		_source.object = [aData retain];
		_inputType = kJSONDataInputType;
#ifdef NDJSONSupportUTF8Only
		NSAssert( is8BitWordSizeForNSStringEncoding(anEncoding), @"with NDJSONSupportUTF8Only set only 8bit character encodings are supported" );
#else
		getCharacterWordSizeAndEndianFromNSStringEncoding( &_character.wordSize, &_character.endian, anEncoding );
#endif
	}
	return self;
}

- (id)initWithContentsOfFile:(NSString *)aPath encoding:(NSStringEncoding)anEncoding
{
	NSAssert( aPath != nil, @"nil input JSON path" );
	NSInputStream		* theInputStream = [NSInputStream inputStreamWithFileAtPath:aPath];
	if( theInputStream != nil )
		self = [self initWithInputStream:theInputStream encoding:anEncoding];
	else
	{
		[self release];
		self = nil;
	}
	return self;
}

- (id)initWithContentsOfURL:(NSURL *)aURL encoding:(NSStringEncoding)anEncoding
{
	NSAssert( aURL != nil, @"nil input JSON file url" );
	NSInputStream		* theInputStream = [NSInputStream inputStreamWithURL:aURL];
	if( theInputStream != nil )
		self = [self initWithInputStream:theInputStream encoding:anEncoding];
	else
	{
		[self release];
		self = nil;
	}
	return self;
}

- (id)initWithInputStream:(NSInputStream *)aStream encoding:(NSStringEncoding)anEncoding
{
	NSAssert( aStream != nil, @"nil input stream" );
	if( (self = [self init]) != nil )
	{
		_bytes.word8 = _inputBytes = malloc(kBufferSize);
		_ownsBytes = YES;
		_source.object = [aStream retain];
		_inputType = kJSONStreamInputType;
#ifdef NDJSONSupportUTF8Only
		NSAssert( is8BitWordSizeForNSStringEncoding(anEncoding), @"with NDJSONSupportUTF8Only set only 8bit character encodings are supported" );
#else
		getCharacterWordSizeAndEndianFromNSStringEncoding( &_character.wordSize, &_character.endian, anEncoding );
#endif
	}
	return self;
}

- (id)initWithSourceFunction:(NDJSONDataStreamProc)aFunction context:(void*)aContext encoding:(NSStringEncoding)anEncoding;
{
	NSAssert( aFunction != NULL, @"NULL function" );
	if( (self = [self init]) != nil )
	{
		_source.function = aFunction;
		_source.context = aContext;
		_inputType = kJSONStreamFunctionType;
	#ifdef NDJSONSupportUTF8Only
		NSAssert( is8BitWordSizeForNSStringEncoding(anEncoding), @"with NDJSONSupportUTF8Only set only 8bit character encodings are supported" );
	#else
		getCharacterWordSizeAndEndianFromNSStringEncoding( &_character.wordSize, &_character.endian, anEncoding );
	#endif
	}
	return self;
}

- (id)initWithSourceBlock:(NDJSONDataStreamBlock)aBlock encoding:(NSStringEncoding)anEncoding;
{
	NSAssert( aBlock != NULL, @"NULL function" );
	if( (self = [self init]) != nil )
	{
		_source.block = [aBlock copy];
		_inputType = kJSONStreamBlockType;
#ifdef NDJSONSupportUTF8Only
		NSAssert( is8BitWordSizeForNSStringEncoding(anEncoding), @"with NDJSONSupportUTF8Only set only 8bit character encodings are supported" );
#else
		getCharacterWordSizeAndEndianFromNSStringEncoding( &_character.wordSize, &_character.endian, anEncoding );
#endif
	}
	return self;
}

- (BOOL)parseWithOptions:(NDJSONOptionFlags)anOptions
{
	BOOL		theResult = NO;
	BOOL		theAlreadyParsing = _alreadyParsing;

	_alreadyParsing = YES;
	_options.strictJSONOnly = (anOptions&NDJSONOptionStrict) != 0;
	if( _delegateMethod.didStartDocument != NULL )
		_delegateMethod.didStartDocument( _delegate, @selector(jsonParserDidStartDocument:), self );

	switch( _inputType )
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

	if( _delegateMethod.didEndDocument != NULL )
		_delegateMethod.didEndDocument( _delegate, @selector(jsonParserDidEndDocument:), self );

	if( theAlreadyParsing )
		_hasSkippedValueForCurrentKey = YES;
	_alreadyParsing = theAlreadyParsing;

	self.currentKey = nil;
	return theResult;
}

/*
 do this once so we don't waste time sending the same message to get the same answer
 Could ad code to look up the IMPs for the messages, and the use NULL values for them to determine whether to send the call
 */
- (void)setUpRespondsTo
{
	NSObject		* theDelegate = self.delegate;
	_delegateMethod.didStartDocument = [theDelegate respondsToSelector:@selector(jsonParserDidStartDocument:)]
										? [theDelegate methodForSelector:@selector(jsonParserDidStartDocument:)]
										: NULL;
	_delegateMethod.didEndDocument = [theDelegate respondsToSelector:@selector(jsonParserDidEndDocument:)]
										? [theDelegate methodForSelector:@selector(jsonParserDidEndDocument:)]
										: NULL;
	_delegateMethod.didStartArray = [theDelegate respondsToSelector:@selector(jsonParserDidStartArray:)]
										? [theDelegate methodForSelector:@selector(jsonParserDidStartArray:)]
										: NULL;
	_delegateMethod.didEndArray = [theDelegate respondsToSelector:@selector(jsonParserDidEndArray:)]
										? [theDelegate methodForSelector:@selector(jsonParserDidEndArray:)]
										: NULL;
	_delegateMethod.didStartObject = [theDelegate respondsToSelector:@selector(jsonParserDidStartObject:)]
										? [theDelegate methodForSelector:@selector(jsonParserDidStartObject:)]
										: NULL;
	_delegateMethod.didEndObject = [theDelegate respondsToSelector:@selector(jsonParserDidEndObject:)]
										? [theDelegate methodForSelector:@selector(jsonParserDidEndObject:)]
										: NULL;
	_delegateMethod.shouldSkipValueForKey = [theDelegate respondsToSelector:@selector(jsonParser:shouldSkipValueForKey:)]
										? [theDelegate methodForSelector:@selector(jsonParser:shouldSkipValueForKey:)]
										: NULL;
	_delegateMethod.foundKey = [theDelegate respondsToSelector:@selector(jsonParser:foundKey:)]
										? [theDelegate methodForSelector:@selector(jsonParser:foundKey:)]
										: NULL;
	_delegateMethod.foundString = [theDelegate respondsToSelector:@selector(jsonParser:foundString:)]
										? [theDelegate methodForSelector:@selector(jsonParser:foundString:)]
										: NULL;
	_delegateMethod.foundNumber = [theDelegate respondsToSelector:@selector(jsonParser:foundNumber:)]
										? [theDelegate methodForSelector:@selector(jsonParser:foundNumber:)]
										: NULL;
	_delegateMethod.foundInteger = [theDelegate respondsToSelector:@selector(jsonParser:foundInteger:)]
										? [theDelegate methodForSelector:@selector(jsonParser:foundInteger:)]
										: NULL;
	_delegateMethod.foundFloat = [theDelegate respondsToSelector:@selector(jsonParser:foundFloat:)]
										? [theDelegate methodForSelector:@selector(jsonParser:foundFloat:)]
										: NULL;
	_delegateMethod.foundBool = [theDelegate respondsToSelector:@selector(jsonParser:foundBool:)]
										? [theDelegate methodForSelector:@selector(jsonParser:foundBool:)]
										: NULL;
	_delegateMethod.foundNULL = [theDelegate respondsToSelector:@selector(jsonParserFoundNULL:)]
										? [theDelegate methodForSelector:@selector(jsonParserFoundNULL:)]
										: NULL;
	_delegateMethod.foundError = [theDelegate respondsToSelector:@selector(jsonParser:error:)]
										? [theDelegate methodForSelector:@selector(jsonParser:error:)]
										: NULL;
}

- (void)abortParsing { _complete = _abort = YES; }

static uint32_t integerForHexidecimalDigit( uint32_t d )
{
	switch (d)
	{
	case '0'...'9': return d-'0';
	case 'a'...'f': return d-'a'+10;
	case 'A'...'F': return d-'A'+10;
	default:		return UINT32_MAX;			// error
	}
}

static uint32_t convertedBytes( NDJSONParser * self )
{
	uint32_t	theResult = '\0';
	switch( self->_character.wordSize )
	{
	case kNDJONCharacterWord8:
		theResult = self->_bytes.word8[self->_position];
		break;
	case kNDJSONCharacterWord16:
		theResult = self->_bytes.word16[self->_position];
		if( self->_position == 0 )
		{
			if( theResult == k16BitLittleEndianBOM )
			{
				self->_character.endian = kNDJSONLittleEndian;
				theResult = ' ';
			}
			else if( theResult == k16BitBigEndianBOM )
			{
				self->_character.endian = kNDJSONBigEndian;
				theResult = 0x2000;
			}
			else if( self->_character.endian == kNDJSONUnknownEndian )
			{
				if( (theResult & 0xFF00) == 0 )			// first character is most likly < 256
					self->_character.endian = kNDJSONLittleEndian;
				else if( (theResult & 0x00FF) == 0 )			// first character is most likly < 256
					self->_character.endian = kNDJSONBigEndian;
				else
					self->_character.endian = kNDJSONLittleEndian;
			}
		}
		if( self->_character.endian == kNDJSONBigEndian )
			theResult = CFSwapInt16BigToHost((uint16_t)theResult);
		else
			theResult = CFSwapInt16HostToLittle((uint16_t)theResult);
		break;
	case kNDJSONCharacterWord32:
		theResult = self->_bytes.word32[self->_position];
		if( self->_position == 0 )
		{
			if( theResult == k32BitLittleEndianBOM )
			{
				self->_character.endian = kNDJSONLittleEndian;
				theResult = ' ';
			}
			else if( theResult == k32BitBigEndianBOM )
			{
				self->_character.endian = kNDJSONBigEndian;
				theResult = 0x20000000;
			}
			else if( self->_character.endian == kNDJSONUnknownEndian )
			{
				if( (theResult & 0xFFFF0000) == 0 )			// first character is most likly < 65536
					self->_character.endian = kNDJSONLittleEndian;
				else if( (theResult & 0x0000FFFF) == 0 )			// first character is most likly < 65536
					self->_character.endian = kNDJSONBigEndian;
				else
					self->_character.endian = kNDJSONLittleEndian;
			}
		}
		if( self->_character.endian == kNDJSONBigEndian )
			theResult = CFSwapInt32BigToHost(theResult);
		else
			theResult = CFSwapInt32HostToLittle(theResult);
		break;
	}
	return theResult;
}

static uint32_t currentChar( NDJSONParser * self )
{
	uint32_t	theResult = '\0';
#ifdef NDJSONSupportUTF8Only
	if( self->_position >= self->_numberOfBytes && !self->_abort )
	{
#else
	if( self->_position >= self->_numberOfBytes>>self->_character.wordSize && !self->_abort )
	{
		/*
			if numberOfBytes was not a multiple of character word size then we need to copy the partial word
			to the begining of the buffer and append the next block onto the end, to comple the last character.
		 */
		NSUInteger		theRemainingLen = self->_numberOfBytes&((1<<self->_character.wordSize)-1);
		if( theRemainingLen > 0 )
			memcpy(self->_inputBytes, self->_inputBytes+self->_numberOfBytes-theRemainingLen, theRemainingLen );
#endif
		switch (self->_inputType)
		{
		case kJSONStreamInputType:
#ifdef NDJSONSupportUTF8Only
			self->_numberOfBytes = (NSUInteger)[self->_source.object read:self->_inputBytes maxLength:kBufferSize];
#else
			self->_numberOfBytes = (NSUInteger)[self->_source.object read:self->_inputBytes+theRemainingLen maxLength:kBufferSize-theRemainingLen] + theRemainingLen;
#endif
			break;
		case kJSONStreamFunctionType:
#ifdef NDJSONSupportUTF8Only
			self->_numberOfBytes = (NSUInteger)self->_source.function(&self->_inputBytes, self->_source.context);
#else
			self->_numberOfBytes = (NSUInteger)self->_source.function(&self->_inputBytes+theRemainingLen, self->_source.context) + theRemainingLen;
#endif
			self->_bytes.word8 = self->_inputBytes;
			break;
		case kJSONStreamBlockType:
#ifdef NDJSONSupportUTF8Only
			self->_numberOfBytes = (NSUInteger)self->_source.block(&self->_inputBytes);
#else
			self->_numberOfBytes = (NSUInteger)self->_source.block(&self->_inputBytes+theRemainingLen) + theRemainingLen;
#endif
			self->_bytes.word8 = self->_inputBytes;
			break;
		case kJSONURLRequestType:
			break;
		default:
			self->_complete = YES;
			break;
		}
		if( self->_numberOfBytes > 0 )
			self->_position = 0;
		else
			self->_complete = YES;
	}

	if( !self->_complete )
	{
#ifdef NDJSONSupportUTF8Only
		theResult = self->_bytes.word8[self->_position];
#else
		theResult = convertedBytes( self );
#endif
	}
	return theResult;
}

static uint32_t nextChar( NDJSONParser * self )
{
	if( !self->_useBackUpByte )
	{
		self->_backUpByte = currentChar( self );
		if( self->_backUpByte != '\0' )
		{
			self->_position++;
			if( self->_backUpByte == '\n' )
				self->_lineNumber++;
		}
#ifdef NDJSONPrintStream
		putc((int)self->_backUpByte, stderr);
#endif
	}
	else
		self->_useBackUpByte = NO;
	return self->_backUpByte;
}
static uint32_t nextCharIgnoreWhiteSpace( NDJSONParser * self )
{
	uint32_t		theResult;
	if( self->_options.strictJSONOnly )				// skip white space only
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

static void backUp( NDJSONParser * self ) { self->_useBackUpByte = YES; }

BOOL parseInputData( NDJSONParser * self )
{
	BOOL		theResult = NO;
	NSCParameterAssert( self->_bytes.word8 != NULL );
	NSCParameterAssert( self->_source.object != nil );
	theResult = parseJSONUnknown( self );
	[self->_source.object release], self->_source.object = nil;
	return theResult;
}

BOOL parseInputStream( NDJSONParser * self )
{
	BOOL		theResult = NO;
	NSCParameterAssert( self->_source.object != nil );
	[self->_source.object open];
	theResult = parseJSONUnknown( self );
	[self->_source.object close], [self->_source.object release], self->_source.object = nil;
	return theResult;
}

BOOL parseInputFunctionOrBlock( NDJSONParser * self )
{
	BOOL		theResult = NO;
	NSCParameterAssert( self->_source.block != nil || self->_source.function != nil );
	theResult = parseJSONUnknown( self );
	return theResult;
}
	
BOOL parseURLRequest( NDJSONParser * self )
{
	BOOL		theResult = NO;
	if( self->_source.object != nil || self->_bytes.word8 != NULL )
	{
		self->_options.strictJSONOnly = NO;
		if( self->_source.object != nil )
			[self->_source.object open];
		theResult = parseJSONUnknown( self );
		[self->_source.object close];
		self.currentKey = nil;
	}
	[self->_source.object release], self->_source.object = nil;
	return theResult;
}

BOOL parseJSONUnknown( NDJSONParser * self )
{
	BOOL		theResult = YES;
	switch( nextCharIgnoreWhiteSpace( self ) )
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

BOOL parseJSONArray( NDJSONParser * self )
{
	BOOL				theResult = YES;
	BOOL				theEnd = NO;
	NSUInteger			theCount = 0;
	if( self->_delegateMethod.didStartArray != NULL )
		self->_delegateMethod.didStartArray( self->_delegate, @selector(jsonParserDidStartArray:), self );
	
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
			if( !self->_options.strictJSONOnly )					// allow trailing comma
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
		if( self->_delegateMethod.didEndArray != NULL )
			self->_delegateMethod.didEndArray( self->_delegate, @selector(jsonParserDidEndArray:), self );
	}
errorOut:
	return theResult;
}

BOOL parseJSONObject( NDJSONParser * self )
{
	BOOL				theResult = YES;
	BOOL				theEnd = NO;
	NSUInteger			theCount = 0;
	
	if( self->_delegateMethod.didStartObject != NULL )
		self->_delegateMethod.didStartObject( self->_delegate, @selector(jsonParserDidStartObject:), self );
	
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

				if( self->_delegateMethod.foundKey != NULL )
					self->_delegateMethod.foundKey( self->_delegate, @selector(jsonParser:foundKey:), self, self.currentKey );

				if( self->_delegateMethod.shouldSkipValueForKey != NULL )
					theSkipParsingValueForCurrentKey = ((_ReturnBoolMethodIMP)self->_delegateMethod.shouldSkipValueForKey)( self->_delegate, @selector(jsonParser:shouldSkipValueForKey:), self, self.currentKey	);

				if( theSkipParsingValueForCurrentKey )
					theResult = skipNextValue(self);
				else if( !self->_hasSkippedValueForCurrentKey )
					theResult = parseJSONUnknown( self );
				else
				{
					self->_hasSkippedValueForCurrentKey = NO;
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
		if( self->_delegateMethod.didEndObject != NULL )
			self->_delegateMethod.didEndObject( self->_delegate, @selector(jsonParserDidEndObject:), self );
	}
	
	return theResult;
}

BOOL parseJSONKey( NDJSONParser * self )
{
	struct NDBytesBuffer	theBuffer = NDBytesBufferInit;
	BOOL					theResult = YES;
	if( nextCharIgnoreWhiteSpace(self) == '"' )
		theResult = parseJSONText( self, &theBuffer, YES, YES );
	else if( !self->_options.strictJSONOnly )				// keys don't have to be quoted
	{
		backUp(self);
		theResult = parseJSONText( self, &theBuffer, YES, NO );
	}
	else
		foundError( self, NDJSONBadFormatError );
	if( theResult != NO )
	{
#ifdef NDJSONSupportUTF8Only
		self.currentKey = [[NSString alloc] initWithBytes:theBuffer.bytes length:theBuffer.length encoding:NSUTF8StringEncoding];
#else
		self.currentKey = [[NSString alloc] initWithBytes:theBuffer.bytes length:theBuffer.length encoding:kNSStringEncodingFromCharacterWordSize[self->_character.wordSize]];
#endif

		NDJSONLog( @"Found key: '%@'", self.currentKey );
	}
	freeByte( &theBuffer );

	return theResult;
}

BOOL parseJSONString( NDJSONParser * self )
{
	struct NDBytesBuffer	theBuffer = NDBytesBufferInit;
	BOOL					theResult = parseJSONText( self, &theBuffer, NO, YES );
	if( theResult != NO )
	{
#ifdef NDJSONSupportUTF8Only
		NSString	* theValue = [[NSString alloc] initWithBytes:theBuffer.bytes length:theBuffer.length encoding:NSUTF8StringEncoding];
#else
		NSString	* theValue = [[NSString alloc] initWithBytes:theBuffer.bytes length:theBuffer.length encoding:kNSStringEncodingFromCharacterWordSize[self->_character.wordSize]];
#endif
		if( self->_delegateMethod.foundString != NULL )
			self->_delegateMethod.foundString( self->_delegate, @selector(jsonParser:foundString:), self, theValue );
		[theValue release];
	}
	freeByte( &theBuffer );
	return theResult;
}

BOOL parseJSONText( NDJSONParser * self, struct NDBytesBuffer * aValueBuffer, BOOL aIsKey, BOOL aIsQuotesTerminated )
{
	BOOL					theResult = YES,
							theEnd = NO;
#ifdef NDJSONSupportUTF8Only
	enum NDJSONCharacterWordSize	theWordSize = kNDJONCharacterWord8;
#else
	enum NDJSONCharacterWordSize	theWordSize = self->_character.wordSize;
#endif
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
				if( !appendBytes( aValueBuffer, theChar, theWordSize ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case 'b':
				if( !appendCharacter( aValueBuffer, '\b', theWordSize ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case 'f':
				if( !appendCharacter( aValueBuffer, '\f', theWordSize ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case 'n':
				if( !appendCharacter( aValueBuffer, '\n', theWordSize ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case 'r':
				if( !appendCharacter( aValueBuffer, '\r', theWordSize ) )
					foundError( self, NDJSONMemoryErrorError );
				break;
			case 't':
				if( !appendCharacter( aValueBuffer, '\t', theWordSize ) )
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
				if( !appendCharacter( aValueBuffer, theCharacterValue, theWordSize) )
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
			else if( !appendBytes( aValueBuffer, theChar, theWordSize ) )
				foundError( self, NDJSONMemoryErrorError );
			break;
		case '\t': case '\n': case '\v': case '\f': case '\r': case ' ':
			if( self->_options.strictJSONOnly )
				foundError( self, NDJSONBadFormatError );
			else if( !aIsQuotesTerminated )
				theEnd = YES;
			else if( !appendBytes( aValueBuffer, theChar, theWordSize ) )
				foundError( self, NDJSONMemoryErrorError );
			break;
		default:
			if( !appendBytes( aValueBuffer, theChar, theWordSize ) )
				foundError( self, NDJSONMemoryErrorError );
			break;
		}
	}
	if( !theEnd )
		foundError( self, NDJSONBadFormatError );
	return theResult;
}

BOOL parseJSONNumber( NDJSONParser * self )
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
		if( self->_delegateMethod.foundNumber != NULL )
			self->_delegateMethod.foundNumber( self->_delegate, @selector(jsonParser:foundNumber:), self, [NSNumber numberWithDouble:theValue] );
		else if( self->_delegateMethod.foundFloat != NULL )
			self->_delegateMethod.foundFloat( self->_delegate, @selector(jsonParser:foundFloat:), self, theValue );
	}
	else if( theDecimalPlaces > 0 )
	{
		if( theNegative )
			theIntegerValue = -theIntegerValue;
		if( self->_delegateMethod.foundNumber != NULL )
			self->_delegateMethod.foundNumber( self->_delegate, @selector(jsonParser:foundNumber:), self, [NSNumber numberWithInteger:theIntegerValue] );
		else if( self->_delegateMethod.foundInteger != NULL )
			self->_delegateMethod.foundInteger( self->_delegate, @selector(jsonParser:foundInteger:), self, theIntegerValue );
	}
	else
		foundError(self, NDJSONBadNumberError );
	
	if( theResult )
		backUp( self );
	return theResult;
}

BOOL parseJSONTrue( NDJSONParser * self )
{
	BOOL		theResult = YES;
	uint32_t	theChar;
	if( (theChar = nextChar(self)) == 'r' && (theChar = nextChar(self)) == 'u' && (theChar = nextChar(self)) == 'e' )
	{
		if( self->_delegateMethod.foundNumber != NULL )
			self->_delegateMethod.foundNumber( self->_delegate, @selector(jsonParser:foundNumber:), self, [NSNumber numberWithBool:YES] );
		else if( self->_delegateMethod.foundBool != NULL )
			self->_delegateMethod.foundBool( self->_delegate, @selector(jsonParser:foundBool:), self, YES );
	}
	else if( theChar == '\0' )
		theResult = NO;
	else
		foundError( self, NDJSONBadTokenError );
	return theResult;
}

BOOL parseJSONFalse( NDJSONParser * self )
{
	BOOL		theResult = YES;
	uint32_t	theChar;
	if( (theChar = nextChar(self)) == 'a' && (theChar = nextChar(self)) == 'l' && (theChar = nextChar(self)) == 's' && (theChar = nextChar(self)) == 'e' )
	{
		if( self->_delegateMethod.foundNumber != NULL )
			self->_delegateMethod.foundNumber( self->_delegate, @selector(jsonParser:foundNumber:), self, [NSNumber numberWithBool:NO] );
		else if( self->_delegateMethod.foundBool != NULL )
			self->_delegateMethod.foundBool( self->_delegate, @selector(jsonParser:foundBool:), self, NO );
	}
	else if( theChar == '\0' )
		theResult = NO;
	else
		foundError( self, NDJSONBadTokenError );
	return theResult;
}

BOOL parseJSONNull( NDJSONParser * self )
{
	BOOL		theResult = YES;
	uint32_t	theChar;
	if( (theChar = nextChar(self)) == 'u' && (theChar = nextChar(self)) == 'l' && (theChar = nextChar(self)) == 'l' )
	{
		if( self->_delegateMethod.foundNULL != NULL )
			self->_delegateMethod.foundNULL( self->_delegate, @selector(jsonParserFoundNULL:), self );
	}
	else if( theChar == '\0' )
		theResult = NO;
	else
		foundError( self, NDJSONBadTokenError );
	return theResult;
}

BOOL skipNextValue( NDJSONParser * self )
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

void foundError( NDJSONParser * self, NDJSONErrorCode aCode )
{
	NSMutableDictionary		* theUserInfo = [[NSMutableDictionary alloc] initWithObjectsAndKeys:kErrorCodeStrings[aCode],NSLocalizedDescriptionKey, nil];
	NSUInteger				thePos = self->_position > 5 ? self->_position - 5 : 5,
							theLen = self->_numberOfBytes - thePos < 10 ? self->_numberOfBytes - thePos : 10;
	NSString				* theString = nil;
	switch (aCode)
	{
	default:
	case NDJSONGeneralError:
		break;
	case NDJSONBadTokenError:
	{
		theString = [[NSString alloc] initWithFormat:@"Bad token at pos %lu, %*s", (unsigned long)self->_position, (int)theLen, self->_bytes.word8];
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
	if( self->_delegateMethod.foundError != NULL )
		self->_delegateMethod.foundError( self->_delegate, @selector(jsonParser:error:), self, [NSError errorWithDomain:NDJSONErrorDomain code:aCode userInfo:theUserInfo] );
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

BOOL appendBytes( struct NDBytesBuffer * aBuffer, uint32_t aByte, enum NDJSONCharacterWordSize aWordSize )
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
		aBuffer->_bytes[aBuffer->length] = (uint8_t)aByte;
		aBuffer->length++;
#else
		memcpy( aBuffer->bytes+aBuffer->length, &aByte, 1<<aWordSize );
		aBuffer->length += 1<<aWordSize;
#endif
	}
	return theResult;
}

BOOL appendCharacter( struct NDBytesBuffer * aBuffer, uint32_t aValue, enum NDJSONCharacterWordSize aWordSize )
{
	switch (aWordSize)
	{
	case kNDJONCharacterWord8:
		if( aValue > 0x3ffffff )				// 1111110x	10xxxxxx	10xxxxxx	10xxxxxx	10xxxxxx	10xxxxxx
		{
			if( !appendBytes( aBuffer, ((aValue>>31) & 0xf) | 0xfc, kNDJONCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, ((aValue>>30) & 0x3f) | 0x80, kNDJONCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, ((aValue>>24) & 0x3f) | 0x80, kNDJONCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, ((aValue>>18) & 0x3f) | 0x80, kNDJONCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, ((aValue>>12) & 0x3f) | 0x80, kNDJONCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, ((aValue>>6) & 0x3f) | 0x80, kNDJONCharacterWord8 ) )
				return NO;
		}
		else if( aValue > 0x1fffff )			// 111110xx	10xxxxxx	10xxxxxx	10xxxxxx	10xxxxxx
		{
			if( !appendBytes( aBuffer, ((aValue>>24) & 0x3f) | 0x80, kNDJONCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, ((aValue>>18) & 0x3f) | 0x80, kNDJONCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, ((aValue>>12) & 0x3f) | 0x80, kNDJONCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, ((aValue>>6) & 0x3f) | 0x80, kNDJONCharacterWord8 ) )
				return NO;
		}
		else if( aValue > 0xffff )				// 11110xxx	10xxxxxx	10xxxxxx	10xxxxxx
		{
			if( !appendBytes( aBuffer, ((aValue>>18) & 0x3f) | 0x80, kNDJONCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, ((aValue>>12) & 0x3f) | 0x80, kNDJONCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, ((aValue>>6) & 0x3f) | 0x80, kNDJONCharacterWord8 ) )
				return NO;
		}
		else if( aValue > 0x7ff )				// 1110xxxx	10xxxxxx	10xxxxxx
		{
			if( !appendBytes( aBuffer, ((aValue>>12) & 0xf) | 0xE0, kNDJONCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, ((aValue>>6) & 0x3f) | 0x80, kNDJONCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, (aValue & 0x3f) | 0x80, kNDJONCharacterWord8 ) )
				return NO;
		}
		else if( aValue > 0x7f )				// 110xxxxx	10xxxxxx
		{
			if( !appendBytes( aBuffer, ((aValue>>6) & 0x1f) | 0xc0, kNDJONCharacterWord8 ) )
				return NO;
			if( !appendBytes( aBuffer, (aValue & 0x3f) | 0x80, kNDJONCharacterWord8 ) )
				return NO;
		}
		else									// 0xxxxxxx
		{
			if( !appendBytes( aBuffer, aValue & 0x7f, kNDJONCharacterWord8 ) )
				return NO;
		}
		break;
	case kNDJSONCharacterWord16:
		if( aValue > 0x10ffff || (aValue >= 0Xd800 && aValue <= 0xdfff) )
		{
			NSLog( @"Bad unicode code point %x", aValue );
			return NO;
		}
		else if( aValue > 0xffff )
		{
			if( !appendBytes( aBuffer, (uint16_t)((aValue-0x10000)>>10)+0xd800, kNDJSONCharacterWord16 )
				   && !appendBytes( aBuffer, (uint16_t)((aValue-0x10000)&0x3ff)+0xdc00, kNDJSONCharacterWord16 ) )
				return NO;
		}
		else
		{
			if( !appendBytes( aBuffer, aValue & 0xffff, kNDJSONCharacterWord16 ) )
				return NO;
		}
		break;
	case kNDJSONCharacterWord32:
		if( !appendBytes( aBuffer, aValue, kNDJSONCharacterWord32 ) )
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


