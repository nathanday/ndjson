//
//  NDJSONToPropertyList.m
//  NDJSON
//
//  Created by Nathan Day on 31/08/11.
//  Copyright 2011 Nathan Day. All rights reserved.
//

#import "NDJSON.h"
#import "NDJSONToPropertyList.h"
#import "NDJSONCore.h"

#pragma mark - cluster class subclass NDJSONToPropertyList interface
@interface NDJSONToPropertyList () <NDJSONDelegate>
{
	struct NDJSONGeneratorContext	generatorContext;
}

@end

#pragma mark - NDJSONToPropertyList implementation
@implementation NDJSONToPropertyList

#pragma mark - parsing methods

- (id)propertyListForJSONString:(NSString *)aString error:(__autoreleasing NSError **)aError
{
	id					theResult =  nil;
	NSAssert( aString != nil, @"nil input JSON string" );
	NDJSON			* theJSONParser = [[NDJSON alloc] initWithDelegate:self];
	if( theJSONParser != nil )
	{
		if( [theJSONParser parseJSONString:aString error:aError] )
			theResult = generatorContext.root;
	}
	[theJSONParser release];
	return theResult;
}

- (id)propertyListForContentsOfFile:(NSString *)aPath error:(__autoreleasing NSError **)aError
{
	id					theResult =  nil;
	NSAssert( aPath != nil, @"nil input path" );
	NDJSON			* theJSONParser = [[NDJSON alloc] initWithDelegate:self];
	if( theJSONParser != nil )
	{
		if( [theJSONParser parseContentsOfFile:aPath error:aError] )
			theResult = generatorContext.root;
	}
	[theJSONParser release];
	return theResult;
}

- (id)propertyListForContentsOfURL:(NSURL *)aURL error:(__autoreleasing NSError **)anError
{
	id					theResult =  nil;
	NSAssert( aURL != nil, @"nil input file url" );
	NDJSON			* theJSONParser = [[NDJSON alloc] initWithDelegate:self];
	if( theJSONParser != nil )
	{
		if( [theJSONParser parseContentsOfURL:aURL error:anError] )
			theResult = generatorContext.root;
	}
	[theJSONParser release];
	return theResult;
}

- (id)propertyListForContentsOfURLRequest:(NSURLRequest *)aURLRequest error:(__autoreleasing NSError **)aError
{
	id					theResult =  nil;
	NSAssert( aURLRequest != nil, @"nil URL request" );
	NDJSON			* theJSONParser = [[NDJSON alloc] initWithDelegate:self];
	if( theJSONParser != nil )
	{
		if( [theJSONParser parseContentsOfURLRequest:aURLRequest error:aError] )
			theResult = generatorContext.root;
	}
	[theJSONParser release];
	return theResult;
}

- (id)propertyListForInputStream:(NSInputStream *)aStream error:(__autoreleasing NSError **)aError
{
	id					theResult =  nil;
	NSAssert( aStream != nil, @"nil input JSON stream" );
	NDJSON			* theJSONParser = [[NDJSON alloc] initWithDelegate:self];
	if( theJSONParser != nil )
	{
		if( [theJSONParser parseInputStream:aStream error:aError] )
			theResult = generatorContext.root;
	}
	[theJSONParser release];
	return theResult;
}

#pragma mark - delegate methods
- (void)jsonParserDidStartDocument:(id)parser
{
	initGeneratorContext( &generatorContext );
}

- (void)jsonParserDidEndDocument:(id)parser
{
	freeGeneratorContext( &generatorContext );
}

- (void)jsonParserDidStartArray:(id)parser
{
	NSMutableArray		* theArrayRep = [[NSMutableArray alloc] init];
	addObject( &generatorContext, theArrayRep );
	pushObject( &generatorContext, theArrayRep );
	[theArrayRep release];
}

- (void)jsonParserDidEndArray:(id)parser
{
	popCurrentObject( &generatorContext );
}

- (void)jsonParserDidStartObject:(id)parser
{
	NSMutableDictionary		* theObjectRep = [[NSMutableDictionary alloc] init];
	addObject( &generatorContext, theObjectRep );
	pushKeyCurrentKey( &generatorContext );
	pushObject( &generatorContext, theObjectRep );
	[theObjectRep release];
}

- (void)jsonParserDidEndObject:(id)parser
{
	popCurrentKey( &generatorContext );
	popCurrentObject( &generatorContext );
}

- (void)jsonParser:(id)parser foundKey:(NSString *)aValue
{
	setCurrentKey( &generatorContext, aValue );
}

- (void)jsonParser:(id)parser foundString:(NSString *)aValue
{
	addObject( &generatorContext, aValue );
}

- (void)jsonParser:(id)parser foundInteger:(NSInteger)aValue
{
	addObject( &generatorContext, [NSNumber numberWithInteger:aValue] );
}

- (void)jsonParser:(id)parser foundFloat:(double)aValue
{
	addObject( &generatorContext, [NSNumber numberWithDouble:aValue] );
}

- (void)jsonParser:(id)parser foundBool:(BOOL)aValue
{
	addObject( &generatorContext, [NSNumber numberWithBool:aValue] );
}

- (void)jsonParserFoundNULL:(id)parser
{
	addObject( &generatorContext, [NSNull null] );
}

@end
