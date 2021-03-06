//
//  TestJSONPrimativeConversion.m
//  NDJSON
//
//  Created by Nathan Day on 6/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestJSONPrimativeConversion.h"
#import "NDJSONDeserializer.h"
#import "TestProtocolBase.h"
#import "NSObject+TestUtilities.h"

static NSDate * dateWithObjects( id year, id mon, id day, id hr, id min, id sec)
{
	NSDateComponents		* theDateComponents = [[NSDateComponents alloc] init];
	[theDateComponents setCalendar:[NSCalendar currentCalendar]];
	[theDateComponents setYear:[year integerValue]];
	[theDateComponents setMonth:[mon integerValue]];
	[theDateComponents setDay:[day integerValue]];
	[theDateComponents setHour:[hr integerValue]];
	[theDateComponents setMinute:[min integerValue]];
	[theDateComponents setSecond:[sec integerValue]];
	return [theDateComponents date];
}

@interface TestConversionTarget : NSObject
{
	NSInteger			valueChi[128];
	size_t				valueChiLen;
}

@property(assign)		NSUInteger		valueIota;
@property(copy)			NSString		* valueSigma;
@property(copy)			NSDate			* valueDelta;
@property(strong)		NSArray			* valueAlpha;
@property(assign)		NSInteger		* valueChi;


+ (id)testConversionTargetWithValueSigma:(NSString *)valueSigma valueIota:(NSUInteger)valueIota valueDelta:(NSDate *)valueDelta valueAlpha:(NSArray*)anArray valueChi:(NSArray *)aValueChi;
- (id)initWithValueSigma:(NSString *)valueSigma valueIota:(NSUInteger)valueIota valueDelta:(NSDate *)valueDelta valueAlpha:(NSArray*)anArray valueChi:(NSArray *)aValueChi;

@end

@interface TestConversionTargetWithConversion : TestConversionTarget

- (void)setValueDeltaByConvertingString:(NSString *)string;
- (void)setValueDeltaByConvertingNumber:(NSNumber *)number;
- (void)setValueDeltaByConvertingArray:(NSArray *)string;
- (void)setValueAlphaByConvertingString:(NSString *)string;
- (void)setValueChiByConvertingString:(NSString *)string;
- (void)setValueChiByConvertingNumber:(NSNumber *)number;

@end

@interface TestJSONPrimativeConversion ()
- (void)addName:(NSString *)name jsonString:(NSString *)json expectedResult:(id)expectedResult options:(NDJSONOptionFlags)anOptions targetClass:(Class)targetClass;
@end

@interface TestConversion : TestProtocolBase
{
	NSString					* jsonString;
	id							expectedResult;
	NDJSONOptionFlags			options;
	Class						targetClass;
}
+ (id)testConversionWithName:(NSString *)name jsonString:(NSString *)json expectedResult:(id)expectedResult options:(NDJSONOptionFlags)options targetClass:(Class)aTargetClass;
- (id)initWithName:(NSString *)name jsonString:(NSString *)json expectedResult:(id)result options:(NDJSONOptionFlags)options targetClass:(Class)aTargetClass;

@property(readonly)			NSString			* jsonString;
@property(readonly)			id					expectedResult;
@property(readonly)			NDJSONOptionFlags	options;
@property(readonly)			Class				targetClass;
@end

@implementation TestJSONPrimativeConversion

- (NSString *)testDescription { return @"Test conversion of JSON primative types"; }

- (void)addName:(NSString *)aName jsonString:(NSString *)aJSON expectedResult:(id)aResult options:(NDJSONOptionFlags)anOptions targetClass:(Class)aTargetClass
{
	[self addTest:[TestConversion testConversionWithName:aName jsonString:aJSON expectedResult:aResult options:anOptions targetClass:aTargetClass]];
}

