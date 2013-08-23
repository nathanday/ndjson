//
//  TestLargeInput.m
//  NDJSON
//
//  Created by Nathan Day on 6/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestLargeInput.h"
#import "NDJSONDeserializer.h"
#import "TestProtocolBase.h"
#import "NSObject+TestUtilities.h"

@interface TestLargeInput ()
- (void)addName:(NSString *)name jsonString:(NSString *)json expectedResult:(id)expectedResult options:(NDJSONOptionFlags)anOptions;
@end

@interface TestLarge : TestProtocolBase
{
	NSString					* jsonString;
	id							expectedResult;
	NDJSONOptionFlags			options;
}
+ (id)testLargeWithName:(NSString *)name jsonString:(NSString *)json expectedResult:(id)expectedResult options:(NDJSONOptionFlags)options;
- (id)initWithName:(NSString *)name jsonString:(NSString *)json expectedResult:(id)result options:(NDJSONOptionFlags)options;

@property(readonly)			NSString			* jsonString;
@property(readonly)			id					expectedResult;
@property(readonly)			NDJSONOptionFlags	options;
@end

@implementation TestLargeInput

- (NSString *)testDescription { return @"Test input with string, all bytes are available, tests ability to recongnize all kinds of JSON"; }

- (void)addName:(NSString *)aName jsonString:(NSString *)aJSON expectedResult:(id)aResult options:(NDJSONOptionFlags)anOptions
{
	[self addTest:[TestLarge testLargeWithName:aName jsonString:aJSON expectedResult:aResult options:anOptions]];
}

