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

#pragma mark - cluster class subclass NDJSONFoundationObjectsGenerator interface
@interface NDJSONFoundationObjectsGenerator : NDJSON <NDJSONDelegate>
{
	struct NDJSONGeneratorContext	generatorContext;
}

@end

#pragma mark - cluster class subclass NDJSONTemplate interface
@interface NDJSONTemplate : NDJSON
{
	NSDictionary					* templateDictionary;
}

@end

#pragma mark - cluster class NDJSON private interface
@interface NDJSON ()
{
	id<NDJSONDelegate>				delegate;
	struct NDJSONContext			parserContext;
}

@property(readonly)	struct NDJSONContext	* parserContext;

@end

#pragma mark - cluster class NDJSON private implementation
@implementation NDJSON

@synthesize		delegate;

#pragma mark - manually implemented properties

- (struct NDJSONContext	*)parserContext { return &parserContext; }
- (NSDictionary *)templateDictionary { return nil; }
- (NDJSONContainer)currentContainer { return currentContainer(&parserContext); }
- (NSString *)currentKey { return nil; }

#pragma mark - creation and destruction etc

- (id)init
{
	[self release];
	return [[NDJSONFoundationObjectsGenerator alloc] init];
}

- (id)initWithDelegate:(id<NDJSONDelegate>)aDelegate
{
    if( (self = [super init]) != nil )
		delegate = aDelegate;
    
    return self;
}

- (id)initWithPropertyList:(NSDictionary *)aTemplateDict
{
	[self release];
	return [[NDJSONFoundationObjectsGenerator alloc] initWithPropertyList:aTemplateDict];
}

#pragma mark - parsing methods

- (id)asynchronousParseJSONString:(NSString *)aString error:(NSError **)aError
{
	NSAssert( NO, @"This method needs to be over ridden" );
	return nil;
}

- (id)asynchronousParseContentsOfFile:(NSString *)aPath error:(NSError **)aError
{
	id					theResult =  nil;
	NSAssert( aPath != nil, @"NUll input JSON path" );
	NSInputStream		* theInputStream = [NSInputStream inputStreamWithFileAtPath:aPath];
	if( theInputStream != nil )
		theResult = [self asynchronousParseInputStream:theInputStream error:aError];
	return theResult;
}

- (id)asynchronousParseContentsOfURL:(NSURL *)aURL error:(NSError **)aError
{
	id					theResult =  nil;
	NSAssert( aURL != nil, @"NUll input JSON file url" );
	NSInputStream		* theInputStream = [NSInputStream inputStreamWithURL:aURL];
	if( theInputStream != nil )
		theResult = [self asynchronousParseInputStream:theInputStream error:aError];
	return theResult;
}

- (id)asynchronousParseInputStream:(NSInputStream *)stream error:(NSError **)error;
{
	NSAssert( NO, @"This method needs to be over ridden" );
	return nil;
}

@end

#pragma mark - functions used by NDJSONFoundationObjectsGenerator to build tree
static void initGeneratorContext( struct NDJSONGeneratorContext * aContext );
static void freeGeneratorContext( struct NDJSONGeneratorContext * aContext );
static void pushObject( struct NDJSONGeneratorContext * aContext, id anObject );
static void popCurrentObject( struct NDJSONGeneratorContext * aContext );
static void setCurrentKey( struct NDJSONGeneratorContext * aContext, NSString * aKey );
static void pushKeyCurrentKey( struct NDJSONGeneratorContext * aContext );
static void popCurrentKey( struct NDJSONGeneratorContext * aContext );
static void addObject( struct NDJSONGeneratorContext * aContext, id anObject );

#pragma mark - cluster class subclass NDJSONFoundationObjectsGenerator implementation
@implementation NDJSONFoundationObjectsGenerator

- (id)init { return [self initWithDelegate:self]; }

#pragma mark - parsing methods

- (id)asynchronousParseJSONString:(NSString *)aString error:(NSError **)aError
{
	id					theResult =  nil;
	NSAssert( aString != nil, @"NUll input JSON string" );
	if( contextWithNullTermiantedString( self.parserContext, self, [aString UTF8String], self ) )
	{
		beginParsing( self.parserContext );
		freeContext( self.parserContext );
		theResult = generatorContext.root;
	}
	return theResult;
}


- (id)asynchronousParseInputStream:(NSInputStream *)aStream error:(NSError **)aError
{
	id					theResult =  nil;
	NSAssert( aStream != nil, @"NUll input stream" );
	if( contextWithInputStream( self.parserContext, self, aStream, self ) )
	{
		beginParsing( self.parserContext );
		freeContext( self.parserContext );
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

#pragma mark - cluster class subclass NDJSONTemplate implementation
@implementation NDJSONTemplate

@synthesize		templateDictionary;

- (id)initWithPropertyList:(NSDictionary *)aTemplateDict
{
    if( (self = [super init]) != nil )
		templateDictionary = [aTemplateDict copy];
    
    return self;
}

@end

#pragma mark - functions used by NDJSONFoundationObjectsGenerator
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
