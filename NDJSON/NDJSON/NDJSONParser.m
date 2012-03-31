//
//  NDJSONParser.m
//  NDJSON
//
//  Created by Nathan Day on 31/08/11.
//  Copyright 2011 Nathan Day. All rights reserved.
//

#import "NDJSON.h"
#import "NDJSONParser.h"
#import "NDJSONCore.h"

#import <objc/objc-class.h>

static BOOL getClassNameFromPropertyAttributes( char * aClassName, size_t aLen, const char * aPropertyAttributes )
{
	BOOL	theResult = NO;
	if( strstr( aPropertyAttributes, "T@\"" ) == aPropertyAttributes )
	{
		NSUInteger		i = 0;
		aPropertyAttributes += 3;
		for( ; aPropertyAttributes[i] != '"' && aPropertyAttributes[i] != '\0' && i < aLen-1; i++ )
			aClassName[i] = aPropertyAttributes[i];
		aClassName[i] = '\0';
		theResult = i > 0;
	}
	return theResult;
}

@interface NDJSONParser () <NDJSONDelegate>
{
	struct NDJSONGeneratorContext	generatorContext;
	Class							rootClass;
}

@end

#pragma mark - NDJSONParser implementation
@implementation NDJSONParser

@synthesize			rootClass;

- (id)init { return [self initWithRootClass:Nil]; }

- (id)initWithRootClass:(Class)aRootClass
{
	if( (self = [super init]) != nil )
		rootClass = aRootClass;
	return self;
}

#pragma mark - parsing methods

- (id)propertyListForJSONString:(NSString *)aString error:(__autoreleasing NSError **)aError
{
	id					theResult =  nil;
	NSAssert( aString != nil, @"nil input JSON string" );
	NDJSON			* theJSONParser = [[NDJSON alloc] init];
	if( theJSONParser != nil )
	{
		if( [theJSONParser setJSONString:aString error:aError] )
			theResult = [self propertyListForJSONParser:theJSONParser];
	}
	[theJSONParser release];
	return theResult;
}

- (id)propertyListForContentsOfFile:(NSString *)aPath error:(__autoreleasing NSError **)aError
{
	id					theResult =  nil;
	NSAssert( aPath != nil, @"nil input path" );
	NDJSON			* theJSONParser = [[NDJSON alloc] init];
	if( theJSONParser != nil )
	{
		if( [theJSONParser setContentsOfFile:aPath error:aError] )
			theResult = [self propertyListForJSONParser:theJSONParser];
	}
	[theJSONParser release];
	return theResult;
}

- (id)propertyListForContentsOfURL:(NSURL *)aURL error:(__autoreleasing NSError **)anError
{
	id					theResult =  nil;
	NSAssert( aURL != nil, @"nil input file url" );
	NDJSON			* theJSONParser = [[NDJSON alloc] init];
	if( theJSONParser != nil )
	{
		if( [theJSONParser setContentsOfURL:aURL error:anError] )
			theResult = [self propertyListForJSONParser:theJSONParser];
	}
	[theJSONParser release];
	return theResult;
}

- (id)propertyListForContentsOfURLRequest:(NSURLRequest *)aURLRequest error:(__autoreleasing NSError **)aError
{
	id					theResult =  nil;
	NSAssert( aURLRequest != nil, @"nil URL request" );
	NDJSON			* theJSONParser = [[NDJSON alloc] init];
	if( theJSONParser != nil )
	{
		if( [theJSONParser setContentsOfURLRequest:aURLRequest error:aError] )
			theResult = [self propertyListForJSONParser:theJSONParser];
	}
	[theJSONParser release];
	return theResult;
}

- (id)propertyListForInputStream:(NSInputStream *)aStream error:(__autoreleasing NSError **)aError
{
	id					theResult =  nil;
	NSAssert( aStream != nil, @"nil input JSON stream" );
	NDJSON			* theJSONParser = [[NDJSON alloc] init];
	if( theJSONParser != nil )
	{
		if( [theJSONParser setInputStream:aStream error:aError] )
			theResult = [self propertyListForJSONParser:theJSONParser];
	}
	[theJSONParser release];
	return theResult;
}

- (id)propertyListForJSONParser:(NDJSON *)aParser
{
	id		theResult = nil;
	NSAssert( aParser != nil, @"nil JSON parser" );
	aParser.delegate = self;
	if( [aParser parse] )
		theResult = generatorContext.root;
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
	id			theObjectRep = [[[self classForPropertyName:generatorContext.currentKey parent:generatorContext.currentObject] alloc] init];
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

- (Class)classForPropertyName:(NSString *)aName parent:(id)aParent
{
	Class		theClass = Nil,
				theRootClass = self.rootClass;
	if( theRootClass != nil )
	{
		if( aParent == nil )
			theClass = theRootClass;
		else
		{
			if( [aParent respondsToSelector:@selector(jsonParser:classForPropertyName:)] )
				theClass = [aParent jsonParser:self classForPropertyName:aName];
			if( theClass == Nil )
			{
				objc_property_t		theProperty = class_getProperty([aParent class], [aName UTF8String]);
				if( theProperty != NULL )
				{
					char			theClassName[256];
					const char		* thePropertyAttributes = property_getAttributes(theProperty);
					
					if( getClassNameFromPropertyAttributes( theClassName, sizeof(theClassName)/sizeof(*theClassName), thePropertyAttributes ) )
						theClass = objc_getClass( theClassName );
				}
				else
					theClass = [NSMutableDictionary class];
			}
		}
	}
	else
		theClass = [NSMutableDictionary class];
	return theClass;
}

@end
