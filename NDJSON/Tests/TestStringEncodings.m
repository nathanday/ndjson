//
//  TestStringEncodings.m
//  NDJSON
//
//  Created by Nathan Day on 6/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestStringEncodings.h"
#import "NDJSONDeserializer.h"
#import "TestProtocolBase.h"
#import "NSObject+TestUtilities.h"

@interface TestStringEncodings ()
- (void)addName:(NSString *)name jsonString:(NSString *)json expectedResult:(id)expectedResult encoding:(NSStringEncoding)encoding;
@end

@interface TestEncoding : TestProtocolBase
{
	NSData						* jsonData;
	NSStringEncoding			stringEncoding;
	id							expectedResult;
}
+ (id)testStringWithName:(NSString *)name jsonString:(NSString *)json expectedResult:(id)expectedResult encoding:(NSStringEncoding)encoding;
- (id)initWithName:(NSString *)name jsonString:(NSString *)json expectedResult:(id)result encoding:(NSStringEncoding)encoding;

@property(readonly)			NSData				* jsonData;
@property(readonly)			NSString			* jsonString;
@property(readonly)			NSStringEncoding	stringEncoding;
@property(readonly)			id					expectedResult;
@end

@implementation TestStringEncodings

- (NSString *)testDescription { return @"Test input with different string encodings"; }

- (void)addName:(NSString *)aName jsonString:(NSString *)aJSON expectedResult:(id)aResult encoding:(NSStringEncoding)anEncoding
{
	[self addTest:[TestEncoding testStringWithName:aName jsonString:aJSON expectedResult:aResult encoding:anEncoding]];
}

static id expectedResult()
{
	return @{@"string":@"A String",
			@"integer":@42,
			@"float":@3.1415,
			@"boolean":@YES,
			@"array":@[@"array",@12],
			@"object":@{@"value1":@"one",@"value2":@2}};
}

- (void)willLoad
{
	static NSStringEncoding		kEncodings[] = {
		NSASCIIStringEncoding, NSNEXTSTEPStringEncoding, NSJapaneseEUCStringEncoding, NSUTF8StringEncoding,
		NSISOLatin1StringEncoding, NSNonLossyASCIIStringEncoding, NSShiftJISStringEncoding,
		NSISOLatin2StringEncoding, NSUnicodeStringEncoding, NSWindowsCP1251StringEncoding, NSWindowsCP1252StringEncoding,
		NSWindowsCP1253StringEncoding, NSWindowsCP1254StringEncoding, NSWindowsCP1250StringEncoding, NSISO2022JPStringEncoding,
		NSMacOSRomanStringEncoding, NSUTF16StringEncoding, NSUTF16BigEndianStringEncoding, NSUTF16LittleEndianStringEncoding,
		NSUTF32StringEncoding, NSUTF32BigEndianStringEncoding, NSUTF32LittleEndianStringEncoding
	};
	static const char		* const kEncodingNames[] = {
		"ASCII", "NEXTSTEP", "JapaneseEUC", "UTF8",
		"ISOLatin1", "NonLossyASCII", "ShiftJIS",
		"ISOLatin2", "Unicode", "WindowsCP1251", "WindowsCP1252",
		"WindowsCP1253", "WindowsCP1254", "WindowsCP1250",
		"ISO2022JP", "MacOSRoman", "UTF16", "UTF16BigEndian", "UTF16LittleEndian",
		"UTF32", "UTF32BigEndian", "UTF32LittleEndian"
	};
	static NSString			* const kTestJSONString = @"{\"string\":\"A String\",\"integer\":42,\"float\":3.1415,\"boolean\":true,\"array\":[\"array\",12],\"object\":{\"value1\":\"one\",\"value2\":2}}";
	for( NSUInteger i = 0; i < sizeof(kEncodings)/sizeof(*kEncodings); i++ )
		[self addName:[NSString stringWithFormat:@"Encoding %s", kEncodingNames[i]] jsonString:kTestJSONString expectedResult:expectedResult() encoding:kEncodings[i]];
	[super willLoad];
}

@end

@implementation TestEncoding

@synthesize		expectedResult,
				jsonData,
				stringEncoding;

#pragma mark - manually implemented properties

- (NSString *)details
{
	return [NSString stringWithFormat:@"json:\n%@\n\nresult:\n%@\n\nexpected result:\n%@\n\n", self.jsonString, [self.lastResult detailedDescription], [self.expectedResult detailedDescription]];
}

- (NSString *)jsonString { return [[NSString alloc] initWithData:self.jsonData encoding:self.stringEncoding]; }

#pragma mark - creation and destruction

+ (id)testStringWithName:(NSString *)aName jsonString:(NSString *)aJSON expectedResult:(id)aResult encoding:(NSStringEncoding)anEncoding
{
	return [[self alloc] initWithName:aName jsonString:aJSON expectedResult:aResult encoding:anEncoding];
}
- (id)initWithName:(NSString *)aName jsonString:(NSString *)aJSON expectedResult:(id)aResult encoding:(NSStringEncoding)anEncoding
{
	if( (self = [super initWithName:aName]) != nil )
	{
		jsonData = [aJSON dataUsingEncoding:anEncoding];
		NSAssert( jsonData!= nil, @"Cannot get data for encoding %ld", anEncoding );
		expectedResult = aResult;
		stringEncoding = anEncoding;
	}
	return self;
}

#pragma mark - execution

- (id)run
{
	NSError				* theError = nil;
	NDJSONParser		* theJSON = [[NDJSONParser alloc] initWithJSONData:self.jsonData encoding:self.stringEncoding];
	NDJSONDeserializer	* theJSONParser = [[NDJSONDeserializer alloc] init];
	id				theResult = [theJSONParser objectForJSON:theJSON options:NDJSONOptionNone error:&theError];
	self.lastResult = theResult;
	self.error = theError;
	return self.lastResult;
}

#pragma mark - NSObject overridden methods

- (NSString *)description { return [NSString stringWithFormat:@"%@, name: %@", [self class], self.name]; }

@end

