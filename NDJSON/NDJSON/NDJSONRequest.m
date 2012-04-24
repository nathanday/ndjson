//
//  NDJSONRequest.m
//  NDJSON
//
//  Created by Nathan Day on 17/04/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import "NDJSONRequest.h"

@interface NDJSONRequest ()

@end

@implementation NDJSONRequest

@synthesize		rootObject,
				rootCollection;

#pragma mark - manually implemented properties

- (NSURL *)URL
{
	NSURL					* theResult = nil;
	NSMutableString			* theURLString = [[NSMutableString alloc] initWithFormat:@"%@://", self.scheme];
	if( self.user.length > 0 )
		[theURLString appendFormat:@"%@@", self.user];
	[theURLString appendString:self.host];
	if( self.port != NSUIntegerMax )
		[theURLString appendFormat:@":%lu", self.port];
	for( NSString * thePathComp in self.path )
		[theURLString appendFormat:@"/%@", thePathComp];
	if( self.query.length > 0 )
		[theURLString appendFormat:@"?%@", self.query];
	theResult = [NSURL URLWithString:theURLString];
	[theURLString release];
	return theResult;
}

- (NSString *)query
{
	NSMutableString			* theResult = nil;
	for( NSString * theKey in self.queryArguments )
	{
		NSString		* theValue = [self.queryArguments objectForKey:theKey];
		if( theResult == nil )
			theResult = [NSMutableString stringWithFormat:@"%@=%@", theKey, theValue];
		else
			[theResult appendFormat:@"&%@=%@", theKey, theValue];
	}
	return theResult;
}

#pragma mark - abstract properties

- (NSString *)scheme { return @"http"; }
- (NSString *)user { return nil; }
- (NSString *)host
{
	NSAssert( NO, @"The method %@ is abstract and needs to be overridden in the class %@", NSStringFromSelector(_cmd), NSStringFromClass([self class]) );
	return nil;
}
- (NSUInteger)port { return NSUIntegerMax; }
- (NSArray *)path { return nil; }
- (NSDictionary *)queryArguments { return nil; }

#if NS_BLOCKS_AVAILABLE
- (void)sendAsynchronousWithQueue:(NSOperationQueue *)aQueue completionHandler:(void (^)(NDJSONResponse *))aBlock
{
}

#endif

- (void)sendAsynchronousWithResponseHandler:(id<NDJSONResponseHandler>)aTarget
{
	NSParameterAssert( [aTarget respondsToSelector:@selector(request:response:)] );
	[self sendAsynchronousWithSelector:@selector(request:response:) target:aTarget];
}

- (void)sendAsynchronousWithSelector:(SEL)aSelector target:(id)aTarget
{
	NSMethodSignature	* theMethodSignature = [aTarget methodSignatureForSelector:aSelector];
	NSInvocation		* theInvocation = [NSInvocation invocationWithMethodSignature:theMethodSignature];
	NSAssert( theMethodSignature.numberOfArguments == 4, @"response handling method must take 2 arguemnts" );
	[theInvocation setArgument:self atIndex:2];
}

- (void)sendAsynchronousWithInvocation:(NSInvocation *)anInvocation { [NSThread detachNewThreadSelector:@selector(threadEntryAsynchronousWithInvocation:) toTarget:self withObject:anInvocation]; }

- (NDJSONResponse *)responseForSynchronousRequest
{
	return nil;
}

@end

@interface NDJSONResponse ()
{
	__strong NSInvocation		* invocation;
	__strong void (^block)(NDJSONResponse *);
	__strong NSOperationQueue	* operationQueue;
	__strong NDJSONRequest		* request;

	__strong id					result;
	__strong NSError			* error;

}
- (void)threadEntry:(id)result;
@end

@implementation NDJSONResponse

- (id)initWithRequest:(NDJSONRequest *)aRequest operationQueue:(NSOperationQueue *)aOperationQueue invocation:(NSInvocation *)aInvocation
{
	if( (self = [super init]) != nil )
	{
		request = [aRequest retain];
		operationQueue = [aOperationQueue retain];
		invocation = [aInvocation retain];
	}
	return self;
}

- (id)initWithRequest:(NDJSONRequest *)aRequest operationQueue:(NSOperationQueue *)aOperationQueue block:(void (^)(NDJSONResponse *))aBlock
{
	if( (self = [super init]) != nil )
	{
		request = [aRequest retain];
		operationQueue = [aOperationQueue retain];
		block = [aBlock copy];
	}
	return self;
}

- (void)threadEntry:(id)aResult
{
	@autoreleasepool
	{
		if( block != nil )
		{
			if( operationQueue != nil )
				[operationQueue addOperationWithBlock:^{block(self);}];
			else
				block(self);
		}
		else
		{
			[invocation setArgument:self atIndex:3];
			if( operationQueue != nil )
				[operationQueue addOperationWithBlock:^{[invocation invoke];}];
			else
				[invocation invoke];
		}
	}
}

@end
