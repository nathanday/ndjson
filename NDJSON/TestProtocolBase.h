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
	NSString					* name;
	id							lastResult;
	NSError						* error;
	TestGroup					* testGroup;
	enum TestOperationState		operationState;
}

@property(readwrite,assign)	TestGroup			* testGroup;
@property(readwrite,copy)	NSString			* name;
@property(readwrite,retain)	id					lastResult;
@property(readwrite,retain)	NSError				* error;
@property(assign) enum TestOperationState		operationState;

- (id)initWithName:(NSString *)name;

@end
