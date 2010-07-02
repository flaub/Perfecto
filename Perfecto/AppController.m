//
//  AppController.m
//  edit2
//
//  Created by fried on 5/17/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#include <Carbon/Carbon.h>
#import "AppController.h"
#import "Document.h"
#import "MyTextView.h"

#define HOTKEY kVK_Tab
#define MODIFIER_MASK NSControlKeyMask

@interface AppController (Private)

- (void) openDirectory: (NSString*) path;
- (void) addDocument: (Document*) doc;
- (void) makeTopDocument;
- (void) updatePosition;

@end

@implementation AppController

#pragma mark -
#pragma mark Accessors

- (Document*) selectedDocument { return m_selectedDocument; }
- (void) setSelectedDocument: (Document*) value
{
	if(m_selectedDocument == value)
		return;
	
	if(value)
	{
		Document* oldDoc = [self selectedDocument];
		if(oldDoc)
			[[oldDoc menuItem] setState: NSOffState];
	}
	m_selectedDocument = value;
	if(value)
	{
		[m_tabView selectTabViewItemWithIdentifier: value];
		[[value menuItem] setState: NSOnState];
		[self makeTopDocument];
		
		[window setTitle: [NSString stringWithFormat: @"Perfecto - %@", [value name]]];
	}
	else
	{
		[window setTitle: @"Perfecto"];
	}
	
	[self updatePosition];
}

- (NSFont*) defaultFont
{
	return [[Document defaultAttributes] objectForKey: NSFontAttributeName];
}

- (NSColor*) defaultTextColor
{
	return [[Document defaultAttributes] objectForKey: NSForegroundColorAttributeName];
}

#pragma mark -
#pragma mark ctor/dtor

- (id) init
{
	self = [super init];
	if(self)
	{
		m_stack = [[NSMutableArray alloc] init];	
		m_documents = [[NSMutableDictionary alloc] init];
	}
	return self;
}

- (void) awakeFromNib
{	
//	[self onNewDocument: self];
	[m_status setStringValue: @"Ready"];
	[self updatePosition];
	[tabBar setUseOverflowMenu: YES];
	[window performZoom: self]; 
	
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];	
	NSArray* files = [defaults stringArrayForKey: @"OpenFile"];
	if(files)
	{
		for(NSString* file in files)
		{
			[self openDocument: file];
		}
	}
	else
	{
		NSString* file = [defaults stringForKey: @"OpenFile"];
		if(file)
			[self openDocument: file];	
	}
}	

#pragma mark -
#pragma mark Actions

- (IBAction) onNewDocument: (id) sender
{
	Document* doc = [[Document alloc] init];
	[self addDocument: doc];
}

- (IBAction) onOpenDocument: (id) sender
{
	NSOpenPanel* panel = [NSOpenPanel openPanel]; 

	Document* doc = [self selectedDocument];
	if([doc path])
	{
		NSMutableArray* parts = [NSMutableArray arrayWithArray: [[doc path] pathComponents]];
		[parts removeLastObject];
		NSString* dir = [NSString pathWithComponents: parts];
		[panel setDirectory: dir];
	}
	
	int result = [panel runModal];
	if(result == NSOKButton)
	{
		NSArray* filenames = [panel filenames];
		NSString* path = [filenames objectAtIndex: 0];
		[self openDocument: path];
	}
}

- (IBAction) onOpenDirectory: (id) sender
{
	NSOpenPanel* panel = [NSOpenPanel openPanel]; 
	[panel setCanChooseDirectories: YES];
	[panel setCanChooseFiles: NO];
	
	Document* doc = [self selectedDocument];
	if([doc path])
	{
		NSMutableArray* parts = [NSMutableArray arrayWithArray: [[doc path] pathComponents]];
		[parts removeLastObject];
		NSString* dir = [NSString pathWithComponents: parts];
		[panel setDirectory: dir];
	}

	int result = [panel runModal];
	if(result == NSOKButton)
	{
		NSArray* filenames = [panel filenames];
		NSString* path = [filenames objectAtIndex: 0];
		[self openDirectory: path];
	}
}

