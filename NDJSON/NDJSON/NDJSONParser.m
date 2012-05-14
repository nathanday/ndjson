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

struct ContainerStackStruct
{
	NSString	* propertyName;
	id			container;
	BOOL		isObject;
};

struct NDJSONGeneratorContext
{
	struct
	{
		NSUInteger						size,
		count;
		struct ContainerStackStruct		* bytes;
	}								containerStack;
	id								root;
	NSString						* currentProperty;
	BOOL							ignoreUnknownPropertyName,
									convertKeysToMedialCapital,
									removeIsAdjective;
};

static const BOOL		kIgnoreUnknownPropertyNameDefaultValue = NO,
						kConvertKeysToMedialCapitalDefaultValue = NO,
						kRemoveIsAdjectiveDefaultValue = NO;

NSString	* const NDJSONBadCollectionClassException = @"NDJSONBadCollectionClassException",
			* const NDJSONAttributeNameUserInfoKey = @"AttributeName";

/**
 functions used by NDJSONParser to build tree
 */

id getCurrentContainer( struct NDJSONGeneratorContext * context );
id getCurrentObject( struct NDJSONGeneratorContext * context );
void pushContainer( struct NDJSONGeneratorContext * context, id container, BOOL isObject );
void popCurrentContainer( struct NDJSONGeneratorContext * context );
void addValue( struct NDJSONGeneratorContext * context, id value );

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
	Class							rootClass,
									rootCollectionClass;
	BOOL							ignoreUnknownPropertyName,
									convertKeysToMedialCapital,
									removeIsAdjective;
}

- (Class)classForPropertyName:(NSString *)name class:(Class)class;
- (Class)collectionClassForPropertyName:(NSString *)name class:(Class)class;

@end

#pragma mark - NDJSONParser implementation
@implementation NDJSONParser

@synthesize		rootClass,
				rootCollectionClass,
				ignoreUnknownPropertyName,
				convertKeysToMedialCapital,
				removeIsAdjective;

#pragma mark - manually implemented properties
- (id)currentContainer { return getCurrentContainer(&generatorContext); }
- (id)currentObject { return getCurrentObject(&generatorContext); }
- (NSString *)currentContainerPropertyName
{
	NSString			* theResult = self.currentProperty;
	if( theResult == nil && generatorContext.containerStack.count > 0 )
		theResult = generatorContext.containerStack.bytes[generatorContext.containerStack.count-1].propertyName;
	return theResult;
}
- (NSString *)currentProperty { return generatorContext.currentProperty; }

#pragma mark - creation and destruction
- (id)init { return [self initWithRootClass:Nil]; }
- (id)initWithRootClass:(Class)aRootClass { return [self initWithRootClass:aRootClass rootCollectionClass:Nil]; }
- (id)initWithRootClass:(Class)aRootClass rootCollectionClass:(Class)aRootCollectionClass
{
	if( (self = [super init]) != nil )
	{
		rootClass = aRootClass;
		rootCollectionClass = aRootCollectionClass;
		ignoreUnknownPropertyName = kIgnoreUnknownPropertyNameDefaultValue;
		convertKeysToMedialCapital = kConvertKeysToMedialCapitalDefaultValue;
		removeIsAdjective = kRemoveIsAdjectiveDefaultValue;
	}
	return self;
}

