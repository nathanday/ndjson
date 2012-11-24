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

- (id)initWithDeserializer:(NDJSONDeserializer *)deserializer;

@end

@implementation NDJSONRequest

@synthesize		deserializer = _deserializer;

@synthesize			responseCompletionHandler = _responseCompletionHandler;

- (NSURLRequest *)URLRequest { return [NSURLRequest requestWithURL:self.URL]; }

- (NSURL *)URL
{
	NSMutableString		* theURLString = [[NSMutableString alloc] initWithFormat:@"%@://",self.scheme];
	NSString			* theUserInfo = self.userInfo,
						* thePath = self.path,
						* theQuery = self.query;
	if( theUserInfo.length > 0 )
		[theURLString appendFormat:@"%@@", theUserInfo];
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
	NSString	* theUserName = self.userName,
				* thePassword = self.password;
	if( theUserName.length > 0 && thePassword.length > 0 )
		theResult = [NSString stringWithFormat:@"%@:%@", theUserName, thePassword];
	else if( theUserName.length > 0 )
		theResult = theUserName;
	else if( thePassword.length > 0 )
		theResult = thePassword;
	return theResult;
}

- (NSString *)userName { return nil; }
- (NSString *)password { return nil; }
- (NSUInteger)port { return kNDJSONDefaultPortNumber; }
- (NSString *)domain { return nil; }
- (NSString *)path
{
	NSMutableString		* theResult = nil;
	for( NSString * theComponent in self.pathComponents )
	{
		if( theResult == nil )
			theResult = [NSMutableString stringWithFormat:@"%@", theComponent];
		else
			[theResult appendFormat:@"/%@",theComponent];
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
- (NSString *)responseJSONRootPath { return nil; }

- (id)initWithDeserializer:(NDJSONDeserializer *)aDeserializer
{
	if( (self = [super init]) != nil )
		_deserializer = aDeserializer;
	return self;
}

- (id)initWithDeserializer:(NDJSONDeserializer *)aDeserializer responseCompletionHandler:(void (^)(NDJSONRequest *, NDJSONResponse *))aHandler
{
	if( (self = [self initWithDeserializer:aDeserializer]) != nil )
		_responseCompletionHandler = [aHandler copy];
	return self;
}

- (id)initWithDeserializer:(NDJSONDeserializer *)aDeserializer responseHandler:(id<NDJSONRequestDelegate>)aHandler
{
	
}

- (id)initWithDeserializer:(NDJSONDeserializer *)aDeserializer responseHandlingSelector:(SEL)aResponseHandlingSelector handler:(id)aHandler
{

}

- (id)initWithDeserializer:(NDJSONDeserializer *)aDeserializer invocation:(NSInvocation *)anInvocation
{
	
}

@end

#pragma mark - NDJSONMutableRequest
@interface NDJSONMutableRequest ()
{
}

@end

@implementation NDJSONMutableRequest

@end