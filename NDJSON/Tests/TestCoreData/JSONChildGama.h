//
//  JSONChildGama.h
//  NDJSON
//
//  Created by Nathan Day on 11/06/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class JSONChildBeta;

@interface JSONChildGama : NSManagedObject

@property (nonatomic, retain) NSString * stringGamaValue;
@property (nonatomic, retain) JSONChildBeta *parent;

@end
