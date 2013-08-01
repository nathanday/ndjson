/*
	NDJSONRequest.h
	NDJSON

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
#import "NDJSONDeserializer.h"

enum NDJSONHTTPMethod
{
	NDJSONHTTPMethodDefault,
	NDJSONHTTPMethodGet,
	NDJSONHTTPMethodHead,
	NDJSONHTTPMethodPost,
	NDJSONHTTPMethodPut,
	NDJSONHTTPMethodDelete,
	NDJSONHTTPMethodTrace,
	NDJSONHTTPMethodOptions,
	NDJSONHTTPMethodConnect,
	NDJSONHTTPMethodPatch
};

@class		NDJSONDeserializer,
			NDJSONResponse;
@protocol	NDJSONRequestDelegate;

extern const NSUInteger				kNDJSONDefaultPortNumber;

@interface NDJSONRequest : NSObject

@property(readonly,nonatomic,copy)		NSURLRequest		* URLRequest;
@property(readonly,nonatomic,copy)		NSURL				* URL;
@property(readonly,nonatomic,copy)		NSString			* scheme;
@property(readonly,nonatomic,copy)		NSString			* userInfo;
@property(readonly,nonatomic,copy)		NSString			* user;
@property(readonly,nonatomic,copy)		NSString			* password;
@property(readonly,nonatomic,copy)		NSNumber			* port;
@property(readonly,nonatomic,copy)		NSString			* host;
@property(readonly,nonatomic,copy)		NSString			* path;
@property(readonly,nonatomic,copy)		NSArray				* pathComponents;
@property(readonly,nonatomic,copy)		NSString			* query;
@property(readonly,nonatomic,copy)		NSDictionary		* queryComponents;

@property(readonly,nonatomic,strong)	NSData				* body;
@property(readonly,nonatomic,strong)	NSInputStream		* bodyStream;
@property(readonly,nonatomic,strong)	NSInteger(^bodyHandler)( uint8_t * buffer,NSUInteger len);
@property(readonly,nonatomic,strong)	NSString			* HTTPMethodString;
@property(readonly,nonatomic)	enum NDJSONHTTPMethod		HTTPMethod;

@property(readonly,nonatomic,strong)	NDJSONDeserializer			* deserializer;
@property(readonly,nonatomic)			NDJSONOptionFlags			deserializerOptions;
@property(readonly,nonatomic,weak)	id<NSURLConnectionDelegate>		delegate;


- (id)initWithDeserializer:(NDJSONDeserializer *)deserializer deserializerOptions:(NDJSONOptionFlags)deserializerOptions;
- (id)initWithDeserializer:(NDJSONDeserializer *)deserializer;

- (id)initWithDelegate:(id<NSURLConnectionDelegate>)delegate deserializer:(NDJSONDeserializer *)deserializer deserializerOptions:(NDJSONOptionFlags)deserializerOptions;
- (id)initWithDelegate:(id<NSURLConnectionDelegate>)delegate deserializer:(NDJSONDeserializer *)deserializer;

- (void)sendAsynchronousWithQueue:(NSOperationQueue *)queue responseCompletionHandler:(void (^)(NDJSONRequest *, NDJSONResponse *))handler;
- (void)sendAsynchronousWithQueue:(NSOperationQueue *)queue responseHandler:(id<NDJSONRequestDelegate>)handler;
- (void)sendAsynchronousWithQueue:(NSOperationQueue *)queue responseHandlingSelector:(SEL)responseHandlingSelector handler:(id)handler;
- (void)sendAsynchronousWithQueue:(NSOperationQueue *)queue invocation:(NSInvocation *)invocation;

@end

@interface NDJSONMutableRequest : NDJSONRequest

@property(readwrite,nonatomic,copy)		NSURL				* URL;
@property(readwrite,nonatomic,copy)		NSString			* scheme;
@property(readwrite,nonatomic,copy)		NSString			* user;
@property(readwrite,nonatomic,copy)		NSString			* password;
@property(readwrite,nonatomic,copy)		NSNumber			* port;
@property(readwrite,nonatomic,copy)		NSString			* host;
@property(readwrite,nonatomic,copy)		NSArray				* pathComponents;
@property(readwrite,nonatomic,copy)		NSString			* query;
@property(readwrite,nonatomic,copy)		NSDictionary		* queryComponents;
@property(readonly,nonatomic,copy)		NSMutableDictionary * mutableQueryComponents;

@property(readwrite,nonatomic,strong)	NSData				* body;
@property(readwrite,nonatomic,strong)	NSInputStream		* bodyStream;
@property(readwrite,nonatomic,strong)	NSString			* HTTPMethodString;
@property(assign,nonatomic)		enum NDJSONHTTPMethod		HTTPMethod;

@property(assign,nonatomic)				NDJSONOptionFlags	deserializerOptions;

@end

@interface NDJSONResponse : NSObject

@property(readonly,nonatomic,getter=isSuccessful)	BOOL			successful;
@property(readonly,nonatomic,strong)				NDJSONRequest	* request;
@property(readonly,nonatomic,strong)				id				result;
@property(readonly,nonatomic,strong)				NSError			* error;

@end

@protocol NDJSONRequestDelegate <NSObject>

- (void)jsonRequest:(NDJSONRequest *)request response:(NDJSONResponse *)response;

@end