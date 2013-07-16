/*
	NDJSONRequest.m
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

#import "NDJSONRequest.h"
#import "NDJSONParser.h"
#import "NDJSONDeserializer.h"

const NSUInteger				kNDJSONDefaultPortNumber = NSNotFound;

static const NSTimeInterval		kNDJSONDefaultTimeoutInterval = 60.0;
static NSString					* const kNDJSONDefaultScheme = @"http";
static const NSUInteger			kNDJSONDefaultPort = NSUIntegerMax;			// use NDURLRequests default

static NSString		* const kHTTPMethodStrings[] = { nil, @"GET", @"HEAD", @"POST", @"PUT", @"DELETE", @"TRACE", @"OPTIONS", @"CONNECT", @"PATCH" };				// must match enum NDJSONHTTPMethod

#pragma mark - NDJSONRequest
@interface NDJSONRequest ()
{
@protected
	NDJSONDeserializer		* __strong _deserializer;
	NDJSONOptionFlags		_deserializerOptions;
//	NSInvocation			* __strong _invocation;
}

//@property(nonatomic,strong)	NSInvocation	* invocation;

@end

@interface NDJSONResponse ()
{
	NDJSONRequest	* __strong _request;
	id				__strong _result;
	NSError			* __strong _error;
	void (__strong ^_responseCompletionHandler)(NDJSONRequest *, NDJSONResponse *);
}

@property(readwrite,nonatomic,strong)				id				result;
@property(readwrite,nonatomic,strong)				NSError			* error;
@property(copy,nonatomic)	void (^responseCompletionHandler)(NDJSONRequest *, NDJSONResponse *);

- (id)initWithRequest:(NDJSONRequest *)request;
- (void)loadAsynchronousWithQueue:(NSOperationQueue *)queue completionHandler:(void (^)(NDJSONRequest *,NDJSONResponse*))block;
- (void)loadAsynchronousWithQueue:(NSOperationQueue *)queue invocation:(NSInvocation *)invocation;

@end

@implementation NDJSONRequest

@synthesize		deserializer = _deserializer,
				deserializerOptions = _deserializerOptions;
//				invocation = _invocation;

- (NSURLRequest *)URLRequest
{
	NSMutableURLRequest		* theResult = [NSMutableURLRequest requestWithURL:self.URL];
	if( self.bodyStream != nil )
		[theResult setHTTPBodyStream:self.bodyStream];
	else if( self.body != nil )
		[theResult setHTTPBody:self.body];

	[theResult setHTTPMethod:self.HTTPMethodString];
	return theResult;
}

- (NSURL *)URL
{
	NSURL				* theResult = nil;
	NSMutableString		* theURLString = [[NSMutableString alloc] initWithFormat:@"%@://",self.scheme];
	NSString			* theUserInfo = self.userInfo,
						* theHost = self.host,
						* thePath = self.path,
						* theQuery = self.query;
	NSNumber			* thePort = self.port;
	if( theUserInfo.length > 0 )
		[theURLString appendFormat:@"%@@", theUserInfo];
	if( theHost.length > 0 )
		[theURLString appendFormat:@"%@", theHost];
	if( thePort != nil )
		[theURLString appendFormat:@":%@", [thePort stringValue]];
	if( thePath.length > 0 )
		[theURLString appendFormat:@"/%@", thePath];
	if( theQuery.length > 0 )
		[theURLString appendFormat:@"?%@", theQuery];
	theResult = [NSURL URLWithString:theURLString];
#if !__has_feature(objc_arc)
	[theURLString release];
#endif
	return theResult;
}

- (NSString *)scheme { return kNDJSONDefaultScheme; }

- (NSString *)userInfo
{
	NSString	* theResult = nil;
	NSString	* theUser = self.user,
				* thePassword = self.password;
	if( theUser.length > 0 && thePassword.length > 0 )
		theResult = [NSString stringWithFormat:@"%@:%@", theUser, thePassword];
	else if( theUser.length > 0 )
		theResult = theUser;
	else if( thePassword.length > 0 )
		theResult = thePassword;
	return theResult;
}

- (NSString *)user { return nil; }
- (NSString *)password { return nil; }
- (NSNumber *)port { return nil; }
- (NSString *)host { return nil; }
- (NSArray *)pathComponents { return nil; }

- (NSString *)path
{
	NSMutableString		* theResult = nil;
	for( NSString * theComponent in self.pathComponents )
	{
		if( ![theComponent isEqualToString:@"/"] )
		{
			if( theResult == nil )
				theResult = [NSMutableString stringWithFormat:@"%@", theComponent];
			else
				[theResult appendFormat:@"/%@",theComponent];
		}
	}
	return theResult;
}

- (NSString *)query
{
	__block NSMutableString		* theResult = nil;
	[self.queryComponents enumerateKeysAndObjectsUsingBlock:^(NSString * aKey, id aValue, BOOL * aStop)
	{
		if( theResult == nil )
			theResult = [NSMutableString stringWithFormat:@"%@=%@", aKey, aValue];
		else
			[theResult appendFormat:@"&%@=%@", aKey, aValue];
	}];
	return theResult;
}

- (NSDictionary *)queryComponents { return nil; }
- (NSData *)body { return nil; }
- (NSInputStream *)bodyStream { return nil; }
- (NSString *)HTTPMethodString
{
	enum NDJSONHTTPMethod	theMethod = self.HTTPMethod;
	if( theMethod == NDJSONHTTPMethodDefault )
		theMethod = ( self.body != nil || self.bodyStream != nil ) ? NDJSONHTTPMethodPost : NDJSONHTTPMethodGet;
	return kHTTPMethodStrings[theMethod];
}
- (enum NDJSONHTTPMethod)HTTPMethod { return NDJSONHTTPMethodDefault; }

- (id)initWithDeserializer:(NDJSONDeserializer *)aDeserializer
{
	return [self initWithDeserializer:aDeserializer deserializerOptions:NDJSONOptionIgnoreUnknownProperties|NDJSONOptionConvertKeysToMedialCapitals];
}
- (id)initWithDeserializer:(NDJSONDeserializer *)aDeserializer deserializerOptions:(NDJSONOptionFlags)anOptions
{
	if( (self = [super init]) != nil )
	{
#if __has_feature(objc_arc)
		_deserializer = aDeserializer;
#else
		_deserializer = [aDeserializer retain];
#endif
		_deserializerOptions = anOptions;
	}
	return self;
}

#if !__has_feature(objc_arc)
- (void)dealloc
{
	[_deserializer release];
//	[_invocation release];
	[super dealloc];
}
#endif

- (void)sendAsynchronousWithQueue:(NSOperationQueue *)aQueue responseCompletionHandler:(void (^)(NDJSONRequest *, NDJSONResponse *))aHandler
{
	NDJSONResponse			* theResponse = [[NDJSONResponse alloc] initWithRequest:self];
	[theResponse loadAsynchronousWithQueue:aQueue completionHandler:aHandler];
}

- (void)sendAsynchronousWithQueue:(NSOperationQueue *)aQueue responseHandler:(id<NDJSONRequestDelegate>)aHandler
{
	NSParameterAssert([aHandler isKindOfClass:[NSObject class]]);
	NDJSONResponse			* theResponse = [[NDJSONResponse alloc] initWithRequest:self];
	SEL						theSelector = @selector(jsonRequest:response:);
	NSInvocation			* theInvocation = [NSInvocation invocationWithMethodSignature:[(NSObject*)aHandler methodSignatureForSelector:theSelector]];
	theInvocation.selector = theSelector;
	theInvocation.target = aHandler;
	[theResponse loadAsynchronousWithQueue:aQueue invocation:theInvocation];
}

- (void)sendAsynchronousWithQueue:(NSOperationQueue *)aQueue responseHandlingSelector:(SEL)aResponseHandlingSelector handler:(id)aHandler
{
	NDJSONResponse			* theResponse = [[NDJSONResponse alloc] initWithRequest:self];
	NSInvocation			* theInvocation = [NSInvocation invocationWithMethodSignature:[aHandler methodSignatureForSelector:aResponseHandlingSelector]];
	theInvocation.selector = aResponseHandlingSelector;
	theInvocation.target = aHandler;
	[theResponse loadAsynchronousWithQueue:aQueue invocation:theInvocation];
}

- (void)sendAsynchronousWithQueue:(NSOperationQueue *)aQueue invocation:(NSInvocation *)anInvocation
{
	NDJSONResponse			* theResponse = [[NDJSONResponse alloc] initWithRequest:self];
	[theResponse loadAsynchronousWithQueue:aQueue invocation:anInvocation];
}

@end

#pragma mark - NDJSONMutableRequest
@interface NDJSONMutableRequest ()
{
	NSString			* __strong _scheme;
	NSString			* __strong _user;
	NSString			* __strong _password;
	NSNumber			* __strong _port;
	NSString			* __strong _host;
	NSArray				* __strong _pathComponents;
	NSString			* __strong _query;
	NSMutableDictionary	* __strong _queryComponents;

	NSData				* __strong _body;
	NSInputStream		* __strong _bodyStream;
	NSString			* __strong _HTTPMethodString;
	enum NDJSONHTTPMethod		_HTTPMethod;
}

@end

@implementation NDJSONMutableRequest

@synthesize		scheme = _scheme,
				user = _user,
				password = _password,
				port = _port,
				host = _host,
				pathComponents = _pathComponents,
				query = _query,
				queryComponents = _queryComponents,
				body = _body,
				bodyStream = _bodyStream,
				HTTPMethodString = _HTTPMethodString,
				HTTPMethod = _HTTPMethod;

- (void)setURL:(NSURL *)aURL
{
	self.scheme = aURL.scheme;
	self.host = aURL.host;
	self.port = aURL.port;
	self.user = aURL.user;
	self.password = aURL.password;
	self.pathComponents = aURL.pathComponents;
	self.query = aURL.query;
}

- (NSString *)HTTPMethodString { return _HTTPMethodString != nil ? _HTTPMethodString : [super HTTPMethodString]; }

- (void)setQueryComponents:(NSDictionary *)aQueryComponents { _queryComponents = [aQueryComponents mutableCopy]; }
- (NSString *)query { return _query != nil ? _query : [super query]; }

- (NSMutableDictionary *)mutableQueryComponents
{
	if( _queryComponents == nil )
		_queryComponents = [[NSMutableDictionary alloc] init];
	return _queryComponents;
}

@end

@implementation NDJSONResponse

@synthesize			request = _request,
					result = _result,
					error = _error,
					responseCompletionHandler = _responseCompletionHandler;

- (BOOL)isSuccessful { return _error != nil; }

- (id)initWithRequest:(NDJSONRequest *)aRequest
{
	if( (self = [super init]) != nil )
	{
#if __has_feature(objc_arc)
		_request = aRequest;
#else
		_request = [aRequest retain];
#endif
	}
	return self;
}

#if !__has_feature(objc_arc)
- (void)dealloc
{
	[_request release];
	[_result release];
	[_error release];
	[_responseCompletionHandler release];
	[super dealloc];
}
#endif

- (void)loadAsynchronousWithQueue:(NSOperationQueue *)aQueue completionHandler:(void (^)(NDJSONRequest *,NDJSONResponse*))aBlock
{
	self.responseCompletionHandler = aBlock;
	[NSURLConnection sendAsynchronousRequest:self.request.URLRequest queue:aQueue completionHandler:^(NSURLResponse * aResponse, NSData * aData, NSError * anError)
	 {
		 if( aData != nil )
		 {
			 NDJSONParser				* theParser = [[NDJSONParser alloc] initWithJSONData:aData encoding:NSUTF8StringEncoding];
			 NSError					* theError = nil;

			 self.result = [self.request.deserializer objectForJSON:theParser options:self.request.deserializerOptions error:&theError];
			 self.error = theError;
#if !__has_feature(objc_arc)
			 [theParser release];
#endif
		 }
		 else
			 self.error = anError;

		 if( self.responseCompletionHandler )
			 self.responseCompletionHandler( self.request, self );
	 }];
}

- (void)loadAsynchronousWithQueue:(NSOperationQueue *)aQueue invocation:(NSInvocation *)anInvocation
{
	NDJSONRequest		* theRequest = self.request;
	[anInvocation retainArguments];
	[anInvocation setArgument:(void*)&theRequest atIndex:2];
#if !__has_feature(objc_arc)
	[anInvocation retain];
#endif
	[NSURLConnection sendAsynchronousRequest:self.request.URLRequest queue:aQueue completionHandler:^(NSURLResponse * aResponse, NSData * aData, NSError * anError)
	 {
		 NDJSONResponse				* theJSONResponse = self;
		 NDJSONParser				* theParser = [[NDJSONParser alloc] initWithJSONData:aData encoding:NSUTF8StringEncoding];
		 NSError					* theError = nil;

		 self.result = [self.request.deserializer objectForJSON:theParser options:self.request.deserializerOptions error:&theError];
		 self.error = theError;

#ifndef NDJSON_SUPPRESS_ALL_LOGING
		 if( self.result == nil )
			 NSLog( @"Failed to result for URLRequest=%@", self.request.URL );
		 else if( self.error != nil )
			 NSLog( @"Error with result for URLRequest=%@", self.request.URL );
#endif

		 [anInvocation setArgument:&theJSONResponse atIndex:3];
		 [anInvocation retainArguments];
		 [anInvocation invoke];
#if !__has_feature(objc_arc)
		 [anInvocation release];
		 [theParser release];
#endif
	 }];
}

@end

