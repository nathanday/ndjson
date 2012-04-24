//
//  NDJSONRequest.h
//  NDJSON
//
//  Created by Nathan Day on 17/04/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class NDJSONResponse;
@protocol NDJSONResponseHandler;

enum NDJSONRequestMethod
{
	NDJSONRequestMethodPOST,
	NDJSONRequestMethodGET
};

@interface NDJSONRequest : NSObject

@property(readonly,copy,nonatomic)		NSString					* scheme;
@property(readonly,copy,nonatomic)		NSString					* user;
@property(readonly,copy,nonatomic)		NSString					* host;
@property(readonly,assign,nonatomic)	NSUInteger					port;
@property(readonly,copy,nonatomic)		NSArray						* path;

@property(readonly,copy,nonatomic)		NSDictionary				* queryArguments;
@property(readonly,copy,nonatomic)		NSString					* query;

@property(readonly,copy,nonatomic)		NSURL						* URL;

@property(readonly,assign,nonatomic)	enum NDJSONRequestMethod	method;

@property(readonly,assign,nonatomic)	Class						rootObject;
@property(readonly,assign,nonatomic)	Class						rootCollection;

#if NS_BLOCKS_AVAILABLE
- (void)sendAsynchronousWithQueue:(NSOperationQueue *)queue completionHandler:(void (^)(NDJSONResponse *))block;
#endif

- (void)sendAsynchronousWithResponseHandler:(id<NDJSONResponseHandler>)target;
- (void)sendAsynchronousWithSelector:(SEL)selector target:(id)target;
- (void)sendAsynchronousWithInvocation:(NSInvocation *)invocation;

- (NDJSONResponse *)responseForSynchronousRequest;

@end

@interface NDJSONMutableRequest : NDJSONRequest

@property(readwrite,copy,nonatomic)		NSString			* schemeName;
@property(readwrite,copy,nonatomic)		NSString			* user;
@property(readwrite,copy,nonatomic)		NSString			* hostName;
@property(readwrite,assign,nonatomic)		NSUInteger			port;
@property(readwrite,copy,nonatomic)		NSArray				* path;

@property(readwrite,copy,nonatomic)		NSDictionary		* queryArguments;

@property(readwrite,copy,nonatomic)		NSURL				* URL;

@property(readwrite,assign,nonatomic)	enum NDJSONRequestMethod	method;

@property(readwrite,assign,nonatomic)	Class						rootObject;
@property(readwrite,assign,nonatomic)	Class						rootCollection;

@end

@interface NDJSONResponse : NSObject

@property(readonly,nonatomic)		id				result;
@property(readonly,nonatomic)		NSError			* error;
@property(readonly,nonatomic)		NDJSONRequest	* request;
@property(readonly,nonatomic)		BOOL			hasResult;
@property(readonly,nonatomic)		BOOL			hasError;

@end

@protocol NDJSONResponseHandler <NSObject>
- (void)request:(NDJSONRequest *)request response:(NDJSONResponse*)response;
@end
