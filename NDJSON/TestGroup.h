//
//  TestGroup.h
//  NDJSON
//
//  Created by Nathan Day on 6/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>

@class		TestGroup;

enum TestOperationState
{
    kTestOperationStateInitial, 
    kTestOperationStateFinished,
    kTestOperationStateExecuting,
	kTestOperationStateException,
	kTestOperationStateTestFailed,
	kTestOperationStateError
};

@protocol TestProtocol <NSObject>

@property(weak)				TestGroup		* testGroup;
@property(readonly,copy)	NSString		* name;
@property(readonly,retain)	id				lastResult;
@property(readonly)			BOOL			hasError;
@property(readonly,retain)	NSError			* error;
@property(assign,nonatomic) enum TestOperationState	operationState;
@property(readonly)			NSString		* details;
- (id)run;

@optional
@property(readonly)			id				expectedResult;

@end

@interface TestGroup : NSObject

@property(retain)			NSString			* name;
@property(assign,nonatomic) enum TestOperationState		operationState;
@property(assign,getter=isEnabled)	BOOL		enabled;

/**
 Methods and protocals to override
 */
@property(readonly)	NSString			* testDescription;
@property(readonly)	NSMutableArray		* everyTest;

- (void)willLoad;
- (enum TestOperationState)operationStateForTestNamed:(NSString *)name;

- (void)addTest:(id<TestProtocol>)test;

@end
