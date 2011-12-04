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

@property(readonly)	struct NDJSONContext	* parserContext;
@property(readonly)		NDJSONContainer		currentContainer;

@end

#pragma mark - cluster class NDJSON private implementation
@implementation NDJSON

@synthesize		delegate;

#pragma mark - manually implemented properties

- (struct NDJSONContext	*)parserContext { return &parserContext; }
- (NDJSONContainer)currentContainer { return currentContainer(&parserContext); }

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

- (BOOL)parseJSONString:(NSString *)aString error:(__autoreleasing NSError **)aError
{
	BOOL			theResult = NO;
	NSAssert( aString != nil, @"nil input JSON string" );
	if( contextWithNullTermiantedString( self.parserContext, self, [aString UTF8String], self.delegate ) )
	{
		theResult = beginParsing( self.parserContext );
		freeContext( self.parserContext );
	}
	return theResult;
}

- (BOOL)parseContentsOfFile:(NSString *)aPath error:(__autoreleasing NSError **)aError
{
	BOOL			theResult = NO;
	NSAssert( aPath != nil, @"nil input JSON path" );
	NSInputStream		* theInputStream = [NSInputStream inputStreamWithFileAtPath:aPath];
	if( theInputStream != nil )
		theResult = [self parseInputStream:theInputStream error:aError];
	return theResult;
}

- (BOOL)parseContentsOfURL:(NSURL *)aURL error:(__autoreleasing NSError **)aError
{
	BOOL			theResult = NO;
	NSAssert( aURL != nil, @"nil input JSON file url" );
	NSInputStream		* theInputStream = [NSInputStream inputStreamWithURL:aURL];
	if( theInputStream != nil )
		theResult = [self parseInputStream:theInputStream error:aError];
	return theResult;
}

- (BOOL)parseContentsOfURLRequest:(NSURLRequest *)aURLRequest error:(__autoreleasing NSError **)anError
{
	BOOL			theResult = NO;
	CFHTTPMessageRef	theMessageRef = CFHTTPMessageCreateRequest( kCFAllocatorDefault, (__bridge CFStringRef)aURLRequest.HTTPMethod, (__bridge CFURLRef)aURLRequest.URL, kCFHTTPVersion1_1 );
	if ( theMessageRef != NULL )
	{
		CFReadStreamRef		theReadStreamRef = CFReadStreamCreateForHTTPRequest( kCFAllocatorDefault, theMessageRef );
		theResult = [self parseInputStream:(__bridge NSInputStream*)theReadStreamRef error:anError];
		CFRelease(theReadStreamRef);
		CFRelease(theMessageRef);
	}
	return theResult;
}

- (BOOL)parseInputStream:(NSInputStream *)aStream error:(__autoreleasing NSError **)aError
{
	BOOL			theResult = NO;
	NSAssert( aStream != nil, @"nil input stream" );
	if( contextWithInputStream( self.parserContext, self, aStream, self.delegate ) )
	{
		theResult = beginParsing( self.parserContext );
		freeContext( self.parserContext );
	}
	return theResult;
}

@end

