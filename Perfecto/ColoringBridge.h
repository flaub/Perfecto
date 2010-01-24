/*
 *  ColoringBridge.h
 *  Perfecto
 *
 *  Created by fried on 5/27/08.
 *  Copyright 2008 __MyCompanyName__. All rights reserved.
 *
 */

#include <CoreFoundation/CoreFoundation.h>

typedef struct _SimpleLineRegion
{
	int start;
	int end;
	int foreground;
	int background;
} SimpleLineRegion;

CFMutableArrayRef parse_syntax(const char* filename, const char* preview, const char* text, const char* style);
