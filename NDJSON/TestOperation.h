//
//  TestOperation.h
//  NDJSON
//
//  Created by Nathan Day on 8/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol TestProtocol;

@interface TestOperation : NSOperation

@property(readonly) id<TestProtocol>	test;
@property(copy) void (^beginningBlock)(void);

- (id)initWithTestProtocol:(id<TestProtocol>)test;

- (void)logMessage:(NSString *)message;


@end
