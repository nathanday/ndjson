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
				genValue,
				nextValueForD;

+ (NDJSONOptionFlags)options { return NDJSONOptionNone; }
+ (NSString *)name { return @"Change Parse from Event to Property List"; }
+ (NSString *)jsonString { return @"{\"a\":{\"gen\":{\"stringValue\":\"alpha\",\"integerValue\":3,\"arrayValue\":[3.14,true,\"bob\"]},\"c\":{\"d\":\"delta\"}}}"; }

+ (id)expectedResultForManagedObjectContext:(NSManagedObjectContext *)aContext
{
	ChangeParseFromEventToPropertyList		* theChangeParseFromEventToPropertyList = [[ChangeParseFromEventToPropertyList alloc] init];
	theChangeParseFromEventToPropertyList.dValue = @"delta";
	theChangeParseFromEventToPropertyList.genValue = @{@"stringValue":@"alpha",@"integerValue":@3,@"arrayValue":@[@3.14,@YES,@"bob"]};
	return theChangeParseFromEventToPropertyList;
}

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)aManagedObjectContext { return [super init]; }

- (BOOL)isEqual:(id)anObject
{
	ChangeParseFromEventToPropertyList		* theObject = (ChangeParseFromEventToPropertyList*)anObject;
	return [theObject isKindOfClass:[ChangeParseFromEventToPropertyList class]] && [self.dValue isEqualToString:theObject.dValue] && [self.genValue isEqualToDictionary:theObject.genValue];
}

#pragma mark - NDJSONParserDelegate methods

- (void)json:(NDJSONParser *)aJSON foundKey:(NSString *)aValue
{
	if( [aValue isEqualToString:@"d"] )
		self.nextValueForD = YES;
	else if( [aValue isEqualToString:@"gen"] )
	{
		NDJSONDeserializer	* theJSONParser = [[NDJSONDeserializer alloc] init];
		NSError			* theError = nil;
		self.genValue = [theJSONParser objectForJSON:aJSON options:NDJSONOptionStrict error:&theError];
		if( self.genValue == nil )
			@throw [NSException exceptionWithName:@"error" reason:@"nil result" userInfo:theError.userInfo];
	}
}

- (void)json:(NDJSONParser *)aJSON foundString:(NSString *)aValue
{
	if( self.nextValueForD )
	{
		self.dValue = aValue;
		self.nextValueForD = NO;
	}
}

- (NSString *)description { return [NSString stringWithFormat:@"{d:%@,gen:%@}", self.dValue, self.genValue]; }

@end
