//
//  TestStringInput.m
//  NDJSON
//
//  Created by Nathan Day on 6/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestStringInput.h"
#import "NDJSONDeserializer.h"
#import "TestProtocolBase.h"
#import "NSObject+TestUtilities.h"

@interface TestStringInput ()
- (void)addName:(NSString *)name jsonString:(NSString *)json expectedResult:(id)expectedResult options:(NDJSONOptionFlags)anOptions;
@end

@interface TestString : TestProtocolBase
{
	NSString					* jsonString;
	id							expectedResult;
	NDJSONOptionFlags			options;
}
+ (id)testStringWithName:(NSString *)name jsonString:(NSString *)json expectedResult:(id)expectedResult options:(NDJSONOptionFlags)options;
- (id)initWithName:(NSString *)name jsonString:(NSString *)json expectedResult:(id)result options:(NDJSONOptionFlags)options;

@property(readonly)			NSString			* jsonString;
@property(readonly)			id					expectedResult;
@property(readonly)			NDJSONOptionFlags	options;
@end

@implementation TestStringInput

- (NSString *)testDescription { return @"Test input with string, all bytes are available, tests ability to recongnize all kinds of JSON"; }

- (void)addName:(NSString *)aName jsonString:(NSString *)aJSON expectedResult:(id)aResult options:(NDJSONOptionFlags)anOptions
{
	[self addTest:[TestString testStringWithName:aName jsonString:aJSON expectedResult:aResult options:anOptions]];
}

