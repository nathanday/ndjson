//
//  TestFileInput.m
//  NDJSON
//
//  Created by Nathan Day on 18/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestFileInput.h"
#import "NDJSON.h"
#import "NDJSONPropertyListGenerator.h"
#import "TestProtocolBase.h"

@interface TestFileInput ()
- (void)addName:(NSString *)name fileName:(NSString *)path;

@end

@interface TestFile : TestProtocolBase
{
	NSString					* path;
}

@property(readonly)	NSString					* path;

+ (id)testFileWithName:(NSString *)aName fileName:(NSString *)aFileName;
- (id)initWithName:(NSString *)aName fileName:(NSString *)aFileName;

@end

@implementation TestFileInput


- (void)addName:(NSString *)aName fileName:(NSString *)aFileName
{
	[self addTest:[TestFile testFileWithName:aName fileName:aFileName]];
}

- (void)willLoad
{
	for( NSUInteger i = 1; i <= 6; i++ )
	{
		NSString	* theTestName = [NSString stringWithFormat:@"File %u", i],
					* theFileName = [NSString stringWithFormat:@"file%u", i];
		[self addName:theTestName fileName:theFileName];
	}
}

@end

@implementation TestFile

@synthesize path,
			expectedResult;

+ (id)testFileWithName:(NSString *)aName fileName:(NSString *)aFileName
{
	return [[[self alloc] initWithName:aName fileName:aFileName] autorelease];
}
- (id)initWithName:(NSString *)aName fileName:(NSString *)aFileName
{
	if( (self = [super initWithName:aName]) != nil )
	{
		NSString	* theExptectResultFilePath = [[NSBundle mainBundle] pathForResource:aFileName ofType:@"plist"];
		path = [[[NSBundle mainBundle] pathForResource:aFileName ofType:@"json"] retain];
		expectedResult = [[NSDictionary alloc] initWithContentsOfFile:theExptectResultFilePath];
	}
	return self;
}

- (void)dealloc
{
	[path release];
	[expectedResult release];
    [super dealloc];
}

#pragma mark - TestFileInput methods

- (NSString *)details
{
	NSError		* theError = nil;
	return [NSString stringWithFormat:@"path:\n%@\n\njson:\n%@\n\nresult:\n%@\n\nexpected result:\n%@\n\n", self.path, [NSString stringWithContentsOfFile:self.path encoding:NSUTF8StringEncoding error:&theError], self.lastResult, self.expectedResult];
}

- (id)run
{
	NSError		* theError = nil;
	NDJSONPropertyListGenerator		* theJSON = [[NDJSONPropertyListGenerator alloc] init];
	self.lastResult = [theJSON propertyListForContentsOfFile:self.path error:&theError];
	self.error = theError;
	[theJSON release];
	return lastResult;
}

@end
