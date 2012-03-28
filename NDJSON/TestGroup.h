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
    kTestOperationStateExecuting,
	kTestOperationStateException,
    kTestOperationStateFinished,
	kTestOperationStateTestFailed,
	kTestOperationStateError
};

@protocol TestProtocol <NSObject>

@property(assign)	TestGroup					* testGroup;
@property(readonly,copy)	NSString			* name;
@property(readonly,retain)	id					lastResult;
@property(readonly)	BOOL					hasError;
@property(readonly,retain)	NSError				* error;
@property(assign) enum TestOperationState		operationState;
@property(readonly)	NSString				* details;
- (id)run;

@optional
@property(readonly)	id							expectedResult;

@end

@interface TestGroup : NSObject

@property(readonly)	NSString					* name;
@property(readonly) enum TestOperationState		operationState;

/**
 Methods and protocals to override
 */
@property(readonly)	NSString			* testDescription;
@property(readonly)	NSMutableArray		* everyTest;

- (void)willLoad;
- (enum TestOperationState)operationStateForTestNamed:(NSString *)name;

- (void)addTest:(id<TestProtocol>)test;

@end
