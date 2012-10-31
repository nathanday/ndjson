//
//  TestRemoteRequest.m
//  NDJSON
//
//  Created by Nathan Day on 21/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestRemoteRequest.h"
#import "NDJSONDeserializer.h"
#import "TestProtocolBase.h"
#import "NSObject+TestUtilities.h"

@interface TestRemoteRequest ()

- (void)addName:(NSString *)name URL:(NSURL *)url;
- (void)willLoad;

@end

@interface RemoteRequest : TestProtocolBase
{
	NSURL		* url;
}
@property(readonly)		NSURL		* url;
+ (id)remoteRequestWithName:(NSString *)name URL:(NSURL *)url;
- (id)initWithName:(NSString *)name URL:(NSURL *)url;
@end

@implementation TestRemoteRequest

- (NSString *)testDescription { return @"Test remote input using NSURLRequest"; }

- (void)addName:(NSString *)aName URL:(NSURL *)aURL
{
	[self addTest:[RemoteRequest remoteRequestWithName:aName URL:aURL]];
}

- (void)willLoad
{
	for( NSUInteger i = 1; i <= 4; i++ )
	{
		NSString	* theTestName = [NSString stringWithFormat:@"File %lu", i],
					* theURLString = [NSString stringWithFormat:@"http://www.godofcocoa.com/SampleJSONFiles/file%lu.json", i];
		NSURL		* theURL = [NSURL URLWithString:theURLString];
		[self addName:theTestName URL:theURL];
	}
}

@end

@implementation RemoteRequest

@synthesize		url;

+ (id)remoteRequestWithName:(NSString *)aName URL:(NSURL *)aURL
{
	return [[self alloc] initWithName:aName URL:aURL];
}
- (id)initWithName:(NSString *)aName URL:(NSURL *)aURL
{
	if( (self = [super initWithName:aName]) != nil )
		url = [aURL copy];
	return self;
}

- (NSString *)details
{
	return [NSString stringWithFormat:@"Name:\n%@\n\nURL:\n%@\n\nresult:\n%@\n\n", self.name, self.url, [self.lastResult detailedDescription]];
}

- (id)run
{
	NSError					* theError = nil;
	NDJSON					* theJSON = [[NDJSON alloc] init];
	NDJSONDeserializer			* theJSONParser = [[NDJSONDeserializer alloc] init];
	NSURLRequest			* theURLRequest = [[NSURLRequest alloc] initWithURL:self.url];
	[theJSON setURLRequest:theURLRequest];
	self.lastResult = [theJSONParser objectForJSON:theJSON options:NDJSONOptionNone error:&theError];
	self.error = theError;

	return lastResult;
}

@end
