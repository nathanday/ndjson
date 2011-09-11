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
    kTestOperationStateInited, 
    kTestOperationStateExecuting, 
    kTestOperationStateFinished,
	kTestOperationStateError
};

@protocol TestProtocol <NSObject>

@property(readonly)	TestGroup					* testGroup;
@property(readonly)	NSString					* name;
@property(readonly)	id							expectedResult;
@property(readonly)	BOOL						hasError;
@property(readonly)	NSError						* error;
@property(assign) enum TestOperationState		operationState;
- (id)run;

@end

@interface TestGroup : NSObject

@property(readonly)	NSString	* name;
/**
 Methods and protocals to override
 */
@property(readonly)	NSString	* testDescription;
@property(readonly)	NSArray		* everyTest;

- (void)willLoad;
- (enum TestOperationState)operationStateForTestNamed:(NSString *)name;

@end
