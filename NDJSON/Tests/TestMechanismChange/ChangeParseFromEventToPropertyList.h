//
//  ChangeParseFromEventToPropertyList.h
//  NDJSON
//
//  Created by Nathan Day on 23/06/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NDJSONParser.h"
#import "NDJSONDeserializer.h"
#import "TestProtocolBase.h"

@interface ChangeParseFromEventToPropertyList : TestProtocolBase<NDJSONParserDelegate>

@property(copy)			NSString		* dValue;
@property(retain)		NSDictionary	* genValue;
@property(assign)		BOOL			nextValueForD;

+ (NDJSONOptionFlags)options;
+ (NSString *)name;
+ (NSString *)jsonString;
+ (id)expectedResultForManagedObjectContext:(NSManagedObjectContext *)context;

@end

