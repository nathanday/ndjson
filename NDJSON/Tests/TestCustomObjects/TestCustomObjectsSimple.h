//
//  TestCustomObjectsSimple.h
//  NDJSON
//
//  Created by Nathan Day on 22/04/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import "TestProtocolBase.h"

@interface TestCustomObjectsSimple : TestProtocolBase
{
	NSString	* jsonSourceString;
	Class		rootClass,
				rootCollectionClass;
}

+ (void)addTestsToTestGroup:(TestGroup *)testGroup;

+ (id)testCustomObjectsSimpleWithName:(NSString *)name
					 jsonSourceString:(NSString *)source
							rootClass:(Class)rootClass
				  rootCollectionClass:(Class)aRootCollectionClass;
- (id)initWithName:(NSString *)name jsonSourceString:(NSString *)source
										   rootClass:(Class)rootClass
								 rootCollectionClass:(Class)aRootCollectionClass;

@end
