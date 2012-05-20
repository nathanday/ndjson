//
//  NDJSONParser.m
//  NDJSON
//
//  Created by Nathan Day on 31/08/11.
//  Copyright 2011 Nathan Day. All rights reserved.
//

#import "NDJSON.h"
#import "NDJSONParser.h"

#import <objc/objc-class.h>

struct ContainerStackStruct
{
	NSString	* propertyName;
	id			container;
	BOOL		isObject;
};

static const BOOL		kIgnoreUnknownPropertyNameDefaultValue = NO,
						kConvertKeysToMedialCapitalDefaultValue = NO,
						kRemoveIsAdjectiveDefaultValue = NO;

NSString	* const NDJSONBadCollectionClassException = @"NDJSONBadCollectionClassException",
			* const NDJSONUnrecongnisedPropertyNameException = @"NDJSONUnrecongnisedPropertyName",
			* const NDJSONAttributeNameUserInfoKey = @"AttributeName",
			* const NDJSONObjectUserInfoKey = @"Object",
			* const NDJSONPropertyNameUserInfoKey = @"PropertyName";

/**
 functions used by NDJSONParser to build tree
 */

static void popCurrentContainer( NDJSONParser * self );
static void addValue( NDJSONParser * self, id value );

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
	struct
	{
		NSUInteger						size,
		count;
		struct ContainerStackStruct		* bytes;
	}								containerStack;
	NSString						* currentProperty;
	struct
	{
		int								ignoreUnknownPropertyName	: 1;
		int								convertKeysToMedialCapital	: 1;
		int								removeIsAdjective			: 1;
	}								options;
	Class							rootClass,
									rootCollectionClass;
	id								result;
}

@property(readonly,nonatomic)	id			currentObject;

- (Class)classForPropertyName:(NSString *)name class:(Class)class;
- (Class)collectionClassForPropertyName:(NSString *)name class:(Class)class;

- (void)pushContainer:(id)container isObject:(BOOL)isObject;

@end

#pragma mark - NDJSONParser implementation
@implementation NDJSONParser

@synthesize		rootClass,
				rootCollectionClass,
				currentProperty;

#pragma mark - manually implemented properties
- (id)currentContainer { return containerStack.count > 0 ? containerStack.bytes[containerStack.count-1].container : nil; }
- (id)currentObject
{
	id				theResult = nil;
	NSInteger		theIndex = containerStack.count;
	while( theResult == nil && theIndex > 0 )
	{
		theIndex--;
		if( containerStack.bytes[theIndex].isObject )
			theResult = containerStack.bytes[theIndex].container;
	}
	return theResult;
}
- (NSString *)currentContainerPropertyName
{
	NSString			* theResult = self.currentProperty;
	if( theResult == nil && containerStack.count > 0 )
		theResult = containerStack.bytes[containerStack.count-1].propertyName;
	return theResult;
}

#pragma mark - creation and destruction
- (id)init { return [self initWithRootClass:Nil]; }
- (id)initWithRootClass:(Class)aRootClass { return [self initWithRootClass:aRootClass rootCollectionClass:Nil]; }
- (id)initWithRootClass:(Class)aRootClass rootCollectionClass:(Class)aRootCollectionClass
{
	if( (self = [super init]) != nil )
	{
		rootClass = aRootClass;
		rootCollectionClass = aRootCollectionClass;
	}
	return self;
}

- (void)dealloc
{
	for( NSUInteger i = 0; i < containerStack.count; i++ )
	{
		[containerStack.bytes[i].propertyName release];
		[containerStack.bytes[i].container release];
	}
	[currentProperty release];
	[result autorelease];
	free(containerStack.bytes);
	[super dealloc];
}

#pragma mark - parsing methods

- (id)objectForJSONString:(NSString *)aString options:(NDJSONOptionFlags)anOptions error:(__autoreleasing NSError **)aError
{
	id					theResult =  nil;
	NSAssert( aString != nil, @"nil input JSON string" );
	NDJSON			* theJSONParser = [[NDJSON alloc] init];
	if( theJSONParser != nil )
	{
		if( [theJSONParser setJSONString:aString error:aError] )
			theResult = [self objectForJSONParser:theJSONParser options:anOptions];
	}
	[theJSONParser release];
	return theResult;
}

- (id)objectForContentsOfFile:(NSString *)aPath options:(NDJSONOptionFlags)anOptions error:(__autoreleasing NSError **)aError
{
	id					theResult =  nil;
	NSAssert( aPath != nil, @"nil input path" );
	NDJSON			* theJSONParser = [[NDJSON alloc] init];
	if( theJSONParser != nil )
	{
		if( [theJSONParser setContentsOfFile:aPath error:aError] )
			theResult = [self objectForJSONParser:theJSONParser options:anOptions];
	}
	[theJSONParser release];
	return theResult;
}

