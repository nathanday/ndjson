//
//  TestOperation.m
//  NDJSON
//
//  Created by Nathan Day on 8/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestOperation.h"
#import "TestGroup.h"

@interface TestOperation ()
{
	id<TestProtocol>	test;
	BOOL				succeeded;
	void (^beginningBlock)(void);
}

@end

@implementation TestOperation

@synthesize		test,
				beginningBlock;

#pragma mark - manually implemented properties

- (BOOL)hasError { return self.test.operationState == kTestOperationStateError; }

#pragma creation and destruction

- (id)initWithTestProtocol:(id<TestProtocol>)aTest
{
	if( (self = [super init]) != nil )
	{
		test = [aTest retain];
		test.operationState = kTestOperationStateInited;
	}
	return self;
}

- (void)dealloc
{
    [test release];
    [super dealloc];
}


#pragma mark - NSOperation overridden methods

- (void)main
{
	if( !self.isCancelled )
	{
		self.test.operationState = kTestOperationStateExecuting;
		self.beginningBlock();
		id		theResult = [self.test run];
		
		if( self.test.hasError )
		{
			if( !self.isCancelled )
				succeeded = [theResult isEqual:[self.test expectedResult]];
		}
	}
	self.test.operationState = self.test.hasError ? kTestOperationStateError : kTestOperationStateFinished;
}

- (BOOL)isConcurrent { return NO; }
- (BOOL)isExecuting { return self.test.operationState == kTestOperationStateExecuting; }
- (BOOL)isFinished { return self.test.operationState == kTestOperationStateFinished; }
- (BOOL)isReady { return YES; }


@end
