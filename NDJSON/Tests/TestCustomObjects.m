//
//  TestCustomObjects.m
//  NDJSON
//
//  Created by Nathan Day on 25/03/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import "TestCustomObjects.h"
#import "TestProtocolBase.h"
#import "NDJSONParser.h"
#import "TestCustomObjectsSimple.h"
#import "TestCustomObjectsExtended.h"

@implementation TestCustomObjects

- (NSString *)testDescription { return @"Test of parsing to custom objects instead of property list objects."; }

- (void)willLoad
{
	[TestCustomObjectsSimple addTestsToTestGroup:self];
    [TestCustomObjectsExtended addTestsToTestGroup:self];
}

@end

