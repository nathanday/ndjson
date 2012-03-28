//
//  NDJSONTo.m
//  NDJSON
//
//  Created by Nathan Day on 24/03/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import "NDJSONTo.h"
#import <objc/objc-class.h>

NSString		* const NDJSONClassNilException = @"ClassNil",
				* const NDJSONNoPropertyForKeyException = @"NoPropertyForKey";
NSString		* const NDJSONPropertyNameKey = @"PropertyName";

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

@interface NDJSONTo ()
{
	Class		rootClass;
}
@end

@implementation NDJSONTo

@synthesize			rootClass;

- (id)initWithRootClass:(Class)aRootClass
{
	if( (self = [super init]) != nil )
		rootClass = aRootClass;
	return self;
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
			if( [aParent respondsToSelector:@selector(classForPropertyName:)] )
				theClass = [aParent classForPropertyName:aName];
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
