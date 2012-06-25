//
//  ChangeParseFromEventToCustom.m
//  NDJSON
//
//  Created by Nathan Day on 23/06/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import "ChangeParseFromEventToCustom.h"
#import "Utility.h"

@interface GenObject : NSObject

@property(copy)		NSString	* stringValue;
@property(assign)	NSInteger	integerValue;
@property(retain)	NSSet		* arrayValue;

@end

@implementation ChangeParseFromEventToCustom

@synthesize		dValue,
				genValue;

+ (NDJSONOptionFlags)options { return NDJSONOptionNone; }
+ (NSString *)name { return @"Change Parse from event to Custom Object"; }
+ (NSString *)jsonString { return @"{\"a\":{\"gen\":{\"stringValue\":\"alpha\",\"integerValue\":3,\"arrayValue\":[3.14,true,\"bob\"]},\"c\":{\"d\":\"delta\"}}}"; }

+ (id)expectedResult
{
	ChangeParseFromEventToCustom		* theChangeParseFromEventToCustom = [[ChangeParseFromEventToCustom alloc] init];
	GenObject							* theGenObject = [[GenObject alloc] init];
	theChangeParseFromEventToCustom.dValue = @"delta";
	theChangeParseFromEventToCustom.genValue = theGenObject;
	theGenObject.stringValue = @"alpha";
	theGenObject.integerValue = 3;
	theGenObject.arrayValue = [NSSet setWithObjects:REALNUM(3.14),BOOLNUM(true),@"bob",nil];
	[theGenObject release];
	return [theChangeParseFromEventToCustom autorelease];
}

- (BOOL)isEqual:(id)anObject
{
	ChangeParseFromEventToCustom		* theObject = (ChangeParseFromEventToCustom*)anObject;
	return [theObject isKindOfClass:[ChangeParseFromEventToCustom class]] && [self.dValue isEqualToString:theObject.dValue] && [self.genValue isEqualToDictionary:theObject.genValue];
}

#pragma mark - NDJSONDelegate methods

- (void)json:(NDJSON *)aJSON foundKey:(NSString *)aValue
{
	if( [aValue isEqualToString:@"d"] )
		self.nextValueForD = YES;
	else if( [aValue isEqualToString:@"gen"] )
	{
		NDJSONParser	* theJSONParser = [[NDJSONParser alloc] initWithRootClass:[GenObject class]];
		NSError			* theError = nil;
		self.genValue = [theJSONParser objectForJSON:aJSON options:NDJSONOptionStrict error:&theError];
		[theJSONParser release];
		if( self.genValue == nil )
			@throw [NSException exceptionWithName:@"error" reason:@"nil result" userInfo:theError.userInfo];
	}
}

- (void)json:(NDJSON *)aJSON foundString:(NSString *)aValue
{
	if( self.nextValueForD )
	{
		self.dValue = aValue;
		self.nextValueForD = NO;
	}
}

- (NSString *)description { return [NSString stringWithFormat:@"{d:%@,gen:%@}", self.dValue, self.genValue]; }

@end

@implementation GenObject

@synthesize		stringValue,
				integerValue,
				arrayValue;

- (BOOL)isEqual:(id)anObject
{
	GenObject		* theObj = (GenObject*)anObject;
	return [theObj isKindOfClass:[GenObject class]] && [self.stringValue isEqualToString:theObj.stringValue] && self.integerValue == theObj.integerValue && [self.arrayValue isEqualToSet:theObj.arrayValue];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@>{stringValue: %@, integerValue: %ld, arrayValue<%@>: %@}", [self class], self.stringValue, self.integerValue, [self.arrayValue class], self.arrayValue];
}

@end
