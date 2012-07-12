//
//  NSObject+TestUtilities.h
//  NDJSON
//
//  Created by Nathan Day on 11/06/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import <Foundation/Foundation.h>

/*
 isLike: is needed because isEqual: does not mean what I want for NSManageObject, google for more technical reason.
 */

@interface NSObject (TestUtilities)

- (BOOL)isLike:(id)obj;
- (NSString *)detailedDescription;

@end


@interface NSSet (TestUtilities)

@end

@interface NSDictionary (TestUtilities)

@end

@interface NSArray (TestUtilities)

@end

@interface NSString (TestUtilities)

@end