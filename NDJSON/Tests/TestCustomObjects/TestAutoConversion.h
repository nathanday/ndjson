//
//  TestAutoConversion.h
//  NDJSON
//
//  Created by Nathan Day on 29/04/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TestProtocolBase.h"

@interface TestAutoConversion : TestProtocolBase
{
	NSString    * jsonSourceString;
	BOOL       multipleChildren;
}

+ (void)addTestsToTestGroup:(TestGroup *)testGroup;

+ (id)testCustomObjectsSimpleWithName:(NSString *)name jsonSourceString:(NSString *)source multipleChildren:(BOOL)flag;
- (id)initWithName:(NSString *)name jsonSourceString:(NSString *)source multipleChildren:(BOOL)flag;

@end
