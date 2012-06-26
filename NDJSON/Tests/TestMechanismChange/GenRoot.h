//
//  GenRoot.h
//  NDJSON
//
//  Created by Nathan Day on 26/06/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class GenChild;

@interface GenRoot : NSManagedObject

@property (nonatomic) int32_t integerValue;
@property (nonatomic, retain) NSString * stringValue;
@property (nonatomic, retain) NSSet *arrayValue;
@end

@interface GenRoot (CoreDataGeneratedAccessors)

- (void)addArrayValueObject:(GenChild *)value;
- (void)removeArrayValueObject:(GenChild *)value;
- (void)addArrayValue:(NSSet *)values;
- (void)removeArrayValue:(NSSet *)values;

@end
