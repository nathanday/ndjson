/*
	NDJSONDeserializer.m
	NDJSON

	Created by Nathan Day on 31/08/11.
	Copyright 2011 Nathan Day. All rights reserved.
 */

#import "NDJSONDeserializer.h"
#import <objc/runtime.h> 

struct ContainerStackStruct
{
	NSString	* propertyName;
	NSString	* key;
	id			container;
	BOOL		isObject;
};

static const BOOL		kIgnoreUnknownPropertyNameDefaultValue = NO,
						kConvertKeysToMedialCapitalDefaultValue = NO,
						kRemoveIsAdjectiveDefaultValue = NO;

NSString				* const NDJSONBadCollectionClassException = @"NDJSONBadCollectionClassException",
						* const NDJSONUnrecongnisedPropertyNameException = @"NDJSONUnrecongnisedPropertyName",
						* const NDJSONAttributeNameUserInfoKey = @"AttributeName",
						* const NDJSONObjectUserInfoKey = @"Object",
						* const NDJSONPropertyNameUserInfoKey = @"PropertyName";

static const size_t		kMaximumClassNameLenght = 512;

/**
 functions used by NDJSONDeserializer to build tree
 */
static NDJSONValueType getTypeNameFromPropertyAttributes( char * aClassName, size_t aLen, const char * aPropertyAttributes )
{
	NSCParameterAssert(*aPropertyAttributes == 'T');
	NDJSONValueType	theResult = NDJSONValueNone;
	aPropertyAttributes++;
	if( strchr("islqISLQ", *aPropertyAttributes) != NULL )
		theResult = NDJSONValueInteger;
	else if( strchr("fd", *aPropertyAttributes) != NULL )
		theResult = NDJSONValueFloat;
	else if( strchr("Bc", *aPropertyAttributes) != NULL )
		theResult = NDJSONValueBoolean;
	else if( memcmp(aPropertyAttributes, "@\"NSString\"", 11) == 0 || memcmp(aPropertyAttributes, "@\"NSMutableString\"", 18) == 0 )
		theResult = NDJSONValueString;
	else if( *aPropertyAttributes == '@' )
	{
		aPropertyAttributes++;
		if( *aPropertyAttributes == '"' && aClassName != NULL )
		{
			NSUInteger		i = 0;
			aPropertyAttributes++;
			for( ; aPropertyAttributes[i] != '"' && aPropertyAttributes[i] != '\0' && i < aLen-1; i++ )
				aClassName[i] = aPropertyAttributes[i];
			aClassName[i] = '\0';
		}
		theResult = NDJSONValueObject;
	}
	return theResult;
}

static void pushContainerForJSONDeserializer( NDJSONDeserializer * self, id container, BOOL isObject );
static id popCurrentContainerForJSONDeserializer( NDJSONDeserializer * self );

@interface NDJSONDeserializer () <NDJSONParserDelegate>
{
@protected
	struct
	{
		NSUInteger								size,
												count;
		struct ContainerStackStruct				* bytes;
	}										_containerStack;
	NSString								* _currentProperty;
	NSString								* _currentKey;
	struct
	{
		int										ignoreUnknownPropertyName	: 1;
		int										convertKeysToMedialCapital	: 1;
		int										removeIsAdjective			: 1;
		int										convertPrimativeJSONTypes	: 1;
	}										_options;
	id										_result;
	__weak id<NDJSONDeserializerDelegate>	_delegate;
	struct
	{
		IMP										didStartDocument,
												didEndDocument,
												didStartArray,
												didEndArray,
												didStartObject,
												didEndObject,
												shouldSkipValueForKey,
												foundKey,
												foundString,
												foundNumber,
												foundInteger,
												foundFloat,
												foundBool,
												foundNULL,
												foundError,
												objectForClass;
	}										_delegateMethod;
}

@property(readonly,nonatomic)	id			currentObject;
@property(readonly,nonatomic)	id			currentContainer;
@property(readonly,nonatomic)	NSString	* currentContainerPropertyName;
@property(readonly,nonatomic)	NSString	* currentContainerKey;

- (void)addValue:(id)value type:(NDJSONValueType)type;

@end

@interface NDJSONExtendedDeserializer : NDJSONDeserializer

@end

#pragma mark - NDJSONCustomDeserializer interface
@interface NDJSONCustomDeserializer : NDJSONExtendedDeserializer
{
	Class	rootClass,
			rootCollectionClass;
}

