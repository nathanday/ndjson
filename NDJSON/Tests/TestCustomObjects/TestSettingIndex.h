//
//  TestSettingIndex.h
//  NDJSON
//
//  Created by Nathan Day on 22/04/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import "TestProtocolBase.h"

@interface TestSettingIndex : TestProtocolBase
{
	NSString	* jsonSourceString;
	id			expectedResult;
}

@property(readonly)			id					expectedResult;

+ (void)addTestsToTestGroup:(TestGroup *)testGroup;

+ (id)testCustomObjectsSimpleWithName:(NSString *)name jsonSourceString:(NSString *)source expectedResult:(id)expectedResult;
- (id)initWithName:(NSString *)name jsonSourceString:(NSString *)source expectedResult:(id)expectedResult;

@end
