//
//  NSObject+TestUtilities.m
//  NDJSON
//
//  Created by Nathan Day on 11/06/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import "NSObject+TestUtilities.h"

@implementation NSObject (TestUtilities)

- (BOOL)isLike:(id)obj { return [self isEqual:obj]; }
- (NSString *)detailedDescription { return [NSString stringWithFormat:@"<%@>%@", NSStringFromClass([self class]), self.description]; }

@end

@implementation NSSet (TestUtilities)

- (BOOL)isLike:(id)obj
{
	BOOL	theResult = [obj isKindOfClass:[NSSet class]] && [obj count] == [self count];
	if( theResult == YES )
	{
		for( id theOuter in self )
		{
			theResult = NO;
			for( id theInner in obj )
			{
				if( [theOuter isLike:theInner] )
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

- (NSString *)detailedDescription
{
	NSMutableString		* theValue = nil;
	for( id theObj in self )
	{
		if( theValue == nil )
			theValue = [NSMutableString stringWithFormat:@"%@", [theObj detailedDescription]];
		else
			[theValue appendFormat:@",\n%@", [theObj detailedDescription]];
	}
	
	return [NSString stringWithFormat:@"(%@)", theValue ? theValue : @""];
}

@end

@implementation NSDictionary (TestUtilities)

- (NSString *)detailedDescription
{
	NSMutableString		* theValue = nil;
	for( id theKey in self )
	{
		if( theValue == nil )
			theValue = [NSMutableString stringWithFormat:@"%@:%@", [theKey detailedDescription], [[self objectForKey:theKey] detailedDescription]];
		else
			[theValue appendFormat:@",\n%@:%@", [theKey detailedDescription], [[self objectForKey:theKey] detailedDescription]];
	}

	return [NSString stringWithFormat:@"{%@}", theValue];
}

@end

@implementation NSArray (TestUtilities)

- (BOOL)isLike:(id)obj
{
	BOOL	theResult = [obj isKindOfClass:[NSArray class]];
	for( NSUInteger i = 0, ci = self.count && theResult; i < ci; i++ )
	{
		for( NSUInteger j = 0, cj = [obj count] && theResult; j < cj; j++ )
			theResult = [[self objectAtIndex:i] isLike:[obj objectAtIndex:j]];
	}
	return theResult;
}

- (NSString *)detailedDescription
{
	NSMutableString		* theValue = nil;
	for( id theObj in self )
	{
		if( theValue == nil )
			theValue = [NSMutableString stringWithFormat:@"%@", [theObj detailedDescription]];
		else
			[theValue appendFormat:@",\n%@", [theObj detailedDescription]];
	}
	
	return [NSString stringWithFormat:@"[%@]", theValue ? theValue : @""];
}

@end

@implementation NSString (TestUtilities)

- (NSString *)detailedDescription
{
	NSString		* theValue = [[self stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"] stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""];
	return [NSString stringWithFormat:@"\"%@\"", theValue ? theValue : @""];
}

@end