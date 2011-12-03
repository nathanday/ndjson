//
//  TestStringInput.m
//  NDJSON
//
//  Created by Nathan Day on 6/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestStringInput.h"
#import "NDJSONPropertyListGenerator.h"
#import "TestProtocolBase.h"

#define INTNUM(_NUM_) [NSNumber numberWithInteger:_NUM_]
#define REALNUM(_NUM_) [NSNumber numberWithDouble:_NUM_]
#define BOOLNUM(_NUM_) [NSNumber numberWithBool:_NUM_]

@interface TestStringInput ()
- (void)addName:(NSString *)name jsonString:(NSString *)json expectedResult:(id)expectedResult;
@end

@interface TestString : TestProtocolBase
{
	NSString					* jsonString;
	id							expectedResult;
}
+ (id)testStringWithName:(NSString *)name jsonString:(NSString *)json expectedResult:(id)expectedResult;
- (id)initWithName:(NSString *)name jsonString:(NSString *)json expectedResult:(id)result;

@property(readonly)			NSString			* jsonString;
@property(readonly)			id					expectedResult;
@end

@implementation TestStringInput

- (NSString *)testDescription { return @"Test input with string, all bytes are available, tests ability to recongnize all kinds of JSON"; }

- (void)addName:(NSString *)aName jsonString:(NSString *)aJSON expectedResult:(id)aResult
{
	[self addTest:[TestString testStringWithName:aName jsonString:aJSON expectedResult:aResult]];
}

