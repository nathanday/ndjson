# NDJSON
**NDJSON** is a JSON parser written in Objective-C. It support three kinds of parsing, as well as parsing to NSDictionary, NSArray, NSNumber, NSString and NSNull (using **NDJSONParser**), it also support event parsing (using the class **NDJSON**), and parsing to your own classes (using NDJSONParser also).

Parsing to you own classes works by supplying the root class the parser is supposed to use, it then uses property runtime introspection to determine what the class type should be. For situation where the class type can not be determined or if you want to override the default classes used, you can implement the class method **classesForPropertyNamesJSONParser:** to return a NSDictionary mapping property names to class objects.

## Automatic Reference Counting.
**NDJSON** can be used in *Automatic Reference Counting* projects by setting the flag *-fno-objc-arc* for the files *NDSJSON.m* and *NDJSONParser.m*, this turns of *Automatic Reference Counting* for just these files.

## Generating JSON
Currently NDJSON does not have any mechanism for generating JSON for Objective-C objects.

## Non-standard JSON features
As well as strict JSON, NDJSON also add support for

* unquoted keys in objects.
* trailing comma in arrays.
* JavaScript comments.

to only accept strict JSON use the option flag, **NDJSONOptionStrict**

## To Do
* handle compressed JSON document, using zlib
* for mismatching string types, look for *set&lt;property&gt;String:* method, for example the property date of type *NSDate* is set using the method *setDateString:*, if that fails then look for an *initWithString:* method, also support the JSON type number, for example *setDateNumber:* or *initWithNumber:*
* unit tests for strict JSON.
* better bad JSON handling.
* work with NSURLConnection.
* method to pass in block of data to parse, this could handle NSURLConnection case.
* Handle keys with characters outside of ASCII.