- (Class)classForPropertyName:(NSString *)name class:(Class)class;
- (Class)collectionClassForPropertyName:(NSString *)name class:(Class)class;

@end

#pragma mark - NDJSONCoreData interface
@interface NDJSONCoreData : NDJSONExtendedDeserializer
{
	NSManagedObjectContext			* managedObjectContext;
	NSEntityDescription				* rootEntity;
	NSManagedObjectModel			* managedObjectModel;
}
@property(readonly,nonatomic)	NSManagedObjectModel		* managedObjectModel;
@property(retain,nonatomic)		NSEntityDescription			* currentEntityDescription;

- (NSEntityDescription *)entityDescriptionForName:(NSString *)name;

@end

#pragma mark - NDJSONDeserializer implementation
@implementation NDJSONDeserializer

@synthesize			delegate = _delegate;

#pragma mark - manually implemented properties

- (Class)rootClass { return Nil; }
- (Class)rootCollectionClass { return Nil; }

- (NSManagedObjectContext *)managedObjectContext { return nil; }
- (NSEntityDescription *)rootEntity { return nil; }

- (void)setDelegate:(id<NDJSONDeserializerDelegate>)aDelegate
{
	_delegate = aDelegate;
}

#pragma mark - creation and destruction
- (id)initWithRootClass:(Class)aRootClass { return [self initWithRootClass:aRootClass rootCollectionClass:Nil]; }
- (id)initWithRootClass:(Class)aRootClass rootCollectionClass:(Class)aRootCollectionClass
{
	return [self initWithRootClass:aRootClass rootCollectionClass:aRootCollectionClass initialParent:nil];
}

- (id)initWithRootClass:(Class)aRootClass rootCollectionClass:(Class)aRootCollectionClass initialParent:(id)aParent
{
	[self release];
	return [[NDJSONCustomDeserializer alloc] initWithRootClass:aRootClass rootCollectionClass:aRootCollectionClass initialParent:aParent];
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
	for( NSUInteger i = 0; i < _containerStack.count; i++ )
	{
		[_containerStack.bytes[i].propertyName release];
		[_containerStack.bytes[i].key release];
		[_containerStack.bytes[i].container release];
	}
	[_currentProperty release];
	[_currentKey release];
	[_result autorelease];
	free(_containerStack.bytes);
	[super dealloc];
}

#pragma mark - parsing methods
- (id)objectForJSON:(NDJSONParser *)aJSON options:(NDJSONOptionFlags)anOptions error:(NSError **)anError
{
	id		theResult = nil;
	id		theOriginalDelegate = aJSON.delegate;
	NSAssert( aJSON != nil, @"nil JSON parser" );
	aJSON.delegate = self;
	_options.ignoreUnknownPropertyName = anOptions&NDJSONOptionIgnoreUnknownProperties ? YES : NO;
	_options.convertKeysToMedialCapital = anOptions&NDJSONOptionConvertKeysToMedialCapitals ? YES : NO;
	_options.removeIsAdjective = anOptions&NDJSONOptionConvertRemoveIsAdjective ? YES : NO;
	_options.convertPrimativeJSONTypes = anOptions&NDJSONOptionCovertPrimitiveJSONTypes ? YES : NO;
	if( [aJSON parseWithOptions:anOptions] )
		theResult = _result;
	aJSON.delegate = theOriginalDelegate;
	return theResult;
}

#pragma mark - NDJSONParserDelegate methods
- (void)jsonParserDidStartDocument:(NDJSONParser *)aJSON
{
	_containerStack.size = 256;
	_containerStack.count = 0;
	if( _containerStack.bytes != NULL )
		free( _containerStack.bytes );
	_containerStack.bytes = calloc(_containerStack.size,sizeof(struct ContainerStackStruct));
	[_currentProperty release], _currentProperty = nil;
	[_currentKey release], _currentKey = nil;
	[_result autorelease], _result = nil;
	if( _delegateMethod.didStartDocument != NULL )
		_delegateMethod.didStartDocument( _delegate, @selector(jsonParserDidStartDocument:), self );
}
- (void)jsonParserDidEndDocument:(NDJSONParser *)aJSON
{
	for( NSUInteger i = 0; i < _containerStack.count; i++ )
	{
		[_containerStack.bytes[i].propertyName release];
		[_containerStack.bytes[i].key release];
		[_containerStack.bytes[i].container release];
	}
	_containerStack.count = 0;
	[_currentProperty release], _currentProperty = nil;
	[_currentKey release], _currentKey = nil;
	if( _containerStack.bytes != NULL )
		free(_containerStack.bytes);
	_containerStack.bytes = NULL;
	if( _delegateMethod.didEndDocument != NULL )
		_delegateMethod.didEndDocument( _delegate, @selector(jsonParserDidEndDocument:), self );
}

