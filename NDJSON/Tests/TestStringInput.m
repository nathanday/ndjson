//
//  TestStringInput.m
//  NDJSON
//
//  Created by Nathan Day on 6/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestStringInput.h"
#import "NDJSON.h"

#define INTNUM(_NUM_) [NSNumber numberWithInteger:_NUM_]
#define REALNUM(_NUM_) [NSNumber numberWithDouble:_NUM_]
#define BOOLNUM(_NUM_) [NSNumber numberWithBool:_NUM_]

@interface TestStringInput ()
{
	NSMutableArray		* tests;
}
- (void)addName:(NSString *)name jsonString:(NSString *)json expectedResult:(id)result;
@end

@interface TestString : NSObject <TestProtocol>
{
	NSString	* jsonString;
	id			result;
	NSError		* error;
}
+ (id)testStringWithName:(NSString *)name jsonString:(NSString *)json expectedResult:(id)result;
- (id)initWithName:(NSString *)name jsonString:(NSString *)json expectedResult:(id)result;

@property(readonly) NSString * jsonString;
@end

@implementation TestStringInput

- (NSArray *)testInstances { return tests; }
- (NSString *)testDescription { return @"Test input with string, all bytes are available, tests ability to recongnize all kinds of JSON"; }

- (void)addName:(NSString *)aName jsonString:(NSString *)aJSON expectedResult:(id)aResult
{
	if( tests == nil )
		tests = [[NSMutableArray alloc] init];
	TestString		* theTestString = [TestString testStringWithName:aName jsonString:aJSON expectedResult:aResult];
	[tests addObject:theTestString];
}

- (BOOL)hasError { self.error != nil; }

- (void)dealloc
{
	[tests release];
	[super dealloc];
}

- (void)willLoad
{
	[self addName:@"TrueString" jsonString:@"true" expectedResult:[NSNumber numberWithBool:YES]];
	[self addName:@"FalseString" jsonString:@"false" expectedResult:[NSNumber numberWithBool:NO]];
	[self addName:@"NullString" jsonString:@"null" expectedResult:[NSNull null]];
	[self addName:@"IntegerString" jsonString:@"83861747" expectedResult:[NSNumber numberWithInteger:83861747]];
	[self addName:@"FloatString" jsonString:@"3.14159265358979" expectedResult:[NSNumber numberWithDouble:3.14159265358979]];
	[self addName:@"NegativeIntegerString" jsonString:@"-4" expectedResult:[NSNumber numberWithInteger:-4]];
	[self addName:@"NegativeFloatString" jsonString:@"-0.0003" expectedResult:[NSNumber numberWithDouble:-0.0003]];
	[self addName:@"WhiteSpaceStringString" jsonString:@"\" \tsome text  \t with  white space in\n it    \"" expectedResult:@" \tsome text  \t with  white space in\n it    "];
	[self addName:@"EscapeString" jsonString:@"\"Hello\\n\\t\\\"Nathan Day\\\"\"" expectedResult:@"Hello\n\t\"Nathan Day\""];
	[self addName:@"ESyntaxNumberString" jsonString:@"314159265358979e-14" expectedResult:[NSNumber numberWithDouble:3.14159265358979]];
	[self addName:@"ArrayString" jsonString:@"[1,2,\"three\",-4,-5.5,true,false,null]" expectedResult:[NSArray arrayWithObjects:INTNUM(1),INTNUM(2),@"three",INTNUM(-4),REALNUM(-5.5),BOOLNUM(YES),BOOLNUM(NO),[NSNull null], nil]];
	[self addName:@"NestedArrayString" jsonString:@"[1,[\"array\"]]" expectedResult:[NSArray arrayWithObjects:INTNUM(1),[NSArray arrayWithObjects:@"array",nil],nil]];
	[self addName:@"EmptyArrayString" jsonString:@"[]" expectedResult:[NSArray array]];
	[self addName:@"ArrayWithWithSpaceString" jsonString:@" [ 1 ,\n2\t,    \"three\"\t\t\t,  true,\t\t  false   ,    null   ]        " expectedResult:[NSArray arrayWithObjects:INTNUM(1),INTNUM(2),@"three",BOOLNUM(YES),BOOLNUM(NO),[NSNull null],nil]];
	[self addName:@"ObjectString" jsonString:@"{\"alpha\":1,\"beta\":\"two\",\"gama\":true}" expectedResult:[NSDictionary dictionaryWithObjectsAndKeys:INTNUM(1),@"alpha",@"two",@"beta",BOOLNUM(YES),@"gama", nil]];
	[self addName:@"ObjectContainingArrayString" jsonString:@"{\"alpha\":1,\"beta\":[1,false]}" expectedResult:[NSDictionary dictionaryWithObjectsAndKeys:INTNUM(1),@"alpha",[NSArray arrayWithObjects:INTNUM(1),BOOLNUM(NO),nil],@"beta",nil]];
	[self addName:@"ObjectWithWhiteSpaceString" jsonString:@"{ \"alpha\" :  1  , \"beta\"\n:\t\t\"two\" ,  \"gama\":true }  " expectedResult:[NSDictionary dictionaryWithObjectsAndKeys:INTNUM(1),@"alpha",@"two",@"beta",BOOLNUM(YES),@"gama", nil]];
	[self addName:@"ObjectContainingArrayContainingObjectETCString" jsonString:@"{ \"alpha\" :  1  , \"beta\"\n:\t\t\"two\" ,  \"gama\":[1,2,\"three\",true,false,null,{\"alpha\":1,\"beta\":[1,false]}]}  " expectedResult:[NSNull null]];
	[self addName:@"NestedObjectString" jsonString:@"{ \"alpha\" : { \"beta\" : 2 }}" expectedResult:[NSDictionary dictionaryWithObjectsAndKeys:[NSDictionary dictionaryWithObjectsAndKeys:INTNUM(2),@"beta",nil],@"alpha", nil]];
//	[self addName:@"NestedObjectWithArrayString" jsonString:@"{ \"alpha\" : { \"beta\" : 2 }, \"gama\":[3,4]}" expectedResult:[NSDictionary dictionaryWithObjectsAndKeys:[NSDictionary dictionaryWithObjectsAndKeys:INTNUM(2),@"beta",nil],@"alpha",[NSArray arrayWithObjects:INTNUM(3),INTNUM(4),nil], nil]];
	[super willLoad];
}

@end

@implementation TestString : NSObject

@synthesize		jsonString,
				expectedResult,
				name,
				error;

+ (id)testStringWithName:(NSString *)aName jsonString:(NSString *)aJSON expectedResult:(id)aResult
{
	return [[[self alloc] initWithName:aName jsonString:aJSON expectedResult:aResult] autorelease];
}
- (id)initWithName:(NSString *)aName jsonString:(NSString *)aJSON expectedResult:(id)aResult
{
	if( (self = [super init]) != nil )
	{
		name = [aName copy];
		jsonString = [aJSON copy];
		expectedResult = [aResult retain];
	}
	return self;
}

- (void)dealloc
{
	[jsonString release];
	[expectedResult release];
	[super dealloc];
}

- (id)run
{
	NDJSON		* theJSON = [[NDJSON alloc] init];
	id			theResult = [theJSON asynchronousParseJSONString:self.jsonString error:&theError];
	[theJSON release];
	return theResult;
}

@end

