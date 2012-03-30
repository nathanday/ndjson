//
//  NDJSONDeserializer.h
//  NDJSON
//
//  Created by Nathan Day on 31/08/11.
//  Copyright 2011 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>

@class			NDJSON;

@interface NDJSONDeserializer : NSObject

@property(readonly,nonatomic)				Class		rootClass;

- (id)init;
- (id)initWithRootClass:(Class)rootClass;

- (id)propertyListForJSONString:(NSString *)string error:(NSError **)error;
- (id)propertyListForContentsOfFile:(NSString *)path error:(NSError **)error;
- (id)propertyListForContentsOfURL:(NSURL *)url error:(NSError **)error;
- (id)propertyListForContentsOfURLRequest:(NSURLRequest *)urlRequest error:(NSError **)error;
- (id)propertyListForInputStream:(NSInputStream *)stream error:(NSError **)error;

- (id)propertyListForJSONParser:(NDJSON *)parser;

- (Class)classForPropertyName:(NSString *)name parent:(id)parent;

@end

@interface NSObject (NDJSONDeserializer)

- (Class)classForPropertyName:(NSString *)name;

@end
