//
//  TestFragementedInput.m
//  NDJSON
//
//  Created by Nathan Day on 18/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestFragementedInput.h"
#import "TestProtocolBase.h"
#import "NDJSONDeserializer.h"
#import "NSObject+TestUtilities.h"

@interface TestFragementedInput ()
@end

@interface FragementedInputStream : NSInputStream
{
	NSUInteger		_position;
	NSUInteger		_minBlockSize,
					_maxBlockSize;
	UTF8Char		* _jsonStringBytes;
	NSUInteger		_jsonLength;
}

+ (id)fragementedInputWithJSON:(NSString *)json minBlockSize:(NSUInteger)minBlockSize maxBlockSize:(NSUInteger)maxBlockSize usingEncoding:(NSStringEncoding)encoding;
- (id)initWithJSON:(NSString *)json minBlockSize:(NSUInteger)minBlockSize maxBlockSize:(NSUInteger)maxBlockSize usingEncoding:(NSStringEncoding)encoding;
@end

@interface FragementedInput : TestProtocolBase
{
	NSUInteger			_minBlockSize,
						_maxBlockSize;
	NSString			* _jsonString;
	NSStringEncoding	_encoding;
}
+ (id)fragementedInputWithName:(NSString *)name json:(NSString *)json minBlockSize:(NSUInteger)minBlockSize maxBlockSize:(NSUInteger)maxBlockSize  usingEncoding:(NSStringEncoding)encoding;
- (id)initWithName:(NSString *)aName json:(NSString *)aJSON minBlockSize:(NSUInteger)aMinBlockSize maxBlockSize:(NSUInteger)aMaxBlockSize usingEncoding:(NSStringEncoding)encoding;
@end

@implementation TestFragementedInput

- (NSString *)testDescription { return @"Test fragmented input, parsing small blocks of bytes when available"; }

- (void)addName:(NSString *)aName json:(NSString *)aJSON minBlockSize:(NSUInteger)aMinBlockSize maxBlockSize:(NSUInteger)aMaxBlockSize usingEncoding:(NSStringEncoding)anEncoding
{
	[self addTest:[FragementedInput fragementedInputWithName:aName json:aJSON minBlockSize:aMinBlockSize maxBlockSize:aMaxBlockSize usingEncoding:anEncoding]];
}

- (void)willLoad
{
	static		NSString	* const kJSON = @"{\"menu\":{\"header\":\"SVG Viewer\",\"items\": [{\"id\":\"Open\"},{\"id\":\"OpenNew\",\"label\":\"Open New\"},null,{\"id\":\"ZoomIn\",\"label\":\"Zoom In\"},{\"id\":\"ZoomOut\",\"label\":\"Zoom Out\"},{\"id\":\"OriginalView\",\"label\":\"Original View\"},null,{\"id\":\"Quality\"},{\"id\":\"Pause\"},{\"id\":\"Mute\"},null,{\"id\":\"Find\",\"label\":\"Find...\"},{\"id\":\"FindAgain\",\"label\":\"Find Again\"},{\"id\":\"Copy\"},{\"id\":\"CopyAgain\",\"label\":\"Copy Again\"},{\"id\":\"CopySVG\",\"label\":\"Copy SVG\"},{\"id\":\"ViewSVG\",\"label\":\"View SVG\"},{\"id\":\"ViewSource\",\"label\":\"View Source\"},{\"id\":\"SaveAs\",\"label\":\"Save As\"},null,{\"id\":\"Help\"},{\"id\":\"About\",\"label\":\"About Adobe CVG Viewer...\"}]}}",
							* const kJSON2 = @"{\"a\":true,\"b\":\"string\",\"c\":42}";
	[self addName:@"100 bytes" json:kJSON minBlockSize:100 maxBlockSize:100 usingEncoding:NSUTF8StringEncoding];
	[self addName:@"50 bytes" json:kJSON minBlockSize:50 maxBlockSize:50 usingEncoding:NSUTF8StringEncoding];
	[self addName:@"10 bytes" json:kJSON minBlockSize:10 maxBlockSize:10 usingEncoding:NSUTF8StringEncoding];
	[self addName:@"5 bytes" json:kJSON minBlockSize:5 maxBlockSize:5 usingEncoding:NSUTF8StringEncoding];
	[self addName:@"1 bytes" json:kJSON minBlockSize:1 maxBlockSize:1 usingEncoding:NSUTF8StringEncoding];
	[self addName:@"(50,100) bytes" json:kJSON minBlockSize:10 maxBlockSize:20 usingEncoding:NSUTF8StringEncoding];
	[self addName:@"(10,50) bytes" json:kJSON minBlockSize:10 maxBlockSize:20 usingEncoding:NSUTF8StringEncoding];
	[self addName:@"(1,5) bytes" json:kJSON minBlockSize:1 maxBlockSize:5 usingEncoding:NSUTF8StringEncoding];
	[self addName:@"(1,100) bytes" json:kJSON minBlockSize:1 maxBlockSize:100 usingEncoding:NSUTF8StringEncoding];
	[self addName:@"(5,8) bytes, 32 bit characters" json:kJSON2 minBlockSize:5 maxBlockSize:8 usingEncoding:NSUTF32StringEncoding];
}

