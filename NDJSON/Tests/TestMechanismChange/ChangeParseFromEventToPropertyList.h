//
//  ChangeParseFromEventToPropertyList.h
//  NDJSON
//
//  Created by Nathan Day on 23/06/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NDJSON.h"
#import "NDJSONParser.h"

@interface ChangeParseFromEventToPropertyList : NSObject<NDJSONDelegate>

@property(copy)			NSString		* dValue;
@property(retain)		NSDictionary	* genValue;
@property(assign)		BOOL			nextValueForD;

+ (NDJSONOptionFlags)options;
+ (NSString *)name;
+ (NSString *)jsonString;
+ (id)expectedResult;

@end
