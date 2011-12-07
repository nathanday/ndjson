//
//  NDJSONSelect.m
//  NDJSON
//
//  Created by Nathan Day on 6/12/11.
//  Copyright (c) 2011 Nathan Day. All rights reserved.
//

#import "NDJSONSelect.h"

@interface NDJSONSelect ()
{
	NSMutableDictionary		* blockForPath;
}

@property(readonly,nonatomic)		NSMutableDictionary		* blockForPath;

@end

@implementation NDJSONSelect

- (NSMutableDictionary *)blockForPath
{
	if( blockForPath == nil )
		blockForPath = [[NSMutableDictionary alloc] init];
	return blockForPath;
}

@end
