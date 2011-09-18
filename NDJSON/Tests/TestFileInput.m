//
//  TestFileInput.m
//  NDJSON
//
//  Created by Nathan Day on 18/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestFileInput.h"
#import "NDJSON.h"
#import "TestProtocolBase.h"

@interface TestFileInput ()
- (void)addName:(NSString *)name filePath:(NSString *)path;

@end

@interface TestFile : TestProtocolBase
{
	NSString					* path;
}

@property(readonly)	NSString					* path;

+ (id)testFileWithName:(NSString *)aName filePath:(NSString *)aPath;
- (id)initWithName:(NSString *)aName filePath:(NSString *)aPath;

@end

@implementation TestFileInput


- (void)addName:(NSString *)aName filePath:(NSString *)aPath
{
	[self addTest:[TestFile testFileWithName:aName filePath:aPath]];
}

- (void)willLoad
{
	for( NSUInteger i = 1; i <= 6; i++ )
	{
		
		NSString	* theFileName = [NSString stringWithFormat:@"file%u", i],
					* thePath = [[NSBundle mainBundle] pathForResource:theFileName ofType:@"json"];
		[self addName:theFileName filePath:thePath];
	}
}

@end

@implementation TestFile

@synthesize path;

+ (id)testFileWithName:(NSString *)aName filePath:(NSString *)aPath
{
	return [[[self alloc] initWithName:aName filePath:aPath] autorelease];
}
- (id)initWithName:(NSString *)aName filePath:(NSString *)aPath
{
	if( (self = [super initWithName:aName]) != nil )
		path = [aPath retain];
	return self;
}

- (void)dealloc
{
	[path release];
    [super dealloc];
}

#pragma mark - TestFileInput methods

- (NSString *)details
{
	NSError		* theError = nil;
	return [NSString stringWithFormat:@"path:\n%@\n\njson:\n%@\n\nresult:\n%@\n\n", self.path, [NSString stringWithContentsOfFile:self.path encoding:NSUTF8StringEncoding error:&theError], self.lastResult];
}

- (id)run
{
	NSError		* theError = nil;
	NDJSON		* theJSON = [[NDJSON alloc] init];
	self.lastResult = [theJSON asynchronousParseContentsOfFile:self.path error:&theError];
	self.error = theError;
	[theJSON release];
	return lastResult;
}

@end
