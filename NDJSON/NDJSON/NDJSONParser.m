//
//  NDJSONParser.m
//  NDJSON
//
//  Created by Nathan Day on 31/08/11.
//  Copyright 2011 Nathan Day. All rights reserved.
//

#import "NDJSON.h"
#import "NDJSONParser.h"

#import <objc/runtime.h>

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

static void pushContainerForJSONParser( NDJSONParser * self, id container, BOOL isObject );
static id popCurrentContainerForJSONParser( NDJSONParser * self );

@interface NDJSONParser () <NDJSONDelegate>
{
@protected
	struct
	{
		NSUInteger						size,
										count;
		struct ContainerStackStruct		* bytes;
	}								containerStack;
	NSString						* currentProperty;
	NSString						* currentKey;
	struct
	{
		int								ignoreUnknownPropertyName	: 1;
		int								convertKeysToMedialCapital	: 1;
		int								removeIsAdjective			: 1;
	}								options;
	id								result;
}

@property(readonly,nonatomic)	id				currentObject;
@property(readonly,nonatomic)	id				currentContainer;
@property(readonly,nonatomic)	NSString		* currentContainerPropertyName;

- (void)addValue:(id)value type:(NDJSONValueType)type;

@end

#pragma mark - NDJSONCustomParser interface
@interface NDJSONCustomParser : NDJSONParser
{
	Class	rootClass,
			rootCollectionClass;
}

- (Class)classForPropertyName:(NSString *)name class:(Class)class;
- (Class)collectionClassForPropertyName:(NSString *)name class:(Class)class;

@end

#pragma mark - NDJSONCoreData interface
@interface NDJSONCoreData : NDJSONParser
{
	NSManagedObjectContext			* managedObjectContext;
	NSEntityDescription				* rootEntity;
	NSManagedObjectModel			* managedObjectModel;
}
@property(readonly,nonatomic)	NSManagedObjectModel		* managedObjectModel;
@property(retain,nonatomic)		NSEntityDescription			* currentEntityDescription;

- (NSEntityDescription *)entityDescriptionForName:(NSString *)name;

@end

#pragma mark - NDJSONParser implementation
@implementation NDJSONParser

#pragma mark - manually implemented properties

- (Class)rootClass { return Nil; }
- (Class)rootCollectionClass { return Nil; }

- (NSManagedObjectContext *)managedObjectContext { return nil; }
- (NSEntityDescription *)rootEntity { return nil; }


#pragma mark - creation and destruction
- (id)initWithRootClass:(Class)aRootClass { return [self initWithRootClass:aRootClass rootCollectionClass:Nil]; }
- (id)initWithRootClass:(Class)aRootClass rootCollectionClass:(Class)aRootCollectionClass
{
	[self release];
	return [[NDJSONCustomParser alloc] initWithRootClass:aRootClass rootCollectionClass:aRootCollectionClass];
}

- (id)initWithRootEntityName:(NSString *)aRootEntityName inManagedObjectContext:(NSManagedObjectContext *)aManagedObjectContext
{
	NSParameterAssert( aRootEntityName != nil );
	NSParameterAssert( aManagedObjectContext != nil );
	return [self initWithRootEntity:[[aManagedObjectContext.persistentStoreCoordinator.managedObjectModel entitiesByName] objectForKey:aRootEntityName] inManagedObjectContext:aManagedObjectContext];
}

- (id)initWithRootEntity:(NSEntityDescription *)aRootEntity inManagedObjectContext:(NSManagedObjectContext *)aManagedObjectContext
{
	NSParameterAssert( aRootEntity != nil );
	NSParameterAssert( aManagedObjectContext != nil );
	[self release];
	return [[NDJSONCoreData alloc] initWithRootEntity:aRootEntity inManagedObjectContext:aManagedObjectContext];
}

- (void)dealloc
{
	for( NSUInteger i = 0; i < containerStack.count; i++ )
	{
		[containerStack.bytes[i].propertyName release];
		[containerStack.bytes[i].container release];
	}
	[currentProperty release];
	[currentKey release];
	[result autorelease];
	free(containerStack.bytes);
	[super dealloc];
}

#pragma mark - parsing methods

- (id)objectForJSONString:(NSString *)aString options:(NDJSONOptionFlags)anOptions error:(__autoreleasing NSError **)anError
{
	id					theResult =  nil;
	NSAssert( aString != nil, @"nil input JSON string" );
	NDJSON			* theJSONParser = [[NDJSON alloc] init];
	if( theJSONParser != nil )
	{
		if( [theJSONParser setJSONString:aString error:anError] )
			theResult = [self objectForJSONParser:theJSONParser options:anOptions];
	}
	[theJSONParser release];
	return theResult;
}

