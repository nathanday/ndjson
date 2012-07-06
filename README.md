# NDJSON

##About
**NDJSON** is a JSON parser written in Objective-C. It support four kinds of parsing, as well as parsing to NSDictionary, NSArray, NSNumber, NSString and NSNull (using **NDJSONParser**), it also support parsing to your own custom classes or coredata entities (using **NDJSONParser**) as well as event parsing (using the class **NDJSON**).

Parsing to you own classes works by supplying the root class the parser is supposed to use, it then uses property runtime introspection to determine what the class type should be. For situation where the class type can not be determined or if you want to override the default classes used, you can implement the class method **classesForPropertyNamesJSONParser:** to return a NSDictionary mapping property names to class objects.

### Licensing
**NDJSON** using an MIT-style license which means use as you wish just give me credit where appropriate.

### Automatic Reference Counting.
**NDJSON** can be used in *Automatic Reference Counting* projects by setting the flag *-fno-objc-arc* for the files *NDSJSON.m* and *NDJSONParser.m*, this turns off *Automatic Reference Counting* for just these files.

### Generating JSON
Currently NDJSON does not have any mechanism for generating JSON for Objective-C objects.

### Non-standard JSON features
As well as strict JSON, NDJSON also add support for

* unquoted keys in objects.
* trailing comma in arrays.
* JavaScript comments.

to only accept strict JSON use the option flag, **NDJSONOptionStrict**

## Getting Started with NDJSONParser
### Supplying a custom root object
You don't have to do anything special to define you root object, just define readwrite properties for properties that you want to be set from JSON values. Properties of immutable collection type, for example NSArray, NSSet will be turned into mutable types so **NDJSONParser** can add values to them.

### Overriding the default mechanism for determining the class used for collection properties
If you want to use a different class for a property to which **NDJSONParser** would choose (you want to use a subclass to what is declared in the property for example) or the class can not be determined by **NDJSONParser** and so you want to help it (properties declared id for example) you can implement the class method +[NSObject classesForPropertyNamesJSONParser:], and return a dictionary that contains the class object for each JSON key as the key in the dictionary. for example

	+ (NSDictionary *)classesForPropertyNamesJSONParser:(NDJSONParser *)aParser
	{
		static NSDictionary     * kClassesForPropertyName = nil;
		if( kClassesForPropertyName == nil )
			kClassesForPropertyName = [[NSDictionary alloc] initWithObjectsAndKeys:
															[MyElement class], @"jsonElementKey",
															nil];
		return kClassesForPropertyName;
	}

because `classesForPropertyNamesJSONParser:` may be called many times you will want to make sure the returned dictionary is created only once.

To simplify the process there is a macro called NDJSONClassesForPropertyNames() for example
	NDJSONClassesForPropertyNames([MyElement class], @"jsonElementKey");
is equivalent to the same code above.

### Using custom classes for elements in a collection property
If you have a property which is used to represent a JSON array, NSArray, NSSet or any class that implements *addObject:*, there is no way for **NDJSONParser** to determine which class you want for element in that array. The mechanism for telling **NDJSONParser** what class to use as elements within a collection is very similar to overriding the default mechanism for determining the class for properties its just a different class method name +[NSObject collectionClassesForPropertyNamesJSONParser:], otherwise it is identical and also may be called many times, it also has a macro to simplify thing `NDJSONCollectionClassesForPropertyNames(...)`

### Changing which property will be used for which JSON key
Sometime you don't want to use a property name that is the same as the JSON key, if you just want to convert every key to medial capitals, (cammelCase with a leading lower case letter) you can use the option flag `NDJSONOptionConvertKeysToMedialCapitals`, this will also remove any illegal identifier characters form properties, (example **my_key name** becomes **myKeyName**).
If you want to remove leading **is** prefix from any keys then use the option flag `NDJSONOptionConvertRemoveIsAdjective`, (example **isSet** becomes **set**).
But if none of the options cover your particular case you have two options you can either implementing Apples NSKeyValueCoding method `-[NSObject setValue:forKey:]`, or alternatively you can implement the class method `+[NSObject propertyNamesForKeysJSONParser:]` which returns a dictionary mapping JSON keys to property names, again this method may be called multiple times and there is a macro to simplify implementing this class method `NDJSONPropertyNamesForKeys(...)`.

### Ignoring JSON keys
By default **NDJSONParser** will throw the exception `NDJSONUnrecongnisedPropertyNameException` which makes debugging easier, you can stop this from occurring by either implementing Apples NSKeyValueCoding method -[NSObject setValue:forKey:] or using option flag `NDJSONOptionIgnoreUnknownProperties`. This will work fine but **NDJSONParser** will still do all the work of parsing the value for that key which can be expensive, to tell NDSJONParser to completely skip this key and value, seeking pass the value without generating any objects, you can implement one of either two class methods `+[NSObject keysConsiderSetJSONParser:]` or `+[NSObject keysIgnoreSetJSONParser:]`, to return a set of either keys to consider, ignoring all other, or keys to ignore. Again these methods may be called many times and there are macros to simplifier implementing these methods `NDJSONKeysConsiderSet(...)` and `NDJSONKeysIgnoreSet(...)`.