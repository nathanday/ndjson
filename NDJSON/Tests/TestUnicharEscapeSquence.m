//
//  TestUnicharEscapeSquence.m
//  NDJSON
//
//  Created by Nathan Day on 6/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestUnicharEscapeSquence.h"
#import "NDJSONDeserializer.h"
#import "TestProtocolBase.h"
#import "NSObject+TestUtilities.h"


@interface TestUnicharEscapeSquence ()
- (void)addName:(NSString *)aName firstCharacter:(NSUInteger)aStart lastCharacter:(NSUInteger)anEnd;
- (void)addName:(NSString *)aName characterRange:(NSRange)aCharacterRange;
@end

@interface EscapeSquences : TestProtocolBase
{
	NSRange			characterRange;
}
- (id)initWithName:(NSString *)aName characterRange:(NSRange)aCharacterRange;

@property(readonly)			NSString			* jsonString;
@property(readonly)			id					expectedResult;
@end

@implementation TestUnicharEscapeSquence

- (NSString *)testDescription { return @"Test \\u escape sequences and how they are converted into utf-8"; }

- (void)addName:(NSString *)aName firstCharacter:(NSUInteger)aStart lastCharacter:(NSUInteger)anEnd
{
	[self addName:aName characterRange:NSMakeRange(aStart, anEnd-aStart)];
}
- (void)addName:(NSString *)aName characterRange:(NSRange)aCharacterRange
{
	EscapeSquences		* theEscapeSquences = [[EscapeSquences alloc] initWithName:aName characterRange:aCharacterRange];
	[self addTest:theEscapeSquences];
}

- (void)willLoad
{
	[super willLoad];
	[self addName:@"7bit characters (ASCII)" firstCharacter:'a' lastCharacter:'z'];
	[self addName:@"9bit characters" firstCharacter:0x100 lastCharacter:0x120];
	[self addName:@"11bit characters" firstCharacter:0x100 lastCharacter:0x120];
	[self addName:@"12bit characters" firstCharacter:0x800 lastCharacter:0x820];
	[self addName:@"13bit characters" firstCharacter:0x1000 lastCharacter:0x1020];
	[self addName:@"16bit characters" firstCharacter:0x8000 lastCharacter:0x8020];
}

@end

@implementation EscapeSquences

@synthesize		expectedResult,
				jsonString;

#pragma mark - manually implemented properties

- (NSString *)details
{
	return [NSString stringWithFormat:@"json:\n%@\n\nresult:\n%@\n\nexpected result:\n%@\n\n", self.jsonString, [self.lastResult detailedDescription], [self.expectedResult detailedDescription]];
}

- (NSString *)jsonString
{
	NSMutableString			* theResult = [NSMutableString stringWithString:@"{\"result\":\""];
	for( NSUInteger theIndex = characterRange.location; theIndex < characterRange.location+characterRange.length; theIndex++ )
		[theResult appendFormat:@"\\u%04lx",theIndex];
	[theResult appendString:@"\"}"];
	return theResult;
}

- (id)expectedResult
{
	NSMutableString			* theString = [NSMutableString stringWithCapacity:characterRange.length];
	for( unichar theIndex = (unichar)characterRange.location; theIndex < characterRange.location+characterRange.length; theIndex++ )
		[theString appendFormat:@"%C",theIndex];
	return [NSDictionary dictionaryWithObject:theString forKey:@"result"];
}

#pragma mark - creation and destruction

- (id)initWithName:(NSString *)aName characterRange:(NSRange)aCharacterRange;
{
	if( (self = [super initWithName:aName]) != nil )
		characterRange = aCharacterRange;
	return self;
}

#pragma mark - execution

- (id)run
{
	NSError					* theError = nil;
	NDJSONParser			* theJSON = [[NDJSONParser alloc] initWithJSONString:self.jsonString];
	NDJSONDeserializer		* theJSONParser = [[NDJSONDeserializer alloc] init];
	id						theResult = [theJSONParser objectForJSON:theJSON options:NDJSONOptionNone error:&theError];
	self.lastResult = theResult;
	self.error = theError;
	return self.lastResult;
}

#pragma mark - NSObject overridden methods

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@, name: %@", [self class], self.name];
}


@end

