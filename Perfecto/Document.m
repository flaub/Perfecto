//
//  Document.m
//  edit2
//
//  Created by fried on 5/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import "Document.h"
#include "ColoringBridge.h"

@interface Document (Private)

- (void) setContents: (NSString*) str;
- (void) setName: (NSString*) str;
- (void) setPath: (NSString*) str;
- (void) refreshName;
- (void) parseSyntax;

@end

@implementation Document

NSParagraphStyle* s_defaultStyle;
NSDictionary* s_defaultAttributes;
int s_counter = 1;

- (NSMenuItem*) menuItem { return m_menuItem; }
- (void) setMenuItem: (NSMenuItem*) value { m_menuItem = value; }
- (MyTextView*) textView { return m_textView; }
- (void) setTextView: (MyTextView*) value { m_textView = value; }

- (NSString*) name { return m_name; }
- (NSString*) title { return m_title; }
- (void) setTitle: (NSString*) value { m_title = value; }
- (NSString*) path { return m_path; }
- (NSTextStorage*) contents { return m_contents; } 
- (BOOL) isEdited { return m_isDirty; }

- (void) setIsEdited: (BOOL) value 
{ 
	if(value != m_isDirty)
	{
		m_isDirty = value; 
		[self refreshName];
	}
}

- (void) refreshName
{
	NSString* str = [NSString stringWithFormat:@"%@%@", m_name, m_isDirty ? @"*" : @""];
	[self setTitle: str]; // for KVO
}

- (void) setName: (NSString*) value
{
	[value retain];
	[m_name release];
	m_name = value;
	[self refreshName];
}

- (void) setPath: (NSString*) value
{
	[value retain];
	[m_path release];
	m_path = value;
	[self setName: [m_path lastPathComponent]];
}

- (id) delegate { return m_delegate; }
- (void) setDelegate: (id) value { m_delegate = value; }

- (void) setContents: (NSString*) str
{
	[str retain];
	[m_original release];
	m_original = str;
	m_contents = [[NSTextStorage alloc] initWithString: str
											attributes: [Document defaultAttributes]];
	[m_contents setDelegate: self];
	[self setIsEdited: NO];
}

- (NSImage*) icon { return m_icon; }

- (void) setIcon:(NSImage*) icon 
{
	m_icon = [icon copy];
	[m_icon setSize: NSMakeSize(16, 16)];
}

- (NSString*) iconName { return m_iconName; }

- (void) setIconName: (NSString*) iconName 
{ 
	[iconName retain];
	[m_iconName release];
	m_iconName = iconName; 
}

- (id) init
{
	self = [super init];
	if(self)
	{
		[self setName: [NSString stringWithFormat:@"Untitled - %d", s_counter++]];
		[self setContents: @" "];
	}		
	return self;
}

- (id) initWithPath: (NSString*) path
{
	self = [super init];
	if(self)
	{
		[self setPath: path];
		[self load];
	}
	return self;
}

- (void) saveAs: (NSString*) path
{
	[self setPath: path];
	[self save];
}

- (void) save
{
	NSString* str = [m_contents string];
	NSError* error = nil;
	[str writeToFile: m_path
		  atomically: YES
			encoding: NSUTF8StringEncoding
			   error: &error];

	[str retain];
	[m_original release];
	m_original = str;
	[self setIsEdited: NO];
}

- (void) load 
{
	NSFileWrapper* file = [[NSFileWrapper alloc] initWithPath: m_path];
	[self setIcon: [file icon]];
	[file release];
	
	NSString* str = [[NSString alloc] initWithContentsOfFile: m_path];
	[self setContents: str];
}

- (void) revert
{
	if(m_path)
		[self load];
	else
		[self setContents: @""];
}

+ (NSParagraphStyle*) defaultStyle
{
	if(!s_defaultStyle)
	{
		float size = 10.0f;
		NSFont* font = [NSFont fontWithName: @"Monaco" size: size];
		NSSize fontSize = [font advancementForGlyph: [font glyphWithName:@" "]];
		float width = fontSize.width * 4.0f;

		NSMutableParagraphStyle* ps = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		NSArray* tabs = [[NSArray alloc] init];
		[ps setTabStops:tabs];
		[ps setDefaultTabInterval: width];
		s_defaultStyle = ps;
	}
	return s_defaultStyle;
}

+ (NSDictionary*) defaultAttributes
{
	if(!s_defaultAttributes)
	{	
		float size = 10.0f;
		NSFont* font = [NSFont fontWithName:@"Monaco" size:size];
		
		NSArray* keys = [NSArray arrayWithObjects:
						 NSForegroundColorAttributeName, 
						 NSFontAttributeName, 
						 NSParagraphStyleAttributeName, 
						 NSKernAttributeName,
						 nil];
		NSArray* objects = [NSArray arrayWithObjects:
							[NSColor whiteColor], 
							font, 
							[self defaultStyle], 
							[NSNumber numberWithFloat:0.0],
							nil];
		s_defaultAttributes = [[NSDictionary alloc] initWithObjects:objects forKeys:keys];
	}
	return s_defaultAttributes;
}

#pragma mark -
#pragma mark TextStorage delegate

- (void) textStorageDidProcessEditing: (NSNotification*) aNotification
{
	NSString* cur = [m_contents string];
	BOOL isEqual = [cur isEqualToString: m_original];
	[self setIsEdited: !isEqual];
}

#pragma mark -
#pragma mark Syntax Highlighting

- (void) parseSyntax
{
	int pos = 0;
	NSString* preview = [m_contents string];
	if([preview length] > 500)
		preview = [preview substringToIndex: 500];
		
	NSString* text = [m_contents string];
	NSArray* lines = (NSArray*)parse_syntax([m_path UTF8String], 
											[preview UTF8String], 
											[text UTF8String], 
											"black");
	for(NSArray* line in lines)
	{
		CFArrayRef array = (CFArrayRef)line;
		int len = CFArrayGetCount(array);
		NSRange lineRange;
		[[m_textView layoutManager] lineFragmentRectForGlyphAtIndex: pos 
													 effectiveRange: &lineRange];
		
		for(int i = 0; i < len; i++)
		{
			SimpleLineRegion* region = (SimpleLineRegion*) CFArrayGetValueAtIndex(array, i);
			int len;
			if(region->end == -1)
				len = lineRange.length - region->start;
			else
				len = region->end - region->start;

			NSRange range = NSMakeRange(lineRange.location + region->start, len);
			if(range.length == 0)
				continue;
				
			int blue =  (region->foreground & 0x000000ff) >> (8 * 0);
			int green = (region->foreground & 0x0000ff00) >> (8 * 1);
			int red =   (region->foreground & 0x00ff0000) >> (8 * 2);
			NSColor* color = [NSColor colorWithDeviceRed: red / 255.0f 
												   green: green / 255.0f
													blue: blue / 255.0f
												   alpha: 1.0f];
			@try
			{
				if(NSLocationInRange(range.location, lineRange))
					[[m_textView layoutManager] addTemporaryAttribute: NSForegroundColorAttributeName 
																value: color 
													forCharacterRange: range];
			}
			@catch (NSException* e) 
			{
				NSLog(@"%@: %@ (%@) line: %@", [e name], [e reason], NSStringFromRange(range), NSStringFromRange(lineRange));
			}
		}
		pos += lineRange.length;
		[line release];
	}
	[lines release];
}

@end
