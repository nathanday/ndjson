//
//  NDJSONMeta.h
//  NDJSON
//
//  Created by Nathan Day on 22/11/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NDJSONMeta : NSObject

@property(readonly,nonatomic)		Class		class;
@property(readonly,nonatomic)		NSString	* indexPropertyName;
@property(readonly,nonatomic)		NSString	* parentPropertyName;
@property(readonly,nonatomic)		NSSet		* ignoredJSONKeys;
@property(readonly,nonatomic)		NSSet		* consideredJSONKeys;

+ (NDJSONMeta *)metaForClass:(Class)class;

- (NSString *)propertyNameForJSONKey:(NSString *)key;
- (Class)classForJSONKey:(NSString *)key;
- (Class)collectionClassForJSONKey:(NSString *)key;

- (NDJSONMeta *)metaForJSONKey:(NSString *)key;
- (NDJSONMeta *)collectionMetaForJSONKey:(NSString *)key;

@end
