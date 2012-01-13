//
//  TestOperation.m
//  NDJSON
//
//  Created by Nathan Day on 8/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestOperation.h"
#import "TestGroup.h"
#import "NDAppDelegate.h"
#import "NDJSON.h"

@interface NSNumber (AproximateEqual)
- (BOOL)isEqual:(id)aNumber;
@end

@interface TestOperation ()
{
	id<TestProtocol>	test;
	BOOL				succeeded;
	void (^beginningBlock)(void);
	BOOL (^additionValidation)(TestOperation * aTestOperation);
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
				if( !self.isCancelled )
				{
					if( [self.test respondsToSelector:@selector(expectedResult)] )
					{
						id		theExpectedResult = [self.test expectedResult];
						succeeded = [theResult isEqual:theExpectedResult];
					}
					else
						succeeded = theResult != nil;
				}
			}
			if( succeeded )
				self.test.operationState = self.test.hasError ? kTestOperationStateError : kTestOperationStateFinished;
			else
				self.test.operationState = kTestOperationStateTestFailed;
		}
		@catch (NSException * anException)
		{
			succeeded = NO;
			self.test.operationState = kTestOperationStateException;
			self.completionBlock();
			NDError( @"%@", [anException description] );
		}		
	}
	else
		self.test.operationState = kTestOperationStateFinished;
}

- (BOOL)isConcurrent { return NO; }
- (BOOL)isExecuting { return self.test.operationState == kTestOperationStateExecuting; }
- (BOOL)isFinished { return self.test.operationState >= kTestOperationStateException; }
- (BOOL)isReady { return YES; }

@end

@implementation NSNumber (AproximateEqual)

- (BOOL)isEqual:(id)aNumber
{
	BOOL	theResult = NO;
	if( [aNumber isKindOfClass:[NSNumber class]] )
	{
		if( *[self objCType] == 'd' && *[aNumber objCType] == 'd' )
		{
			double		r = [(id)self doubleValue] - [aNumber doubleValue];
			theResult = r < 0.0000000000000000001 && r > -0.0000000000000000001;
		}
		if( *[self objCType] == 'f' && *[aNumber objCType] == 'f' )
		{
			double		r = [(id)self floatValue] - [aNumber floatValue];
			theResult = r < 0.000000001 && r > -0.000000001;
		}
		else
			theResult = [(id)self isEqualToNumber:aNumber];
	}
	return theResult;
}

@end
