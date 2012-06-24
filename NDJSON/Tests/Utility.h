//
//  Utility.h
//  NDJSON
//
//  Created by Nathan Day on 23/06/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>

#define INTNUM(_NUM_) [NSNumber numberWithInteger:_NUM_]
#define REALNUM(_NUM_) [NSNumber numberWithDouble:_NUM_]
#define BOOLNUM(_NUM_) [NSNumber numberWithBool:_NUM_]
#define NULLOBJ [NSNull null]
#define ARRAY(...) [NSArray arrayWithObjects:__VA_ARGS__,nil]
#define DICT(...) [NSDictionary dictionaryWithObjectsAndKeys:__VA_ARGS__,nil]
