//
//  TestFileInput.m
//  NDJSON
//
//  Created by Nathan Day on 18/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "TestFileInput.h"
#import "NDJSONParser.h"
#import "NDJSONDeserializer.h"
#import "TestProtocolBase.h"
#import "NSObject+TestUtilities.h"

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

- (NSString *)testDescription { return @"Test file input, this uses InputStream and therefore parses what is available."; }

- (void)addName:(NSString *)aName fileName:(NSString *)aFileName
{
	[self addTest:[TestFile testFileWithName:aName fileName:aFileName]];
}

- (void)willLoad
{
	for( NSUInteger i = 1; i <= 4; i++ )
	{
		NSString	* theTestName = [NSString stringWithFormat:@"File %lu", i],
					* theFileName = [NSString stringWithFormat:@"file%lu", i];
		[self addName:theTestName fileName:theFileName];
	}
}

@end

@implementation TestFile

@synthesize		path,
				expectedResult;

+ (id)testFileWithName:(NSString *)aName fileName:(NSString *)aFileName
{
	return [[self alloc] initWithName:aName fileName:aFileName];
}
- (id)initWithName:(NSString *)aName fileName:(NSString *)aFileName
{
	if( (self = [super initWithName:aName]) != nil )
	{
		NSString	* theExpectedResultFilePath = [[NSBundle mainBundle] pathForResource:aFileName ofType:@"plist"];
		path = [[NSBundle mainBundle] pathForResource:aFileName ofType:@"json"];
		expectedResult = [[NSDictionary alloc] initWithContentsOfFile:theExpectedResultFilePath];
	}
	return self;
}

#pragma mark - TestFileInput methods

- (NSString *)details
{
	NSError		* theError = nil;
	return [NSString stringWithFormat:@"path:\n%@\n\njson:\n%@\n\nresult:\n%@\n\nexpected result:\n%@\n\n", self.path, [NSString stringWithContentsOfFile:self.path encoding:NSUTF8StringEncoding error:&theError], [self.lastResult detailedDescription], [self.expectedResult detailedDescription]];
}

- (id)run
{
	NSError					* theError = nil;
	NDJSONParser			* theJSON = [[NDJSONParser alloc] init];
	NDJSONDeserializer		* theJSONToPropertyList = [[NDJSONDeserializer alloc] init];
	[theJSON setContentsOfFile:self.path encoding:NSUTF8StringEncoding];
	self.lastResult = [theJSONToPropertyList objectForJSON:theJSON options:NDJSONOptionNone error:&theError];
	self.error = theError;
	return lastResult;
}

@end