- (IBAction) onSaveDocument: (id) sender
{
	Document* doc = [self selectedDocument];
	[self saveDocument: doc];
}

- (IBAction) onSaveAsDocument: (id) sender
{
	Document* doc = [self selectedDocument];
	[self saveAsDocument: doc];
}

- (IBAction) onCloseDocument: (id) sender
{
	Document* doc = [self selectedDocument];
	if([self shouldCloseDocument: doc])
		[self closeDocument: doc];
}

- (IBAction) onCloseAllDocuments: (id) sender
{
	while([m_stack count])
	{
		Document* doc = [m_stack objectAtIndex: 0];
		if(![self shouldCloseDocument: doc])
			return;
		[self closeDocument: doc];
	}
}

- (IBAction) onRevertDocument: (id) sender
{
	Document* doc = [self selectedDocument];
	[doc revert];
}

- (IBAction) onSaveAll: (id) sender
{
	for(Document* doc in m_stack)
	{
		[self saveDocument: doc];
	}
}

- (IBAction) onFind: (id) sender
{
	SEL selector = @selector(performFindPanelAction:);
	NSMenuItem* context = [[NSMenuItem alloc] init];
	NSResponder* responder = [window firstResponder];
	
	[context setTag: NSFindPanelActionSetFindString];
	[responder tryToPerform: selector with: context];

	[context setTag: NSFindPanelActionShowFindPanel];
	[responder tryToPerform: selector with: context];
}

- (IBAction) onFindNext: (id) sender
{
	NSMenuItem* context = [[NSMenuItem alloc] init];	
	[context setTag: NSFindPanelActionNext];
	[[window firstResponder] tryToPerform: @selector(performFindPanelAction:) with: context];
}

- (IBAction) onFindPrevious: (id) sender
{
	NSMenuItem* context = [[NSMenuItem alloc] init];	
	[context setTag: NSFindPanelActionPrevious];
	[[window firstResponder] tryToPerform: @selector(performFindPanelAction:) with: context];
}

- (IBAction) onDeleteLine: (id) sender
{
	NSResponder* responder = [window firstResponder];
	if([responder respondsToSelector: @selector(selectLine:)] && 
	   [responder respondsToSelector: @selector(delete:)])
	{
		[responder performSelector: @selector(selectLine:) withObject: sender];
		[responder performSelector: @selector(delete:) withObject: sender];
	}
}

- (IBAction) onZoom: (id) sender
{
	return [window performZoom: sender];
}

- (IBAction) onMinimize: (id) sender
{
	return [window performMiniaturize: sender];
}

#pragma mark -
#pragma mark Document tab/stack switching

- (void) iterateSelectedDocument
{
	Document* doc = [self selectedDocument];
	int index = [m_stack indexOfObject: doc];
	++index;
	if(index >= [m_stack count])
		index = 0;
	Document* next = [m_stack objectAtIndex: index];
	[self setSelectedDocument: next];
}

- (void) makeTopDocument
{
	if(isModifierPressed)
		return;
	
	Document* selected = [self selectedDocument];
	[m_stack removeObject: selected];
	[m_stack insertObject: selected atIndex: 0];
}

- (BOOL) onKeyPressed: (NSEvent*) event
{
	if(isModifierPressed && [event keyCode] == HOTKEY)
	{
		isHotkeyPressed = YES;	
		[self iterateSelectedDocument];
		return YES;
	}
	return NO;
}

- (BOOL) onFlagsChanged: (NSEvent*) event
{
	if([event modifierFlags] & MODIFIER_MASK)
	{
		isModifierPressed = YES;
		return YES;
	}
	if(isModifierPressed && (([event modifierFlags] & MODIFIER_MASK) == 0))
	{
		isModifierPressed = NO;
		if(isHotkeyPressed)
		{
			isHotkeyPressed = NO;
			[self makeTopDocument];
		}
		return YES;
	}
	return NO;
}

