//
//  TestStringInput.m
//  NDJSON
//
//  Created by Nathan Day on 6/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestStringInput.h"
#import "NDJSONParser.h"
#import "TestProtocolBase.h"
#import "Utility.h"
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
	[self addName:@"True" jsonString:@"true" expectedResult:BOOLNUM(YES) options:NDJSONOptionNone];
	[self addName:@"False" jsonString:@"false" expectedResult:BOOLNUM(NO) options:NDJSONOptionNone];
	[self addName:@"Null" jsonString:@"null" expectedResult:NULLOBJ options:NDJSONOptionNone];
	[self addName:@"Integer" jsonString:@"83177846" expectedResult:INTNUM(83177846) options:NDJSONOptionNone];
	[self addName:@"Float" jsonString:@"3.141592" expectedResult:REALNUM(3.141592) options:NDJSONOptionNone];
	[self addName:@"Negative Integer" jsonString:@"-4" expectedResult:INTNUM(-4) options:NDJSONOptionNone];
	[self addName:@"Negative Float" jsonString:@"-0.003" expectedResult:REALNUM(-0.003) options:NDJSONOptionNone];
	[self addName:@"String" jsonString:@"\"String Value\"" expectedResult:@"String Value" options:NDJSONOptionNone];
	[self addName:@"White Space" jsonString:@"\" \tsome text  \t with  white space in\n it    \"" expectedResult:@" \tsome text  \t with  white space in\n it    " options:NDJSONOptionNone];
	[self addName:@"Escape" jsonString:@"\"Hello\\n\\t\\\"Nathan Day\\\"\"" expectedResult:@"Hello\n\t\"Nathan Day\"" options:NDJSONOptionNone];
	[self addName:@"Escaped Forward Slashs in String" jsonString:@"\"http:\\/\\/rhtv.cdn.launchpad6.tv\\/thumbnails\\/small\\/100.png\"" expectedResult:@"http://rhtv.cdn.launchpad6.tv/thumbnails/small/100.png" options:NDJSONOptionNone];
	[self addName:@"Scientific Notation Number" jsonString:@"314159265358979e-14" expectedResult:REALNUM(3.14159265358979) options:NDJSONOptionNone];
	[self addName:@"Array" jsonString:@"[1,2,\"three\",-4,-5.5,true,false,null]" expectedResult:ARRAY(INTNUM(1),INTNUM(2),@"three",INTNUM(-4),REALNUM(-5.5),BOOLNUM(YES),BOOLNUM(NO),NULLOBJ) options:NDJSONOptionNone];
	[self addName:@"Array with trailing comma" jsonString:@"{\"array\":[1,\"two\",],\"number\":2}" expectedResult:DICT(ARRAY(INTNUM(1),@"two"),@"array",INTNUM(2),@"number") options:NDJSONOptionNone];
	[self addName:@"Nested Array" jsonString:@"[1,[\"array\"]]" expectedResult:ARRAY(INTNUM(1),ARRAY(@"array")) options:NDJSONOptionNone];
	[self addName:@"Empty Array" jsonString:@"[]" expectedResult:[NSArray array] options:NDJSONOptionNone];
	[self addName:@"Empty Object" jsonString:@"{}" expectedResult:[NSDictionary dictionary] options:NDJSONOptionNone];
	[self addName:@"Array with With Space" jsonString:@" [ 1 ,\n2\t,    \"three\"\t\t\t,  true,\t\t  false   ,    null   ]        " expectedResult:ARRAY(INTNUM(1),INTNUM(2),@"three",BOOLNUM(YES),BOOLNUM(NO),NULLOBJ) options:NDJSONOptionNone];
	[self addName:@"Object" jsonString:@"{\"alpha\":1,\"beta\":\"two\",\"gama\":true}" expectedResult:DICT(INTNUM(1),@"alpha",@"two",@"beta",BOOLNUM(YES),@"gama") options:NDJSONOptionNone];
	[self addName:@"Object Containing Array" jsonString:@"{\"alpha\":1,\"beta\":[1,false]}" expectedResult:DICT(INTNUM(1),@"alpha",ARRAY(INTNUM(1),BOOLNUM(NO)),@"beta") options:NDJSONOptionNone];
	[self addName:@"Object with White Space" jsonString:@"{ \"alpha\" :  1  , \"beta\"\n:\t\t\"two\" ,  \"gama\":true }  " expectedResult:DICT(INTNUM(1),@"alpha",@"two",@"beta",BOOLNUM(YES),@"gama") options:NDJSONOptionNone];
	[self addName:@"Zero Length Key" jsonString:@"{\"\":{\"message\":\"lib comment is not found\",\"errCode\":1,\"result\":null,\"lib\":\"\"}}" expectedResult:DICT(DICT(@"lib comment is not found",@"message",INTNUM(1),@"errCode",NULLOBJ,@"result",@"", @"lib"),@"") options:NDJSONOptionNone];
	[self addName:@"Object Containing Array Containing Object etc." jsonString:@"{ \"alpha\" :  1  , \"beta\"\n:\t\t\"two\" ,  \"gama\":[1,2,\"three\",true,false,null,{\"alpha\":1,\"beta\":[1,false]}]}  " expectedResult:DICT(INTNUM(1),@"alpha",@"two",@"beta",ARRAY(INTNUM(1),INTNUM(2),@"three",BOOLNUM(YES),BOOLNUM(NO),NULLOBJ,DICT(INTNUM(1),@"alpha",ARRAY(INTNUM(1),BOOLNUM(NO)),@"beta")),@"gama") options:NDJSONOptionNone];
	[self addName:@"Nested Object" jsonString:@"{ \"alpha\" : { \"beta\" : 2 }}" expectedResult:DICT(DICT(INTNUM(2),@"beta"),@"alpha") options:NDJSONOptionNone];
	[self addName:@"Nested Object with Array" jsonString:@"{ \"alpha\" : { \"beta\" : 2 }, \"gama\":[3,4]}" expectedResult:DICT(DICT(INTNUM(2),@"beta"),@"alpha",ARRAY(INTNUM(3),INTNUM(4)), @"gama") options:NDJSONOptionNone];
	[self addName:@"Nested Object with nested Array" jsonString:@"{ \"alpha\" : { \"beta\" : [3,4] }}" expectedResult:DICT(DICT(ARRAY(INTNUM(3),INTNUM(4)),@"beta"),@"alpha") options:NDJSONOptionNone];
	[self addName:@"Comments single line" jsonString:@"//\ta\n[//\tbc\n1//\td\n,//\te\n{//ab\n\"two\"//cde\n://fghi\n2//jk\n}//\n,//\tf/gh\n\"three\"//\tij*klm\n//\tsecond in a row\n,//\top\n-4//\tqr\n,-5.5,true,false,null//\tstw\n]//\txyz\n" expectedResult:ARRAY(INTNUM(1),DICT(INTNUM(2),@"two"),@"three",INTNUM(-4),REALNUM(-5.5),BOOLNUM(YES),BOOLNUM(NO),NULLOBJ) options:NDJSONOptionNone];
	[self addName:@"Comments multi line" jsonString:@"/*\na\n*/[/*\nbc\n*/1/*\nd\n*/,/*\ne\n*/{/*ab*/\"two\"/*cde*/:/*fghi*/2/*jk*/}/**/,/*\nf/gh\n*/\"three\"/*\nij*klm\n*//*\nsecond in a row\n*/,/*\nop\n*/-4/*\nqr\n*/,-5.5,true,false,null/*\nstw\n*/]/*\nxyz\n*/" expectedResult:ARRAY(INTNUM(1),DICT(INTNUM(2),@"two"),@"three",INTNUM(-4),REALNUM(-5.5),BOOLNUM(YES),BOOLNUM(NO),NULLOBJ) options:NDJSONOptionNone];
	[self addName:@"UnBalanced Nested Object, Shallower End" jsonString:@"{\"one\":1,\"two\":2,\"three\":{\"four\":4}" expectedResult:DICT(INTNUM(1),@"one",INTNUM(2),@"two",DICT(INTNUM(4),@"four"), @"three") options:NDJSONOptionNone];
	[self addName:@"UnBalanced Nested Object, Deeper End" jsonString:@"{\"one\":1,\"two\":2},\"three\":3,\"four\":4}" expectedResult:DICT(INTNUM(1),@"one",INTNUM(2),@"two") options:NDJSONOptionNone];
	NSDictionary	* theDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"file4" ofType:@"plist"]];
	[self addName:@"Large JSON with no spacing" jsonString:@"{title:\"javascriptkit.com\",link:\"http://www.javascriptkit.com\",description:\"JavaScript tutorials and over 400+ free scripts!\",language:\"en\",items:[{title:\"Document Text Resizer\",link:\"http://www.javascriptkit.com/script/script2/doctextresizer.shtml\",description:\"This script adds the ability for your users to toggle your webpage's font size, with persistent cookies then used to remember the setting\"},{title:\"JavaScript Reference- Keyboard/ Mouse Buttons Events\",link:\"http://www.javascriptkit.com/jsref/eventkeyboardmouse.shtml\",description:\"The latest update to our JS Reference takes a hard look at keyboard and mouse button events in JavaScript, including the unicode value of each key.\"},{title:\"Dynamically loading an external JavaScript or CSS file\",link:\"http://www.javascriptkit.com/javatutors/loadjavascriptcss.shtml\",description:\"External JavaScript or CSS files do not always have to be synchronously loaded as part of the page, but dynamically as well. In this tutorial, see how.\"}]}"  expectedResult:theDict options:NDJSONOptionNone];
	[self addName:@"Bad Property Names" jsonString:@"{\"NUMBER one\":1,\"number-two\":2,\"number+3\":3,\"number:four\":4,\"numberFive\":5,\"\t\nNumber   \t\tSix  \":6}" expectedResult:DICT(INTNUM(1),@"NUMBEROne",INTNUM(2),@"numberTwo",INTNUM(3),@"number3",INTNUM(4),@"numberFour",INTNUM(5),@"numberFive",INTNUM(6),@"numberSix") options:NDJSONOptionConvertKeysToMedialCapitals];
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
	return [[[self alloc] initWithName:aName jsonString:aJSON expectedResult:aResult options:anOptions] autorelease];
}
- (id)initWithName:(NSString *)aName jsonString:(NSString *)aJSON expectedResult:(id)aResult options:(NDJSONOptionFlags)anOptions
{
	if( (self = [super initWithName:aName]) != nil )
	{
		jsonString = [aJSON copy];
		expectedResult = [aResult retain];
		options = anOptions;
	}
	return self;
}

- (void)dealloc
{
	[jsonString release];
	[expectedResult release];
	[super dealloc];
}

#pragma mark - execution

- (id)run
{
	NSError			* theError = nil;
	NDJSON			* theJSON = [[NDJSON alloc] init];
	NDJSONParser	* theJSONParser = [[NDJSONParser alloc] init];
	[theJSON setJSONString:self.jsonString];
	id				theResult = [theJSONParser objectForJSON:theJSON options:self.options error:&theError];
	self.lastResult = theResult;
	self.error = theError;
	[theJSONParser release];
	[theJSON release];
	return self.lastResult;
}

#pragma mark - NSObject overridden methods

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@, name: %@", [self class], self.name];
}


@end

