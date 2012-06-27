//
//  NSObject+TestUtilities.m
//  NDJSON
//
//  Created by Nathan Day on 11/06/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import "NSObject+TestUtilities.h"

@implementation NSObject (TestUtilities)

- (BOOL)isReallyEqual:(id)obj { return [self isEqual:obj]; }

@end

@implementation NSSet (TestUtilities)

- (BOOL)isReallyEqual:(id)obj
{
	BOOL	theResult = [obj isKindOfClass:[NSSet class]] && [obj count] == [self count];
	if( theResult == YES )
	{
		for( id theOuter in self )
		{
			theResult = NO;
			for( id theInner in obj )
			{
				if( [theOuter isReallyEqual:theInner] )
				{
					theResult = YES;
					break;
				}
			}
			if( theResult == NO )
				break;
		}
	}
	return theResult;
}

@end