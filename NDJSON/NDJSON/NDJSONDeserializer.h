/*
	NDJSONDeserializer.h
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

#import <Foundation/Foundation.h>
#import "NDJSONParser.h"

extern NSString		* const NDJSONBadCollectionClassException;
extern NSString		* const NDJSONUnrecongnisedPropertyNameException;

extern NSString		* const NDJSONAttributeNameUserInfoKey;
extern NSString		* const NDJSONObjectUserInfoKey;
extern NSString		* const NDJSONPropertyNameUserInfoKey;

enum {
//	NDJSONOptionNone = 0,				// defined in NDJSON
//	NDJSONOptionStrict = 1<<0,			// defined in NDJSON
/**
	determines if the parser will fail if an attempt to setValue:forKey: fails because the property does not exist.
 */
	NDJSONOptionIgnoreUnknownProperties = 1<<16,
/**
	determines if object keys are converted to medial capitals (cammelCase) with the first character converted to cammel case, for example Cammel-case becomes cammelCase. can be used with *removeIsAdjective*
 */
	NDJSONOptionConvertKeysToMedialCapitals = 1<<17,
/**
	determines if _is_ prefix is removed from object keys, for example isPrefix becoms Prefix. Can be used with *convertKeysToMedialCapital*
 */
	NDJSONOptionConvertRemoveIsAdjective = 1<<18,
/**
	If a parsed JSON primative doesn't match the destination property type, this option tell NDJSONDeserializer to attempt to convert it.
 */
	NDJSONOptionCovertPrimitiveJSONTypes = 1<<19,
/**
	 If this flag is set, no attempt to call awakeFromDeserializationWithJSONDeserializer: to every created class is made, this ptentially can increase performace.
 */
	NDJSONOptionDontSendAwakeFromDeserializationMessages = 1<<20,
/**
	If this flag is set, when an none array is generated from the JSON but the recieving property expects an NSArray, NSSet, NSOrderedSet, then the generated object is wrapped in the expected type.
 */
	NDJSONOptionConvertToArrayTypeIfRequired = 1<<21
};

@protocol NDJSONDeserializerDelegate;

/**
 The *NDJSONDeserializer* class provides methods that convert a JSON document into an object tree representation. *NDJSONDeserializer* can either generate property list type objects, *NSDictionary*s, *NSArrays*, *NSStrings* and *NSNumber*s as well as *NSNull* for the JSON value null, or by supplying your own root object and maybe implementing the methods defined in the anyomnous protocol NSObject+NDJSONDeserializer in your own classes, NDJSONDeserializer will generate a tree if your own classes.
 When generating classes of your own type, *NDJSONDeserializer* will determine the correct class type for properties by quering the Objective-C runetime, NSObject+NDJSONDeserializer methods can be used when the information is not avaialable, for example what classes to insert in an array.
 */
@interface NDJSONDeserializer : NSObject <NDJSONParserDelegate>

@property(readonly,nonatomic)	id			currentObject;

/**
	Class used for root JSON object
 */
@property(readonly,nonatomic)	Class		rootClass;
/**
 Class used for root JSON arrays
 */
@property(readonly,nonatomic)	Class		rootCollectionClass;

/**
 The delegate object deserializer. The delegate will receive delegate messages as the JSON is parsed. Messages to the delegate will be sent on the thread that calls the method -[NDJSONDeserializer objectForJSON:options:error:
*/
@property(assign,nonatomic)		id<NDJSONDeserializerDelegate>		delegate;

/**
 Resulting error
 */
@property(readonly,strong,nonatomic)	NSError		* error;

/**
	initalize with the classes type to represent the root JSON object, if the root of the JSON document is an array, the the class type is what is used for the objects within the array.
 */
- (id)initWithRootClass:(Class)rootClass;
/**
	initalize with the classes type to represent the root JSON object and the class type used for root collection type (array, set etc), if the root of the JSON document is an array then the root collection class is used and the class type is what is used for the objects within the array.
 */
- (id)initWithRootClass:(Class)rootClass rootCollectionClass:(Class)rootCollectionClass;

