//
//  JSONChildBeta.m
//  NDJSON
//
//  Created by Nathan Day on 11/06/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import "JSONChildBeta.h"
#import "JSONChildGama.h"
#import "JSONRoot.h"


@implementation JSONChildBeta

@dynamic floatBetaValue;
@dynamic stringBetaValue;
@dynamic parent;
@dynamic subChildC;

- (void)setSubChildCByConvertingString:(NSString *)aString
{
	self.subChildC = [NSEntityDescription insertNewObjectForEntityForName:@"ChildGama" inManagedObjectContext:self.managedObjectContext];
	self.subChildC.stringGamaValue = aString;
}

@end