- (id)objectForJSONData:(NSData *)aData encoding:(NSStringEncoding)anEncoding options:(NDJSONOptionFlags)anOptions error:(NSError **)anError
{
	id					theResult =  nil;
	NSAssert( aData != nil, @"nil input JSON string" );
	NDJSON			* theJSONParser = [[NDJSON alloc] init];
	if( theJSONParser != nil )
	{
		if( [theJSONParser setJSONData:aData encoding:anEncoding error:anError] )
			theResult = [self objectForJSONParser:theJSONParser options:anOptions];
	}
	[theJSONParser release];
	return theResult;
}

- (id)objectForContentsOfFile:(NSString *)aPath encoding:(NSStringEncoding)anEncoding options:(NDJSONOptionFlags)anOptions error:(__autoreleasing NSError **)anError
{
	id					theResult =  nil;
	NSAssert( aPath != nil, @"nil input path" );
	NDJSON			* theJSONParser = [[NDJSON alloc] init];
	if( theJSONParser != nil )
	{
		if( [theJSONParser setContentsOfFile:aPath encoding:anEncoding error:anError] )
			theResult = [self objectForJSONParser:theJSONParser options:anOptions];
	}
	[theJSONParser release];
	return theResult;
}

- (id)objectForContentsOfURL:(NSURL *)aURL encoding:(NSStringEncoding)anEncoding options:(NDJSONOptionFlags)anOptions error:(__autoreleasing NSError **)anError
{
	id					theResult =  nil;
	NSAssert( aURL != nil, @"nil input file url" );
	NDJSON			* theJSONParser = [[NDJSON alloc] init];
	if( theJSONParser != nil )
	{
		if( [theJSONParser setContentsOfURL:aURL encoding:anEncoding error:anError] )
			theResult = [self objectForJSONParser:theJSONParser options:anOptions];
	}
	[theJSONParser release];
	return theResult;
}

- (id)objectForURLRequest:(NSURLRequest *)aURLRequest options:(NDJSONOptionFlags)anOptions error:(__autoreleasing NSError **)anError
{
	id					theResult =  nil;
	NSAssert( aURLRequest != nil, @"nil URL request" );
	NDJSON			* theJSONParser = [[NDJSON alloc] init];
	if( theJSONParser != nil )
	{
		if( [theJSONParser setURLRequest:aURLRequest error:anError] )
			theResult = [self objectForJSONParser:theJSONParser options:anOptions];
	}
	[theJSONParser release];
	return theResult;
}

