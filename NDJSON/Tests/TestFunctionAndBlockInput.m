/*
	TestFunctionAndBlockInput.m
	NDJSON

	Created by Nathan Day on 18/09/11.
	Copyright (c) 2011 Nathan Day. All rights reserved.
 */

#import "TestFunctionAndBlockInput.h"
#import "TestProtocolBase.h"
#import "NDJSONDeserializer.h"
#import "NSObject+TestUtilities.h"

@interface TestFunctionAndBlockInput ()
@end

@interface InputFunctionSource : NSObject
{
	NSUInteger		position;
	NSUInteger		minBlockSize,
					maxBlockSize;
	UTF8Char		* jsonStringBytes;
	NSUInteger		jsonLength;
}

- (id)initWithJSON:(NSString *)json minBlockSize:(NSUInteger)minBlockSize maxBlockSize:(NSUInteger)maxBlockSize;
NSInteger sourceFuction(uint8_t ** aBuffer, void * aContext );
@end

@interface FragementedFuncInput : TestProtocolBase
{
	NSUInteger						minBlockSize,
									maxBlockSize;
	BOOL							 useBlock;
	__strong NSString				* jsonString;
	__strong InputFunctionSource	* inputFunctionSource;
}
+ (id)fragementedInputWithName:(NSString *)name json:(NSString *)json minBlockSize:(NSUInteger)minBlockSize maxBlockSize:(NSUInteger)maxBlockSize useBlock:(BOOL)useBlock;
- (id)initWithName:(NSString *)aName json:(NSString *)aJSON minBlockSize:(NSUInteger)aMinBlockSize maxBlockSize:(NSUInteger)aMaxBlockSize useBlock:(BOOL)useBlock;
@end

@implementation TestFunctionAndBlockInput

- (NSString *)testDescription { return @"Test user supplied function or block to supply input, also happens to test fragmented input."; }

- (void)addName:(NSString *)aName json:(NSString *)aJSON minBlockSize:(NSUInteger)aMinBlockSize maxBlockSize:(NSUInteger)aMaxBlockSize useBlock:(BOOL)aUseBlock
{
	[self addTest:[FragementedFuncInput fragementedInputWithName:aName json:aJSON minBlockSize:aMinBlockSize maxBlockSize:aMaxBlockSize useBlock:aUseBlock]];
}

- (void)willLoad
{
	static		NSString	* const kJSON = @"{\"menu\":{\"header\":\"SVG Viewer\",\"items\": [{\"id\":\"Open\"},{\"id\":\"OpenNew\",\"label\":\"Open New\"},null,{\"id\":\"ZoomIn\",\"label\":\"Zoom In\"},{\"id\":\"ZoomOut\",\"label\":\"Zoom Out\"},{\"id\":\"OriginalView\",\"label\":\"Original View\"},null,{\"id\":\"Quality\"},{\"id\":\"Pause\"},{\"id\":\"Mute\"},null,{\"id\":\"Find\",\"label\":\"Find...\"},{\"id\":\"FindAgain\",\"label\":\"Find Again\"},{\"id\":\"Copy\"},{\"id\":\"CopyAgain\",\"label\":\"Copy Again\"},{\"id\":\"CopySVG\",\"label\":\"Copy SVG\"},{\"id\":\"ViewSVG\",\"label\":\"View SVG\"},{\"id\":\"ViewSource\",\"label\":\"View Source\"},{\"id\":\"SaveAs\",\"label\":\"Save As\"},null,{\"id\":\"Help\"},{\"id\":\"About\",\"label\":\"About Adobe CVG Viewer...\"}]}}";
	[self addName:@"100 bytes function" json:kJSON minBlockSize:100 maxBlockSize:100 useBlock:NO];
	[self addName:@"(10,200) bytes function" json:kJSON minBlockSize:10 maxBlockSize:200 useBlock:NO];
	[self addName:@"100 bytes block" json:kJSON minBlockSize:100 maxBlockSize:100 useBlock:YES];
	[self addName:@"(10,200) bytes block" json:kJSON minBlockSize:10 maxBlockSize:200 useBlock:YES];
}

@end

@implementation FragementedFuncInput

+ (id)fragementedInputWithName:(NSString *)aName json:(NSString *)aJSON minBlockSize:(NSUInteger)aMinBlockSize maxBlockSize:(NSUInteger)aMaxBlockSize useBlock:(BOOL)aUseBlock
{
	return [[self alloc] initWithName:aName json:aJSON minBlockSize:aMinBlockSize maxBlockSize:aMaxBlockSize useBlock:aUseBlock];
}
- (id)initWithName:(NSString *)aName json:(NSString *)aJSON minBlockSize:(NSUInteger)aMinBlockSize maxBlockSize:(NSUInteger)aMaxBlockSize useBlock:(BOOL)aUseBlock
{
	if( (self = [super initWithName:aName]) != nil )
	{
		minBlockSize = aMinBlockSize;
		maxBlockSize = aMaxBlockSize;
		jsonString = [aJSON copy];
		useBlock =  aUseBlock;
	}
	return self;
}

- (NSString *)details
{
	return [NSString stringWithFormat:@"block size range: {%lu,%lu}\n\njson:\n%@\n\nresult:\n%@\n\n", minBlockSize, maxBlockSize, jsonString, [self.lastResult detailedDescription]];
}

- (id)run
{
	NSError					* theError = nil;
	NDJSONParser			* theJSON = nil;
	NDJSONDeserializer		* theJSONParser = [[NDJSONDeserializer alloc] init];
	inputFunctionSource = [[InputFunctionSource alloc] initWithJSON:jsonString minBlockSize:minBlockSize maxBlockSize:maxBlockSize];
	if( useBlock )
		theJSON = [[NDJSONParser alloc] initWithSourceBlock:^(uint8_t ** aBuffer){return sourceFuction(aBuffer, (__bridge void *)(inputFunctionSource));} encoding:NSUTF8StringEncoding];
	else
		theJSON = [[NDJSONParser alloc] initWithSourceFunction:sourceFuction context:(__bridge void *)(inputFunctionSource) encoding:NSUTF8StringEncoding];
	self.lastResult = [theJSONParser objectForJSON:theJSON options:NDJSONOptionNone error:&theError];
	self.error = theError;
	return lastResult;
}

@end

@implementation InputFunctionSource

- (id)initWithJSON:(NSString *)aJSON minBlockSize:(NSUInteger)aMinBlockSize maxBlockSize:(NSUInteger)aMaxBlockSize
{
	if( (self = [super init]) != nil )
	{
		jsonLength = [aJSON lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
		jsonStringBytes = malloc( jsonLength );
		memcpy( jsonStringBytes, [aJSON UTF8String], jsonLength );
		minBlockSize = aMinBlockSize;
		maxBlockSize = aMaxBlockSize;
		position = 0;
	}
	return self;
}

NSInteger sourceFuction(uint8_t ** aBuffer, void * aContext )
{
	InputFunctionSource		* self = (__bridge InputFunctionSource*)aContext;
	NSUInteger	theResult = 0;
	if( self->position < self->jsonLength )
	{
		theResult = self->maxBlockSize == self->minBlockSize
						? self->minBlockSize
						: (((NSUInteger)random() % (self->maxBlockSize-self->minBlockSize)) + self->minBlockSize);
		if( theResult + self->position >= self->jsonLength )
			theResult = self->jsonLength - self->position;
		*aBuffer = self->jsonStringBytes+self->position;
		self->position += theResult;
	}
	return (NSInteger)theResult;
}

@end
