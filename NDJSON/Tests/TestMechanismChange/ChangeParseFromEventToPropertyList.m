//
//  ChangeParseFromEventToPropertyList.m
//  NDJSON
//
//  Created by Nathan Day on 23/06/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import "ChangeParseFromEventToPropertyList.h"
#import "Utility.h"

@implementation ChangeParseFromEventToPropertyList

@synthesize		dValue,
				genValue;

+ (NDJSONOptionFlags)options { return NDJSONOptionNone; }
+ (NSString *)name { return @"Change Parse from event to property list"; }
+ (NSString *)jsonString { return @"{\"a\":{\"gen\":{\"stringValue\":\"alpha\",\"integerValue\":3,\"arrayValue\":[3.14,true,\"bob\"]},\"c\":{\"d\":\"delta\"}}}"; }

+ (id)expectedResult
{
	ChangeParseFromEventToPropertyList		* theChangeParseFromEventToPropertyList = [[ChangeParseFromEventToPropertyList alloc] init];
	theChangeParseFromEventToPropertyList.dValue = @"delta";
	theChangeParseFromEventToPropertyList.genValue = DICT(@"alpha",@"stringValue",INTNUM(3),@"integerValue",ARRAY(REALNUM(3.14),BOOLNUM(true),@"bob"),@"arrayValue");
	return [theChangeParseFromEventToPropertyList autorelease];
}

- (BOOL)isEqual:(id)anObject
{
	ChangeParseFromEventToPropertyList		* theObject = (ChangeParseFromEventToPropertyList*)anObject;
	return [theObject isKindOfClass:[ChangeParseFromEventToPropertyList class]] && [self.dValue isEqualToString:theObject.dValue] && [self.genValue isEqualToDictionary:theObject.genValue];
}

#pragma mark - NDJSONDelegate methods

- (void)jsonParser:(NDJSON *)aParser foundKey:(NSString *)aValue
{
	if( [aValue isEqualToString:@"d"] )
		self.nextValueForD = YES;
	else if( [aValue isEqualToString:@"gen"] )
	{
		NDJSONParser	* theJSONParser = [[NDJSONParser alloc] init];
		NSError			* theError = nil;
		self.genValue = [theJSONParser objectForJSON:aParser options:NDJSONOptionStrict error:&theError];
		[theJSONParser release];
		if( self.genValue == nil )
			@throw [NSException exceptionWithName:@"error" reason:@"nil result" userInfo:theError.userInfo];
	}
}

- (void)jsonParser:(NDJSON *)aParser foundString:(NSString *)aValue
{
	if( self.nextValueForD )
	{
		self.dValue = aValue;
		self.nextValueForD = NO;
	}
}

- (NSString *)description { return [NSString stringWithFormat:@"{d:%@,gen:%@}", self.dValue, self.genValue]; }

@end