- (id)objectForInputStream:(NSInputStream *)aStream encoding:(NSStringEncoding)anEncoding options:(NDJSONOptionFlags)anOptions error:(__autoreleasing NSError **)anError
{
	id					theResult =  nil;
	NSAssert( aStream != nil, @"nil input JSON stream" );
	NDJSON			* theJSONParser = [[NDJSON alloc] init];
	if( theJSONParser != nil )
	{
		if( [theJSONParser setInputStream:aStream encoding:anEncoding error:anError] )
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

#pragma mark - NDJSONDelegate methods
- (void)jsonParserDidStartDocument:(NDJSON *)aParser
{
	containerStack.size = 256;
	containerStack.count = 0;
	if( containerStack.bytes != NULL )
		free( containerStack.bytes );
	containerStack.bytes = calloc(containerStack.size,sizeof(struct ContainerStackStruct));
	[currentProperty release], currentProperty = nil;
	[currentKey release], currentKey = nil;
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
	[currentKey release], currentKey = nil;
	if( containerStack.bytes != NULL )
		free(containerStack.bytes);
	containerStack.bytes = NULL;
}

- (void)jsonParserDidStartArray:(NDJSON *)aParser
{
	NSMutableArray		* theArrayRep = [[NSMutableArray alloc] init];
//	[self addValue:theArrayRep type:NDJSONValueArray];
	pushContainerForJSONParser( self, theArrayRep, NO );
	[currentProperty release], currentProperty = nil;
	[theArrayRep release];
}

- (void)jsonParserDidEndArray:(NDJSON *)aParser
{
	id		theArray = popCurrentContainerForJSONParser(self);
	[self addValue:theArray type:NDJSONValueArray];
}

- (void)jsonParserDidStartObject:(NDJSON *)aParser
{
	id			theObjectRep = theObjectRep = [[NSMutableDictionary alloc] init];

//	[self addValue:theObjectRep type:NDJSONValueObject];
	pushContainerForJSONParser( self, theObjectRep, YES );
	[currentProperty release], currentProperty = nil;
	[theObjectRep release];
}

- (void)jsonParserDidEndObject:(NDJSON *)aParser
{
	id		theObject = popCurrentContainerForJSONParser(self);
	[self addValue:theObject type:NDJSONValueArray];
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
	NSParameterAssert( containerStack.count == 0 || containerStack.bytes[containerStack.count-1].isObject );
	NSString	* theKey = stringByConvertingPropertyName( aValue, options.removeIsAdjective != 0, options.convertKeysToMedialCapital != 0 );
	[currentProperty release], currentProperty = [theKey retain];
	[currentKey release], currentKey = [aValue retain];
}
- (void)jsonParser:(NDJSON *)aParser foundString:(NSString *)aValue
{
	[self addValue:aValue type:NDJSONValueString];
	[currentProperty release], currentProperty = nil;
}
- (void)jsonParser:(NDJSON *)aParser foundInteger:(NSInteger)aValue
{
	[self addValue:[NSNumber numberWithInteger:aValue] type:NDJSONValueInteger];
	[currentProperty release], currentProperty = nil;
}
- (void)jsonParser:(NDJSON *)aParser foundFloat:(double)aValue
{
	[self addValue:[NSNumber numberWithDouble:aValue] type:NDJSONValueFloat];
	[currentProperty release], currentProperty = nil;
}
- (void)jsonParser:(NDJSON *)aParser foundBool:(BOOL)aValue
{
	[self addValue:[NSNumber numberWithBool:aValue] type:NDJSONValueBoolean];
	[currentProperty release], currentProperty = nil;
}
- (void)jsonParserFoundNULL:(NDJSON *)aParser
{
	[self addValue:[NSNull null] type:NDJSONValueBoolean];
	[currentProperty release], currentProperty = nil;
}

#pragma mark - private

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
	NSString			* theResult = currentProperty;
	if( theResult == nil && containerStack.count > 0 )
		theResult = containerStack.bytes[containerStack.count-1].propertyName;
	return theResult;
}

static void pushContainerForJSONParser( NDJSONParser * self, id aContainer, BOOL anIsObject )
{
	NSCParameterAssert( aContainer != nil );
	NSCParameterAssert( self->containerStack.bytes != NULL );
	
	if( self->containerStack.count >= self->containerStack.size )
	{
		void		* theBytes = NULL;
		self->containerStack.size *= 2;
		theBytes = realloc(self->containerStack.bytes, self->containerStack.size);
		NSCAssert( theBytes != NULL, @"Memory error" );
		self->containerStack.bytes = theBytes;
	}
	self->containerStack.bytes[self->containerStack.count].container = [aContainer retain];
	self->containerStack.bytes[self->containerStack.count].propertyName = self->currentProperty;
	self->currentProperty = nil;
	self->containerStack.bytes[self->containerStack.count].isObject = anIsObject;
	self->containerStack.count++;
}

- (void)addValue:(id)aValue type:(NDJSONValueType)aType
{
	id			theCurrentContainer = self.currentContainer;;
	if( theCurrentContainer != nil )
	{
		if( currentProperty == nil )
			[theCurrentContainer addObject:aValue];
		else
			[theCurrentContainer setValue:aValue forKey:currentProperty];
	}
	else
		result = [aValue retain];
}

id popCurrentContainerForJSONParser( NDJSONParser * self )
{
	id		theResult = nil;
	if( self->containerStack.count > 0 )
	{
		self->containerStack.count--;
		[self->currentProperty release], self->currentProperty = nil;
		self->currentProperty = self->containerStack.bytes[self->containerStack.count].propertyName;
		theResult = [self->containerStack.bytes[self->containerStack.count].container autorelease];
	}
	return theResult;
}

@end

@implementation NDJSONCustomParser

@synthesize		rootClass,
				rootCollectionClass;

#pragma mark - creation and destruction
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
	[rootClass release];
	[rootCollectionClass release];
	[super dealloc];
}

- (void)jsonParserDidStartArray:(NDJSON *)aParser
{
	id		theArrayRep = [[[self collectionClassForPropertyName:currentProperty class:[self.currentObject class]] alloc] init];
	[self addValue:theArrayRep type:NDJSONValueArray];
	pushContainerForJSONParser( self, theArrayRep, NO );
	[currentProperty release], currentProperty = nil;
	[theArrayRep release];
}

- (void)jsonParserDidStartObject:(NDJSON *)aParser
{
	Class		theClass = [self classForPropertyName:self.currentContainerPropertyName class:[self.currentObject class]];
	id			theObjectRep = theObjectRep = [[theClass alloc] init];
	
//	[self addValue:theObjectRep type:NDJSONValueObject];
	pushContainerForJSONParser( self, theObjectRep, YES );
	[currentProperty release], currentProperty = nil;
	[theObjectRep release];
}