@end

@implementation FragementedInput

+ (id)fragementedInputWithName:(NSString *)aName json:(NSString *)aJSON minBlockSize:(NSUInteger)aMinBlockSize maxBlockSize:(NSUInteger)aMaxBlockSize usingEncoding:(NSStringEncoding)anEncoding
{
	return [[self alloc] initWithName:aName json:aJSON minBlockSize:aMinBlockSize maxBlockSize:aMaxBlockSize usingEncoding:anEncoding];
}
- (id)initWithName:(NSString *)aName json:(NSString *)aJSON minBlockSize:(NSUInteger)aMinBlockSize maxBlockSize:(NSUInteger)aMaxBlockSize usingEncoding:(NSStringEncoding)anEncoding
{
	if( (self = [super initWithName:aName]) != nil )
	{
		_minBlockSize = aMinBlockSize;
		_maxBlockSize = aMaxBlockSize;
		_jsonString = [aJSON copy];
		_encoding = anEncoding;
	}
	return self;
}

- (NSString *)details
{
	return [NSString stringWithFormat:@"block size range: {%lu,%lu}\n\njson:\n%@\n\nresult:\n%@\n\n", _minBlockSize, _maxBlockSize, _jsonString, [self.lastResult detailedDescription]];
}

- (id)run
{
	NSError					* theError = nil;
	NDJSONParser			* theJSON = [[NDJSONParser alloc] initWithInputStream:[FragementedInputStream fragementedInputWithJSON:_jsonString minBlockSize:_minBlockSize maxBlockSize:_maxBlockSize usingEncoding:_encoding]  encoding:_encoding];
	NDJSONDeserializer		* theJSONParser = [[NDJSONDeserializer alloc] init];
	self.lastResult = [theJSONParser objectForJSON:theJSON options:NDJSONOptionNone error:&theError];
	self.error = theError;
	return lastResult;
}

@end

@implementation FragementedInputStream

+ (id)fragementedInputWithJSON:(NSString *)aJSON minBlockSize:(NSUInteger)aMinBlockSize maxBlockSize:(NSUInteger)aMaxBlockSize usingEncoding:(NSStringEncoding)anEncoding
{
	return [[self alloc] initWithJSON:aJSON minBlockSize:aMinBlockSize maxBlockSize:aMaxBlockSize usingEncoding:anEncoding];
}
- (id)initWithJSON:(NSString *)aJSON minBlockSize:(NSUInteger)aMinBlockSize maxBlockSize:(NSUInteger)aMaxBlockSize usingEncoding:(NSStringEncoding)anEncoding
{
	if( (self = [super init]) != nil )
	{
		_jsonLength = [aJSON lengthOfBytesUsingEncoding:anEncoding];
		_jsonStringBytes = malloc( _jsonLength );
		NSParameterAssert([aJSON getBytes:_jsonStringBytes maxLength:_jsonLength usedLength:NULL encoding:anEncoding options:0 range:NSMakeRange(0,aJSON.length) remainingRange:NULL]);
		_minBlockSize = aMinBlockSize;
		_maxBlockSize = aMaxBlockSize;
	}
	return self;
}

- (void)open { _position = 0; }
- (void)close { }

- (NSInteger)read:(uint8_t *)aBuffer maxLength:(NSUInteger)aBufferLength
{
	NSInteger		theLen = -1;
	if( _position < _jsonLength )
	{
		theLen = _maxBlockSize == _minBlockSize
								? (NSInteger)_minBlockSize
								: (random() % (NSInteger)(_maxBlockSize-_minBlockSize)) + (NSInteger)_minBlockSize;
		if( theLen >= (NSInteger)aBufferLength )
			theLen = (NSInteger)aBufferLength;
		if( theLen + (NSInteger)_position >= (NSInteger)_jsonLength )
			theLen = (NSInteger)_jsonLength - (NSInteger)_position;
		memcpy( aBuffer, _jsonStringBytes+_position, theLen );
		_position += (NSUInteger)theLen;
	}
	return theLen;
}

- (BOOL)getBuffer:(uint8_t **)aBuffer length:(NSUInteger *)aLength
{
	BOOL	theResult = NO;
	if( _position < _jsonLength )
	{
		*aLength = _maxBlockSize == _minBlockSize
									? _minBlockSize
									: ((NSUInteger)random() % (_maxBlockSize-_minBlockSize)) + _minBlockSize;
		if( *aLength + _position >= _jsonLength )
			*aLength = _jsonLength - _position;
		*aBuffer = _jsonStringBytes+_position;
		_position += *aLength;
		theResult = YES;
	}
	return theResult;
}

- (BOOL)hasBytesAvailable { return _position < _jsonLength; }

@end
