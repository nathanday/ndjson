//
//  TestRemoteRequest.m
//  NDJSON
//
//  Created by Nathan Day on 21/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestRemoteRequest.h"
#import "NDJSONToPropertyList.h"
#import "TestProtocolBase.h"

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

- (void)addName:(NSString *)aName URL:(NSURL *)aURL
{
	[self addTest:[RemoteRequest remoteRequestWithName:aName URL:aURL]];
}

- (void)willLoad
{
	for( NSUInteger i = 1; i <= 6; i++ )
	{
		NSString	* theTestName = [NSString stringWithFormat:@"File %u", i],
					* theURLString = [NSString stringWithFormat:@"http://homepage.mac.com/nathan_day/SampleJSONFiles/file%u.json", i];
		NSURL		* theURL = [NSURL URLWithString:theURLString];
		[self addName:theTestName URL:theURL];
	}
}

@end

@implementation RemoteRequest

@synthesize		url;

+ (id)remoteRequestWithName:(NSString *)aName URL:(NSURL *)aURL
{
	return [[[self alloc] initWithName:aName URL:aURL] autorelease];
}
- (id)initWithName:(NSString *)aName URL:(NSURL *)aURL
{
	if( (self = [super initWithName:aName]) != nil )
		url = [aURL retain];
	return self;
}

- (void)dealloc
{
    [url release];
    [super dealloc];
}

- (NSString *)details
{
	return [NSString stringWithFormat:@"Name:\n%@\n\nURL:\n%@\n\nresult:\n%@\n\n", self.name, self.url, self.lastResult];
}

- (id)run
{
	NSError							* theError = nil;
	NDJSONToPropertyList		* theJSON = [[NDJSONToPropertyList alloc] init];
	NSURLRequest					* theURLRequest = [[NSURLRequest alloc] initWithURL:self.url];

	self.lastResult = [theJSON propertyListForContentsOfURLRequest:theURLRequest error:&theError];
	self.error = theError;

	[theJSON release];
	[theURLRequest release];
	return lastResult;
}

@end