- (BOOL)jsonParser:(NDJSON *)parser shouldSkipValueForKey:(NSString *)aKey
{
	BOOL		theResult = NO;
	Class		theClass = [self.currentObject class];
	if( [theClass respondsToSelector:@selector(keysIgnoreSetJSONParser:)] )
		theResult = [[theClass keysIgnoreSetJSONParser:self] containsObject:currentProperty];
	else if( [theClass respondsToSelector:@selector(keysConsiderSetJSONParser:)] )
		theResult = ![[theClass keysConsiderSetJSONParser:self] containsObject:currentProperty];
	if( theResult )
	{
		NSCParameterAssert(currentProperty != nil);
		[currentProperty release], currentProperty = nil;;
	}
	return theResult;
}

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

- (void)addValue:(id)aValue type:(NDJSONValueType)aType
{
	id			theCurrentContainer = self.currentContainer;;
	if( theCurrentContainer != nil )
	{
		if( currentProperty == nil )
		{
			NSCParameterAssert( [theCurrentContainer respondsToSelector:@selector(addObject:)] );
			[theCurrentContainer addObject:aValue];
		}
		else
		{
			NSString	* thePropertyName = currentProperty;
			if( [[theCurrentContainer class] respondsToSelector:@selector(propertyNamesForKeysJSONParser:)] )
			{
				NSString	* theNewPropertyName = [[[theCurrentContainer class] propertyNamesForKeysJSONParser:self] objectForKey:currentKey];
				if( theNewPropertyName != nil )
					thePropertyName = theNewPropertyName;
			}
			@try
			{
				[theCurrentContainer setValue:aValue forKey:thePropertyName];
			}
			@catch( NSException * anException )
			{
				if( [[anException name] isEqualToString:NSUndefinedKeyException] )
				{
					if( !options.ignoreUnknownPropertyName )
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
		result = [aValue retain];
}

@end

@implementation NDJSONCoreData

@synthesize		managedObjectContext,
				rootEntity;

- (NSEntityDescription *)currentEntityDescription
{
	NSManagedObject		* theCurrentContainer = self.currentObject;
	return theCurrentContainer.entity;
}

- (NSManagedObjectModel *)managedObjectModel
{
	if( managedObjectModel == nil )
		managedObjectModel = [self.managedObjectContext.persistentStoreCoordinator.managedObjectModel retain];
	return managedObjectModel;
}

#pragma mark - creation and destruction
- (id)initWithRootEntity:(NSEntityDescription *)aRootEntity inManagedObjectContext:(NSManagedObjectContext *)aManagedObjectContext
{
	if( (self = [super init]) != nil )
	{
		managedObjectContext = [aManagedObjectContext retain];
		rootEntity = [aRootEntity retain];
	}
	return self;
}

- (void)dealloc
{
	[managedObjectContext release];
	[rootEntity release];
	[managedObjectModel release];
	[super dealloc];
}

- (NSEntityDescription *)entityDescriptionForName:(NSString *)aName { return [[self.managedObjectModel entitiesByName] objectForKey:aName]; }

- (void)jsonParserDidStartDocument:(NDJSON *)aParser
{
	self.currentEntityDescription = nil;
	[super jsonParserDidStartDocument:aParser];
}

- (void)jsonParserDidEndDocument:(NDJSON *)aParser
{
	NSError			* theError = nil;
	if( ![self.managedObjectContext save:&theError] )
		NSLog( @"Error: %@", theError );
	self.currentEntityDescription = nil;
	[super jsonParserDidEndDocument:aParser];
}

- (void)jsonParserDidStartArray:(NDJSON *)aParser
{
	NSMutableSet		* theSet = [[NSMutableSet alloc] init];
	[self addValue:theSet type:NDJSONValueArray];
	pushContainerForJSONParser( self, theSet, NO );
	[currentProperty release], currentProperty = nil;
	[theSet release];
}

- (void)jsonParserDidStartObject:(NDJSON *)aParser
{
	NSEntityDescription			* theEntityDesctipion = nil;
	NSManagedObject				* theNewObject = nil;
	NSEntityDescription			* theCurrentEntityDescription = self.currentEntityDescription;
	if( theCurrentEntityDescription != nil )
	{
		NSRelationshipDescription		* theRelationshipDescription = [[theCurrentEntityDescription relationshipsByName] objectForKey:self.currentContainerPropertyName];
		theEntityDesctipion = theRelationshipDescription.destinationEntity;
	}
	else
		theEntityDesctipion = self.rootEntity;

	theNewObject = [[NSManagedObject alloc] initWithEntity:theEntityDesctipion insertIntoManagedObjectContext:self.managedObjectContext];
	
//	[self addValue:theNewObject type:NDJSONValueObject];
	pushContainerForJSONParser( self, theNewObject, YES );
	[currentProperty release], currentProperty = nil;
	[theNewObject release];
}

- (BOOL)sonParser:(NDJSON *)aParser shouldSkipValueForKey:(NSString *)key
{
	NSEntityDescription		* theEntityDescription = self.currentEntityDescription;
	return [theEntityDescription.propertiesByName objectForKey:currentProperty] != nil;
}

@end
