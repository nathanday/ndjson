//
//  TestFragementedInput.m
//  NDJSON
//
//  Created by Nathan Day on 18/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestFragementedInput.h"
#import "TestProtocolBase.h"
#import "NDJSON.h"

@interface TestFragementedInput ()
@end

@interface FragementedInputStream : NSInputStream
{
	NSUInteger		position;
	NSUInteger		minBlockSize,
					maxBlockSize;
	NSString		* jsonString;					
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
}

@end

@implementation FragementedInput

+ (id)fragementedInputWithName:(NSString *)aName json:(NSString *)aJSON minBlockSize:(NSUInteger)aMinBlockSize maxBlockSize:(NSUInteger)aMaxBlockSize
{
	return [[[self alloc] initWithName:aName jsonaJSON minBlockSize:aMinBlockSize maxBlockSize:aMaxBlockSize] autorelease];
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
	NSError		* theError = nil;
	NDJSON		* theJSON = [[NDJSON alloc] init];
	self.lastResult = [theJSON asynchronousParseInputStream:[FragementedInputStream fragementedInputWithJSON:jsonString minBlockSize:minBlockSize maxBlockSize:maxBlockSize] error:&theError];
	self.error = theError;
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
		jsonString = [aJSON copy];
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

- (NSInteger)readBuffer:(uint8_t *)aBuffer maxLength:(NSUInteger)aBufferLength
{
	NSInteger		theLen = -1;
	if( position < jsonString.length )
	{
		const char		* theUTF8Str = [jsonString UTF8String];
		NSUInteger		theLen = (random() % (maxBlockSize-minBlockSize)) + minBlockSize;
		if( theLen >= aBufferLength )
			theLen = aBufferLength;
		if( theLen + position >= jsonString.length )
			theLen = jsonString.length - position;
		memcpy( aBuffer, theUTF8Str+position, theLen );
		position += theLen;
	}
	return theLen;
}

@end
