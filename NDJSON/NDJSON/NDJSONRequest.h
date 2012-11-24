/*
	NDJSONRequest.h

	Created by Nathan Day on 3.11.12 under a MIT-style license.
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

@class		NDJSONDeserializer,
			NDJSONResponse;
@protocol	NDJSONRequestDelegate;

extern const NSUInteger				kNDJSONDefaultPortNumber;

@interface NDJSONRequest : NSObject

@property(readonly,nonatomic,copy)		NSURLRequest		* URLRequest;
@property(readonly,nonatomic,copy)		NSURL				* URL;
@property(readonly,nonatomic,copy)		NSString			* scheme;
@property(readonly,nonatomic,copy)		NSString			* userInfo;
@property(readonly,nonatomic,copy)		NSString			* userName;
@property(readonly,nonatomic,copy)		NSString			* password;
@property(readonly,nonatomic,assign)	NSUInteger			port;
@property(readonly,nonatomic,copy)		NSString			* domain;
@property(readonly,nonatomic,copy)		NSString			* path;
@property(readonly,nonatomic,copy)		NSArray				* pathComponents;
@property(readonly,nonatomic,copy)		NSString			* query;
@property(readonly,nonatomic,copy)		NSDictionary		* queryComponents;

@property(readonly,nonatomic,copy)		NSString			* responseJSONRootPath;

@property(readonly,nonatomic,strong)	NDJSONDeserializer	* deserializer;

- (id)initWithDeserializer:(NDJSONDeserializer *)deserializer responseCompletionHandler:(void (^)(NDJSONRequest *, NDJSONResponse *))handler;
- (id)initWithDeserializer:(NDJSONDeserializer *)deserializer responseHandler:(id<NDJSONRequestDelegate>)handler;
- (id)initWithDeserializer:(NDJSONDeserializer *)deserializer responseHandlingSelector:(SEL)responseHandlingSelector handler:(id)handler;
- (id)initWithDeserializer:(NDJSONDeserializer *)deserializer invocation:(NSInvocation *)invocation;

@end

@interface NDJSONMutableRequest : NDJSONRequest

@property(readwrite,nonatomic,copy)		NSString			* scheme;
@property(readwrite,nonatomic,copy)		NSString			* userName;
@property(readwrite,nonatomic,copy)		NSString			* password;
@property(readwrite,nonatomic,assign)	NSUInteger			port;
@property(readwrite,nonatomic,copy)		NSString			* domain;
@property(readwrite,nonatomic,copy)		NSArray				* pathComponents;
@property(readwrite,nonatomic,copy)		NSDictionary		* queryComponents;

@end

@protocol NDJSONRequestDelegate <NSObject>

- (void)jsonRequest:(NDJSONRequest *)request response:(NDJSONResponse *)response;

@end