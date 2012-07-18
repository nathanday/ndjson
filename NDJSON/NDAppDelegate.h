//
//  NDAppDelegate.h
//  NDJSON
//
//  Created by Nathan Day on 5/09/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import <Cocoa/Cocoa.h>

void NDMessage( NSString *format, ... ) NS_FORMAT_FUNCTION(1,2);
void NDError( NSString *format, ... ) NS_FORMAT_FUNCTION(1,2);

@interface NDAppDelegate : NSObject <NSApplicationDelegate,NSOutlineViewDataSource,NSOutlineViewDelegate,NSSplitViewDelegate>
{
@private
	IBOutlet __weak				NSWindow		* window;
	IBOutlet __unsafe_unretained NSTextView		* logTextView;
	IBOutlet __weak NSOutlineView	* testsOutlineView;
	IBOutlet __weak NSButton		* runStopButton;
	IBOutlet __weak NSButton		* detailsButton;
	IBOutlet __weak NSButton		* showMessagesCheckBoxButton;
	IBOutlet __weak NSButton		* checkButton;
	IBOutlet __weak NSButton		* uncheckButton;
}

@property (weak)		NSWindow	* window;
@property (readonly)	NSArray		* everyCheckedTest;
@property(nonatomic,assign,getter=isShowMessages)	BOOL	showMessages;

- (void)resetAllTests;

- (IBAction)clearLogs:(NSButton *)sender;
- (IBAction)detailsForSelectedTest:(NSButton *)sender;
- (IBAction)runTests:(NSButton *)sender;
- (IBAction)checkAllTests:(NSButton *)sender;
- (IBAction)uncheckAllTests:(NSButton *)sender;
- (IBAction)clearAll:(id)sender;
- (IBAction)showMessagesAction:(NSButton *)sender;

@end
