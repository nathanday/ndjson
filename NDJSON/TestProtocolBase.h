//
//  TestProtocolBase.h
//  NDJSON
//
//  Created by Nathan Day on 19/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TestGroup.h"

@interface TestProtocolBase : NSObject <TestProtocol>
{
	__strong NSString			* name;
	__strong id					lastResult;
	__strong NSError			* error;
	__weak TestGroup			* testGroup;
	enum TestOperationState		operationState;
}

@property(readwrite,weak)	TestGroup			* testGroup;
@property(readwrite,copy)	NSString			* name;
@property(readwrite,retain)	id					lastResult;
@property(readwrite,retain)	NSError				* error;
@property(assign,nonatomic) enum TestOperationState		operationState;

- (id)initWithName:(NSString *)name;

@end