- (void)willLoad
{
	[self addName:@"True" jsonString:@"true" expectedResult:@YES options:NDJSONOptionNone];
	[self addName:@"False" jsonString:@"false" expectedResult:@NO options:NDJSONOptionNone];
	[self addName:@"Null" jsonString:@"null" expectedResult:[NSNull null] options:NDJSONOptionNone];
	[self addName:@"Integer" jsonString:@"83177846" expectedResult:@83177846 options:NDJSONOptionNone];
	[self addName:@"Float" jsonString:@"3.141592" expectedResult:@3.141592 options:NDJSONOptionNone];
	[self addName:@"Negative Integer" jsonString:@"-4" expectedResult:@-4 options:NDJSONOptionNone];
	[self addName:@"Negative Float" jsonString:@"-0.003" expectedResult:@-0.003 options:NDJSONOptionNone];
	[self addName:@"String" jsonString:@"\"String Value\"" expectedResult:@"String Value" options:NDJSONOptionNone];
	[self addName:@"White Space" jsonString:@"\" \tsome text  \t with  white space in\n it    \"" expectedResult:@" \tsome text  \t with  white space in\n it    " options:NDJSONOptionNone];
	[self addName:@"Escape" jsonString:@"\"Hello\\n\\t\\\"Nathan Day\\\"\"" expectedResult:@"Hello\n\t\"Nathan Day\"" options:NDJSONOptionNone];
	[self addName:@"Escaped Forward Slashs in String" jsonString:@"\"http:\\/\\/rhtv.cdn.launchpad6.tv\\/thumbnails\\/small\\/100.png\"" expectedResult:@"http://rhtv.cdn.launchpad6.tv/thumbnails/small/100.png" options:NDJSONOptionNone];
	[self addName:@"Scientific Notation Number" jsonString:@"314159265358979e-14" expectedResult:@3.14159265358979 options:NDJSONOptionNone];
	[self addName:@"Array" jsonString:@"[1,2,\"three\",-4,-5.5,true,false,null]" expectedResult:@[@1,@2,@"three",@-4,@-5.5,@YES,@NO,[NSNull null]] options:NDJSONOptionNone];
	[self addName:@"Array with trailing comma" jsonString:@"{\"array\":[1,\"two\",],\"number\":2}" expectedResult:@{@"array":@[@1,@"two"],@"number":@2} options:NDJSONOptionNone];
	[self addName:@"Object with trailing comma" jsonString:@"[{\"a\":1,\"b\":2,},3]" expectedResult:@[@{@"a":@1,@"b":@2},@3] options:NDJSONOptionNone];

	[self addName:@"Nested Array" jsonString:@"[1,[\"array\"]]" expectedResult:@[@1,@[@"array"]] options:NDJSONOptionNone];
	[self addName:@"Empty Array" jsonString:@"[]" expectedResult:@[] options:NDJSONOptionNone];
	[self addName:@"Empty Object" jsonString:@"{}" expectedResult:@{} options:NDJSONOptionNone];
	[self addName:@"Object with Empty Array" jsonString:@"{\"a\":[],\"b\":2}" expectedResult:@{@"a":@[],@"b":@2} options:NDJSONOptionNone];
	[self addName:@"Array with Empty Object" jsonString:@"[{},2]" expectedResult:@[@{},@2] options:NDJSONOptionNone];
	[self addName:@"Array with With Space" jsonString:@" [ 1 ,\n2\t,    \"three\"\t\t\t,  true,\t\t  false   ,    null   ]        " expectedResult:@[@1,@2,@"three",@YES,@NO,[NSNull null]] options:NDJSONOptionNone];
	[self addName:@"Object" jsonString:@"{\"alpha\":1,\"beta\":\"two\",\"gama\":true}" expectedResult:@{@"alpha":@1,@"beta":@"two",@"gama":@YES} options:NDJSONOptionNone];
	[self addName:@"Object Containing Array" jsonString:@"{\"alpha\":1,\"beta\":[1,false]}" expectedResult:@{@"alpha":@1,@"beta":@[@1,@NO]} options:NDJSONOptionNone];
	 [self addName:@"Object with White Space" jsonString:@"{ \"alpha\" :  1  , \"beta\"\n:\t\t\"two\" ,  \"gama\":true }  " expectedResult:@{@"alpha":@1,@"beta":@"two",@"gama":@YES} options:NDJSONOptionNone];
	[self addName:@"Zero Length Key" jsonString:@"{\"\":{\"message\":\"lib comment is not found\",\"errCode\":1,\"result\":null,\"lib\":\"\"}}" expectedResult:@{@"":@{@"message":@"lib comment is not found",@"errCode":@1,@"result":[NSNull null],@"lib":@""}} options:NDJSONOptionNone];
	 [self addName:@"Object Containing Array Containing Object etc." jsonString:@"{ \"alpha\" :  1  , \"beta\"\n:\t\t\"two\" ,  \"gama\":[1,2,\"three\",true,false,null,{\"alpha\":1,\"beta\":[1,false]}]}  " expectedResult:@{@"alpha":@1, @"beta":@"two", @"gama":@[@1,@2,@"three",@YES,@NO,[NSNull null],@{@"alpha":@1,@"beta":@[@1,@NO]}]} options:NDJSONOptionNone];
	[self addName:@"Nested Object" jsonString:@"{ \"alpha\" : { \"beta\" : 2 }}" expectedResult:@{@"alpha":@{@"beta":@2}} options:NDJSONOptionNone];
	[self addName:@"Nested Object with Array" jsonString:@"{ \"alpha\" : { \"beta\" : 2 }, \"gama\":[3,4]}" expectedResult:@{@"alpha":@{@"beta":@2},@"gama":@[@3,@4]} options:NDJSONOptionNone];
	[self addName:@"Nested Object with nested Array" jsonString:@"{ \"alpha\" : { \"beta\" : [3,4] }}" expectedResult:@{@"alpha":@{@"beta":@[@3,@4]}} options:NDJSONOptionNone];

	[self addName:@"3 deep array" jsonString:@"[[[1],2],3]" expectedResult:@[@[@[@1],@2],@3] options:NDJSONOptionNone];
	[self addName:@"3 deep array trailing" jsonString:@"[1,[2,[3]]]" expectedResult:@[@1,@[@2,@[@3]]] options:NDJSONOptionNone];

	[self addName:@"3 deep object" jsonString:@"{\"a\":{\"b\":{\"c\":1},\"d\":2},\"e\":3}" expectedResult:@{@"a":@{@"b":@{@"c":@1},@"d":@2},@"e":@3} options:NDJSONOptionNone];
	[self addName:@"3 deep object trailing" jsonString:@"{\"a\":1,\"b\":{\"c\":2,\"d\":{\"e\":3}}}" expectedResult:@{@"a":@1,@"b":@{@"c":@2,@"d":@{@"e":@3}}} options:NDJSONOptionNone];

	[self addName:@"4 deep object" jsonString:@"{\"a\":{\"b\":{\"c\":{\"d\":1}},\"e\":2},\"f\":3}" expectedResult:@{@"a":@{@"b":@{@"c":@{@"d":@1}},@"e":@2},@"f":@3} options:NDJSONOptionNone];

	[self addName:@"2 deep array within object" jsonString:@"[{\"a\":{\"b\":1},\"c\":2},3]" expectedResult:@[@{@"a":@{@"b":@1},@"c":@2},@3] options:NDJSONOptionNone];

	[self addName:@"Comments single line" jsonString:@"//\ta\n[//\tbc\n1//\td\n,//\te\n{//ab\n\"two\"//cde\n://fghi\n2//jk\n}//\n,//\tf/gh\n\"three\"//\tij*klm\n//\tsecond in a row\n,//\top\n-4//\tqr\n,-5.5,true,false,null//\tstw\n]//\txyz\n" expectedResult:@[@1,@{@"two":@2},@"three",@-4,@-5.5,@YES,@NO,[NSNull null]] options:NDJSONOptionNone];
	[self addName:@"Comments multi line" jsonString:@"/*\na\n*/[/*\nbc\n*/1/*\nd\n*/,/*\ne\n*/{/*ab*/\"two\"/*cde*/:/*fghi*/2/*jk*/}/**/,/*\nf/gh\n*/\"three\"/*\nij*klm\n*//*\nsecond in a row\n*/,/*\nop\n*/-4/*\nqr\n*/,-5.5,true,false,null/*\nstw\n*/]/*\nxyz\n*/" expectedResult:@[@1,@{@"two":@2},@"three",@-4,@-5.5,@YES,@NO,[NSNull null]] options:NDJSONOptionNone];
	[self addName:@"UnBalanced Nested Object, Shallower End" jsonString:@"{\"one\":1,\"two\":2,\"three\":{\"four\":4}" expectedResult:@{@"one":@1,@"two":@2,@"three":@{@"four":@4}} options:NDJSONOptionNone];
	[self addName:@"UnBalanced Nested Object, Deeper End" jsonString:@"{\"one\":1,\"two\":2},\"three\":3,\"four\":4}" expectedResult:@{@"one":@1,@"two":@2} options:NDJSONOptionNone];
	[super willLoad];
}

