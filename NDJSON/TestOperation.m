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
		test.operationState = kTestOperationStateInitial;
	}
	return self;
}

- (void)dealloc
{
    [test release];
	[beginningBlock release];
    [super dealloc];
}


#pragma mark - NSOperation overridden methods

- (void)main
{
	if( !self.isCancelled )
	{
		id		theResult = nil;
		self.test.operationState = kTestOperationStateExecuting;
		self.beginningBlock();
		@try
		{
			theResult = [self.test run];
			if( !self.test.hasError )
			{
				if( !self.isCancelled && [self.test respondsToSelector:@selector(expectedResult)] )
				{
					id		theExpectedResult = [self.test expectedResult];
					succeeded = [theResult isEqual:theExpectedResult];
				}
			}
			self.test.operationState = self.test.hasError ? kTestOperationStateError : kTestOperationStateFinished;
		}
		@catch (NSException *exception)
		{
			succeeded = NO;
			self.test.operationState = kTestOperationStateException;
		}		
	}
	else
		self.test.operationState = kTestOperationStateFinished;
}

- (BOOL)isConcurrent { return NO; }
- (BOOL)isExecuting { return self.test.operationState == kTestOperationStateExecuting; }
- (BOOL)isFinished { return self.test.operationState == kTestOperationStateFinished; }
- (BOOL)isReady { return YES; }


@end
