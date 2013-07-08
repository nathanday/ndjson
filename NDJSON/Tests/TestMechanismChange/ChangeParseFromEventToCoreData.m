//
//  ChangeParseFromEventToCoreData.m
//  NDJSON
//
//  Created by Nathan Day on 23/06/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import "ChangeParseFromEventToCoreData.h"
#import "Utility.h"
#import "GenRoot.h"
#import "GenChild.h"
#import "NDCoreDataController.h"
#import "NDJSONCoreDataDeserializer.h"

@implementation ChangeParseFromEventToCoreData

@synthesize		dValue,
				genValue,
				nextValueForD,
				managedObjectContext;

+ (NDJSONOptionFlags)options { return NDJSONOptionNone; }
+ (NSString *)name { return @"Change Parse from event to Core Data Object"; }
+ (NSString *)jsonString { return @"{\"a\":{\"gen\":{\"stringValue\":\"alpha\",\"integerValue\":3,\"arrayValue\":[{\"integerValue\":3},{\"integerValue\":5},{\"integerValue\":8}]},\"c\":{\"d\":\"delta\"}}}"; }

+ (id)expectedResultForManagedObjectContext:(NSManagedObjectContext *)aContext
{
	GenRoot		* theResult = [NSEntityDescription insertNewObjectForEntityForName:@"GenRoot" inManagedObjectContext:aContext];
	GenChild	* theChildren[] = {
		[NSEntityDescription insertNewObjectForEntityForName:@"GenChild" inManagedObjectContext:aContext],
		[NSEntityDescription insertNewObjectForEntityForName:@"GenChild" inManagedObjectContext:aContext],
		[NSEntityDescription insertNewObjectForEntityForName:@"GenChild" inManagedObjectContext:aContext]
	};
	theResult.stringValue = @"alpha";
	theResult.integerValue = 3;
	theChildren[0].integerValue = 3;
	theChildren[1].integerValue = 5;
	theChildren[2].integerValue = 8;
	theResult.arrayValue = [NSSet setWithObjects:theChildren count:sizeof(theChildren)/sizeof(*theChildren)];
	return theResult;
}

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)aManagedObjectContext
{
	NSParameterAssert( aManagedObjectContext != nil );
	if( (self = [super init]) != nil )
		managedObjectContext = aManagedObjectContext;
	return self;
}

- (BOOL)isEqual:(id)anObject
{
	ChangeParseFromEventToCoreData		* theObject = (ChangeParseFromEventToCoreData*)anObject;
	return [theObject isKindOfClass:[ChangeParseFromEventToCoreData class]] && [self.dValue isEqualToString:theObject.dValue] && [self.genValue isEqualToDictionary:theObject.genValue];
}

#pragma mark - NDJSONParserDelegate methods

- (void)json:(NDJSONParser *)aJSON foundKey:(NSString *)aValue
{
	if( [aValue isEqualToString:@"d"] )
		self.nextValueForD = YES;
	else if( [aValue isEqualToString:@"gen"] )
	{
		NDJSONDeserializer			* theJSONParser = [[NDJSONDeserializer alloc] initWithRootEntityName:@"GenRoot" inManagedObjectContext:self.managedObjectContext];
		NSError					* theError = nil;

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
