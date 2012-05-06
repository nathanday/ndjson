//
//  TestCustomObjectsExtended.h
//  NDJSON
//
//  Created by Nathan Day on 29/04/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TestProtocolBase.h"

@interface TestCustomObjectsExtended : TestProtocolBase
{
    NSString    * jsonSourceString;
    Class       rootClass;
}

+ (void)addTestsToTestGroup:(TestGroup *)testGroup;

+ (id)testCustomObjectsSimpleWithName:(NSString *)name jsonSourceString:(NSString *)source rootClass:(Class)rootClass;
- (id)initWithName:(NSString *)name jsonSourceString:(NSString *)source rootClass:(Class)rootClass;

@end
