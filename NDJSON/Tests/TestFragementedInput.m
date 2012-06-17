//
//  TestFragementedInput.m
//  NDJSON
//
//  Created by Nathan Day on 18/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestFragementedInput.h"
#import "TestProtocolBase.h"
#import "NDJSONParser.h"

@interface TestFragementedInput ()
@end

@interface FragementedInputStream : NSInputStream
{
	NSUInteger		position;
	NSUInteger		minBlockSize,
					maxBlockSize;
	UTF8Char		* jsonStringBytes;
	NSUInteger		jsonLength;
}

+ (id)fragementedInputWithJSON:(NSString *)json minBlockSize:(NSUInteger)minBlockSize maxBlockSize:(NSUInteger)maxBlockSize;
- (id)initWithJSON:(NSString *)json minBlockSize:(NSUInteger)minBlockSize maxBlockSize:(NSUInteger)maxBlockSize;
@end

@interface FragementedInput : TestProtocolBase
{
	NSUInteger		minBlockSize,
					maxBlockSize;
	NSString		* jsonString;					
}
+ (id)fragementedInputWithName:(NSString *)name json:(NSString *)json minBlockSize:(NSUInteger)minBlockSize maxBlockSize:(NSUInteger)maxBlockSize;
- (id)initWithName:(NSString *)aName json:(NSString *)aJSON minBlockSize:(NSUInteger)aMinBlockSize maxBlockSize:(NSUInteger)aMaxBlockSize;
@end

@implementation TestFragementedInput

- (void)addName:(NSString *)aName json:(NSString *)aJSON minBlockSize:(NSUInteger)aMinBlockSize maxBlockSize:(NSUInteger)aMaxBlockSize
{
	[self addTest:[FragementedInput fragementedInputWithName:aName json:aJSON minBlockSize:aMinBlockSize maxBlockSize:aMaxBlockSize]];
}

- (void)willLoad
{
	static		NSString	* const kJSON = @"{\"menu\":{\"header\":\"SVG Viewer\",\"items\": [{\"id\":\"Open\"},{\"id\":\"OpenNew\",\"label\":\"Open New\"},null,{\"id\":\"ZoomIn\",\"label\":\"Zoom In\"},{\"id\":\"ZoomOut\",\"label\":\"Zoom Out\"},{\"id\":\"OriginalView\",\"label\":\"Original View\"},null,{\"id\":\"Quality\"},{\"id\":\"Pause\"},{\"id\":\"Mute\"},null,{\"id\":\"Find\",\"label\":\"Find...\"},{\"id\":\"FindAgain\",\"label\":\"Find Again\"},{\"id\":\"Copy\"},{\"id\":\"CopyAgain\",\"label\":\"Copy Again\"},{\"id\":\"CopySVG\",\"label\":\"Copy SVG\"},{\"id\":\"ViewSVG\",\"label\":\"View SVG\"},{\"id\":\"ViewSource\",\"label\":\"View Source\"},{\"id\":\"SaveAs\",\"label\":\"Save As\"},null,{\"id\":\"Help\"},{\"id\":\"About\",\"label\":\"About Adobe CVG Viewer...\"}]}}";
	[self addName:@"100 bytes" json:kJSON minBlockSize:100 maxBlockSize:100];
	[self addName:@"50 bytes" json:kJSON minBlockSize:50 maxBlockSize:50];
	[self addName:@"10 bytes" json:kJSON minBlockSize:10 maxBlockSize:10];
	[self addName:@"5 bytes" json:kJSON minBlockSize:5 maxBlockSize:5];
	[self addName:@"1 bytes" json:kJSON minBlockSize:1 maxBlockSize:1];
	[self addName:@"(50,100) bytes" json:kJSON minBlockSize:10 maxBlockSize:20];
	[self addName:@"(10,50) bytes" json:kJSON minBlockSize:10 maxBlockSize:20];
	[self addName:@"(1,5) bytes" json:kJSON minBlockSize:1 maxBlockSize:5];
	[self addName:@"(1,100) bytes" json:kJSON minBlockSize:1 maxBlockSize:100];
}