- (id)objectForContentsOfURL:(NSURL *)aURL options:(NDJSONOptionFlags)anOptions error:(__autoreleasing NSError **)anError
{
	id					theResult =  nil;
	NSAssert( aURL != nil, @"nil input file url" );
	NDJSON			* theJSONParser = [[NDJSON alloc] init];
	if( theJSONParser != nil )
	{
		if( [theJSONParser setContentsOfURL:aURL error:anError] )
			theResult = [self objectForJSONParser:theJSONParser options:anOptions];
	}
	[theJSONParser release];
	return theResult;
}

- (id)objectForURLRequest:(NSURLRequest *)aURLRequest options:(NDJSONOptionFlags)anOptions error:(__autoreleasing NSError **)aError
{
	id					theResult =  nil;
	NSAssert( aURLRequest != nil, @"nil URL request" );
	NDJSON			* theJSONParser = [[NDJSON alloc] init];
	if( theJSONParser != nil )
	{
		if( [theJSONParser setURLRequest:aURLRequest error:aError] )
			theResult = [self objectForJSONParser:theJSONParser options:anOptions];
	}
	[theJSONParser release];
	return theResult;
}

- (id)objectForInputStream:(NSInputStream *)aStream options:(NDJSONOptionFlags)anOptions error:(__autoreleasing NSError **)aError
{
	id					theResult =  nil;
	NSAssert( aStream != nil, @"nil input JSON stream" );
	NDJSON			* theJSONParser = [[NDJSON alloc] init];
	if( theJSONParser != nil )
	{
		if( [theJSONParser setInputStream:aStream error:aError] )
			theResult = [self objectForJSONParser:theJSONParser options:anOptions];
	}
	[theJSONParser release];
	return theResult;
}

- (id)objectForJSONParser:(NDJSON *)aParser options:(NDJSONOptionFlags)anOptions
{
	id		theResult = nil;
	NSAssert( aParser != nil, @"nil JSON parser" );
	aParser.delegate = self;
	options.ignoreUnknownPropertyName = anOptions&NDJSONOptionIgnoreUnknownProperties ? YES : NO;
	options.convertKeysToMedialCapital = anOptions&NDJSONOptionConvertKeysToMedialCapitals ? YES : NO;
	options.removeIsAdjective = anOptions&NDJSONOptionConvertRemoveIsAdjective ? YES : NO;
	if( [aParser parseWithOptions:anOptions] )
		theResult = result;
	return theResult;
}

#pragma mark - delegate methods
- (void)jsonParserDidStartDocument:(NDJSON *)aParser
{
	containerStack.size = 256;
	containerStack.count = 0;
	if( containerStack.bytes != NULL )
		free( containerStack.bytes );
	containerStack.bytes = calloc(containerStack.size,sizeof(struct ContainerStackStruct));
	[currentProperty release], currentProperty = nil;
	[result autorelease], result = nil;
}
- (void)jsonParserDidEndDocument:(NDJSON *)aParser
{
	for( NSUInteger i = 0; i < containerStack.count; i++ )
	{
		[containerStack.bytes[i].propertyName release];
		[containerStack.bytes[i].container release];
	}
	containerStack.count = 0;
	[currentProperty release], currentProperty = nil;
	if( containerStack.bytes != NULL )
		free(containerStack.bytes);
	containerStack.bytes = NULL;
}

- (void)jsonParserDidStartArray:(NDJSON *)aParser
{
	id		theArrayRep = [[[self collectionClassForPropertyName:currentProperty class:[self.currentObject class]] alloc] init];
	addValue( self, theArrayRep );
	[self pushContainer:theArrayRep isObject:NO];
	[currentProperty release], currentProperty = nil;
	[theArrayRep release];
}

- (void)jsonParserDidEndArray:(NDJSON *)aParser { popCurrentContainer( self ); }

- (void)jsonParserDidStartObject:(NDJSON *)aParser
{
	id			theObjectRep = [[[self classForPropertyName:self.currentContainerPropertyName class:[self.currentObject class]] alloc] init];
	addValue( self, theObjectRep );
	[self pushContainer:theObjectRep isObject:YES];
	[currentProperty release], currentProperty = nil;
	[theObjectRep release];
}

- (void)jsonParserDidEndObject:(NDJSON *)aParser { popCurrentContainer( self ); }

- (BOOL)jsonParser:(NDJSON *)parser shouldSkipValueForKey:(NSString *)aKey
{
	BOOL		theResult = NO;
	Class		theClass = [self.currentObject class];
	if( [theClass respondsToSelector:@selector(ignoreSetJSONParser:)] )
		theResult = [[theClass ignoreSetJSONParser:self] containsObject:currentProperty];
	else if( [theClass respondsToSelector:@selector(considerSetJSONParser:)] )
		theResult = ![[theClass considerSetJSONParser:self] containsObject:currentProperty];
	if( theResult )
	{
		NSCParameterAssert(currentProperty != nil);
		[currentProperty release], currentProperty = nil;;
	}
	return theResult;
}

