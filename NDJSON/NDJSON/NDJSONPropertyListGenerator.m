//
//  NDJSON.m
//  NDJSON
//
//  Created by Nathan Day on 31/08/11.
//  Copyright 2011 Nathan Day. All rights reserved.
//

#import "NDJSON.h"

struct NDJSONGeneratorContext
{
	NSMutableArray		* previoustKeys;
	NSMutableArray		* previoustObject;
	id					currentObject;
	id					currentKey;
	id					root;
};

#pragma mark - cluster class subclass NDJSONPropertyListGenerator interface
@interface NDJSONPropertyListGenerator : NSObject <NDJSONDelegate>
{
	struct NDJSONGeneratorContext	generatorContext;
}

@end

#pragma mark - functions used by NDJSONPropertyListGenerator to build tree
static void initGeneratorContext( struct NDJSONGeneratorContext * aContext );
static void freeGeneratorContext( struct NDJSONGeneratorContext * aContext );
static void pushObject( struct NDJSONGeneratorContext * aContext, id anObject );
static void popCurrentObject( struct NDJSONGeneratorContext * aContext );
static void setCurrentKey( struct NDJSONGeneratorContext * aContext, NSString * aKey );
static void pushKeyCurrentKey( struct NDJSONGeneratorContext * aContext );
static void popCurrentKey( struct NDJSONGeneratorContext * aContext );
static void addObject( struct NDJSONGeneratorContext * aContext, id anObject );

#pragma mark - cluster class subclass NDJSONPropertyListGenerator implementation
@implementation NDJSONPropertyListGenerator

#pragma mark - parsing methods

- (id)propertyListForJSONString:(NSString *)aString error:(NSError **)aError
{
	id					theResult =  nil;
	NSAssert( aString != nil, @"nil input JSON string" );
	NDJSON			* theJSONParser = [[NDJSON alloc] initWithDelegate:self];
	if( theJSONParser != nil )
	{
		if( [theJSONParser parseJSONString:aString error:aError] )
			theResult = generatorContext.root;
	}
	return theResult;
}

- (id)propertyListForContentsOfFile:(NSString *)aPath error:(NSError **)aError
{
	id					theResult =  nil;
	NSAssert( aPath != nil, @"nil input path" );
	NDJSON			* theJSONParser = [[NDJSON alloc] initWithDelegate:self];
	if( theJSONParser != nil )
	{
		if( [theJSONParser parseContentsOfFile:aPath error:aError] )
			theResult = generatorContext.root;
	}
	return theResult;
}

- (id)propertyListForContentsOfURL:(NSURL *)aURL error:(NSError **)anError
{
	id					theResult =  nil;
	NSAssert( aURL != nil, @"nil input file url" );
	NDJSON			* theJSONParser = [[NDJSON alloc] initWithDelegate:self];
	if( theJSONParser != nil )
	{
		if( [theJSONParser parseContentsOfURL:aURL error:anError] )
			theResult = generatorContext.root;
	}
	return theResult;
}

- (id)propertyListForContentsOfURLRequest:(NSURLRequest *)aURLRequest error:(NSError **)aError
{
	id					theResult =  nil;
	NSAssert( aURLRequest != nil, @"nil URL request" );
	NDJSON			* theJSONParser = [[NDJSON alloc] initWithDelegate:self];
	if( theJSONParser != nil )
	{
		if( [theJSONParser parseContentsOfURLRequest:aURLRequest error:aError] )
			theResult = generatorContext.root;
	}
	return theResult;
}

- (id)propertyListForInputStream:(NSInputStream *)aStream error:(NSError **)aError
{
	id					theResult =  nil;
	NSAssert( aStream != nil, @"nil input JSON stream" );
	NDJSON			* theJSONParser = [[NDJSON alloc] initWithDelegate:self];
	if( theJSONParser != nil )
	{
		if( [theJSONParser parseInputStream:aStream error:aError] )
			theResult = generatorContext.root;
	}
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

#pragma mark - functions used by NDJSONPropertyListGenerator
void initGeneratorContext( struct NDJSONGeneratorContext * aContext )
{
	aContext->previoustKeys = [[NSMutableArray alloc] init];
	aContext->previoustObject = [[NSMutableArray alloc] init];
	aContext->currentObject = nil;
	aContext->currentKey = nil;
	aContext->root = nil;
}

void freeGeneratorContext( struct NDJSONGeneratorContext * aContext )
{
	[aContext->previoustKeys release];
	[aContext->previoustObject release];
}

void pushObject( struct NDJSONGeneratorContext * aContext, id anObject )
{
	NSCParameterAssert( anObject != nil );
	NSCParameterAssert( aContext->previoustObject != nil );
	if( aContext->currentObject != nil )
	{
		[aContext->previoustObject addObject:aContext->currentObject];
//		[aContext->currentObject release];
	}
	aContext->currentObject = [anObject retain];
}

void popCurrentObject( struct NDJSONGeneratorContext * aContext )
{
	[aContext->currentObject release];
	aContext->currentObject = nil;
	NSCParameterAssert( aContext->previoustObject != nil );
	if( [aContext->previoustObject count] > 0 )
	{
		aContext->currentObject = [aContext->previoustObject lastObject];
		[aContext->previoustObject removeLastObject];
	}
}

void setCurrentKey( struct NDJSONGeneratorContext * aContext, NSString * aKey )
{
	NSCParameterAssert(aContext->currentKey == nil);
	aContext->currentKey = [aKey retain];
}

void pushKeyCurrentKey( struct NDJSONGeneratorContext * aContext )
{
	if( aContext->currentKey != nil )
	{
		NSCParameterAssert(aContext->previoustKeys != nil );
		[aContext->previoustKeys addObject:aContext->currentKey];
		[aContext->currentKey release], aContext->currentKey = nil;
	}
}

void popCurrentKey( struct NDJSONGeneratorContext * aContext )
{
	NSCParameterAssert( aContext->currentKey == nil);
	aContext->currentKey = [aContext->previoustKeys lastObject];
	if( aContext->currentKey == [NSNull null] )
		aContext->currentKey = nil;
	[aContext->currentKey retain];
	[aContext->previoustKeys removeLastObject];
}

void addObject( struct NDJSONGeneratorContext * aContext, id anObject )
{
	if( aContext->currentObject != nil )
	{
		if( aContext->currentKey == nil )
		{
			NSCParameterAssert( [aContext->currentObject respondsToSelector:@selector(addObject:)] );
			[aContext->currentObject addObject:anObject];
		}
		else
		{
			NSCParameterAssert( [aContext->currentObject respondsToSelector:@selector(setValue:forKey:)] );
			[aContext->currentObject setValue:anObject forKey:aContext->currentKey];
			[aContext->currentKey release], aContext->currentKey = nil;
		}
	}
	else
	{
		NSCParameterAssert( aContext->root == nil );
		aContext->root = [anObject retain];
	}
}
