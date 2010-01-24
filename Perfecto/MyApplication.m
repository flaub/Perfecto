//
//  MyApplication.m
//  edit2
//
//  Created by fried on 5/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "MyApplication.h"
#import "AppController.h"

@implementation MyApplication

- (id)init
{
	self = [super init];
	return self;
}

- (AppController*) appContoller
{
	return [self delegate];
}

- (void) sendEvent: (NSEvent*) anEvent
{
	if([[self appContoller] onAppEvent: anEvent])
		return;
	[super sendEvent:anEvent];
}

- (void) addWindowsItem: (NSWindow*) aWindow title: (NSString*) aString filename: (BOOL) isFilename
{
}

- (void) changeWindowsItem: (NSWindow*) aWindow title: (NSString*) aString filename: (BOOL) isFilename
{
}

@end
