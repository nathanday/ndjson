//
//  TestProtocolBase.m
//  NDJSON
//
//  Created by Nathan Day on 19/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestProtocolBase.h"

@implementation TestProtocolBase

@synthesize					testGroup,
							name,
							lastResult,
							error,
							operationState;
- (BOOL)hasError { return self.error != nil; }

- (id)initWithName:(NSString *)aName
{
	if( (self = [super init]) != nil )
	{
		operationState = kTestOperationStateInitial;
		name = [aName copy];
	}
	return self;
}

- (void)dealloc
{
	[name release];
	[lastResult release];
	[error release];
    [super dealloc];
}

- (NSString *)details { return [NSString stringWithFormat:@"result:\n%@\n\nexpected result:\n%@\n\n", self.lastResult, self.expectedResult]; }

- (id)run
{
	NSAssert( NO, @"Method %@ is abstract and must be overridden in the class %@", NSStringFromSelector(_cmd), [self class] );
	return nil;
}

@end
