//
//  NDJSONMeta.m
//  NDJSON
//
//  Created by Nathan Day on 22/11/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import "NDJSONMeta.h"
#import <objc/runtime.h>

static NSValue * NDJSONKeyForClass( Class aClass ) { return [NSValue valueWithPointer:(__bridge const void*)aClass]; }

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

@interface NDJSONMeta ()
{
	Class		_class;
	NSString	* _indexPropertyName;
	NSString	* _parentPropertyName;
	NSSet		* _ignoredJSONKeys;
	NSSet		* _consideredJSONKeys;
	NSDictionary	* _everyPropertyNameForJSONKey;
	NSDictionary	* _everyClassForJSONKey;
	NSDictionary	* _everyCollectionClassForJSONKey;
}

@end

@implementation NDJSONMeta

@synthesize		class = _class,
				indexPropertyName = _indexPropertyName,
				parentPropertyName = _parentPropertyName,
				ignoredJSONKeys = _ignoredJSONKeys,
				consideredJSONKeys = _consideredJSONKeys;

static NSMutableDictionary			* kEveryMeta = nil;

+ (void)addMeta:(NDJSONMeta *)aMeta
{
	if( kEveryMeta == nil )
		kEveryMeta = [[NSMutableDictionary alloc] initWithObjectsAndKeys:aMeta,  NDJSONKeyForClass(aMeta.class), nil];
	else
		[kEveryMeta setObject:aMeta forKey:NDJSONKeyForClass(aMeta.class)];
}

+ (NDJSONMeta *)metaForClass:(Class)aClass { return [kEveryMeta objectForKey:NDJSONKeyForClass(aClass)]; }

- (NSString *)propertyNameForJSONKey:(NSString *)aKey
{
	NSString	* theResult = [_everyPropertyNameForJSONKey objectForKey:aKey];
	return theResult != nil ? theResult : aKey;
}
- (Class)classForJSONKey:(NSString *)aKey { return [_everyClassForJSONKey objectForKey:aKey]; }
- (Class)collectionClassForJSONKey:(NSString *)aKey { return [_everyCollectionClassForJSONKey objectForKey:aKey]; }
- (NDJSONMeta *)metaForJSONKey:(NSString *)aKey { return [NDJSONMeta metaForClass:[self classForJSONKey:aKey]]; }
- (NDJSONMeta *)collectionMetaForJSONKey:(NSString *)aKey { return [NDJSONMeta metaForClass:[self collectionClassForJSONKey:aKey]]; }


@end