- (void)willLoad
{
	[self addName:@"True" jsonString:@"true" expectedResult:[NSNumber numberWithBool:YES]];
	[self addName:@"False" jsonString:@"false" expectedResult:[NSNumber numberWithBool:NO]];
	[self addName:@"Null" jsonString:@"null" expectedResult:[NSNull null]];
	[self addName:@"Integer" jsonString:@"83861747" expectedResult:[NSNumber numberWithInteger:83861747]];
	[self addName:@"Float" jsonString:@"3.14159265358979" expectedResult:[NSNumber numberWithDouble:3.14159265358979]];
	[self addName:@"Negative Integer" jsonString:@"-4" expectedResult:[NSNumber numberWithInteger:-4]];
	[self addName:@"Negative Float" jsonString:@"-0.0003" expectedResult:[NSNumber numberWithDouble:-0.0003]];
	[self addName:@"White Space" jsonString:@"\" \tsome text  \t with  white space in\n it    \"" expectedResult:@" \tsome text  \t with  white space in\n it    "];
	[self addName:@"Escape" jsonString:@"\"Hello\\n\\t\\\"Nathan Day\\\"\"" expectedResult:@"Hello\n\t\"Nathan Day\""];
	[self addName:@"Scientific Notation Number" jsonString:@"314159265358979e-14" expectedResult:[NSNumber numberWithDouble:3.14159265358979]];
	[self addName:@"Array" jsonString:@"[1,2,\"three\",-4,-5.5,true,false,null]" expectedResult:[NSArray arrayWithObjects:INTNUM(1),INTNUM(2),@"three",INTNUM(-4),REALNUM(-5.5),BOOLNUM(YES),BOOLNUM(NO),[NSNull null], nil]];
	[self addName:@"Nested Array" jsonString:@"[1,[\"array\"]]" expectedResult:[NSArray arrayWithObjects:INTNUM(1),[NSArray arrayWithObjects:@"array",nil],nil]];
	[self addName:@"Empty Array" jsonString:@"[]" expectedResult:[NSArray array]];
	[self addName:@"Array with With Space" jsonString:@" [ 1 ,\n2\t,    \"three\"\t\t\t,  true,\t\t  false   ,    null   ]        " expectedResult:[NSArray arrayWithObjects:INTNUM(1),INTNUM(2),@"three",BOOLNUM(YES),BOOLNUM(NO),[NSNull null],nil]];
	[self addName:@"Object" jsonString:@"{\"alpha\":1,\"beta\":\"two\",\"gama\":true}" expectedResult:[NSDictionary dictionaryWithObjectsAndKeys:INTNUM(1),@"alpha",@"two",@"beta",BOOLNUM(YES),@"gama", nil]];
	[self addName:@"Object Containing Array" jsonString:@"{\"alpha\":1,\"beta\":[1,false]}" expectedResult:[NSDictionary dictionaryWithObjectsAndKeys:INTNUM(1),@"alpha",[NSArray arrayWithObjects:INTNUM(1),BOOLNUM(NO),nil],@"beta",nil]];
	[self addName:@"Object with White Space" jsonString:@"{ \"alpha\" :  1  , \"beta\"\n:\t\t\"two\" ,  \"gama\":true }  " expectedResult:[NSDictionary dictionaryWithObjectsAndKeys:INTNUM(1),@"alpha",@"two",@"beta",BOOLNUM(YES),@"gama", nil]];
	[self addName:@"Object Containing Array Containing Object etc." jsonString:@"{ \"alpha\" :  1  , \"beta\"\n:\t\t\"two\" ,  \"gama\":[1,2,\"three\",true,false,null,{\"alpha\":1,\"beta\":[1,false]}]}  " expectedResult:[NSNull null]];
	[self addName:@"Nested Object" jsonString:@"{ \"alpha\" : { \"beta\" : 2 }}" expectedResult:[NSDictionary dictionaryWithObjectsAndKeys:[NSDictionary dictionaryWithObjectsAndKeys:INTNUM(2),@"beta",nil],@"alpha", nil]];
	[self addName:@"Nested Object with Array" jsonString:@"{ \"alpha\" : { \"beta\" : 2 }, \"gama\":[3,4]}" expectedResult:[NSDictionary dictionaryWithObjectsAndKeys:[NSDictionary dictionaryWithObjectsAndKeys:INTNUM(2),@"beta",nil],@"alpha",[NSArray arrayWithObjects:INTNUM(3),INTNUM(4),nil], @"gama", nil]];
	NSDictionary	* theDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"file5" ofType:@"plist"]];
	[self addName:@"Large JSON with no spacing" jsonString:@"{\"menu\":{\"header\":\"SVG Viewer\",\"items\": [{\"id\":\"Open\"},{\"id\":\"OpenNew\",\"label\":\"Open New\"},null,{\"id\":\"ZoomIn\",\"label\":\"Zoom In\"},{\"id\":\"ZoomOut\",\"label\":\"Zoom Out\"},{\"id\":\"OriginalView\",\"label\":\"Original View\"},null,{\"id\":\"Quality\"},{\"id\":\"Pause\"},{\"id\":\"Mute\"},null,{\"id\":\"Find\",\"label\":\"Find...\"},{\"id\":\"FindAgain\",\"label\":\"Find Again\"},{\"id\":\"Copy\"},{\"id\":\"CopyAgain\",\"label\":\"Copy Again\"},{\"id\":\"CopySVG\",\"label\":\"Copy SVG\"},{\"id\":\"ViewSVG\",\"label\":\"View SVG\"},{\"id\":\"ViewSource\",\"label\":\"View Source\"},{\"id\":\"SaveAs\",\"label\":\"Save As\"},null,{\"id\":\"Help\"},{\"id\":\"About\",\"label\":\"About Adobe CVG Viewer...\"}]}}"  expectedResult:theDict];
	[super willLoad];
}

@end

@implementation TestString

@synthesize		expectedResult,
				jsonString;

#pragma mark - manually implemented properties

- (NSString *)details
{
	return [NSString stringWithFormat:@"json:\n%@\n\nresult:\n%@\n\nexpected result:\n%@\n\n", self.jsonString, self.lastResult, self.expectedResult];
}

#pragma mark - creation and destruction

+ (id)testStringWithName:(NSString *)aName jsonString:(NSString *)aJSON expectedResult:(id)aResult
{
	return [[[self alloc] initWithName:aName jsonString:aJSON expectedResult:aResult] autorelease];
}
- (id)initWithName:(NSString *)aName jsonString:(NSString *)aJSON expectedResult:(id)aResult
{
	if( (self = [super initWithName:aName]) != nil )
	{
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

#pragma mark - execution

- (id)run
{
	NSError		* theError = nil;
	NDJSONPropertyListGenerator		* theJSON = [[NDJSONPropertyListGenerator alloc] init];
	id			theResult = [theJSON propertyListForJSONString:self.jsonString error:&theError];
	self.lastResult = theResult;
	self.error = theError;
	[theJSON release];
	return self.lastResult;
}

#pragma mark - NSObject overridden methods

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@, name: %@", [self class], self.name];
}


@end

