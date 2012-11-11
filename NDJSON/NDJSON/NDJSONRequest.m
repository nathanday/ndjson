/*
	NDJSONRequest.m
	NDJSON

	Created by Nathan Day on 3/11/12.
	Copyright (c) 2012 Nathan Day. All rights reserved.
 */

#import "NDJSONRequest.h"
#import "NDJSONParser.h"
#import "NDJSONDeserializer.h"

static const NSTimeInterval		kNDJSONDefaultTimeoutInterval = 60.0;
static NSString					* const kNDJSONDefaultScheme = @"http";
static const NSUInteger			kNDJSONDefaultPort = NSUIntegerMax;			// use NDURLRequests default

#pragma mark - NDJSONRequest
@interface NDJSONRequest ()
{
@protected
	NSURLRequest			* __strong _URLRequest;
	NSString				* __strong _rootJSONPath;
	NDJSONDeserializer		* __strong _deserializer;
}

@end

@implementation NDJSONRequest

@synthesize		requestURL = _requestURL,
				deserializer = _deserializer;

- (id)initWithURLRequest:(NSURLRequest *)aURLRequest rootJSONPath:(NSString *)aRootJSONPath deserializer:(NDJSONDeserializer *)aDeserializer
{
	if( (self = [super init]) != nil )
	{
		_URLRequest = [aURLRequest copy];
		_rootJSONPath = [aRootJSONPath copy];
#if __has_feature(objc_arc)
		_deserializer = aDeserializer;
#else
		_deserializer = [aDeserializer retain];
#endif
	}
	return self;
}

@end

#pragma mark - NDJSONMutableRequest
@interface NDJSONMutableRequest ()
{
}

@end

@implementation NDJSONMutableRequest

@end