- (void)willLoad
{
	TestConversionTarget	* theTestConversionTarget = nil;

	theTestConversionTarget = [TestConversionTarget testConversionTargetWithValueSigma:@"12"
																			 valueIota:24
																			valueDelta:[NSDate dateWithString:@"1968-01-22 06:30:00 +1000"]
																			valueAlpha:nil
																			  valueChi:nil];
	[self addName:@"String to Date by converting methods"
	   jsonString:@"{\"valueIota\":\"24\",\"valueSigma\":12,valueDelta:\"1968-01-22 06:30:00 +1000\"}"
   expectedResult:theTestConversionTarget
		  options:NDJSONOptionCovertPrimitiveJSONTypes
	  targetClass:[TestConversionTargetWithConversion class]];

	[self addName:@"Number to Date by converting method"
	   jsonString:@"{\"valueIota\":\"24\",\"valueSigma\":12,valueDelta:-61356600}"
   expectedResult:theTestConversionTarget
		  options:NDJSONOptionCovertPrimitiveJSONTypes
	  targetClass:[TestConversionTargetWithConversion class]];

	[self addName:@"String to Date by initWithDate"
	   jsonString:@"{\"valueIota\":\"24\",\"valueSigma\":12,valueDelta:\"1968-01-22 06:30:00 +1000\"}"
   expectedResult:theTestConversionTarget
		  options:NDJSONOptionCovertPrimitiveJSONTypes
	  targetClass:[TestConversionTarget class]];

	[self addName:@"String to Array by converting method"
	   jsonString:@"{\"valueAlpha\":\"Alpha,Beta,Gamma,Delta\"}"
   expectedResult:[TestConversionTarget testConversionTargetWithValueSigma:nil
																 valueIota:0
																valueDelta:nil
																valueAlpha:@[@"Alpha",@"Beta",@"Gamma",@"Delta"]
																  valueChi:nil]
		  options:NDJSONOptionCovertPrimitiveJSONTypes
	  targetClass:[TestConversionTargetWithConversion class]];

	[self addName:@"String to C array by converting method"
	   jsonString:@"{\"valueChi\":\"1,2,3,5,8,13\"}"
   expectedResult:[TestConversionTarget testConversionTargetWithValueSigma:nil
																 valueIota:0
																valueDelta:nil
																valueAlpha:nil
																  valueChi:@[@1,@2,@3,@5,@8,@13]]
		  options:NDJSONOptionCovertPrimitiveJSONTypes
	  targetClass:[TestConversionTargetWithConversion class]];

	[self addName:@"Array to Date by by calling setXXXByConvertingArray:"
	   jsonString:@"{\"valueIota\":\"24\",\"valueSigma\":12,valueDelta:[\"1968\",\"01\",\"22\",\"6\",\"30\",\"00\"]}"
   expectedResult:theTestConversionTarget
		  options:NDJSONOptionCovertPrimitiveJSONTypes|NDJSONOptionConvertToArrayTypeIfRequired
	  targetClass:[TestConversionTargetWithConversion class]];

	[super willLoad];
}

@end

@implementation TestConversion

@synthesize		expectedResult,
				jsonString,
				options,
				targetClass;

#pragma mark - manually implemented properties

- (NSString *)details
{
	return [NSString stringWithFormat:@"json:\n%@\n\nresult:\n%@\n\nexpected result:\n%@\n\n", self.jsonString, [self.lastResult detailedDescription], [self.expectedResult detailedDescription]];
}

#pragma mark - creation and destruction

+ (id)testConversionWithName:(NSString *)aName jsonString:(NSString *)aJSON expectedResult:(id)aResult options:(NDJSONOptionFlags)anOptions targetClass:(Class)aTargetClass
{
	return [[self alloc] initWithName:aName jsonString:aJSON expectedResult:aResult options:anOptions targetClass:aTargetClass];
}
- (id)initWithName:(NSString *)aName jsonString:(NSString *)aJSON expectedResult:(id)aResult options:(NDJSONOptionFlags)anOptions targetClass:(Class)aTargetClass
{
	if( (self = [super initWithName:aName]) != nil )
	{
		jsonString = [aJSON copy];
		expectedResult = aResult;
		options = anOptions;
		targetClass = aTargetClass;
	}
	return self;
}

#pragma mark - execution

- (id)run
{
	NSError				* theError = nil;
	NDJSONParser		* theJSON = [[NDJSONParser alloc] initWithJSONString:self.jsonString];
	NDJSONDeserializer	* theJSONParser = [[NDJSONDeserializer alloc] initWithRootClass:self.targetClass];
	id				theResult = [theJSONParser objectForJSON:theJSON options:self.options error:&theError];
	self.lastResult = theResult;
	self.error = theError;
	return self.lastResult;
}

#pragma mark - NSObject overridden methods

- (NSString *)description { return [NSString stringWithFormat:@"%@, name: %@", [self class], self.name]; }

@end

@implementation TestConversionTarget

@synthesize			valueSigma,
					valueIota,
					valueDelta,
					valueAlpha;

