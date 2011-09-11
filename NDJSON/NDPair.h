//
//  NDPair.h
//  NDJSON
//
//  Created by Nathan Day on 10/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NDPair : NSObject <NSCopying,NSMutableCopying,NSCoding>
@property(readonly,retain)		id		primary,
								secondary;

+ (id)pairWithPrimary:(id)primary secondary:(id)secondary;
- (id)initWithPrimary:(id)primary secondary:(id)secondary;

- (BOOL)containsObject:(id)object;
- (BOOL)containsIdenticalObject:(id)object;

- (BOOL)containsObjectPassingTest:(BOOL (^)(id object))predicate;

- (NDPair *)pairBySwappingObjects;
- (NDPair *)pairByReplacingPrimaryWithObject:(id)object;
- (NDPair *)pairByReplacingSecondaryWithObject:(id)object;

- (BOOL)isEqualToPair:(NDPair *)pair;
- (BOOL)isEqualToArray:(NSArray *)array;
- (BOOL)isEquivelentToPair:(NDPair *)pair;
- (NSArray *)arrayWithObjects;

- (BOOL)containedInDictionary:(NSDictionary *)dictionary;
- (void)addToDictionary:(NSMutableDictionary *)dictionary;

- (BOOL)containedInArray:(NSArray *)array;
- (NSUInteger)indexInArray:(NSArray *)array;
- (void)addToArray:(NSMutableArray *)array;

enum NDPairPosition
{
	NDPairPositionNone = 0,
	NDPairPositionPrimary = 1,
	NDPairPositionSecondary = 2,
	NDPairPositionBoth = 3
};
- (enum NDPairPosition)positionOfObject:(id)object;
- (enum NDPairPosition)positionOfIdenticalObject:(id)object;
- (enum NDPairPosition)positionOfObjectPassingTest:(BOOL (^)(id object))predicate;

@end

@interface NDMutablePair : NDPair

- (void)setPrimary:(id)primary secondary:(id)secondary;
- (void)setPrimary:(id)object;
- (void)setSecondary:(id)object;

- (void)swappingObjects;
- (void)removeAllObjects;

@end
