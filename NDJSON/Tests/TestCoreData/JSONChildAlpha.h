//
//  JSONChildAlpha.h
//  NDJSON
//
//  Created by Nathan Day on 11/06/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class JSONRoot;

@interface JSONChildAlpha : NSManagedObject

@property (nonatomic) BOOL booleanAlphaValue;
@property (nonatomic, retain) NSString * stringAlphaValue;
@property (nonatomic, retain) JSONRoot *parent;

@end
