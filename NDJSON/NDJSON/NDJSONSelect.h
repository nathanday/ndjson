//
//  NDJSONSelect.h
//  NDJSON
//
//  Created by Nathan Day on 6/12/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NDJSONSelect : NSObject

- (BOOL)parseJSONString:(NSString *)string error:(NSError **)error;
- (BOOL)parseContentsOfFile:(NSString *)path error:(NSError **)error;
- (BOOL)parseContentsOfURL:(NSURL *)url error:(NSError **)error;
- (BOOL)parseContentsOfURLRequest:(NSURLRequest *)urlRequest error:(NSError **)error;
- (BOOL)parseInputStream:(NSInputStream *)stream error:(NSError **)error;

- (void)addMatchPath:(NSString *)path block:(void (^)(NSString * path, id value))block;

@end
