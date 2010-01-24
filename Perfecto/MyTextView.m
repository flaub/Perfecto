//
//  MyTextView.m
//  Perfecto
//
//  Created by fried on 5/21/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

// Standard key-bindings
// file:///System/Library/Frameworks/AppKit.framework/Resources/StandardKeyBinding.dict
// User key-bindings
// file:///Users/franklaub/Library/KeyBindings/DefaultKeyBinding.dict

#import "MyTextView.h"
#import "Document.h"
#include "yy.lex.h"

@interface MyTextView(Private)

- (NSClipView*) nearestClipView;
- (BOOL) doMovement: (BOOL) isUpward shouldModifyRange: (BOOL) shouldModifyRange;
- (void) refreshColumn;
- (BOOL) handleTab: (BOOL) isForward;
- (BOOL) checkBottomOverflow;
- (BOOL) checkTopOverflow;
- (int) previousWordFrom: (int) location;
- (int) nextWordFrom: (int) location;
- (void) moveWordAndModifySelection: (BOOL) isForward;

@end

@implementation MyTextView

#pragma mark -
#pragma mark init

- (id)initWithFrame: (NSRect)frame 
{
    self = [super initWithFrame: frame];
    if (self) 
	{
		m_beep = [NSSound soundNamed: @"Pop"];
		[self setMinSize: NSMakeSize(0.0, frame.size.height)];
		[self setMaxSize: NSMakeSize(FLT_MAX, FLT_MAX)];
		[self setBackgroundColor: [NSColor darkGrayColor]];
		[self setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
		[self setVerticallyResizable: YES];
		[self setHorizontallyResizable: YES];
		[self setInsertionPointColor: [NSColor whiteColor]];
		[self setDefaultParagraphStyle: [Document defaultStyle]];
		[self setAllowsUndo: YES];
		[self setUsesFindPanel: YES];
		[[self textContainer] setContainerSize: NSMakeSize(FLT_MAX, FLT_MAX)];
		[[self textContainer] setWidthTracksTextView: NO];
    }
    return self;
}

#pragma mark -
#pragma mark Accessors

- (TextPosition) textPosition
{
	NSRange range = [self selectedRange];
	NSRange lineRange;
	[[self layoutManager] lineFragmentRectForGlyphAtIndex: range.location 
										   effectiveRange: &lineRange];
	NSRect rect = [[self layoutManager] boundingRectForGlyphRange: NSMakeRange(range.location, 1) 
												  inTextContainer: [self textContainer]];

	TextPosition pos;
	pos.line = (rect.origin.y / rect.size.height) + 1;
	pos.column = (range.location - lineRange.location) + 1;
	pos.character = range.location + 1;
	return pos;
}

#pragma mark -
#pragma mark Overrides

- (void) moveUp: (id) sender
{
	m_selpos = 0;
	if([self checkTopOverflow])
		return;
	[self doMovement: YES shouldModifyRange: NO];
}

- (void) moveUpAndModifySelection: (id) sender
{
	if([self checkTopOverflow])
		return;
	[self doMovement: YES shouldModifyRange: YES];
}

- (void) moveDown: (id) sender 
{
	m_selpos = 0;
	if([self checkBottomOverflow])
		return;
	[self doMovement: NO shouldModifyRange: NO];
}

- (void) moveDownAndModifySelection: (id) sender
{
	if([self checkBottomOverflow])
		return;
	[self doMovement: NO shouldModifyRange: YES];
}

- (void) moveLeft: (id) sender
{
	m_selpos = 0;
	[self checkTopOverflow];
	[super moveLeft: sender];
	[self refreshColumn];
}

- (void) moveLeftAndModifySelection: (id) sender
{
	[self checkTopOverflow];
	[super moveLeftAndModifySelection: sender];
	[self refreshColumn];
}

- (void) moveRight: (id) sender
{
	m_selpos = 0;
	[self checkBottomOverflow];
	[super moveRight: sender];
	[self refreshColumn];
}

- (void) moveRightAndModifySelection: (id) sender
{
	[self checkBottomOverflow];
	[super moveRightAndModifySelection: sender];
	[self refreshColumn];
}

- (void) mouseDown: (NSEvent*) theEvent
{
	m_selpos = 0;
	[super mouseDown: theEvent];
	[self refreshColumn];
}

- (void) mouseUp: (NSEvent*) theEvent
{
	[super mouseUp: theEvent];
	NSRange range = [self selectedRange];
	if(range.length && !m_selpos)
		m_selpos = range.location;
}

- (void) insertBacktab: (id) sender
{
	if(![self handleTab: NO])
		[super insertBacktab: sender];
}

- (void) insertTab: (id) sender
{
	if(![self handleTab: YES])
		[super insertTab: sender];
}

- (void) moveWordForward: (id) sender
{
	m_selpos = 0;
	if([self checkBottomOverflow])
		return;

	NSRange range = [self selectedRange];
	int location = [self nextWordFrom: range.location];
	[self setSelectedRange: NSMakeRange(location, 0)];
	[self refreshColumn];
}

- (void) moveWordBackward: (id) sender
{
	m_selpos = 0;
	if([self checkTopOverflow])
		return;
	
	NSRange range = [self selectedRange];
	int location = [self previousWordFrom: range.location];
	[self setSelectedRange: NSMakeRange(location, 0)];
	[self refreshColumn];
}

- (void) moveWordForwardAndModifySelection: (id) sender
{
	if([self checkBottomOverflow])
		return;
	[self moveWordAndModifySelection: YES];
}

- (void) moveWordBackwardAndModifySelection: (id) sender
{
	if([self checkTopOverflow])
		return;
	[self moveWordAndModifySelection: NO];
}

- (void) copy: (id) sender
{
	NSRange range = [self selectedRange];
	if(range.length == 0)
		[self selectLine: sender];
	[super copy: sender];
}

- (void) cut: (id) sender
{
	NSRange range = [self selectedRange];
	if(range.length == 0)
		[self selectLine: sender];
	[super cut: sender];
}

- (BOOL) validateMenuItem: (NSMenuItem*) menuItem
{
	SEL action = [menuItem action];
	if( action == @selector(copy:) ||
		action == @selector(cut:) )
		return YES;
	
	return [super validateMenuItem: menuItem];
}

#pragma mark -
#pragma mark Implementation

- (void) beep
{
	[m_beep play];
}

- (NSClipView*) nearestClipView
{
	NSView* contentView = [[self window] contentView];
	NSView* view = self;
	while(true)
	{
		view = [view superview];
		if(view == contentView)
			return nil;
		
		if([view isKindOfClass: [NSClipView class]])
			return (NSClipView*)view;
	}
}

- (void) refreshColumn
{
	NSRange range = [self selectedRange];
	NSRange lineRange;
	[[self layoutManager] lineFragmentRectForGlyphAtIndex: range.location 
										   effectiveRange: &lineRange];	
	if(m_seldir > 0)
	{
		int tail = range.location + range.length;
		m_column = tail - lineRange.location;
//		NSLog(@"Move tail");
	}
	else
	{
		m_column = range.location - lineRange.location;
//		NSLog(@"Move head");
	}
}	

- (BOOL) checkBottomOverflow
{
	NSRange range = [self selectedRange];
	if(range.location == [[self textStorage] length] - 1)
	{
		[self beep];
		return YES;
	}
	return NO;
}

- (BOOL) checkTopOverflow
{
	NSRange range = [self selectedRange];
	if(range.location == 0)
	{
		[self beep];
		return YES;
	}
	return NO;
}

- (BOOL) handleTab: (BOOL) isForward
{
	NSRange range = [self selectedRange];
	if(range.length > 0)
	{
		NSTextStorage* contents = [self textStorage];
		NSString* selection = [[contents string] substringWithRange: range];
		NSArray* lines = [selection componentsSeparatedByString: @"\n"];
		NSString* result = [[NSString alloc] init];
		if([lines count] > 1)
		{
			for(NSString* line in lines)
			{
				if([line length])
				{
					if(isForward)
						result = [result stringByAppendingFormat: @"\t%@\n", line];
					else
					{
						if([line characterAtIndex: 0] == '\t')
							result = [result stringByAppendingFormat: @"%@\n", [line substringFromIndex: 1]];
						else
							result = [result stringByAppendingFormat: @"%@\n", line];
					}
				}
			}
			
			if(![result isEqualToString: selection])
			{
				if ([self shouldChangeTextInRange: range replacementString: result]) 
				{
					[contents replaceCharactersInRange: range withString: result];
					[self setSelectedRange: NSMakeRange(range.location, [result length])];
					[self didChangeText];
				}
			}
			return YES;
		}
	}
	return NO;
}

- (int) previousWordFrom: (int) location
{
	NSString* text = [[self string] substringToIndex: location];
	const char* str = [text UTF8String];
	YY_BUFFER_STATE buf = yy_scan_string(str);
	int next;
	int last = 1;
	while(next = yylex()) { last = next; }
	yy_delete_buffer(buf);
	return location - last;
}

- (int) nextWordFrom: (int) location
{
	NSString* text = [[self string] substringFromIndex: location];
	const char* str = [text UTF8String];
	YY_BUFFER_STATE buf = yy_scan_string(str);
	int next = yylex();
	yy_delete_buffer(buf);
	return location + next;
}

- (void) moveWordAndModifySelection: (BOOL) isForward
{
	NSRange range = [self selectedRange];
	
	int start = range.location;
	int tail = range.location + range.length;
	if(m_seldir > 0)
		start = tail;
	
	int location = isForward ? 
	[self nextWordFrom: start] : 
	[self previousWordFrom: start];
	
	if(m_selpos == 0)
		m_selpos = range.location;
	
	m_seldir = location - m_selpos;
	NSRange newRange;
	if(m_seldir < 0)
	{
		// move head
		newRange.location = location;
		newRange.length = tail - newRange.location;
	}
	else if(m_seldir > 0)
	{
		// move tail
		newRange.location = range.location;
		newRange.length = location - newRange.location;
	}
	
	[self setSelectedRange: newRange];
	[self refreshColumn];
}

- (BOOL) doMovement: (BOOL) isUpward shouldModifyRange: (BOOL) shouldModifyRange
{
	int length = [[self string] length] - 1;
	NSRange range = [self selectedRange];
	
	// start is either the head or the tail
	// can be tail in two cases:
	// 1. when the selection direction is downward and selection should be extended
	// 2. when there was a previous selection and now movement is downward without selection extension
	int start = range.location;
	int tail = range.location + range.length;
	if( (shouldModifyRange && m_seldir > 0) ||
	   (!shouldModifyRange && !isUpward && range.length) )		
		start = tail;
	
	NSRange lineRange;
	NSRect lineRect = [[self layoutManager] lineFragmentRectForGlyphAtIndex: start 
															 effectiveRange: &lineRange];
	
	NSRange visRange = NSMakeRange(start, 1);
	NSRect rect = [[self layoutManager] boundingRectForGlyphRange: visRange inTextContainer: [self textContainer]];
	NSClipView* clipView = [self nearestClipView];
	NSRect visibleRect = [clipView documentVisibleRect];
	
	float after, delta;
	BOOL isOutside;
	if(isUpward)
	{
		after = rect.origin.y - lineRect.size.height;
		delta = after - visibleRect.origin.y;
		isOutside = delta < 0;
	}
	else
	{
		after = rect.origin.y + lineRect.size.height;
		float bottom = visibleRect.origin.y + visibleRect.size.height;
		delta = (after - bottom) + lineRect.size.height;
		isOutside = delta > 0;
		//		NSLog(@"bottom: %f, now: %f, after: %f, delta: %f", bottom, rect.origin.y, after, delta);
	}
	
	if(isOutside)
	{
		NSRect newRect = NSMakeRect(0, visibleRect.origin.y + delta, visibleRect.size.width, visibleRect.size.height);
		//		NSLog(@"Out of bounds");
		[self scrollRectToVisible: newRect];
	}
	
	// get the location of the cursor after the move
	NSPoint point = NSMakePoint(rect.origin.x, after);
	int index = [[self layoutManager] glyphIndexForPoint: point 
										 inTextContainer: [self textContainer] 
						  fractionOfDistanceThroughGlyph: NULL];
	
	// this is the next line, either above or below, depending on direction
	NSRange nextRange;
	[[self layoutManager] lineFragmentRectForGlyphAtIndex: index
										   effectiveRange: &nextRange];
	int nextEnd = nextRange.location + nextRange.length;
	
	int location = 0;
	// check for line wrap at the top
	if(!isUpward || lineRange.location > 0)
	{
		location = nextRange.location + m_column;
		if( (isUpward && location >= lineRange.location) ||
		   (!isUpward && location > nextEnd) )
		{
			location = nextEnd - 1;
		}
	}
	
	NSRange newRange = NSMakeRange(location, 0);
	if(shouldModifyRange)
	{
		// move head or move tail
		if(m_selpos == 0)
			m_selpos = range.location;
		
		m_seldir = location - m_selpos;
		if(m_seldir < 0)
		{
			// move head
			newRange.length = tail - newRange.location;
		}
		else if(m_seldir > 0)
		{
			// move tail
			newRange.location = range.location;
			newRange.length = location - newRange.location;
		}
	}
	
	if(newRange.length == 0)
		m_seldir = 0;
	
	if(newRange.location < 0 || newRange.location + newRange.length > length)
		NSLog(@"overflow");
	
	//	NSLog(@"newRange: %@, dir: %d", NSStringFromRange(newRange), m_seldir);
	[self setSelectedRange: newRange];
	return YES;
}

@end