/**
 initalize with the classes type to represent the root JSON object and the class type used for root collection type (array, set etc), if the root of the JSON document is an array then the root collection class is used and the class type is what is used for the objects within the array. The initialParent parent is used if used for root object that implement the -[NSObject parentPropertyNameWithJSONDeserializer:] method, this is most usful if their is more than one root object ie the root of the JSON is an array.
 */
- (id)initWithRootClass:(Class)rootClass rootCollectionClass:(Class)rootCollectionClass initialParent:(id)parent;

/**
	return the root object generted from the parsers output.
 */
- (id)objectForJSON:(NDJSONParser *)parser options:(NDJSONOptionFlags)options error:(NSError **)error;

/**
 The current property name for the object neing parsed, this can be thought of as a stack of values for nested objects and this property returns the top one.
 */
@property(copy,nonatomic)		NSString	* currentProperty;
/**
 Simplar to currentProperty, with will return the property name of the current container object, ie object generated from a JSON object, whereas currentProperty can return this values or the name of the property for the current primate type.
 */
@property(readonly,nonatomic)	NSString	* currentContainerPropertyName;

@end

/**
 The NDJSONDeserializerDelegate protocol defines the optional methods implemented by delegates of NSURLConnection objects.
 
 Implement a delegate gives you anouther way of creating instances for properties as well as letting you listen in of the NDJSONParserDelegate methods that NDJSONDeserializer recieves.
 */
@protocol NDJSONDeserializerDelegate <NDJSONParserDelegate>
@optional
/**
 This is the only way you can directly create an instance for a property, in all of the other methods supply the class and NDJSONDeserializer creates and instance for you.
 */
- (id)jsonDeserializer:(NDJSONDeserializer *)jsonDeserializer objectForClass:(Class)aClass propertName:(NSString *)property;
@end

/**
	NSObject+NDJSONDeserializer is an informal protocol for methods that objects which can be generated from parsing can implement to control how parsing of child onjects and arrays.
	*NDJSONDeserializer* can determine the class types for properties at runtime, but the methods of NSObject+NDJSONDeserializer can be used to override this behavor or help in situations where the type information is not available, for exmaple the class types used for the elements in a JSON array or if the type is *id*.
 */
@interface NSObject (NDJSONDeserializer)

/**
	implemented by classes to override the default mechanism for determining the class type used for a property, if the property is a collection type (array, set etc), then this method is used to determine the types used in the collection, by default an NSDictionat will be used but any method which implements the method setObject:forKey: method.
 */
+ (NSDictionary *)classesForPropertyNamesWithJSONDeserializer:(NDJSONDeserializer *)aDeserializer;
/**
	implemented by classed to override the default mechanism for determining the class type used for a property collection, by default an NSArray will be used but any mehtod which implements the method addObject: method.
 */
+ (NSDictionary *)collectionClassesForPropertyNamesWithJSONDeserializer:(NDJSONDeserializer *)aDeserializer;

/**
	return a set of property names to ignore, this can speed up parsing as the parsing will just scan pass the valuing in the JSON.
 */
+ (NSSet *)keysIgnoreSetWithJSONDeserializer:(NDJSONDeserializer *)aDeserializer;
/**
	return a set of property names to only consider, this can speed up parsing as the parsing will just scan pass the valuing in the JSON.
 */
+ (NSSet *)keysConsiderSetWithJSONDeserializer:(NDJSONDeserializer *)aDeserializer;

/**
	return a dictionary used to map JSON jeys to property names
 */
+ (NSDictionary *)propertyNamesWithJSONDeserializer:(NDJSONDeserializer *)aDeserializer;

/*
	return the property name for the objects index, this property will be set for obejcts added to collections.
 */
+ (NSString *)indexPropertyNameWithJSONDeserializer:(NDJSONDeserializer *)aDeserializer;

/*
	return the property name for the objects parent property, this property will be set if this method is implemented.
 */
+ (NSString *)parentPropertyNameWithJSONDeserializer:(NDJSONDeserializer *)aDeserializer;

/*
	if implemented called when deserialization of the JSON is complete.
 */
- (void)awakeFromDeserializationWithJSONDeserializer:(NDJSONDeserializer *)aDeserializer;

