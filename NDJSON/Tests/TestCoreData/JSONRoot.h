//
//  JSONRoot.h
//  NDJSON
//
//  Created by Nathan Day on 11/06/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class JSONChildAlpha, JSONChildBeta;

@interface JSONRoot : NSManagedObject

@property (nonatomic) int32_t integerValue;
@property (nonatomic, retain) NSString * stringValue;
@property (nonatomic, retain) JSONChildAlpha *alphaObject;
@property (nonatomic, retain) NSSet *betaObject;
@end

@interface JSONRoot (CoreDataGeneratedAccessors)

- (void)addBetaObjectObject:(JSONChildBeta *)value;
- (void)removeBetaObjectObject:(JSONChildBeta *)value;
- (void)addBetaObject:(NSSet *)values;
- (void)removeBetaObject:(NSSet *)values;

@end
