//
//  AppController.h
//  edit2
//
//  Created by fried on 5/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <PSMTabBarControl/PSMTabBarControl.h>
#import "Document.h"
#import "FileSystemItem.h"

@interface AppController : NSObject 
{
	IBOutlet NSWindow* window;
	IBOutlet NSTabView* m_tabView;
	IBOutlet PSMTabBarControl* tabBar;
	IBOutlet NSMenu* windowMenu;
	IBOutlet FileSystemView* fileView;
	IBOutlet NSTextField* m_status;
	IBOutlet NSTextField* m_position;
	NSMutableDictionary* m_documents;
	NSMutableArray* m_stack;
	Document* m_selectedDocument;
	
	BOOL isModifierPressed;
	BOOL isHotkeyPressed;
}

#pragma mark -
#pragma mark Accessors

- (NSFont*) defaultFont;
- (NSColor*) defaultTextColor;
- (Document*) selectedDocument;
- (void) setSelectedDocument: (Document*) value;

#pragma mark -
#pragma mark Actions

- (IBAction) onNewDocument: (id) sender;
- (IBAction) onOpenDocument: (id) sender;
- (IBAction) onOpenDirectory: (id) sender;
- (IBAction) onSaveDocument: (id) sender;
- (IBAction) onSaveAsDocument: (id) sender;
- (IBAction) onSaveAll: (id) sender;
- (IBAction) onCloseDocument: (id) sender;
- (IBAction) onCloseAllDocuments: (id) sender;
- (IBAction) onRevertDocument: (id) sender;
- (IBAction) onFind: (id) sender;
- (IBAction) onFindNext: (id) sender;
- (IBAction) onFindPrevious: (id) sender;
- (IBAction) onDeleteLine: (id) sender;
- (IBAction) onZoom: (id) sender;
- (IBAction) onMinimize: (id) sender;
- (void) onSelectWindow: (NSMenuItem*) sender;

#pragma mark -
#pragma mark Implementation

- (void) openDocument: (NSString*) path;
- (void) closeDocument: (Document*) doc;
- (BOOL) shouldCloseDocument: (Document*) doc;
- (BOOL) saveAsDocument: (Document*) doc;
- (BOOL) saveDocument: (Document*) doc;

#pragma mark -
#pragma mark Event Handling

- (BOOL) onAppEvent: (NSEvent*) event;
- (NSApplicationTerminateReply) applicationShouldTerminate: (NSApplication*) sender;

@end
