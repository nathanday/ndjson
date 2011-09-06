//
//  NDAppDelegate.h
//  NDJSON
//
//  Created by Nathan Day on 5/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NDAppDelegate : NSObject <NSApplicationDelegate,NSOutlineViewDataSource,NSOutlineViewDelegate>
{
	IBOutlet	NSWindow	* window;
	IBOutlet	NSTextView	* logTextView;
	IBOutlet NSOutlineView	* testsOutlineView;
}

@property (assign) NSWindow			* window;

- (IBAction)clearLogs:(NSButton *)sender;
- (IBAction)runTests:(NSButton *)sender;
- (IBAction)checkAllTests:(NSButton *)sender;
- (IBAction)uncheckAllTests:(NSButton *)sender;

@end
