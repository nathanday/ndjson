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
@private
	IBOutlet	NSWindow	* window;
	IBOutlet	NSTextView	* logTextView;
	IBOutlet NSOutlineView	* testsOutlineView;
	IBOutlet	NSButton	* runStopButton;
	IBOutlet	NSButton	* errorsOnlyCheckBoxButton;
}

@property (assign)		NSWindow	* window;
@property (readonly)	NSArray		* everyCheckedTest;
@property(nonatomic,assign,getter=isShowErrorsOnly)	BOOL	showErrorsOnly;

- (IBAction)clearLogs:(NSButton *)sender;
- (IBAction)runTests:(NSButton *)sender;
- (IBAction)checkAllTests:(NSButton *)sender;
- (IBAction)uncheckAllTests:(NSButton *)sender;
- (IBAction)errorsOnlyAction:(NSButton *)sender;

- (void)logMessage:(NSString *)message;

@end
