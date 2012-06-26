//
//  ChangeParseFromEventToCoreData.h
//  NDJSON
//
//  Created by Nathan Day on 23/06/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NDJSON.h"
#import "NDJSONParser.h"
#import "TestProtocolBase.h"

@interface ChangeParseFromEventToCoreData : TestProtocolBase<NDJSONDelegate>

@property(copy)			NSString				* dValue;
@property(retain)		id						genValue;
@property(assign)		BOOL					nextValueForD;
@property(readonly)		NSManagedObjectContext	* managedObjectContext;

+ (NDJSONOptionFlags)options;
+ (NSString *)name;
+ (NSString *)jsonString;
+ (id)expectedResultForManagedObjectContext:(NSManagedObjectContext *)context;

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)aManagedObjectContext;

@end

