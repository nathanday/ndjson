//
//  JSONChildBeta.h
//  NDJSON
//
//  Created by Nathan Day on 11/06/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class JSONChildGama, JSONRoot;

@interface JSONChildBeta : NSManagedObject

@property (nonatomic) float floatBetaValue;
@property (nonatomic, retain) NSString * stringBetaValue;
@property (nonatomic, retain) JSONRoot *parent;
@property (nonatomic, retain) JSONChildGama *subChildC;

@end
