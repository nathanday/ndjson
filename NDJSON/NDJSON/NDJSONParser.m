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

static const BOOL		kIgnoreUnknownPropertyNameDefaultValue = NO,
						kConvertKeysToMedialCapitalDefaultValue = NO,
						kRemoveIsAdjectiveDefaultValue = NO;

NSString	* const NDJSONBadCollectionClassException = @"NDJSONBadCollectionClassException",
			* const NDJSONAttributeNameUserInfoKey = @"AttributeName";

/**
 functions used by NDJSONParser to build tree
 */

void popCurrentContainer( NDJSONParser * self );
void addValue( NDJSONParser * self, id value );

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
	BOOL							ignoreUnknownPropertyName,
									convertKeysToMedialCapital,
									removeIsAdjective;
	Class							rootClass,
									rootCollectionClass;
	id								result;
}

- (Class)classForPropertyName:(NSString *)name class:(Class)class;
- (Class)collectionClassForPropertyName:(NSString *)name class:(Class)class;

- (void)pushContainer:(id)container isObject:(BOOL)isObject;
- (void)popCurrentContainer;
- (void)addValue:(id)value;

@end

#pragma mark - NDJSONParser implementation
@implementation NDJSONParser

@synthesize		rootClass,
				rootCollectionClass,
				ignoreUnknownPropertyName,
				convertKeysToMedialCapital,
				removeIsAdjective,
				currentProperty,
				result;

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
		ignoreUnknownPropertyName = kIgnoreUnknownPropertyNameDefaultValue;
		convertKeysToMedialCapital = kConvertKeysToMedialCapitalDefaultValue;
		removeIsAdjective = kRemoveIsAdjectiveDefaultValue;
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
		theResult = self.result;
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
	ignoreUnknownPropertyName = self.ignoreUnknownPropertyName;
	convertKeysToMedialCapital = self.convertKeysToMedialCapital;
	removeIsAdjective = self.removeIsAdjective;
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
	[self addValue:theArrayRep];
	[self pushContainer:theArrayRep isObject:NO];
	[currentProperty release], currentProperty = nil;
	[theArrayRep release];
}

- (void)jsonParserDidEndArray:(NDJSON *)aParser { [self popCurrentContainer]; }

- (void)jsonParserDidStartObject:(NDJSON *)aParser
{
	id			theObjectRep = [[[self classForPropertyName:self.currentContainerPropertyName class:[self.currentObject class]] alloc] init];
	[self addValue:theObjectRep];
	[self pushContainer:theObjectRep isObject:YES];
	[currentProperty release], currentProperty = nil;
	[theObjectRep release];
}

- (void)jsonParserDidEndObject:(NDJSON *)aParser { [self popCurrentContainer]; }

- (BOOL)jsonParserShouldSkipValueForCurrentKey:(NDJSON *)aParser
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
	NSCParameterAssert(currentProperty == nil);
	NSCParameterAssert( containerStack.count == 0 || containerStack.bytes[containerStack.count-1].isObject );
	NSString	* theKey = stringByConvertingPropertyName( aValue, self.removeIsAdjective, self.convertKeysToMedialCapital );
	currentProperty = [theKey retain];
}
- (void)jsonParser:(NDJSON *)aParser foundString:(NSString *)aValue { [self addValue:aValue]; [currentProperty release], currentProperty = nil; }
- (void)jsonParser:(NDJSON *)aParser foundInteger:(NSInteger)aValue { [self addValue:[NSNumber numberWithInteger:aValue]]; [currentProperty release], currentProperty = nil; }
- (void)jsonParser:(NDJSON *)aParser foundFloat:(double)aValue { [self addValue:[NSNumber numberWithDouble:aValue]]; [currentProperty release], currentProperty = nil; }
- (void)jsonParser:(NDJSON *)aParser foundBool:(BOOL)aValue { [self addValue:[NSNumber numberWithBool:aValue]]; [currentProperty release], currentProperty = nil; }
- (void)jsonParserFoundNULL:(NDJSON *)aParser { [self addValue:[NSNull null]]; [currentProperty release], currentProperty = nil; }

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

- (void)popCurrentContainer
{
	if( containerStack.count > 0 )
	{
		containerStack.count--;
		[currentProperty release];
//		currentProperty = containerStack.bytes[containerStack.count].propertyName;
		[containerStack.bytes[containerStack.count].container release];
	}
}

- (void)addValue:(id)aValue
{
	if( result != nil )
	{
		id			theCurrentContainer = self.currentContainer;;
		if( currentProperty == nil )
		{
			NSCParameterAssert( [theCurrentContainer respondsToSelector:@selector(addObject:)] );
			[theCurrentContainer addObject:aValue];
		}
		else
		{
			@try
			{
				NSString	* thePropertyName = currentProperty;
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
				if( !ignoreUnknownPropertyName || ![[anException name] isEqualToString:NSUndefinedKeyException] )
					@throw anException;
			}
		}
	}
	else
		result = [aValue retain];
}

@end

