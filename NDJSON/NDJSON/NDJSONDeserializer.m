/*
	NDJSONDeserializer.m
	NDJSON

	Created by Nathan Day on 31.02.12 under a MIT-style license.
	Copyright (c) 2012 Nathan Day

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
 */

#import "NDJSONDeserializer.h"
#import <objc/runtime.h> 

struct NDContainerStackStruct
{
	NSString	* propertyName;
	NSString	* key;
	id			container;
	BOOL		isObject;
};

struct NDClassesDesc
{
	Class	actual,
			expected;
};

static const BOOL		kIgnoreUnknownPropertyNameDefaultValue = NO,
						kConvertKeysToMedialCapitalDefaultValue = NO,
						kRemoveIsAdjectiveDefaultValue = NO;

NSString				* const NDJSONBadCollectionClassException = @"NDJSONBadCollectionClassException",
						* const NDJSONUnrecongnisedPropertyNameException = @"NDJSONUnrecongnisedPropertyName",
						* const NDJSONAttributeNameUserInfoKey = @"AttributeName",
						* const NDJSONObjectUserInfoKey = @"Object",
						* const NDJSONPropertyNameUserInfoKey = @"PropertyName";

static const size_t		kMaximumClassNameLength = 512;

/**
 functions used by NDJSONDeserializer to build tree
 */
static NDJSONValueType NDJSONGetTypeNameFromPropertyAttributes( char * aClassName, size_t aLen, const char * aPropertyAttributes )
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


static Class NDMutableClassForClass( Class aClass )
{
	Class		theResult = Nil;
	struct { Class base, mutable; }		theMaps[] = {
		{[NSArray class],[NSMutableArray class]},
		{[NSSet class],[NSMutableSet class]},
		{[NSOrderedSet class],[NSMutableOrderedSet class]},
		{[NSIndexSet class],[NSMutableIndexSet class]},
		{[NSDictionary class],[NSMutableDictionary class]},
	};
	for( NSUInteger i = 0; theResult == Nil && i < sizeof(theMaps)/sizeof(*theMaps); i++ )
	{
		if( theMaps[i].base == aClass )
			theResult = theMaps[i].mutable;
	}
	return theResult ? theResult : aClass;
}

void NDJSONPushContainerForJSONDeserializer( NDJSONDeserializer * self, id container, BOOL isObject );
static id NDJSONPopCurrentContainerForJSONDeserializer( NDJSONDeserializer * self );