- (BOOL) onAppEvent: (NSEvent*) event
{
	switch ([event type])
	{
		case NSKeyDown:
			return [self onKeyPressed: event];
		case NSFlagsChanged:
			return [self onFlagsChanged: event];
		default:
			return NO;
	}
}

#pragma mark -
#pragma mark PSMTabBarControl delegate

- (void) tabView: (NSTabView*) tabView didSelectTabViewItem: (NSTabViewItem*) tabViewItem
{
	[self setSelectedDocument: [tabViewItem identifier]];
}

- (BOOL) tabView: (NSTabView*) tabView shouldCloseTabViewItem: (NSTabViewItem*) tabViewItem
{
	Document* doc = [tabViewItem identifier];
	return [self shouldCloseDocument: doc];
}

- (void) tabView: (NSTabView*) tabView didCloseTabViewItem: (NSTabViewItem*) tabViewItem
{
	Document* doc = [tabViewItem identifier];
	[self closeDocument: doc];
}

#pragma mark -
#pragma mark NSTextView delegate

- (void) textViewDidChangeSelection: (NSNotification*) aNotification
{
	[self updatePosition];
}

#pragma mark -
#pragma mark NSApplication delegate

- (void) applicationDidFinishLaunching: (NSNotification*) aNotification
{
}

- (NSApplicationTerminateReply) applicationShouldTerminate: (NSApplication*) sender
{
	for(Document* doc in m_stack)
	{
		if(![self shouldCloseDocument: doc])
			return NSTerminateCancel;
	}
	return NSTerminateNow;
}

- (BOOL) application: (NSApplication *) theApplication openFile: (NSString*) filename
{
	[self openDocument: filename];
	return YES;
}

# pragma mark -
# pragma mark OutlineView handlers

- (void) outlineViewDoubleClicked: (id) sender
{
	FileSystemItem* item = [fileView itemAtRow: [fileView selectedRow]];
	NSError* error;
	NSDictionary* attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[item fullPath] error:&error];
	NSString* fileType = [attributes fileType];
	if(fileType == NSFileTypeRegular)
	{
		[self openDocument: [item fullPath]];
	}
	else
	{
		if([fileView isItemExpanded: item])
			[fileView collapseItem: item];
		else
			[fileView expandItem: item];
	}
}

- (void) outlineView: (NSOutlineView*) outlineView 
	 willDisplayCell: (id) cell 
	  forTableColumn: (NSTableColumn*) tableColumn 
				item: (id) item
{
	NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFile: [item fullPath]];
	[cell setImage: icon];
}

#pragma mark -
#pragma mark Implementation

