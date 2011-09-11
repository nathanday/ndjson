//
//  NDPair.m
//  NDJSON
//
//  Created by Nathan Day on 10/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "NDPair.h"

static NSString		* const kPrimaryObjectKey = @"primary",
					* const kSecondaryObjectKey = @"secondary";

@interface NDPair ()
{
@protected
	id		primary,
			secondary;
}

@end

@implementation NDPair

@synthesize		primary,
				secondary;

+ (id)pairWithPrimary:(id)aPrimary secondary:(id)aSecondary { return [[[self alloc] initWithPrimary:aPrimary secondary:aSecondary] autorelease]; }

- (id)initWithPrimary:(id)aPrimary secondary:(id)aSecondary
{
	if( (self = [super init]) != nil )
	{
		primary = [aPrimary retain];
		secondary = [aSecondary retain];
	}
	return self;
}

- (void)dealloc {
    [primary release];
	[secondary release];
    [super dealloc];
}

- (BOOL)containsObject:(id)anObject { return [self.primary isEqual:anObject] || [self.secondary isEqual:anObject]; }
- (BOOL)containsIdenticalObject:(id)anObject { return self.primary == anObject || self.secondary == anObject; }

- (BOOL)containsObjectPassingTest:(BOOL (^)(id object))aPredicate { return aPredicate(self.primary) || aPredicate(self.secondary); }

- (NDPair *)pairBySwappingObjects { return [NDPair pairWithPrimary:self.secondary secondary:self.primary]; }
- (NDPair *)pairByReplacingPrimaryWithObject:(id)anObject { return [NDPair pairWithPrimary:anObject secondary:self.secondary]; }

- (NDPair *)pairByReplacingSecondaryWithObject:(id)anObject { return [NDPair pairWithPrimary:self.primary secondary:anObject]; }
- (BOOL)isEqualToPair:(NDPair *)aPair { return [self.primary isEqual:aPair.primary] && [self.secondary isEqual:aPair.secondary]; }

- (BOOL)isEqualToArray:(NSArray *)anArray
{
	return anArray.count == 2 && [[anArray objectAtIndex:0] isEqual:self.primary] && [[anArray objectAtIndex:1] isEqual:self.secondary];
}

- (BOOL)isEquivelentToPair:(NDPair *)aPair
{
	return ([self.primary isEqual:aPair.primary] && [self.secondary isEqual:aPair.secondary])
		|| ([self.primary isEqual:aPair.secondary] && [self.secondary isEqual:aPair.primary]);
}

- (NSArray *)arrayWithObjects { return [NSArray arrayWithObjects:self.primary, self.secondary, nil]; }
- (BOOL)containedInDictionary:(NSDictionary *)aDictionary { return [[aDictionary objectForKey:self.primary] isEqual:self.secondary]; }
- (void)addToDictionary:(NSMutableDictionary *)aDictionary { [aDictionary setObject:self.secondary forKey:self.primary]; }
- (BOOL)containedInArray:(NSArray *)anArray { return [self indexInArray:anArray] != NSNotFound; }

- (NSUInteger)indexInArray:(NSArray *)anArray
{
	NSUInteger	theResult = 0;
	BOOL		theHaveFirst = NO;
	for( id anObject in anArray )
	{
		if( theHaveFirst )
		{
			if( [anObject isEqual:self.secondary] )
				return theResult;
			else if( ![anObject isEqual:self.primary] )
				theHaveFirst = NO;
		}
		else if( [anObject isEqual:self.primary] )
			theHaveFirst = YES;
		theResult++;
	}
	return NSNotFound;
}

- (void)addToArray:(NSMutableArray *)anArray
{
	[anArray addObject:self.primary];
	[anArray addObject:self.secondary];
}

- (enum NDPairPosition)positionOfObject:(id)anObject
{
	return [self positionOfObjectPassingTest:^(id anObj){ return [anObj isEqual:anObject]; }];
}

- (enum NDPairPosition)positionOfIdenticalObject:(id)anObject
{
	return [self positionOfObjectPassingTest:^(id anObj){ return (BOOL)(anObj == anObject); }];
}

- (enum NDPairPosition)positionOfObjectPassingTest:(BOOL (^)(id object))aPredicate
{
	enum NDPairPosition		theResult = NDPairPositionNone;
	if( aPredicate(self.primary) )
		theResult |= NDPairPositionPrimary;
	if( aPredicate(self.secondary) )
		theResult |= NDPairPositionSecondary;
	return theResult;
}

#pragma mark - NSCopying protocol methods

- (id)copyWithZone:(NSZone *)aZone
{
	return [[NDPair allocWithZone:aZone] initWithPrimary:self.primary secondary:self.secondary];
}

#pragma mark - NSMutableCopying protocol methods

- (id)mutableCopyWithZone:(NSZone *)aZone
{
	return [[NDMutablePair allocWithZone:aZone] initWithPrimary:self.primary secondary:self.secondary];
}

#pragma mark - NSCoding protocol methods

- (void)encodeWithCoder:(NSCoder *)aCoder
{
	if( [aCoder allowsKeyedCoding] )
	{
		[aCoder encodeObject:self.primary forKey:kPrimaryObjectKey];
		[aCoder encodeObject:self.secondary forKey:kSecondaryObjectKey];
	}
	else
	{
		[aCoder encodeObject:self.primary];
		[aCoder encodeObject:self.secondary];
	}
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if( (self = [self init]) != nil )
	{
		if( [aDecoder allowsKeyedCoding] )
		{
			primary = [aDecoder decodeObjectForKey:kPrimaryObjectKey];
			secondary = [aDecoder decodeObjectForKey:kSecondaryObjectKey];
		}
		else
		{
			primary = [aDecoder decodeObject];
			secondary = [aDecoder decodeObject];
		}
	}
	return self;
}

#pragma mark - NSObject overridden methods

- (NSUInteger)hash { return [self.primary hash] ^ [self.secondary hash]; }

- (BOOL)isEqual:(id)anObject
{
	BOOL	theResult = NO;
	if( [anObject isKindOfClass:[NDPair class]] )
		theResult = [self isEqualToPair:anObject];
	else if( [anObject isKindOfClass:[NSArray class]] )
		theResult = [self isEqualToArray:anObject];
	return theResult;
}

- (NSString *)description { return [NSString stringWithFormat:@"{primary: %@, secondary: %@}", self.primary, self.secondary]; }

@end

@implementation NDMutablePair

- (void)setPrimary:(id)aPrimary secondary:(id)aSecondary
{
	[self setPrimary:aPrimary];
	[self setSecondary:aSecondary];
}

- (void)setPrimary:(id)anObject
{
	if( anObject != primary )
	{
		[primary release];
		primary = [anObject retain];
	}
}
- (void)setSecondary:(id)anObject
{
	if( anObject != primary )
	{
		[secondary release];
		secondary = [anObject retain];
	}
}

- (void)swappingObjects
{
	if( primary != secondary )
	{
		id	theTemp = primary;
		primary = secondary;
		secondary = theTemp;
	}
}

- (void)removeAllObjects
{
	[primary release], primary = nil;
	[secondary release], secondary = nil;
}


@end
