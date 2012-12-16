/*
	NDJSONRequest.m
	NDJSON

	Created by Nathan Day on 3/11/12.
	Copyright (c) 2012 Nathan Day. All rights reserved.
 */

#import "NDJSONRequest.h"
#import "NDJSONParser.h"
#import "NDJSONDeserializer.h"

const NSUInteger				kNDJSONDefaultPortNumber = NSNotFound;

static const NSTimeInterval		kNDJSONDefaultTimeoutInterval = 60.0;
static NSString					* const kNDJSONDefaultScheme = @"http";
static const NSUInteger			kNDJSONDefaultPort = NSUIntegerMax;			// use NDURLRequests default

#pragma mark - NDJSONRequest
@interface NDJSONRequest ()
{
@protected
	NDJSONDeserializer		* __strong _deserializer;
	void (__strong ^_responseCompletionHandler)(NDJSONRequest *, NDJSONResponse *);
	NSInvocation			* __strong _invocation;
}

@property(readonly,nonatomic,strong)	void (^responseCompletionHandler)(NDJSONRequest *, NDJSONResponse *);
@property(readonly,nonatomic,strong)	NSInvocation	* invocation;

- (id)initWithDeserializer:(NDJSONDeserializer *)deserializer;

@end

@interface NDJSONResponse ()
{
	NDJSONRequest	* __strong request;
	id				__strong result;
	NSError			* __strong error;
}

@property(readwrite,nonatomic,strong)				id				result;
@property(readwrite,nonatomic,strong)				NSError			* error;

- (id)initWithRequest:(NDJSONRequest *)request;
- (void)loadAsynchronousWithQueue:(NSOperationQueue *)queue completionHandler:(void (^)(NDJSONRequest *,NDJSONResponse*))block;
- (void)loadAsynchronousWithQueue:(NSOperationQueue *)queue invocation:(NSInvocation *)invocation;

@end

@implementation NDJSONRequest

@synthesize		deserializer = _deserializer,
				invocation = _invocation,
				responseCompletionHandler = _responseCompletionHandler;

- (NSURLRequest *)URLRequest { return [NSURLRequest requestWithURL:self.URL]; }

- (NSURL *)URL
{
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
	return [NSURL URLWithString:theURLString];
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

- (NSArray *)pathComponents { return nil; }

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
- (NSString *)responseJSONRootPath { return nil; }
- (NSString *)errorJSONRootPath { return nil; }

- (id)initWithDeserializer:(NDJSONDeserializer *)aDeserializer
{
	if( (self = [super init]) != nil )
		_deserializer = aDeserializer;
	return self;
}

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
	[theResponse loadAsynchronousWithQueue:aQueue invocation:self.invocation];
}

- (void)sendAsynchronousWithQueue:(NSOperationQueue *)aQueue responseHandlingSelector:(SEL)aResponseHandlingSelector handler:(id)aHandler
{
	NDJSONResponse			* theResponse = [[NDJSONResponse alloc] initWithRequest:self];
	NSInvocation			* theInvocation = [NSInvocation invocationWithMethodSignature:[aHandler methodSignatureForSelector:aResponseHandlingSelector]];
	theInvocation.selector = aResponseHandlingSelector;
	theInvocation.target = aHandler;
	[theResponse loadAsynchronousWithQueue:aQueue invocation:self.invocation];
}

- (void)sendAsynchronousWithQueue:(NSOperationQueue *)aQueue invocation:(NSInvocation *)anInvocation
{
	NDJSONResponse			* theResponse = [[NDJSONResponse alloc] initWithRequest:self];
	[theResponse loadAsynchronousWithQueue:aQueue invocation:self.invocation];
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

	NSString			* __strong _responseJSONRootPath;
	NSString			* __strong _errorJSONRootPath;
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
				responseJSONRootPath = _responseJSONRootPath,
				errorJSONRootPath = _errorJSONRootPath;

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
					error = _error;

- (BOOL)isSuccessful { return _error != nil; }

- (id)initWithRequest:(NDJSONRequest *)aRequest
{
	if( (self = [super init]) != nil )
		_request = aRequest;
	return self;
}

- (void)loadAsynchronousWithQueue:(NSOperationQueue *)aQueue completionHandler:(void (^)(NDJSONRequest *,NDJSONResponse*))aBlock
{
	NSURLRequest		* theURLRequest = [[NSURLRequest alloc] initWithURL:self.request.URL];
	[NSURLConnection sendAsynchronousRequest:theURLRequest queue:aQueue completionHandler:^(NSURLResponse * aResponse, NSData * aData, NSError * anError)
	 {
		 NDJSONParser				* theParser = [[NDJSONParser alloc] initWithJSONData:aData encoding:NSUTF8StringEncoding];
		 NDJSONDeserializer			* theDeserializer = [[NDJSONDeserializer alloc] init]; // WithRootClass:self.request.rootClass];
		 NSError					* theError = nil;

		 self.result = [theDeserializer objectForJSON:theParser options:NDJSONOptionNone error:&theError];
		 self.error = theError;
		 if( aBlock )
			 aBlock( self.request, self );
	 }];
}

- (void)loadAsynchronousWithQueue:(NSOperationQueue *)aQueue invocation:(NSInvocation *)anInvocation
{
	NSURLRequest		* theURLRequest = [[NSURLRequest alloc] initWithURL:self.request.URL];
	[anInvocation retainArguments];
	[anInvocation setArgument:(void*)self.request atIndex:2];
	[NSURLConnection sendAsynchronousRequest:theURLRequest queue:aQueue completionHandler:^(NSURLResponse * aResponse, NSData * aData, NSError * anError)
	 {
		 NDJSONParser				* theParser = [[NDJSONParser alloc] initWithJSONData:aData encoding:NSUTF8StringEncoding];
		 NDJSONDeserializer			* theDeserializer = [[NDJSONDeserializer alloc] init]; // WithRootClass:self.request.rootClass];
		 NSError					* theError = nil;

		 self.result = [[theDeserializer objectForJSON:theParser options:NDJSONOptionNone error:&theError] valueForKeyPath:self.request.responseJSONRootPath];
		 self.error = theError;

		 [anInvocation setArgument:(void*)self atIndex:3];
		 [anInvocation retainArguments];
		 [anInvocation invoke];
	 }];
}

@end