- (void)jsonParserDidStartArray:(NDJSONParser *)aJSON
{
	NSMutableArray		* theArrayRep = [[NSMutableArray alloc] init];
	if( self->_delegateMethod.didStartArray != NULL )
		self->_delegateMethod.didStartArray( self->_delegate, @selector(jsonParserDidStartArray:), self );
	pushContainerForJSONDeserializer( self, theArrayRep, NO );
	[_currentProperty release], _currentProperty = nil;
	[theArrayRep release];
}

- (void)jsonParserDidEndArray:(NDJSONParser *)aJSON
{
	id		theArray = popCurrentContainerForJSONDeserializer(self);
	if( self->_delegateMethod.didEndArray != NULL )
		self->_delegateMethod.didEndArray( self->_delegate, @selector(jsonParserDidEndArray:), self );
	[self addValue:theArray type:NDJSONValueArray];
}

- (void)jsonParserDidStartObject:(NDJSONParser *)aJSON
{
	id			theObjectRep = theObjectRep = [[NSMutableDictionary alloc] init];

	if( self->_delegateMethod.didStartObject != NULL )
		self->_delegateMethod.didStartObject( self->_delegate, @selector(jsonParserDidStartObject:), self );
	pushContainerForJSONDeserializer( self, theObjectRep, YES );
	[_currentProperty release], _currentProperty = nil;
	[theObjectRep release];
}