- (void)dealloc
{
	for( NSUInteger i = 0; i < generatorContext.containerStack.count; i++ )
	{
		[generatorContext.containerStack.bytes[i].propertyName release];
		[generatorContext.containerStack.bytes[i].container release];
	}
	[generatorContext.currentProperty release];
	[generatorContext.root autorelease];
	free(generatorContext.containerStack.bytes);
	[super dealloc];
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
- (void)jsonParserDidStartDocument:(NDJSON *)aParser
{
	generatorContext.containerStack.size = 256;
	generatorContext.containerStack.count = 0;
	if( generatorContext.containerStack.bytes != NULL )
		free( generatorContext.containerStack.bytes );
	generatorContext.containerStack.bytes = calloc(generatorContext.containerStack.size,sizeof(struct ContainerStackStruct));
	[generatorContext.currentProperty release], generatorContext.currentProperty = nil;
	[generatorContext.root autorelease], generatorContext.root = nil;
	generatorContext.ignoreUnknownPropertyName = self.ignoreUnknownPropertyName;
	generatorContext.convertKeysToMedialCapital = self.convertKeysToMedialCapital;
	generatorContext.removeIsAdjective = self.removeIsAdjective;
}
- (void)jsonParserDidEndDocument:(NDJSON *)aParser
{
	for( NSUInteger i = 0; i < generatorContext.containerStack.count; i++ )
	{
		[generatorContext.containerStack.bytes[i].propertyName release];
		[generatorContext.containerStack.bytes[i].container release];
	}
	generatorContext.containerStack.count = 0;
	[generatorContext.currentProperty release], generatorContext.currentProperty = nil;
	if( generatorContext.containerStack.bytes != NULL )
		free(generatorContext.containerStack.bytes);
	generatorContext.containerStack.bytes = NULL;
}

- (void)jsonParserDidStartArray:(NDJSON *)aParser
{
	id		theArrayRep = [[[self collectionClassForPropertyName:generatorContext.currentProperty class:[getCurrentObject(&generatorContext) class]] alloc] init];
	addValue( &generatorContext, theArrayRep );
	pushContainer( &generatorContext, theArrayRep, NO );
	[generatorContext.currentProperty release], generatorContext.currentProperty = nil;
	[theArrayRep release];
}

- (void)jsonParserDidEndArray:(NDJSON *)aParser { popCurrentContainer( &generatorContext ); }

- (void)jsonParserDidStartObject:(NDJSON *)aParser
{
	id			theObjectRep = [[[self classForPropertyName:self.currentContainerPropertyName class:[getCurrentObject(&generatorContext) class]] alloc] init];
	addValue( &generatorContext, theObjectRep );
	pushContainer( &generatorContext, theObjectRep, YES );
	[generatorContext.currentProperty release], generatorContext.currentProperty = nil;
	[theObjectRep release];
}

- (void)jsonParserDidEndObject:(NDJSON *)aParser { popCurrentContainer( &generatorContext ); }

- (BOOL)jsonParserShouldSkipValueForCurrentKey:(NDJSON *)aParser
{
	BOOL		theResult = NO;
	Class		theClass = [getCurrentObject(&generatorContext) class];
	if( [theClass respondsToSelector:@selector(ignoreSetJSONParser:)] )
		theResult = [[theClass ignoreSetJSONParser:self] containsObject:generatorContext.currentProperty];
	else if( [theClass respondsToSelector:@selector(considerSetJSONParser:)] )
		theResult = ![[theClass considerSetJSONParser:self] containsObject:generatorContext.currentProperty];
	if( theResult )
	{
		NSCParameterAssert(generatorContext.currentProperty != nil);
		[generatorContext.currentProperty release], generatorContext.currentProperty = nil;;
	}
	return theResult;
}

static NSString * stringByConvertingPropertyName( NSString * aString, BOOL aRemoveIs, BOOL aConvertToCamelCase )
{
	NSString	* theResult = aString;
	NSUInteger	theBufferLen = aString.length;
	unichar		theBuffer[theBufferLen];
	unichar		* theResultingBytes = theBuffer;
	[aString getCharacters:theBuffer range:NSMakeRange(0, theBufferLen)];
	if( aRemoveIs && theResultingBytes[0] == 'i' && theResultingBytes[1] == 's' && isupper(theResultingBytes[2]) )
	{
		theResultingBytes[2] += 'a' - 'A';
		theBufferLen -= 2;
		theResultingBytes += 2;
	}
	
	if( aConvertToCamelCase )
	{
		for( NSUInteger i = 0, o = 0, theSourceLen = theBufferLen; i < theSourceLen; i++, o++ )
		{
			if( i == 0 )
			{
				if(  isupper(theResultingBytes[i]) )
					theResultingBytes[o] = theResultingBytes[i] + ('a' - 'A');
				else
					theResultingBytes[o] = theResultingBytes[i];
			}
			else if( theResultingBytes[i] == '_' )
			{
				i++;
				theBufferLen--;
				if( islower(theResultingBytes[i]) )
					theResultingBytes[o] = theResultingBytes[i] - ('a' - 'A');
				else
					theResultingBytes[o] = theResultingBytes[i];
			}
			else
				theResultingBytes[o] = theResultingBytes[i];
		}
	}
	
	if( aRemoveIs || aConvertToCamelCase )
		theResult = [NSString stringWithCharacters:theResultingBytes length:theBufferLen];
	
	return theResult;
}

- (void)jsonParser:(NDJSON *)aParser foundKey:(NSString *)aValue
{
	NSCParameterAssert(generatorContext.currentProperty == nil);
	NSCParameterAssert( generatorContext.containerStack.count == 0 || generatorContext.containerStack.bytes[generatorContext.containerStack.count-1].isObject );
	NSString	* theKey = stringByConvertingPropertyName( aValue, self.removeIsAdjective, self.convertKeysToMedialCapital );
	generatorContext.currentProperty = [theKey retain];
}
- (void)jsonParser:(NDJSON *)aParser foundString:(NSString *)aValue { addValue( &generatorContext, aValue ); [generatorContext.currentProperty release], generatorContext.currentProperty = nil; }
- (void)jsonParser:(NDJSON *)aParser foundInteger:(NSInteger)aValue { addValue( &generatorContext, [NSNumber numberWithInteger:aValue] ); [generatorContext.currentProperty release], generatorContext.currentProperty = nil; }
- (void)jsonParser:(NDJSON *)aParser foundFloat:(double)aValue { addValue( &generatorContext, [NSNumber numberWithDouble:aValue] ); [generatorContext.currentProperty release], generatorContext.currentProperty = nil; }
- (void)jsonParser:(NDJSON *)aParser foundBool:(BOOL)aValue { addValue( &generatorContext, [NSNumber numberWithBool:aValue] ); [generatorContext.currentProperty release], generatorContext.currentProperty = nil; }
- (void)jsonParserFoundNULL:(NDJSON *)aParser { addValue( &generatorContext, [NSNull null] ); [generatorContext.currentProperty release], generatorContext.currentProperty = nil; }

#pragma mark - private

- (Class)classForPropertyName:(NSString *)aName class:(Class)aClass
{
	Class		theClass = Nil,
				theRootClass = self.rootClass;
	if( theRootClass != nil )
	{
		if( aClass == Nil )
			theClass = theRootClass;
		else
		{
			if( [aClass respondsToSelector:@selector(classesForPropertyNamesJSONParser:)] )
				theClass = [[aClass classesForPropertyNamesJSONParser:self] objectForKey:aName];
			if( theClass == Nil )
			{
				objc_property_t		theProperty = class_getProperty(aClass, [aName UTF8String]);
				if( theProperty != NULL )
				{
					char			theClassName[256];
					const char		* thePropertyAttributes = property_getAttributes(theProperty);
					
					if( getClassNameFromPropertyAttributes( theClassName, sizeof(theClassName)/sizeof(*theClassName), thePropertyAttributes ) )
						theClass = objc_getClass( theClassName );
					else
						theClass = [NSMutableDictionary class];
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

- (Class)collectionClassForPropertyName:(NSString *)aName class:(Class)aClass
{
	Class		theClass = Nil;
	if( self.rootClass != nil )
	{
		if( aClass == Nil )
		{
			Class		theRootCollectionClass = self.rootCollectionClass;
			if( theRootCollectionClass != nil )
				theClass = theRootCollectionClass;
			else
				theClass = [NSMutableArray class];
		}
		else
		{
			if( [aClass respondsToSelector:@selector(collectionClassesForPropertyNamesJSONParser:)] )
				theClass = [[aClass collectionClassesForPropertyNamesJSONParser:self] objectForKey:aName];
			if( theClass == Nil )
			{
				objc_property_t		theProperty = class_getProperty(aClass, [aName UTF8String]);
				if( theProperty != NULL )
				{
					char			theClassName[256];
					const char		* thePropertyAttributes = property_getAttributes(theProperty);
					
					if( getClassNameFromPropertyAttributes( theClassName, sizeof(theClassName)/sizeof(*theClassName), thePropertyAttributes ) )
						theClass = objc_getClass( theClassName );
				}
				else
					theClass = [NSMutableArray class];
			}
		}
		
		if( theClass == [NSArray class] )
			theClass = [NSMutableArray class];
		else if( theClass == [NSSet class] )
			theClass = [NSMutableSet class];
		else if( theClass == [NSOrderedSet class] )
			theClass = [NSMutableOrderedSet class];
		else if( theClass == [NSIndexSet class])
			theClass = [NSMutableIndexSet class];
		else if( theClass == [NSDictionary class] )
			theClass = [NSMutableDictionary class];
	}
	else
		theClass = [NSMutableArray class];

	if( ![theClass instancesRespondToSelector:@selector(addObject:)] )
	{
		NSString		* theReason = [[NSString alloc] initWithFormat:@"The collection class '%@' for the key '%@' does not respond to the selector 'addObject:'", NSStringFromClass(theClass), aName];
		NSDictionary	* theUserInfo = [[NSDictionary alloc] initWithObjectsAndKeys:aName, NDJSONAttributeNameUserInfoKey, nil];
		NSException		* theException = [NSException exceptionWithName:NDJSONBadCollectionClassException reason:theReason userInfo:theUserInfo];
		[theReason release];
		[theUserInfo release];
		@throw theException;
	}
	return theClass;
}

@end


#pragma mark - functions used by NDJSONParser

id getCurrentContainer( struct NDJSONGeneratorContext * aContext )
{
	return aContext->containerStack.count > 0 ? aContext->containerStack.bytes[aContext->containerStack.count-1].container : nil;
}

id getCurrentObject( struct NDJSONGeneratorContext * aContext )
{
	id				theResult = nil;
	NSInteger		theIndex = aContext->containerStack.count;
	while( theResult == nil && theIndex > 0 )
	{
		theIndex--;
		if( aContext->containerStack.bytes[theIndex].isObject )
			theResult = aContext->containerStack.bytes[theIndex].container;
	}
	return theResult;
}

void pushContainer( struct NDJSONGeneratorContext * aContext, id aContainer, BOOL anIsObject )
{
	NSCParameterAssert( aContainer != nil );
	NSCParameterAssert( aContext->containerStack.bytes != NULL );
	
	if( aContext->containerStack.count >= aContext->containerStack.size )
	{
		void		* theBytes = NULL;
		aContext->containerStack.size *= 2;
		theBytes = realloc(aContext->containerStack.bytes, aContext->containerStack.size);
		NSCAssert( theBytes != NULL, @"Memory error" );
		aContext->containerStack.bytes = theBytes;
	}
	aContext->containerStack.bytes[aContext->containerStack.count].container = [aContainer retain];
	aContext->containerStack.bytes[aContext->containerStack.count].propertyName = aContext->currentProperty;
	aContext->currentProperty = nil;
	aContext->containerStack.bytes[aContext->containerStack.count].isObject = anIsObject;
	aContext->containerStack.count++;
}

void popCurrentContainer( struct NDJSONGeneratorContext * aContext )
{
	if( aContext->containerStack.count > 0 )
	{
		aContext->containerStack.count--;
		[aContext->currentProperty release];
//		aContext->currentProperty = aContext->containerStack.bytes[aContext->containerStack.count].propertyName;
		[aContext->containerStack.bytes[aContext->containerStack.count].container release];
	}
}

void addValue( struct NDJSONGeneratorContext * aContext, id aValue )
{
	if( aContext->root != nil )
	{
		id			theCurrentContainer = getCurrentContainer(aContext);
		if( aContext->currentProperty == nil )
		{
			NSCParameterAssert( [theCurrentContainer respondsToSelector:@selector(addObject:)] );
			[theCurrentContainer addObject:aValue];
		}
		else
		{
			@try
			{
				NSString	* thePropertyName = aContext->currentProperty;
				if( [[theCurrentContainer class] respondsToSelector:@selector(propertyNamesForKeysJSONParser:)] )
				{
					NSString	* theNewPropertyName = [[[theCurrentContainer class] propertyNamesForKeysJSONParser:nil] objectForKey:thePropertyName];
					if( theNewPropertyName != nil )
						thePropertyName = theNewPropertyName;
				}
				NSCParameterAssert( [theCurrentContainer respondsToSelector:@selector(setValue:forKey:)] );
				[theCurrentContainer setValue:aValue forKey:thePropertyName];
			}
			@catch( NSException * anException )
			{
				if( !aContext->ignoreUnknownPropertyName || ![[anException name] isEqualToString:NSUndefinedKeyException] )
					@throw anException;
			}
		}
	}
	else
		aContext->root = [aValue retain];
}