- (void)willLoad
{
	[self addName:@"Very Deep 1" jsonString:@"{\"key1\":{\"key11\":[{\"key111\":[{\"name\": \"name1\",\"value\": \"value1\"},{\"name\": \"name2\",\"value\": \"value2\"}],\"key112\": \"value3\"},{\"key113\": [{\"name\": \"name4\",\"value\": \"value4\"},{\"name\": \"name5\",\"value\": \"value5\"}],\"key114\": \"value6\"}]}}" expectedResult:@{@"key1":@{@"key11":@[@{@"key111":@[@{@"name": @"name1",@"value": @"value1"},@{@"name": @"name2",@"value": @"value2"}],@"key112": @"value3"},@{@"key113": @[@{@"name": @"name4",@"value": @"value4"},@{@"name": @"name5",@"value": @"value5"}],@"key114": @"value6"}]}} options:NDJSONOptionNone];

	[self addName:@"Very Deep 2" jsonString:@"{\"k1\":\"v1\",\"k2\":\"v2\",\"k3\":[],\"k4\":{\"k5\":{\"k6\":\"v6\",\"k7\":\"v7\",\"k8\":\"v8\",},\"k9\":{\"k10\":\"v10\",\"k11\":\"v11\",},\"k12\":{\"k13\":\"v13\",\"k14\":\"v14\",}},\"k15\":{\"k16\":{\"k17\":{\"k18\":\"v18\",\"k19\":\"v19\",\"k20\":\"v20\",\"k21\":\"v21\",\"k22\":\"v22\",\"k-23\":23,\"k-24\":24,\"k-25\":2025},\"k26\":{\"k-27\":\"v27\",\"k-28\":\"v28\",\"k29\":\"v29\",\"k30\":\"v30\",\"k31\":\"v31\",\"k32\":\"v32\",\"k33\":\"v33\",\"k34\":\"v34\"},\"k35\":{\"k36\":\"v36\",\"k37\":\"v37\",\"k38\":\"v38\",\"k39\":\"v39\",\"k40\":\"v40\",\"k41\":\"v41\"}},\"k42\":{\"k43\":{\"k44\":\"v44\",\"k45\":\"v45\",\"k46\":\"v46\",\"k47\":\"v47\",\"k48\":\"v48\",\"k-49\":49,\"k-50\":50,\"k-51\":2051},\"k52\":{\"k-53\":\"v53\",\"k-54\":\"v54\",\"k55\":\"v55\",\"k56\":\"v56\",\"k57\":\"v57\",\"k58\":\"v58\",\"k59\":\"v59\",\"k60\":\"v60\"},\"k61\":{\"k62\":\"v62\",\"k63\":\"v63\",\"k64\":\"v64\",\"k65\":\"v65\",\"k66\":\"v66\",\"k67\":\"v67\"}}}}" expectedResult:@{@"k1":@"v1",@"k2":@"v2",@"k3":@[],@"k4":@{@"k5":@{@"k6":@"v6",@"k7":@"v7",@"k8":@"v8",},@"k9":@{@"k10":@"v10",@"k11":@"v11",},@"k12":@{@"k13":@"v13",@"k14":@"v14",}},@"k15":@{@"k16":@{@"k17":@{@"k18":@"v18",@"k19":@"v19",@"k20":@"v20",@"k21":@"v21",@"k22":@"v22",@"k-23":@23,@"k-24":@24,@"k-25":@2025},@"k26":@{@"k-27":@"v27",@"k-28":@"v28",@"k29":@"v29",@"k30":@"v30",@"k31":@"v31",@"k32":@"v32",@"k33":@"v33",@"k34":@"v34"},@"k35":@{@"k36":@"v36",@"k37":@"v37",@"k38":@"v38",@"k39":@"v39",@"k40":@"v40",@"k41":@"v41"}},@"k42":@{@"k43":@{@"k44":@"v44",@"k45":@"v45",@"k46":@"v46",@"k47":@"v47",@"k48":@"v48",@"k-49":@49,@"k-50":@50,@"k-51":@2051},@"k52":@{@"k-53":@"v53",@"k-54":@"v54",@"k55":@"v55",@"k56":@"v56",@"k57":@"v57",@"k58":@"v58",@"k59":@"v59",@"k60":@"v60"},@"k61":@{@"k62":@"v62",@"k63":@"v63",@"k64":@"v64",@"k65":@"v65",@"k66":@"v66",@"k67":@"v67"}}}} options:NDJSONOptionNone];

	NSDictionary	* theDict = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"file4" ofType:@"plist"]];
	[self addName:@"Large JSON with no spacing" jsonString:@"{title:\"javascriptkit.com\",link:\"http://www.javascriptkit.com\",description:\"JavaScript tutorials and over 400+ free scripts!\",language:\"en\",items:[{title:\"Document Text Resizer\",link:\"http://www.javascriptkit.com/script/script2/doctextresizer.shtml\",description:\"This script adds the ability for your users to toggle your webpage's font size, with persistent cookies then used to remember the setting\"},{title:\"JavaScript Reference- Keyboard/ Mouse Buttons Events\",link:\"http://www.javascriptkit.com/jsref/eventkeyboardmouse.shtml\",description:\"The latest update to our JS Reference takes a hard look at keyboard and mouse button events in JavaScript, including the unicode value of each key.\"},{title:\"Dynamically loading an external JavaScript or CSS file\",link:\"http://www.javascriptkit.com/javatutors/loadjavascriptcss.shtml\",description:\"External JavaScript or CSS files do not always have to be synchronously loaded as part of the page, but dynamically as well. In this tutorial, see how.\"}]}"  expectedResult:theDict options:NDJSONOptionNone];
	[self addName:@"Bad Property Names" jsonString:@"{\"NUMBER one\":1,\"number-two\":2,\"number+3\":3,\"number:four\":4,\"numberFive\":5,\"\t\nNumber   \t\tSix  \":6}" expectedResult:@{@"NUMBEROne":@1,@"numberTwo":@2,@"number3":@3,@"numberFour":@4,@"numberFive":@5,@"numberSix":@6} options:NDJSONOptionConvertKeysToMedialCapitals];
	[super willLoad];
}

@end

@implementation TestLarge

@synthesize		expectedResult,
				jsonString,
				options;

#pragma mark - manually implemented properties

- (NSString *)details
{
	return [NSString stringWithFormat:@"json:\n%@\n\nresult:\n%@\n\nexpected result:\n%@\n\n", self.jsonString, [self.lastResult detailedDescription], [self.expectedResult detailedDescription]];
}

#pragma mark - creation and destruction

+ (id)testLargeWithName:(NSString *)aName jsonString:(NSString *)aJSON expectedResult:(id)aResult options:(NDJSONOptionFlags)anOptions
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

