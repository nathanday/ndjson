//
//  JSONRoot+Utilities.m
//  NDJSON
//
//  Created by Nathan Day on 11/06/12.
//  Copyright (c) 2012 Nathan Day. All rights reserved.
//

#import "JSONRoot+Utilities.h"
#import "JSONRoot.h"
#import "JSONChildAlpha.h"
#import "JSONChildBeta.h"
#import "JSONChildGama.h"

static double magn( double a ) { return a >= 0 ? a : -a; }

static BOOL doesSetContain( NSSet * set, id obj )
{
	for( id setObj in set )
	{
		if( [setObj isReallyEqual:obj] )
			return YES;
	}
	return NO;
}

static BOOL areSetsEqual2( NSSet * setA, NSSet * setB )
{
	for( id setAObj in setA )
	{
		if( !doesSetContain( setB, setAObj) )
			return NO;
	}
	return YES;
}

@implementation JSONRoot (Utilities)

- (NSString *)description
{
	return [NSString stringWithFormat:@"integerValue: %d, stringValue: %@, alphaObject: {%@}, betaObject: %@",
			self.integerValue, self.stringValue, self.alphaObject, self.betaObject.allObjects];
}

- (BOOL)isReallyEqual:(id)obj
{
	JSONRoot		* o = obj;
	return [obj isKindOfClass:[JSONRoot class]]
			&& self.integerValue == o.integerValue
			&& [self.stringValue isEqualToString:o.stringValue]
			&& areSetsEqual2( self.betaObject, o.betaObject );
}


@end

/*
	isReallyEqual: is needed because isEqual seems to fail because NSManageObject does not seem to implement hash method.
 */

@implementation JSONChildAlpha (Utilities)

- (NSString *)description
{
	return [NSString stringWithFormat:@"booleanAlphaValue: %s, stringAlphaValue: %@", self.booleanAlphaValue ? "true" : "false", self.stringAlphaValue];
}

- (BOOL)isReallyEqual:(id)obj
{
	JSONChildAlpha		* o = obj;
	return [obj isKindOfClass:[JSONChildAlpha class]]
			&& self.booleanAlphaValue == o.booleanAlphaValue
			&& [self.stringAlphaValue isEqualToString:o.stringAlphaValue];
}

@end

@implementation JSONChildBeta (Utilities)

- (NSString *)description
{
	return [NSString stringWithFormat:@"floatBetaValue: %f, stringBetaValue: %@, subChildC: %@",
			self.floatBetaValue, self.stringBetaValue, self.subChildC];
}

- (BOOL)isReallyEqual:(id)obj
{
	JSONChildBeta		* o = obj;
	return [obj isKindOfClass:[JSONChildBeta class]]
			&& magn(self.floatBetaValue - o.floatBetaValue) < 0.0001
			&& [self.stringBetaValue isEqualToString:o.stringBetaValue]
			&& [self.subChildC isReallyEqual:o.subChildC];
}

@end

@implementation JSONChildGama (Utilities)

- (NSString *)description
{
	return [NSString stringWithFormat:@"stringGamaValue: %@", self.stringGamaValue];
}

- (BOOL)isReallyEqual:(id)obj
{
	JSONChildGama		* o = obj;
	return [obj isKindOfClass:[JSONChildGama class]]
			&& [self.stringGamaValue isEqualToString:o.stringGamaValue];
}

@end