@end

/**
	@functiongroup These macros make implements some of the delegate methods easier, though they do have the limitation in that they do not inherite values from any super class
 */

/**
	implements the class method `+[NSObject classesForPropertyNamesWithJSONDeserializer:]` returning a dictionary with the supplied arguemnts.
 */
#define NDJSONClassesForPropertyNames(...) \
+ (NSDictionary *)classesForPropertyNamesWithJSONDeserializer:(NDJSONDeserializer *)aParser { \
	static NSDictionary     * kClassesForPropertyName = nil; \
	if( kClassesForPropertyName == nil ) kClassesForPropertyName = [[NSDictionary alloc] initWithObjectsAndKeys:__VA_ARGS__, nil]; \
	return kClassesForPropertyName; \
}

/**
 implements the class method `+[NSObject collectionClassesForPropertyNamesWithJSONDeserializer:]` returning a dictionary with the supplied arguemnts.
 */
#define NDJSONCollectionClassesForPropertyNames(...) \
+ (NSDictionary *)collectionClassesForPropertyNamesWithJSONDeserializer:(NDJSONDeserializer *)aParser { \
	static NSDictionary     * kClassesForPropertyName = nil; \
	if( kClassesForPropertyName == nil ) kClassesForPropertyName = [[NSDictionary alloc] initWithObjectsAndKeys:__VA_ARGS__, nil]; \
	return kClassesForPropertyName; \
}

/**
 implements the class method `+[NSObject keysConsiderSetWithJSONDeserializer:]` returning a set with the supplied arguemnts.
 */
#define NDJSONKeysConsiderSet(...) \
+ (NSSet *)keysConsiderSetWithJSONDeserializer:(NDJSONDeserializer *)aParser { \
    static NSSet       * kSet = nil; \
    if( kSet == nil ) kSet = [[NSSet alloc] initWithObjects:__VA_ARGS__, nil]; \
	return kSet; \
}

/**
 implements the class method `+[NSObject keysIgnoreSetWithJSONDeserializer:]` returning a set with the supplied arguemnts.
 */
#define NDJSONKeysIgnoreSet(...) \
+ (NSSet *)keysIgnoreSetWithJSONDeserializer:(NDJSONDeserializer *)aParser { \
	static NSSet       * kSet = nil; \
	if( kSet == nil ) kSet = [[NSSet alloc] initWithObjects:__VA_ARGS__, nil]; \
	return kSet; \
}

/**
 implements the class method `+[NSObject propertyNamesWithJSONDeserializer:]` returning a dictionary with the supplied arguemnts.
 */
#define NDJSONPropertyNamesForKeys(...) \
+ (NSDictionary *)propertyNamesWithJSONDeserializer:(NDJSONDeserializer *)aParser { \
    static NSDictionary     * kNamesForKeys = nil; \
    if( kNamesForKeys == nil ) kNamesForKeys = [[NSDictionary alloc] initWithObjectsAndKeys:__VA_ARGS__, nil]; \
	return kNamesForKeys; \
}

/**
 implements the class method `+[NSObject indexPropertyNameWithJSONDeserializer:]` returning the string upplied arguemnts.
 */
#define NDJSONIndexPropertyName(_SELECTOR_NAME_) \
+ (NSString *)indexPropertyNameWithJSONDeserializer:(NDJSONDeserializer *)aParser { return _SELECTOR_NAME_; }


/**
 implements the class method `+[NSObject parentPropertyNameWithJSONDeserializer:]` returning the string upplied arguemnts.
 */
#define NDJSONParentPropertyName(_SELECTOR_NAME_) \
+ (NSString *)parentPropertyNameWithJSONDeserializer:(NDJSONDeserializer *)aParser { return _SELECTOR_NAME_; }


/*
 Private subclass of NDJSONDeserializer used for subclassing by NDJSONCoreDataDeserializer
 */
@interface NDJSONExtendedDeserializer : NDJSONDeserializer

@end

/*
 Private function used by the subclass NDJSONCoreDataDeserializer
 */
void NDJSONPushContainerForJSONDeserializer( NDJSONDeserializer * self, id container, BOOL isObject );

