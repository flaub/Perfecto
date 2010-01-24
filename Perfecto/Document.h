//
//  Document.h
//  edit2
//
//  Created by fried on 5/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MyTextView.h"

@interface Document : NSObject 
{
	NSString* m_title;
	NSString* m_name;
	NSString* m_path;
	NSMenuItem* m_menuItem;
	NSTextStorage* m_contents;
	MyTextView* m_textView;
	NSString* m_original;
	BOOL m_isDirty;
	id m_delegate;

    NSImage* m_icon;
    NSString* m_iconName;
}

- (NSString*) title;
- (void) setTitle: (NSString*) value;
- (NSString*) name;
- (NSString*) path;
- (NSTextStorage*) contents;
- (NSMenuItem*) menuItem;
- (void) setMenuItem: (NSMenuItem*) value;
- (BOOL) isEdited;
- (void) setIsEdited: (BOOL) value;
- (id) delegate;
- (void) setDelegate: (id) value;
- (MyTextView*) textView;
- (void) setTextView: (MyTextView*) value;

- (NSImage*) icon;
- (void) setIcon: (NSImage*) icon;
- (NSString*) iconName;
- (void) setIconName: (NSString*) iconName;

+ (NSParagraphStyle*) defaultStyle;
+ (NSDictionary*) defaultAttributes;

- (id) init;
- (id) initWithPath: (NSString*) path;
- (void) saveAs: (NSString*) path;
- (void) save;
- (void) load;
- (void) revert;
- (void) parseSyntax;

@end