@interface NDJSONDeserializer ()
{
@protected
	struct
	{
		NSUInteger								size,
												count;
		struct NDContainerStackStruct			* bytes;
	}										_containerStack;
	NSString								* _currentProperty;
	NSString								* _currentKey;
	struct
	{
		int										ignoreUnknownPropertyName					: 1;
		int										convertKeysToMedialCapital					: 1;
		int										removeIsAdjective							: 1;
		int										convertPrimativeJSONTypes					: 1;
		int										dontSendAwakeFromDeserializationMessages	: 1;
		int										convertToArrayTypeIfRequired				: 1;
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
	NSError									* _error;
}

@property(readonly,nonatomic)			id			currentContainer;
@property(readonly,nonatomic)			NSString	* currentContainerKey;
@property(readwrite,strong,nonatomic)	NSError		* error;

- (void)addValue:(id)value type:(NDJSONValueType)type;

@end

#pragma mark - NDJSONCustomDeserializer interface
@interface NDJSONCustomDeserializer : NDJSONExtendedDeserializer
{
	Class				rootClass,
						rootCollectionClass;
	NSMutableArray		* _objectThatRespondToAwakeFromDeserialization;
}

- (struct NDClassesDesc)classForPropertyName:(NSString *)name class:(Class)class;
- (struct NDClassesDesc)collectionClassForPropertyName:(NSString *)name class:(Class)class;

@end

#pragma mark - NDJSONDeserializer implementation
@implementation NDJSONDeserializer

@synthesize			delegate = _delegate,
					currentProperty = _currentProperty,
					error = _error;

#pragma mark - manually implemented properties

- (Class)rootClass { return Nil; }
- (Class)rootCollectionClass { return Nil; }

- (NSManagedObjectContext *)managedObjectContext { return nil; }

- (void)setDelegate:(id<NDJSONDeserializerDelegate>)aDelegate
{
	_delegate = aDelegate;
	[self setUpRespondsTo];
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
	_options.dontSendAwakeFromDeserializationMessages = anOptions&NDJSONOptionDontSendAwakeFromDeserializationMessages ? YES : NO;
	_options.convertToArrayTypeIfRequired = anOptions&NDJSONOptionConvertToArrayTypeIfRequired ? YES : NO;
	if( [aJSON parseWithOptions:anOptions] )
		theResult = _result;
	else if( anError != NULL )
		*anError = self.error;
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
	_containerStack.bytes = calloc(_containerStack.size,sizeof(struct NDContainerStackStruct));
	NSAssert( _containerStack.bytes != NULL, @"Malloc failure" );
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
	NDJSONPushContainerForJSONDeserializer( self, theArrayRep, NO );
	[_currentProperty release], _currentProperty = nil;
	[theArrayRep release];
}

- (void)jsonParserDidEndArray:(NDJSONParser *)aJSON
{
	id		theArray = NDJSONPopCurrentContainerForJSONDeserializer(self);
	if( self->_delegateMethod.didEndArray != NULL )
		self->_delegateMethod.didEndArray( self->_delegate, @selector(jsonParserDidEndArray:), self );
	[self addValue:theArray type:NDJSONValueArray];
}

- (void)jsonParserDidStartObject:(NDJSONParser *)aJSON
{
	id			theObjectRep = theObjectRep = [[NSMutableDictionary alloc] init];

	if( self->_delegateMethod.didStartObject != NULL )
		self->_delegateMethod.didStartObject( self->_delegate, @selector(jsonParserDidStartObject:), self );
	NDJSONPushContainerForJSONDeserializer( self, theObjectRep, YES );
	[_currentProperty release], _currentProperty = nil;
	[theObjectRep release];
}

- (void)jsonParserDidEndObject:(NDJSONParser *)aJSON
{
	id		theObject = NDJSONPopCurrentContainerForJSONDeserializer(self);
	if( self->_delegateMethod.didEndObject != NULL )
		self->_delegateMethod.didEndObject( self->_delegate, @selector(jsonParserDidEndObject:), self );
	[self addValue:theObject type:NDJSONValueObject];
}

static NSString * NDJSONStringByConvertingPropertyName( NSString * aString, BOOL aRemoveIs, BOOL aConvertToCamelCase )
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
	NSString	* thePropertyName = NDJSONStringByConvertingPropertyName( aValue, _options.removeIsAdjective != 0, _options.convertKeysToMedialCapital != 0 );
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
- (void)jsonParser:(NDJSONParser *)aJSONParser error:(NSError *)anError
{
	self.error = anError;
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

void NDJSONPushContainerForJSONDeserializer( NDJSONDeserializer * self, id aContainer, BOOL anIsObject )
{
	NSCParameterAssert( aContainer != nil );

	if( self->_containerStack.count >= self->_containerStack.size )
	{
		void		* theBytes = NULL;
		self->_containerStack.size *= 2;
		theBytes = realloc(self->_containerStack.bytes, self->_containerStack.size);
		NSCAssert( theBytes != NULL, @"Memory failure" );
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
	id			theCurrentContainer = self.currentContainer;
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
			[theCurrentContainer setValue:aValue forKey:_currentProperty];
	}
	else
		_result = [aValue retain];
}

id NDJSONPopCurrentContainerForJSONDeserializer( NDJSONDeserializer * self )
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

static SEL NDJSONConversionSelectorForPropertyAndType( NSString * aProperty, NDJSONValueType aType )
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

static SEL NDJSONInstanceInitSelectorForType( NDJSONValueType aType )
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

static BOOL NDJSONSetValueByConvertingPrimativeType( id aContainer, id aValue, NSString * aPropertyName, NDJSONValueType aSourceType )
{
	BOOL				theResult = NO;
	objc_property_t		theProperty = class_getProperty([aContainer class], [aPropertyName UTF8String]);
	if( theProperty != NULL )
	{
		const char			* thePropertyAttributes = property_getAttributes(theProperty);
		char				theClassName[kMaximumClassNameLength];
		NDJSONValueType		theTargetType = NDJSONGetTypeNameFromPropertyAttributes( theClassName, sizeof(theClassName)/sizeof(*theClassName), thePropertyAttributes );
		Class				theTargetClass = Nil;
		if( NDJSONParserValueEquivelentObjectTypes(theTargetType, aSourceType) || (NDJSONParserValueIsNSNumberType(aSourceType) && [(theTargetClass = objc_getClass(theClassName)) isSubclassOfClass:[NSNumber class]]) )
		{
			[aContainer setValue:aValue forKey:aPropertyName];
		}
		else
		{
			SEL		theSelector = NDJSONConversionSelectorForPropertyAndType( aPropertyName, aSourceType );
			if( [aContainer respondsToSelector:theSelector] )
			{
				[aContainer performSelector:theSelector withObject:aValue];
			}
			else if( NDJSONParserValueIsPrimativeType(theTargetType) )
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
				theSelector = NDJSONInstanceInitSelectorForType( aSourceType );
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
	id			theCurrentContainer = self.currentContainer;
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
				if( _options.convertPrimativeJSONTypes && NDJSONParserValueIsPrimativeType(aType) )
				{
					if( !NDJSONSetValueByConvertingPrimativeType( theCurrentContainer, aValue, _currentProperty, aType ) )
						[theCurrentContainer setValue:aValue forKey:_currentProperty];
				}
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
			NDJSONPushContainerForJSONDeserializer( self, aParent, YES );
	}
	return self;
}

- (void)dealloc
{
	[rootClass release];
	[rootCollectionClass release];
	[super dealloc];
}

- (void)jsonParserDidEndDocument:(NDJSONParser *)aJSON
{
	[super jsonParserDidEndDocument:aJSON];
	for( id theObject in _objectThatRespondToAwakeFromDeserialization )
	{
		NSParameterAssert([theObject respondsToSelector:@selector(awakeFromDeserializationWithJSONDeserializer:)]);
		[theObject awakeFromDeserializationWithJSONDeserializer:self];
	}
	[_objectThatRespondToAwakeFromDeserialization release], _objectThatRespondToAwakeFromDeserialization = nil;
}

- (void)jsonParserDidStartArray:(NDJSONParser *)aJSON
{
	struct NDClassesDesc	theClassesDes = [self collectionClassForPropertyName:_currentProperty class:[self.currentObject class]];

	if( ![theClassesDes.actual instancesRespondToSelector:@selector(addObject:)] )
	{
		NSString		* theReason = [[NSString alloc] initWithFormat:@"The collection class '%@' for the key '%@' does not respond to the selector 'addObject:'", NSStringFromClass(theClassesDes.actual), _currentProperty];
		NSDictionary	* theUserInfo = [[NSDictionary alloc] initWithObjectsAndKeys:_currentProperty, NDJSONAttributeNameUserInfoKey, nil];
		NSException		* theException = [NSException exceptionWithName:NDJSONBadCollectionClassException reason:theReason userInfo:theUserInfo];
		[theReason release];
		[theUserInfo release];
		@throw theException;
	}

	id		theArrayRep = [[theClassesDes.actual alloc] init];

	if( !_options.dontSendAwakeFromDeserializationMessages && [theArrayRep respondsToSelector:@selector(awakeFromDeserializationWithJSONDeserializer:)] )
	{
		if( _objectThatRespondToAwakeFromDeserialization == nil )
			_objectThatRespondToAwakeFromDeserialization = [[NSMutableArray alloc] init];
		[_objectThatRespondToAwakeFromDeserialization addObject:theArrayRep];
	}

	NDJSONPushContainerForJSONDeserializer( self, theArrayRep, NO );
	[_currentProperty release], _currentProperty = nil;
	[theArrayRep release];
}

- (void)jsonParserDidStartObject:(NDJSONParser *)aJSON
{
	struct NDClassesDesc		theClassDesc = [self classForPropertyName:self.currentContainerPropertyName class:[self.currentObject class]];
	id							theObjectRep = nil;

	if( _delegateMethod.objectForClass != NULL )
		theObjectRep = [_delegateMethod.objectForClass( self.delegate, @selector(jsonDeserializer:objectForClass:propertName:), self, theClassDesc.actual, self.currentContainerPropertyName) retain];

	if( theObjectRep == nil )
		theObjectRep = [[theClassDesc.actual alloc] init];

	if( [[theObjectRep class] respondsToSelector:@selector(parentPropertyNameWithJSONDeserializer:)] )
		[theObjectRep setValue:self.currentObject forKey:[[theObjectRep class] parentPropertyNameWithJSONDeserializer:self]];

	if( !_options.dontSendAwakeFromDeserializationMessages && [theObjectRep respondsToSelector:@selector(awakeFromDeserializationWithJSONDeserializer:)] )
	{
		if( _objectThatRespondToAwakeFromDeserialization == nil )
			_objectThatRespondToAwakeFromDeserialization = [[NSMutableArray alloc] init];
		[_objectThatRespondToAwakeFromDeserialization addObject:theObjectRep];
	}

	if( _options.convertToArrayTypeIfRequired && theClassDesc.expected != Nil && theClassDesc.actual != theClassDesc.expected && ![theClassDesc.actual isSubclassOfClass:theClassDesc.expected] )
	{
		id		theContainer = [[theClassDesc.expected alloc] init];
		[theContainer addObject:theObjectRep];
		NDJSONPushContainerForJSONDeserializer( self, theObjectRep, YES );
		[theContainer release];
	}
	else
		NDJSONPushContainerForJSONDeserializer( self, theObjectRep, YES );
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

- (struct NDClassesDesc)classForPropertyName:(NSString *)aName class:(Class)aClass
{
	struct NDClassesDesc	theClassesDes = {Nil,Nil};
	Class					theRootClass = self.rootClass;
	if( theRootClass != nil )
	{
		if( aClass == Nil )
		{
			theClassesDes.actual = theClassesDes.expected = theRootClass;
		}
		else
		{
			if( [aClass respondsToSelector:@selector(classesForPropertyNamesWithJSONDeserializer:)] )
				theClassesDes.actual = [[aClass classesForPropertyNamesWithJSONDeserializer:self] objectForKey:aName];
			if( theClassesDes.actual == Nil || _options.convertToArrayTypeIfRequired )
			{
				objc_property_t		theProperty = class_getProperty(aClass, [aName UTF8String]);
				if( theProperty != NULL )
				{
					char			theClassName[kMaximumClassNameLength];
					const char		* thePropertyAttributes = property_getAttributes(theProperty);
					
					if( NDJSONGetTypeNameFromPropertyAttributes( theClassName, sizeof(theClassName)/sizeof(*theClassName), thePropertyAttributes ) )
					{
						theClassesDes.expected = objc_getClass( theClassName );
					}
					else
						theClassesDes.expected = [NSMutableDictionary class];
				}
				else
					theClassesDes.expected = [NSMutableDictionary class];
				if( theClassesDes.actual == Nil )
					theClassesDes.actual = theClassesDes.expected;
			}
		}
	}
	else
		theClassesDes.actual = theClassesDes.expected = [NSMutableDictionary class];
	NSParameterAssert(theClassesDes.actual != Nil);
	theClassesDes.expected = NDMutableClassForClass(theClassesDes.expected);
	return theClassesDes;
}

- (struct NDClassesDesc)collectionClassForPropertyName:(NSString *)aName class:(Class)aClass
{
	struct NDClassesDesc	theClassesDes = {Nil,Nil};
	if( self.rootClass != nil )
	{
		if( aClass == Nil )
		{
			Class		theRootCollectionClass = self.rootCollectionClass;
			if( theRootCollectionClass != nil )
				theClassesDes.actual = theClassesDes.expected = theRootCollectionClass;
			else
				theClassesDes.actual = theClassesDes.expected = [NSMutableArray class];
		}
		else
		{
			if( [aClass respondsToSelector:@selector(collectionClassesForPropertyNamesWithJSONDeserializer:)] )
				theClassesDes.actual = [[aClass collectionClassesForPropertyNamesWithJSONDeserializer:self] objectForKey:aName];
			if( theClassesDes.actual == Nil || _options.convertToArrayTypeIfRequired )
			{
				objc_property_t		theProperty = class_getProperty(aClass, [aName UTF8String]);
				if( theProperty != NULL )
				{
					char			theClassName[kMaximumClassNameLength];
					const char		* thePropertyAttributes = property_getAttributes(theProperty);
					
					if( NDJSONGetTypeNameFromPropertyAttributes( theClassName, sizeof(theClassName)/sizeof(*theClassName), thePropertyAttributes ) )
					{
						theClassesDes.expected = objc_getClass( theClassName );
						if( theClassesDes.actual == Nil )
						{
							if( _options.convertToArrayTypeIfRequired && ![theClassesDes.expected instancesRespondToSelector:@selector(addObject:)] )
								theClassesDes.actual = [NSMutableArray class];
							else
								theClassesDes.actual = theClassesDes.expected;
						}
					}
				}
				else
					theClassesDes.actual = theClassesDes.expected = [NSMutableArray class];
			}
		}
	}
	else
		theClassesDes.actual = theClassesDes.expected = [NSMutableArray class];
	theClassesDes.actual = NDMutableClassForClass(theClassesDes.actual);
	NSParameterAssert(theClassesDes.actual != Nil);
	return theClassesDes;
}

@end