static NSString * stringByConvertingPropertyName( NSString * aString, BOOL aRemoveIs, BOOL aConvertToCamelCase )
{
	NSString	* theResult = aString;
	NSUInteger	theBufferLen = aString.length;
	if( theBufferLen > 0 )
	{
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
			BOOL		theIsFirstChar = YES,
						theCaptializeNext = NO;
			for( NSUInteger i = 0, o = 0, theSourceLen = theBufferLen; i < theSourceLen; i++ )
			{
				if( isalpha(theResultingBytes[i]) || (!theIsFirstChar && isalnum(theResultingBytes[i])) )
				{
					if( islower(theResultingBytes[i]) && theCaptializeNext && !theIsFirstChar )
						theResultingBytes[o] = theResultingBytes[i] - ('a' - 'A');
					else if( isupper(theResultingBytes[i]) && theCaptializeNext && theIsFirstChar )
						theResultingBytes[o] = theResultingBytes[i] + ('a' - 'A');
					else
						theResultingBytes[o] = theResultingBytes[i];
					o++;
					theIsFirstChar = NO;
					theCaptializeNext = NO;
				}
				else
				{
					theCaptializeNext = YES;
					theBufferLen --;
				}
			}
		}
		
		if( aRemoveIs || aConvertToCamelCase )
			theResult = [NSString stringWithCharacters:theResultingBytes length:theBufferLen];
	}
	
	return theResult;
}

- (void)jsonParser:(NDJSON *)aParser foundKey:(NSString *)aValue
{
	NSCParameterAssert(currentProperty == nil);
	NSCParameterAssert( containerStack.count == 0 || containerStack.bytes[containerStack.count-1].isObject );
	NSString	* theKey = stringByConvertingPropertyName( aValue, options.removeIsAdjective != 0, options.convertKeysToMedialCapital != 0 );
	currentProperty = [theKey retain];
}
- (void)jsonParser:(NDJSON *)aParser foundString:(NSString *)aValue
{
	addValue( self, aValue );
	[currentProperty release], currentProperty = nil;
}
- (void)jsonParser:(NDJSON *)aParser foundInteger:(NSInteger)aValue
{
	addValue( self, [NSNumber numberWithInteger:aValue] );
	[currentProperty release], currentProperty = nil;
}
- (void)jsonParser:(NDJSON *)aParser foundFloat:(double)aValue
{
	addValue( self, [NSNumber numberWithDouble:aValue] );
	[currentProperty release], currentProperty = nil;
}
- (void)jsonParser:(NDJSON *)aParser foundBool:(BOOL)aValue
{
	addValue( self, [NSNumber numberWithBool:aValue] );
	[currentProperty release], currentProperty = nil;
}
- (void)jsonParserFoundNULL:(NDJSON *)aParser
{
	addValue( self, [NSNull null] );
	[currentProperty release], currentProperty = nil;
}

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

- (void)pushContainer:(id)aContainer isObject:(BOOL)anIsObject
{
	NSCParameterAssert( aContainer != nil );
	NSCParameterAssert( containerStack.bytes != NULL );
	
	if( containerStack.count >= containerStack.size )
	{
		void		* theBytes = NULL;
		containerStack.size *= 2;
		theBytes = realloc(containerStack.bytes, containerStack.size);
		NSCAssert( theBytes != NULL, @"Memory error" );
		containerStack.bytes = theBytes;
	}
	containerStack.bytes[containerStack.count].container = [aContainer retain];
	containerStack.bytes[containerStack.count].propertyName = currentProperty;
	currentProperty = nil;
	containerStack.bytes[containerStack.count].isObject = anIsObject;
	containerStack.count++;
}

void popCurrentContainer( NDJSONParser * self )
{
	if( self->containerStack.count > 0 )
	{
		self->containerStack.count--;
		[self->currentProperty release], self->currentProperty = nil;
		[self->containerStack.bytes[self->containerStack.count].container release];
	}
}

void addValue( NDJSONParser * self, id aValue )
{
	if( self->result != nil )
	{
		id			theCurrentContainer = self.currentContainer;;
		if( self->currentProperty == nil )
		{
			NSCParameterAssert( [theCurrentContainer respondsToSelector:@selector(addObject:)] );
			[theCurrentContainer addObject:aValue];
		}
		else
		{
			NSString	* thePropertyName = self->currentProperty;
			@try
			{
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
				if( [[anException name] isEqualToString:NSUndefinedKeyException] )
				{
					if( !self->options.ignoreUnknownPropertyName )
					{
						NSString		* theReasonString = [[NSString alloc] initWithFormat:@"Failed to set value for property name '%@'", thePropertyName];
						NSDictionary	* theUserInfo = [[NSDictionary alloc] initWithObjectsAndKeys:self.currentObject, NDJSONObjectUserInfoKey, thePropertyName, NDJSONPropertyNameUserInfoKey, nil];
						NSException		* theException = [NSException exceptionWithName:NDJSONUnrecongnisedPropertyNameException reason:theReasonString userInfo:theUserInfo];
						[theReasonString release];
						[theUserInfo release];
						@throw theException;
					}
				}
				else
					@throw anException;
			}
		}
	}
	else
		self->result = [aValue retain];
}

@end