- (void) openDocument: (NSString*) path
{
	@try
	{
		Document* doc = [m_documents objectForKey: path];
		if(doc)
		{
			[self setSelectedDocument: doc];
		}
		else
		{
			doc = [[Document alloc] initWithPath: path];
			[self addDocument: doc];

		}

		NSURL* url = [NSURL fileURLWithPath: path]; 
		[[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL: url];
	}
	@catch (NSException* ex) 
	{
		NSRunAlertPanel(@"Could not open file", @"%@\n\n%@", @"OK", nil, nil, path, ex);
	}
}

- (void) addDocument: (Document*) doc
{
	if([doc path])
		[m_documents setObject: doc forKey: [doc path]];
	[m_stack addObject: doc];

	NSRect frame = [m_tabView contentRect];
	NSScrollView* scrollView = [[NSScrollView alloc] initWithFrame: frame];
	NSSize contentSize = [scrollView contentSize];
	
	MyTextView* textView = [[MyTextView alloc] initWithFrame: NSMakeRect(0, 0, contentSize.width, contentSize.height)];
	[doc setTextView: textView];
	[textView setDelegate: self];
	[[textView layoutManager] setTextStorage: [doc contents]];
	[[doc contents] addLayoutManager: [textView layoutManager]];
	
	[scrollView setHasHorizontalScroller: YES];
	[scrollView setHasVerticalScroller: YES];
	//	[scrollView setBorderType: NSNoBorder];
	[scrollView setAutohidesScrollers: YES];
	
	[scrollView setDocumentView: textView];
	
	// create a new tab
	NSTabViewItem* item = [[NSTabViewItem alloc] initWithIdentifier: doc];
	[item setLabel: [doc title]];
	[item setView: scrollView];
	[m_tabView addTabViewItem: item];
		
	[textView release];
	[scrollView release];
	
	[item bind: @"label" toObject: doc withKeyPath: @"title" options: nil];
	[doc setDelegate: self];

	NSMenuItem* menuItem = [windowMenu addItemWithTitle: [doc title] action: @selector(onSelectWindow:) keyEquivalent: @""];
	[menuItem bind: @"title" toObject: doc withKeyPath: @"title" options: nil];
	[doc setMenuItem: menuItem];
	[menuItem setRepresentedObject: doc];

	[self setSelectedDocument: doc];
	
	[doc parseSyntax];
}

- (void) onSelectWindow: (NSMenuItem*) menuItem
{
	[self setSelectedDocument: [menuItem representedObject]];
}

- (BOOL) shouldCloseDocument: (Document*) doc
{
	if ([doc isEdited])
	{
		NSAlert* alert = [[NSAlert alloc] init];
		[alert addButtonWithTitle: @"Save"];
		[alert addButtonWithTitle: @"Don't Save"];
		[alert addButtonWithTitle: @"Cancel"];
		[alert setMessageText: @"Save your changes?"];
		NSString* name = [doc path];
		if(!name)
			name = [doc name];
		NSString* msg = [NSString stringWithFormat:@"You have unsaved changes in:\n'%@'", name];
		[alert setInformativeText: msg];
		[alert setAlertStyle: NSWarningAlertStyle];
		
		int result = [alert runModal];
		[alert release];
		
		if(result == NSAlertThirdButtonReturn)
			return NO;
		
		if(result == NSAlertFirstButtonReturn)
			return [self saveDocument: doc];
	}
	return YES;
}

- (void) closeDocument: (Document*) doc
{
	NSMenuItem* menuItem = [doc menuItem];
	[[menuItem menu] removeItem: menuItem];
	
	int index = [m_tabView indexOfTabViewItemWithIdentifier: doc];
	if(index != NSNotFound)
	{
		NSTabViewItem* item = [m_tabView tabViewItemAtIndex: index]; 
		[m_tabView removeTabViewItem: item];
	}
	[m_stack removeObject: doc];
	if([doc path])
		[m_documents removeObjectForKey: [doc path]];
	
	if([m_tabView numberOfTabViewItems] == 0)
	{
		NSAssert([m_stack count] == 0, @"Stack should be cleared");
		[self setSelectedDocument: nil];
	}
}

- (BOOL) saveAsDocument: (Document*) doc
{
	NSString* name = [doc name];
	NSSavePanel* panel = [NSSavePanel savePanel];
	[panel setTitle: [NSString stringWithFormat:@"Save - %@", name]];
	int result = [panel runModal];
	if(result == NSOKButton)
	{
		NSString* path = [panel filename];
		if([doc path])
			[m_documents removeObjectForKey: [doc path]];
		[doc saveAs: path];
		[m_documents setObject: doc forKey: path];
		return YES;
	}
	return NO;
}

- (BOOL) saveDocument: (Document*) doc
{
	if([doc path])
	{
		[doc save];
		return YES;
	}
	
	return [self saveAsDocument: doc];
}

- (void) updatePosition
{
	Document* doc = [self selectedDocument];
	if(doc)
	{
		TextPosition pos = [[doc textView] textPosition];
		NSString* str = [NSString stringWithFormat: @"Line: %d  Col: %d  Ch: %d", 
						 pos.line, pos.column, pos.character];
		[m_position setStringValue: str];
	}
	else
	{
		[m_position setStringValue: @""];
	}
}

- (void) openDirectory: (NSString*) path
{
	[fileView setRootPath: path];
}

@end