- (void)jsonParserDidEndObject:(NDJSONParser *)aJSON
{
	id		theObject = popCurrentContainerForJSONDeserializer(self);
	if( self->_delegateMethod.didEndObject != NULL )
		self->_delegateMethod.didEndObject( self->_delegate, @selector(jsonParserDidEndObject:), self );
	[self addValue:theObject type:NDJSONValueObject];
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

- (void)jsonParser:(NDJSONParser *)aJSON foundKey:(NSString *)aValue
{
	NSParameterAssert( _containerStack.count == 0 || _containerStack.bytes[_containerStack.count-1].isObject );
	NSString	* thePropertyName = stringByConvertingPropertyName( aValue, _options.removeIsAdjective != 0, _options.convertKeysToMedialCapital != 0 );
	id			theCurrentContainer = self.currentContainer;
	if( self->_delegateMethod.foundKey != NULL )
		self->_delegateMethod.foundKey( self->_delegate, @selector(jsonParser:foundKey:), self, aValue );
	/*
	 Do we need to map the property name to a different name
	 */
	if( [[theCurrentContainer class] respondsToSelector:@selector(propertyNamesWithJSONDeserializer:)] )
	{
		NSString	* theNewPropertyName = [[[theCurrentContainer class] propertyNamesWithJSONDeserializer:self] objectForKey:aValue];
		if( theNewPropertyName != nil )
			thePropertyName = theNewPropertyName;
	}
	[_currentProperty release], _currentProperty = [thePropertyName retain];
	[_currentKey release], _currentKey = [aValue retain];
}
- (void)jsonParser:(NDJSONParser *)aJSON foundString:(NSString *)aValue
{
	[self addValue:aValue type:NDJSONValueString];
	if( self->_delegateMethod.foundString != NULL )
		self->_delegateMethod.foundString( self->_delegate, @selector(jsonParser:foundString:), self, aValue );
	[_currentProperty release], _currentProperty = nil;
}
- (void)jsonParser:(NDJSONParser *)aJSON foundInteger:(NSInteger)aValue
{
	[self addValue:[NSNumber numberWithInteger:aValue] type:NDJSONValueInteger];
	if( self->_delegateMethod.foundNumber != NULL )
		self->_delegateMethod.foundNumber( self->_delegate, @selector(jsonParser:foundNumber:), self, [NSNumber numberWithInteger:aValue] );
	else if( self->_delegateMethod.foundInteger != NULL )
		self->_delegateMethod.foundInteger( self->_delegate, @selector(jsonParser:foundInteger:), self, aValue );
	[_currentProperty release], _currentProperty = nil;
}
- (void)jsonParser:(NDJSONParser *)aJSON foundFloat:(double)aValue
{
	[self addValue:[NSNumber numberWithDouble:aValue] type:NDJSONValueFloat];
	if( self->_delegateMethod.foundNumber != NULL )
		self->_delegateMethod.foundNumber( self->_delegate, @selector(jsonParser:foundNumber:), self, [NSNumber numberWithDouble:aValue] );
	else if( self->_delegateMethod.foundFloat != NULL )
		self->_delegateMethod.foundFloat( self->_delegate, @selector(jsonParser:foundFloat:), self, aValue );
	[_currentProperty release], _currentProperty = nil;
}
- (void)jsonParser:(NDJSONParser *)aJSON foundBool:(BOOL)aValue
{
	[self addValue:[NSNumber numberWithBool:aValue] type:NDJSONValueBoolean];
	if( self->_delegateMethod.foundNumber != NULL )
		self->_delegateMethod.foundNumber( self->_delegate, @selector(jsonParser:foundNumber:), self, [NSNumber numberWithBool:aValue] );
	else if( self->_delegateMethod.foundBool != NULL )
		self->_delegateMethod.foundBool( self->_delegate, @selector(jsonParser:foundBool:), self, aValue );
	[_currentProperty release], _currentProperty = nil;
}
- (void)jsonParserFoundNULL:(NDJSONParser *)aJSON
{
	[self addValue:[NSNull null] type:NDJSONValueBoolean];
	if( self->_delegateMethod.foundNULL != NULL )
		self->_delegateMethod.foundNULL( self->_delegate, @selector(jsonParserFoundNULL:), self );
	[_currentProperty release], _currentProperty = nil;
}

#pragma mark - private

/*
 do this once so we don't waste time sending the same message to get the same answer
 Could ad code to look up the IMPs for the messages, and the use NULL values for them to determine whether to send the call
 */
- (void)setUpRespondsTo
{
	NSObject		* theDelegate = self.delegate;
	_delegateMethod.didStartDocument = [theDelegate respondsToSelector:@selector(jsonParserDidStartDocument:)]
										? [theDelegate methodForSelector:@selector(jsonParserDidStartDocument:)]
										: NULL;
	_delegateMethod.didEndDocument = [theDelegate respondsToSelector:@selector(jsonParserDidEndDocument:)]
										? [theDelegate methodForSelector:@selector(jsonParserDidEndDocument:)]
										: NULL;
	_delegateMethod.didStartArray = [theDelegate respondsToSelector:@selector(jsonParserDidStartArray:)]
										? [theDelegate methodForSelector:@selector(jsonParserDidStartArray:)]
										: NULL;
	_delegateMethod.didEndArray = [theDelegate respondsToSelector:@selector(jsonParserDidEndArray:)]
										? [theDelegate methodForSelector:@selector(jsonParserDidEndArray:)]
										: NULL;
	_delegateMethod.didStartObject = [theDelegate respondsToSelector:@selector(jsonParserDidStartObject:)]
										? [theDelegate methodForSelector:@selector(jsonParserDidStartObject:)]
										: NULL;
	_delegateMethod.didEndObject = [theDelegate respondsToSelector:@selector(jsonParserDidEndObject:)]
										? [theDelegate methodForSelector:@selector(jsonParserDidEndObject:)]
										: NULL;
	_delegateMethod.shouldSkipValueForKey = [theDelegate respondsToSelector:@selector(jsonParser:shouldSkipValueForKey:)]
										? [theDelegate methodForSelector:@selector(jsonParser:shouldSkipValueForKey:)]
										: NULL;
	_delegateMethod.foundKey = [theDelegate respondsToSelector:@selector(jsonParser:foundKey:)]
										? [theDelegate methodForSelector:@selector(jsonParser:foundKey:)]
										: NULL;
	_delegateMethod.foundString = [theDelegate respondsToSelector:@selector(jsonParser:foundString:)]
										? [theDelegate methodForSelector:@selector(jsonParser:foundString:)]
										: NULL;
	_delegateMethod.foundNumber = [theDelegate respondsToSelector:@selector(jsonParser:foundNumber:)]
										? [theDelegate methodForSelector:@selector(jsonParser:foundNumber:)]
										: NULL;
	_delegateMethod.foundInteger = [theDelegate respondsToSelector:@selector(jsonParser:foundInteger:)]
										? [theDelegate methodForSelector:@selector(jsonParser:foundInteger:)]
										: NULL;
	_delegateMethod.foundFloat = [theDelegate respondsToSelector:@selector(jsonParser:foundFloat:)]
										? [theDelegate methodForSelector:@selector(jsonParser:foundFloat:)]
										: NULL;
	_delegateMethod.foundBool = [theDelegate respondsToSelector:@selector(jsonParser:foundBool:)]
										? [theDelegate methodForSelector:@selector(jsonParser:foundBool:)]
										: NULL;
	_delegateMethod.foundNULL = [theDelegate respondsToSelector:@selector(jsonParserFoundNULL:)]
										? [theDelegate methodForSelector:@selector(jsonParserFoundNULL:)]
										: NULL;
	_delegateMethod.foundError = [theDelegate respondsToSelector:@selector(jsonParser:error:)]
										? [theDelegate methodForSelector:@selector(jsonParser:error:)]
										: NULL;
	_delegateMethod.objectForClass = [theDelegate respondsToSelector:@selector(jsonDeserializer:objectForClass:propertName:)]
										? [theDelegate methodForSelector:@selector(jsonDeserializer:objectForClass:propertName:)]
										: NULL;
}

- (id)currentContainer { return _containerStack.count > 0 ? _containerStack.bytes[_containerStack.count-1].container : nil; }
- (id)currentObject
{
	id				theResult = nil;
	NSInteger		theIndex = (NSInteger)_containerStack.count;
	while( theResult == nil && theIndex > 0 )
	{
		theIndex--;
		if( _containerStack.bytes[theIndex].isObject )
			theResult = _containerStack.bytes[theIndex].container;
	}
	return theResult;
}
- (NSString *)currentContainerPropertyName
{
	NSString			* theResult = _currentProperty;
	if( theResult == nil && _containerStack.count > 0 )
		theResult = _containerStack.bytes[_containerStack.count-1].propertyName;
	return theResult;
}

- (NSString *)currentContainerKey
{
	NSString			* theResult = _currentKey;
	if( theResult == nil && _containerStack.count > 0 )
		theResult = _containerStack.bytes[_containerStack.count-1].key;
	return theResult;
}

static void pushContainerForJSONDeserializer( NDJSONDeserializer * self, id aContainer, BOOL anIsObject )
{
	NSCParameterAssert( aContainer != nil );
	NSCParameterAssert( self->_containerStack.bytes != NULL );
	
	if( self->_containerStack.count >= self->_containerStack.size )
	{
		void		* theBytes = NULL;
		self->_containerStack.size *= 2;
		theBytes = realloc(self->_containerStack.bytes, self->_containerStack.size);
		NSCAssert( theBytes != NULL, @"Memory error" );
		self->_containerStack.bytes = theBytes;
	}
	self->_containerStack.bytes[self->_containerStack.count].container = [aContainer retain];
	self->_containerStack.bytes[self->_containerStack.count].propertyName = self->_currentProperty;
	self->_containerStack.bytes[self->_containerStack.count].key = self->_currentKey;
	self->_currentProperty = nil;
	self->_currentKey = nil;
	self->_containerStack.bytes[self->_containerStack.count].isObject = anIsObject;
	self->_containerStack.count++;
}

- (void)addValue:(id)aValue type:(NDJSONValueType)aType
{
	id			theCurrentContainer = self.currentContainer;;
	if( theCurrentContainer != nil )
	{
		if( _currentProperty == nil )
		{
			NSCParameterAssert( [theCurrentContainer respondsToSelector:@selector(addObject:)] );
			if( [theCurrentContainer respondsToSelector:@selector(count)] && [[aValue class] respondsToSelector:@selector(indexPropertyNameWithJSONDeserializer:)] )
			{
				[aValue setValue:[NSNumber numberWithUnsignedInteger:[theCurrentContainer count]] forKey:[[aValue class] indexPropertyNameWithJSONDeserializer:self]];
			}
			[theCurrentContainer addObject:aValue];
		}
		else
			[theCurrentContainer setValue:aValue forKey:_currentProperty];
	}
	else
		_result = [aValue retain];
}

id popCurrentContainerForJSONDeserializer( NDJSONDeserializer * self )
{
	id		theResult = nil;
	if( self->_containerStack.count > 0 )
	{
		self->_containerStack.count--;
		[self->_currentProperty release], self->_currentProperty = nil;
		[self->_currentKey release], self->_currentKey = nil;;
		self->_currentProperty = self->_containerStack.bytes[self->_containerStack.count].propertyName;
		self->_currentKey = self->_containerStack.bytes[self->_containerStack.count].key;
		theResult = [self->_containerStack.bytes[self->_containerStack.count].container autorelease];
	}
	return theResult;
}

@end

@implementation NDJSONExtendedDeserializer

static SEL conversionSelectorForPropertyAndType( NSString * aProperty, NDJSONValueType aType )
{
	SEL				theResult = (SEL)0;
	NSUInteger		theLen = [aProperty lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
	char			* theSelectorName  = malloc(theLen+3+12+12);
	char			* thePos = theSelectorName;
	memcpy( thePos, "set", sizeof("set")-1 );
	thePos += sizeof("set")-1;
	memcpy( thePos, [aProperty UTF8String], theLen );
	*thePos = (char)toupper((char)*thePos);
	thePos += theLen;
	memcpy( thePos, "ByConverting", sizeof("ByConverting")-1 );
	thePos += 12;
	switch( aType )
	{
	case NDJSONValueArray:
		memcpy(thePos, "Array:", sizeof("Array:"));
		theResult = sel_registerName(theSelectorName);
		break;
	case NDJSONValueObject:
		memcpy(thePos, "Dictionary:", sizeof("Dictionary:"));
		theResult = sel_registerName(theSelectorName);
		break;
	case NDJSONValueString:
		memcpy(thePos, "String:", sizeof("String:"));
		theResult = sel_registerName(theSelectorName);
		break;
	case NDJSONValueInteger:
	case NDJSONValueFloat:
	case NDJSONValueBoolean:
		memcpy(thePos, "Number:", sizeof("Number:"));
		theResult = sel_registerName(theSelectorName);
		break;
	case NDJSONValueNull:
		memcpy(thePos, "Null:", sizeof("Null:"));
		theResult = sel_registerName(theSelectorName);
		break;
	case NDJSONValueNone:
		break;
	}
	free(theSelectorName);
	return theResult;
}

static SEL instanceInitSelectorForType( NDJSONValueType aType )
{
	SEL				theResult = (SEL)0;
	char			theSelectorName[sizeof("initWith")+sizeof("Dictionary:")];
	char			* thePos = theSelectorName;
	memcpy(thePos, "initWith", sizeof("initWith"));
	thePos += sizeof("initWith")-1;
	switch( aType )
	{
	case NDJSONValueArray:
		memcpy(thePos, "Array:", sizeof("Array:"));
		theResult = sel_registerName(theSelectorName);
		break;
	case NDJSONValueObject:
		memcpy(thePos, "Dictionary:", sizeof("Dictionary:"));
		theResult = sel_registerName(theSelectorName);
		break;
	case NDJSONValueString:
		memcpy(thePos, "String:", sizeof("String:"));
		theResult = sel_registerName(theSelectorName);
		break;
	case NDJSONValueInteger:
	case NDJSONValueFloat:
	case NDJSONValueBoolean:
		memcpy(thePos, "Number:", sizeof("Number:"));
		theResult = sel_registerName(theSelectorName);
		break;
	case NDJSONValueNull:
		memcpy(thePos, "Null:", sizeof("Null:"));
		theResult = sel_registerName(theSelectorName);
		break;
	case NDJSONValueNone:
		break;
	}
	return theResult;
}

static BOOL setValueByConvertingPrimativeType( id aContainer, id aValue, NSString * aPropertyName, NDJSONValueType aSourceType )
{
	BOOL				theResult = NO;
	objc_property_t		theProperty = class_getProperty([aContainer class], [aPropertyName UTF8String]);
	if( theProperty != NULL )
	{
		const char			* thePropertyAttributes = property_getAttributes(theProperty);
		char				theClassName[kMaximumClassNameLenght];
		NDJSONValueType		theTargetType = getTypeNameFromPropertyAttributes( theClassName, sizeof(theClassName)/sizeof(*theClassName), thePropertyAttributes );
		Class				theTargetClass = Nil;
		if( jsonParserValueEquivelentObjectTypes(theTargetType, aSourceType) || (jsonParserValueIsNSNumberType(aSourceType) && [(theTargetClass = objc_getClass(theClassName)) isSubclassOfClass:[NSNumber class]]) )
		{
			[aContainer setValue:aValue forKey:aPropertyName];
		}
		else
		{
			SEL		theSelector = conversionSelectorForPropertyAndType( aPropertyName, aSourceType );
			if( [aContainer respondsToSelector:theSelector] )
			{
				[aContainer performSelector:theSelector withObject:aValue];
			}
			else if( jsonParserValueIsPrimativeType(theTargetType) )
			{
				switch (theTargetType)
				{
				case NDJSONValueString:
					[aContainer setValue:[aValue stringValue] forKey:aPropertyName];
					break;
				case NDJSONValueInteger:
					[aContainer setValue:[NSNumber numberWithInteger:[aValue integerValue]] forKey:aPropertyName];
					break;
				case NDJSONValueFloat:
					[aContainer setValue:[NSNumber numberWithFloat:[aValue floatValue]] forKey:aPropertyName];
					break;
				case NDJSONValueBoolean:
					[aContainer setValue:[NSNumber numberWithBool:[aValue boolValue]] forKey:aPropertyName];
					break;
				case NDJSONValueNull:
					[aContainer setNilValueForKey:aPropertyName];
					break;
				default:
					break;
				}
			}
			else
			{
				theSelector = instanceInitSelectorForType( aSourceType );
				if( theTargetClass == Nil )
					theTargetClass = objc_getClass(theClassName);
				if( [theTargetClass instancesRespondToSelector:theSelector] )
				{
					id	theValue = [theTargetClass alloc];
					[aContainer setValue:[theValue performSelector:theSelector withObject:aValue] forKey:aPropertyName];
					[theValue release];
				}
			}
		}
		theResult = YES;
	}
	return theResult;
}

- (void)addValue:(id)aValue type:(NDJSONValueType)aType
{
	id			theCurrentContainer = self.currentContainer;;
	if( theCurrentContainer != nil )
	{
		if( _currentProperty == nil )								// container must be array like
		{
			NSCParameterAssert( [theCurrentContainer respondsToSelector:@selector(addObject:)] );
			if( [theCurrentContainer respondsToSelector:@selector(count)] && [[aValue class] respondsToSelector:@selector(indexPropertyNameWithJSONDeserializer:)] )
			{
				[aValue setValue:[NSNumber numberWithUnsignedInteger:[theCurrentContainer count]] forKey:[[aValue class] indexPropertyNameWithJSONDeserializer:self]];
			}
			[theCurrentContainer addObject:aValue];
		}
		else														// container must be dictionary like
		{
			@try
			{
				if( _options.convertPrimativeJSONTypes && jsonParserValueIsPrimativeType(aType) )
					setValueByConvertingPrimativeType( theCurrentContainer, aValue, _currentProperty, aType );
				else
					[theCurrentContainer setValue:aValue forKey:_currentProperty];
			}
			@catch( NSException * anException )
			{
				if( [[anException name] isEqualToString:NSUndefinedKeyException] )
				{
					if( !_options.ignoreUnknownPropertyName )
					{
						NSString		* theReasonString = [[NSString alloc] initWithFormat:@"Failed to set value for property name '%@'", _currentProperty];
						NSDictionary	* theUserInfo = [[NSDictionary alloc] initWithObjectsAndKeys:self.currentObject, NDJSONObjectUserInfoKey, _currentProperty, NDJSONPropertyNameUserInfoKey, nil];
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
		_result = [aValue retain];
}

@end

@implementation NDJSONCustomDeserializer

@synthesize		rootClass,
				rootCollectionClass;

#pragma mark - creation and destruction
- (id)initWithRootClass:(Class)aRootClass rootCollectionClass:(Class)aRootCollectionClass initialParent:(id)aParent
{
	if( (self = [super init]) != nil )
	{
		rootClass = aRootClass;
		rootCollectionClass = aRootCollectionClass;
		if( aParent != nil )
			pushContainerForJSONDeserializer( self, aParent, YES );
	}
	return self;
}

- (void)dealloc
{
	[rootClass release];
	[rootCollectionClass release];
	[super dealloc];
}

- (void)jsonParserDidStartArray:(NDJSONParser *)aJSON
{
	id		theArrayRep = [[[self collectionClassForPropertyName:_currentProperty class:[self.currentObject class]] alloc] init];

	pushContainerForJSONDeserializer( self, theArrayRep, NO );
	[_currentProperty release], _currentProperty = nil;
	[theArrayRep release];
}

- (void)jsonParserDidStartObject:(NDJSONParser *)aJSON
{
	Class		theClass = [self classForPropertyName:self.currentContainerPropertyName class:[self.currentObject class]];
	id			theObjectRep = nil;

	if( _delegateMethod.objectForClass != NULL )
		theObjectRep = [_delegateMethod.objectForClass( self.delegate, @selector(jsonDeserializer:objectForClass:propertName:), self, theClass, self.currentContainerPropertyName) retain];

	if( theObjectRep == nil )
		theObjectRep = [[theClass alloc] init];

	if( [[theObjectRep class] respondsToSelector:@selector(parentPropertyNameWithJSONDeserializer:)] )
		[theObjectRep setValue:self.currentObject forKey:[[theObjectRep class] parentPropertyNameWithJSONDeserializer:self]];

	pushContainerForJSONDeserializer( self, theObjectRep, YES );
	[_currentProperty release], _currentProperty = nil;
	[theObjectRep release];
}

- (BOOL)jsonParser:(NDJSONParser *)parser shouldSkipValueForKey:(NSString *)aKey
{
	BOOL		theResult = NO;
	Class		theClass = [self.currentObject class];
	if( [theClass respondsToSelector:@selector(keysIgnoreSetWithJSONDeserializer:)] )
		theResult = [[theClass keysIgnoreSetWithJSONDeserializer:self] containsObject:_currentKey];
	else if( [theClass respondsToSelector:@selector(keysConsiderSetWithJSONDeserializer:)] )
		theResult = ![[theClass keysConsiderSetWithJSONDeserializer:self] containsObject:_currentKey];
	if( theResult )
	{
		NSCParameterAssert(_currentProperty != nil);
		[_currentProperty release], _currentProperty = nil;;
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
			if( [aClass respondsToSelector:@selector(classesForPropertyNamesWithJSONDeserializer:)] )
				theClass = [[aClass classesForPropertyNamesWithJSONDeserializer:self] objectForKey:aName];
			if( theClass == Nil )
			{
				objc_property_t		theProperty = class_getProperty(aClass, [aName UTF8String]);
				if( theProperty != NULL )
				{
					char			theClassName[kMaximumClassNameLenght];
					const char		* thePropertyAttributes = property_getAttributes(theProperty);
					
					if( getTypeNameFromPropertyAttributes( theClassName, sizeof(theClassName)/sizeof(*theClassName), thePropertyAttributes ) )
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
			if( [aClass respondsToSelector:@selector(collectionClassesForPropertyNamesWithJSONDeserializer:)] )
				theClass = [[aClass collectionClassesForPropertyNamesWithJSONDeserializer:self] objectForKey:aName];
			if( theClass == Nil )
			{
				objc_property_t		theProperty = class_getProperty(aClass, [aName UTF8String]);
				if( theProperty != NULL )
				{
					char			theClassName[kMaximumClassNameLenght];
					const char		* thePropertyAttributes = property_getAttributes(theProperty);
					
					if( getTypeNameFromPropertyAttributes( theClassName, sizeof(theClassName)/sizeof(*theClassName), thePropertyAttributes ) )
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

@implementation NDJSONCoreData

@synthesize		currentEntityDescription,
				managedObjectContext,
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

- (void)jsonParserDidStartDocument:(NDJSONParser *)aJSON
{
	self.currentEntityDescription = nil;
	[super jsonParserDidStartDocument:aJSON];
}

- (void)jsonParserDidEndDocument:(NDJSONParser *)aJSON
{
	self.currentEntityDescription = nil;
	[super jsonParserDidEndDocument:aJSON];
}

- (void)jsonParserDidStartArray:(NDJSONParser *)aJSON
{
	NSMutableSet		* theSet = [[NSMutableSet alloc] init];
	pushContainerForJSONDeserializer( self, theSet, NO );
	[_currentProperty release], _currentProperty = nil;
	[theSet release];
}

- (void)jsonParserDidStartObject:(NDJSONParser *)aJSON
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
	
	pushContainerForJSONDeserializer( self, theNewObject, YES );
	[_currentProperty release], _currentProperty = nil;
	[theNewObject release];
}

- (BOOL)sonParser:(NDJSONParser *)aJSON shouldSkipValueForKey:(NSString *)key
{
	NSEntityDescription		* theEntityDescription = self.currentEntityDescription;
	return [theEntityDescription.propertiesByName objectForKey:_currentProperty] != nil;
}

@end
