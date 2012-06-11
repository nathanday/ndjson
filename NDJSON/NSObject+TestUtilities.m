//
//  NSObject+TestUtilities.m
//  NDJSON
//
//  Created by Nathan Day on 11/06/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import "NSObject+TestUtilities.h"

@implementation NSObject (TestUtilities)

- (BOOL)isReallyEqual:(id)obj { return [self isEqual:obj]; }

@end