@end

@implementation FragementedInput

+ (id)fragementedInputWithName:(NSString *)aName json:(NSString *)aJSON minBlockSize:(NSUInteger)aMinBlockSize maxBlockSize:(NSUInteger)aMaxBlockSize
{
	return [[[self alloc] initWithName:aName json:aJSON minBlockSize:aMinBlockSize maxBlockSize:aMaxBlockSize] autorelease];
}
- (id)initWithName:(NSString *)aName json:(NSString *)aJSON minBlockSize:(NSUInteger)aMinBlockSize maxBlockSize:(NSUInteger)aMaxBlockSize
{
	if( (self = [super initWithName:aName]) != nil )
	{
		minBlockSize = aMinBlockSize;
		maxBlockSize = aMaxBlockSize;
		jsonString = [aJSON copy];
	}
	return self;
}

- (NSString *)details
{
	return [NSString stringWithFormat:@"block size range: {%lu,%lu}\n\njson:\n%@\n\nresult:\n%@\n\n", minBlockSize, maxBlockSize, jsonString, self.lastResult];
}

- (id)run
{
	NSError				* theError = nil;
	NDJSON				* theJSON = [[NDJSON alloc] init];
	NDJSONParser		* theJSONParser = [[NDJSONParser alloc] init];
	[theJSON setInputStream:[FragementedInputStream fragementedInputWithJSON:jsonString minBlockSize:minBlockSize maxBlockSize:maxBlockSize]  encoding:NSUTF8StringEncoding];
	self.lastResult = [theJSONParser objectForJSONParser:theJSON options:NDJSONOptionNone error:&theError];
	self.error = theError;
	[theJSONParser release];
	[theJSON release];
	return lastResult;
}

@end

@implementation FragementedInputStream

+ (id)fragementedInputWithJSON:(NSString *)aJSON minBlockSize:(NSUInteger)aMinBlockSize maxBlockSize:(NSUInteger)aMaxBlockSize
{
	return [[[self alloc] initWithJSON:aJSON minBlockSize:aMinBlockSize maxBlockSize:aMaxBlockSize] autorelease];
}
- (id)initWithJSON:(NSString *)aJSON minBlockSize:(NSUInteger)aMinBlockSize maxBlockSize:(NSUInteger)aMaxBlockSize
{
	if( (self = [super init]) != nil )
	{
		jsonLength = [aJSON lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
		jsonStringBytes = malloc( jsonLength );
		memcpy( jsonStringBytes, [aJSON UTF8String], jsonLength );
		minBlockSize = aMinBlockSize;
		maxBlockSize = aMaxBlockSize;
	}
	return self;
}

- (void)open
{
	position = 0;
}

- (void)close
{
	
}

- (NSInteger)read:(uint8_t *)aBuffer maxLength:(NSUInteger)aBufferLength
{
	NSInteger		theLen = -1;
	if( position < jsonLength )
	{
		theLen = maxBlockSize == minBlockSize
								? minBlockSize
								: (random() % (maxBlockSize-minBlockSize)) + minBlockSize;
		if( theLen >= aBufferLength )
			theLen = aBufferLength;
		if( theLen + position >= jsonLength )
			theLen = jsonLength - position;
		memcpy( aBuffer, jsonStringBytes+position, theLen );
		position += theLen;
	}
	return theLen;
}

- (BOOL)getBuffer:(uint8_t **)aBuffer length:(NSUInteger *)aLength
{
	BOOL	theResult = NO;
	if( position < jsonLength )
	{
		*aLength = maxBlockSize == minBlockSize
									? minBlockSize
									: (random() % (maxBlockSize-minBlockSize)) + minBlockSize;
		if( *aLength + position >= jsonLength )
			*aLength = jsonLength - position;
		*aBuffer = jsonStringBytes+position;
		position += *aLength;
		theResult = YES;
	}
	return theResult;
}

- (BOOL)hasBytesAvailable
{
	return position < jsonLength;
}

@end
