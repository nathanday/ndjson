//
//  GenChild.h
//  NDJSON
//
//  Created by Nathan Day on 26/06/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class GenRoot;

@interface GenChild : NSManagedObject

@property (nonatomic) int32_t integerValue;
@property (nonatomic, retain) GenRoot *parent;

@end
