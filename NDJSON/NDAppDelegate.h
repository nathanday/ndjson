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
	IBOutlet	NSWindow *window;
}

@property (assign) NSWindow			* window;


@end
