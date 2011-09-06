//
//  TestGroup.h
//  NDJSON
//
//  Created by Nathan Day on 6/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol TestProtocol <NSObject>

@property(readonly)	NSString	* name;
@property(readonly)	id			expectedResult;
@property(readonly)	BOOL		hasError;
@property(readonly)	NSError		* error;

- (id)run;

@end

@interface TestGroup : NSObject

@property(readonly)	NSArray		* everyTestName;

- (id<TestProtocol>)testForName:(NSString*)name;

- (void)willLoad;

/**
 Methods and protocals to override
 */
@property(readonly)	NSString	* testDescription;
@property(readonly)	NSArray		* testInstances;


@end