@end

@implementation TestString

@synthesize		expectedResult,
				jsonString,
				options;

#pragma mark - manually implemented properties

- (NSString *)details
{
	return [NSString stringWithFormat:@"json:\n%@\n\nresult:\n%@\n\nexpected result:\n%@\n\n", self.jsonString, [self.lastResult detailedDescription], [self.expectedResult detailedDescription]];
}

#pragma mark - creation and destruction

+ (id)testStringWithName:(NSString *)aName jsonString:(NSString *)aJSON expectedResult:(id)aResult options:(NDJSONOptionFlags)anOptions
{
	return [[self alloc] initWithName:aName jsonString:aJSON expectedResult:aResult options:anOptions];
}
- (id)initWithName:(NSString *)aName jsonString:(NSString *)aJSON expectedResult:(id)aResult options:(NDJSONOptionFlags)anOptions
{
	if( (self = [super initWithName:aName]) != nil )
	{
		jsonString = [aJSON copy];
		expectedResult = aResult;
		options = anOptions;
	}
	return self;
}

#pragma mark - execution

- (id)run
{
	NSError					* theError = nil;
	NDJSONParser			* theJSON = [[NDJSONParser alloc] initWithJSONString:self.jsonString];
	NDJSONDeserializer		* theJSONParser = [[NDJSONDeserializer alloc] init];
	id				theResult = [theJSONParser objectForJSON:theJSON options:self.options error:&theError];
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

