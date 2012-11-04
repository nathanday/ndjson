/*
	NDJSONRequest.m
	NDJSON

	Created by Nathan Day on 3/11/12.
	Copyright (c) 2012 Nathan Day. All rights reserved.
 */

#import "NDJSONRequest.h"

static const NSTimeInterval		kNDJSONDefaultTimeoutInterval = 60.0;
static NSString					* const kNDJSONDefaultScheme = @"http";
static const NSUInteger			kNDJSONDefaultPort = NSUIntegerMax;			// use NDURLRequests default

#pragma mark - NDJSONRequest
@interface NDJSONRequest ()
{
@protected
	NSURLRequest	* __strong _URLRequest;
}

@end

@implementation NDJSONRequest

- (NSURLRequest *)requestURL
{
	if( _URLRequest == nil )
		_URLRequest = [NSURLRequest requestWithURL:self.URL cachePolicy:self.cachePolicy timeoutInterval:self.timeoutInterval];
	return _URLRequest;
}

- (NSURLRequestCachePolicy)cachePolicy { return NSURLRequestUseProtocolCachePolicy; }
- (NSTimeInterval)timeoutInterval { return kNDJSONDefaultTimeoutInterval; }

- (NSURL *)URL
{
	NSURL				* theURL = nil;
	NSMutableString		* theURLString = [[NSMutableString alloc] initWithFormat:@"%@://", self.scheme];
	NSString			* theQueryString = self.query;
	if( self.user.length > 0 )
	{
		[theURLString appendString:self.user];
		if( self.password.length > 0 )
			[theURLString appendFormat:@":%@",self.password];
		[theURLString appendString:@"@"];
	}
	[theURLString appendString:self.host];
	if( self.port <= 0xFFFF )
		[theURLString appendFormat:@":%lu", self.port];
	[theURLString appendFormat:@"/%@", self.path];
	
	if( theQueryString.length > 0 )
		[theURLString appendFormat:@"?%@", theQueryString];

	theURL = [NSURL URLWithString:theURLString];
#if !__has_feature(objc_arc)
	[theURLString release];
#endif
	return theURL;
}

- (NSString *)scheme { return kNDJSONDefaultScheme; }

- (NSString *)host { return nil; }
- (NSString *)user { return nil; }
- (NSString *)password { return nil; }
- (NSUInteger)port { return kNDJSONDefaultPort; }
- (NSString *)path { return [self.pathComponents componentsJoinedByString:@"/"]; }
- (NSArray *)pathComponents { return nil; }
- (NSString *)query
{
	__block NSMutableString		* theResult = nil;
	if( self.queryComponents.count > 0 )
	{
		[self.queryComponents enumerateKeysAndObjectsUsingBlock:^(NSString * aKey, NSString * aValue, BOOL * aStop)
		 {
			 NSParameterAssert([aKey isKindOfClass:[NSString class]]);
			 NSParameterAssert([aValue isKindOfClass:[NSString class]]);
			 if( theResult == nil )
				 theResult = [[NSMutableString alloc] initWithFormat:@"%@=%@", aKey, aValue];
			 else
				 [theResult appendFormat:@"&%@=%@", aKey, aValue];
		 }];
	}
	return theResult;
}
- (NSDictionary *)queryComponents { return nil; }

@end

#pragma mark - NDJSONMutableRequest
@interface NDJSONMutableRequest ()
{
}

@end

@implementation NDJSONMutableRequest

@end