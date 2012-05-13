//
//  NDJSON.m
//  NDJSON
//
//  Created by Nathan Day on 31/08/11.
//  Copyright 2011 Nathan Day. All rights reserved.
//

#import "NDJSON.h"
#import "NDJSONCore.h"

#pragma mark - cluster class NDJSON private interface
@interface NDJSON ()
{
	__weak id<NDJSONDelegate>		delegate;
	struct NDJSONContext			parserContext;
}

@property(readonly)	struct NDJSONContext		* parserContext;
@property(readonly)		NDJSONContainerType		currentContainerType;

@end

#pragma mark - cluster class NDJSON private implementation
@implementation NDJSON

@synthesize		delegate;

#pragma mark - manually implemented properties

- (NSUInteger)position { return currentPosition(&parserContext); }

- (struct NDJSONContext	*)parserContext { return &parserContext; }
- (NDJSONContainerType)currentContainerType { return getCurrentContainerType(&parserContext); }

- (void)setDelegate:(id<NDJSONDelegate>)aDelegate
{
	delegate = aDelegate;
	setDelegateForContext( self.parserContext, self.delegate );
}

#pragma mark - creation and destruction etc

- (id)init
{
	return [self initWithDelegate:nil];
}

- (id)initWithDelegate:(id<NDJSONDelegate>)aDelegate
{
	if( (self = [super init]) != nil )
		delegate = aDelegate;

	return self;
}

#pragma mark - parsing methods

- (BOOL)parseJSONString:(NSString *)aString error:(NSError **)anError
{
	return [self setJSONString:aString error:anError] && [self parse];
}

- (BOOL)parseContentsOfFile:(NSString *)aPath error:(NSError **)anError
{
	return [self setContentsOfFile:aPath error:anError] && [self parse];
}

- (BOOL)parseContentsOfURL:(NSURL *)aURL error:(NSError **)anError
{
	return [self setContentsOfURL:aURL error:anError] && [self parse];
}

- (BOOL)parseContentsOfURLRequest:(NSURLRequest *)aURLRequest error:(NSError **)anError
{
	return [self setContentsOfURLRequest:aURLRequest error:anError] && [self parse];
}

- (BOOL)parseInputStream:(NSInputStream *)aStream error:(NSError **)anError
{
	return [self setInputStream:aStream error:anError] && [self parse];
}

- (BOOL)setJSONString:(NSString *)aString error:(__autoreleasing NSError **)anError
{
	NSAssert( aString != nil, @"nil input JSON string" );
	return contextWithNullTermiantedString( self.parserContext, self, [aString UTF8String], self.delegate );
}

- (BOOL)setContentsOfFile:(NSString *)aPath error:(__autoreleasing NSError **)anError
{
	BOOL			theResult = NO;
	NSAssert( aPath != nil, @"nil input JSON path" );
	NSInputStream		* theInputStream = [NSInputStream inputStreamWithFileAtPath:aPath];
	if( theInputStream != nil )
		theResult = [self setInputStream:theInputStream error:anError];
	return theResult;
}

- (BOOL)setContentsOfURL:(NSURL *)aURL error:(__autoreleasing NSError **)anError
{
	BOOL			theResult = NO;
	NSAssert( aURL != nil, @"nil input JSON file url" );
	NSInputStream		* theInputStream = [NSInputStream inputStreamWithURL:aURL];
	if( theInputStream != nil )
		theResult = [self setInputStream:theInputStream error:anError];
	return theResult;
}

- (BOOL)setContentsOfURLRequest:(NSURLRequest *)aURLRequest error:(__autoreleasing NSError **)anError
{
	BOOL			theResult = NO;
	CFHTTPMessageRef	theMessageRef = CFHTTPMessageCreateRequest( kCFAllocatorDefault, (CFStringRef)aURLRequest.HTTPMethod, (CFURLRef)aURLRequest.URL, kCFHTTPVersion1_1 );
	if ( theMessageRef != NULL )
	{
		CFReadStreamRef		theReadStreamRef = CFReadStreamCreateForHTTPRequest( kCFAllocatorDefault, theMessageRef );
		theResult = [self setInputStream:(NSInputStream*)theReadStreamRef error:anError];
		CFRelease(theReadStreamRef);
		CFRelease(theMessageRef);
	}
	return theResult;
}

- (BOOL)setInputStream:(NSInputStream *)aStream error:(__autoreleasing NSError **)anError
{
	NSAssert( aStream != nil, @"nil input stream" );
	return contextWithInputStream( self.parserContext, self, aStream, self.delegate );
}

- (BOOL)parse
{
	BOOL		theResult = NO;
	if( self.parserContext->inputStream != nil || self.parserContext->bytes != NULL )
		theResult = beginParsing( self.parserContext );
	freeContext( self.parserContext );
	return theResult;
}

@end

