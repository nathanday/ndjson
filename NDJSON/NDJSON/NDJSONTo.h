//
//  NDJSONTo.h
//  NDJSON
//
//  Created by Nathan Day on 24/03/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import "NDJSONToPropertyList.h"

extern NSString		* const NDJSONClassNilException,
					* const NDJSONNoPropertyForKeyException;
extern NSString		* const NDJSONPropertyNameKey;

@interface NDJSONTo : NDJSONToPropertyList

@property(readonly,nonatomic)									Class		rootClass;

- (id)initWithRootClass:(Class)rootClass;

@end

@interface NSObject (NDJSONTo)

- (Class)classForPropertyName:(NSString *)name;
- (SEL)setterForPropertyName:(NSString *)name;

@end