+ (id)testConversionTargetWithValueSigma:(NSString *)aString valueIota:(NSUInteger)aInteger valueDelta:(NSDate *)aDate valueAlpha:(NSArray*)anArray valueChi:(NSArray *)aValueChi
{
	return [[self alloc] initWithValueSigma:aString valueIota:aInteger valueDelta:aDate valueAlpha:anArray valueChi:aValueChi];
}
- (id)initWithValueSigma:(NSString *)aString valueIota:(NSUInteger)aInteger valueDelta:(NSDate *)aDate valueAlpha:(NSArray*)anArray valueChi:(NSArray *)aValueChi
{
	if( (self = [super init]) != nil )
	{
		valueSigma = [aString copy];
		valueIota = aInteger;
		valueDelta = [aDate copy];
		valueAlpha = [anArray copy];
		valueChiLen = aValueChi.count;
		[aValueChi enumerateObjectsUsingBlock:^(NSNumber * theObj, NSUInteger anIndex, BOOL * aStop) {
			valueChi[anIndex] = [theObj integerValue];
			*aStop = anIndex+1>=sizeof(valueChi)/sizeof(*valueChi);
		}];
	}
	return self;
}

- (BOOL)isLike:(id)anObject
{
	TestConversionTarget		* theObj = (TestConversionTarget*)anObject;
	BOOL	theResult = (self.valueSigma == theObj.valueSigma || [self.valueSigma isEqual:theObj.valueSigma])
			&& self.valueIota == theObj.valueIota
			&& (self.valueDelta == theObj.valueDelta || [self.valueDelta isLike:theObj.valueDelta])
			&& (self.valueAlpha == theObj.valueAlpha || [self.valueAlpha isLike:theObj.valueAlpha])
			&& valueChiLen == theObj->valueChiLen;
	for( NSUInteger i = 0; i < valueChiLen && theResult; i++ )
		theResult = valueChi[i] == theObj->valueChi[i];
	return theResult;
}

- (NSString *)description
{
	NSMutableString		* theMutableString = [NSMutableString string];
	for( NSUInteger i = 0; i < valueChiLen; i++ )
		[theMutableString appendFormat:@"%s%ld", i > 0 ? "," : "", valueChi[i]];
	return [NSString stringWithFormat:@"valueIota: %lu, valueSigma: %@, valueDelta: %@, valueAlpha: %@, valueChi: [%@]", self.valueIota, self.valueSigma, self.valueDelta, self.valueAlpha, theMutableString];
}

- (void)setValueDeltaByConvertingArray:(NSArray *)anArray
{
	NSAssert( anArray.count > 5, @"Not enaough components, %lu", anArray.count );
	NSDateComponents		* theComps = [[NSDateComponents alloc] init];
	[theComps setYear:[anArray[0] integerValue]];
	[theComps setMonth:[anArray[1] integerValue]];
	[theComps setDay:[anArray[2] integerValue]];
	[theComps setHour:[anArray[3] integerValue]];
	[theComps setMinute:[anArray[4] integerValue]];
	[theComps setSecond:[anArray[5] integerValue]];
	self.valueDelta = [theComps date];
}

- (NSInteger *)valueChi { return valueChi; }
- (void)setValueChi:(NSInteger *)aValues
{
	for( valueChiLen = 0; valueChiLen < sizeof(valueChi)/sizeof(*valueChi) && aValues[valueChiLen] != NSNotFound; valueChiLen++ )
		valueChi[valueChiLen] = aValues[valueChiLen];
}

@end

@implementation TestConversionTargetWithConversion

- (void)setValueDeltaByConvertingString:(NSString *)aString { self.valueDelta = [NSDate dateWithString:aString]; }
- (void)setValueDeltaByConvertingNumber:(NSNumber *)aNumber { self.valueDelta = [NSDate dateWithTimeIntervalSince1970:aNumber.doubleValue]; }
- (void)setValueDeltaByConvertingArray:(NSArray *)anArray
{
	self.valueDelta = dateWithObjects( anArray[0], anArray[1], anArray[2], anArray[3], anArray[4], anArray[5] );
}
- (void)setValueAlphaByConvertingString:(NSString *)aString { self.valueAlpha = [aString componentsSeparatedByString:@","]; }
- (void)setValueChiByConvertingString:(NSString *)aString
{
	NSScanner		* theScanner = [NSScanner scannerWithString:aString];
	[theScanner setCharactersToBeSkipped:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]];
	for( valueChiLen = 0; ![theScanner isAtEnd] && valueChiLen < sizeof(valueChi)/sizeof(*valueChi); valueChiLen++ )
		[theScanner scanInteger:&valueChi[valueChiLen]];
}

- (void)setValueChiByConvertingNumber:(NSNumber *)aNumber
{
	NSUInteger		c = aNumber.unsignedIntegerValue;
	for( valueChiLen = 0; valueChiLen < c && valueChiLen < sizeof(valueChi)/sizeof(*valueChi); valueChiLen++ )
	{
		switch(valueChiLen)
		{
		case 0:
			valueChi[0] = 1;
			break;
		case 1:
			valueChi[1] = 2;
			break;
		default:
			valueChi[valueChiLen] = valueChi[valueChiLen-1]+valueChi[valueChiLen-2];
			break;
		}
	}
}


@end
