//
//  FileSystemItem.m
//  Perfecto
//
//  Created by fried on 5/23/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#include <Carbon/Carbon.h>
#import "FileSystemItem.h"
#import "Document.h"

@implementation FileSystemView

- (void) awakeFromNib
{
	[self setRowHeight: 14];

	NSString* dir = [[NSUserDefaults standardUserDefaults] stringForKey: @"OpenDir"];
	if(!dir)
	{
		NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
		if([paths count])
			dir = [paths objectAtIndex: 0];
		else
			dir = [[NSFileManager defaultManager] currentDirectoryPath];
	}
	[self setDoubleAction: @selector(outlineViewDoubleClicked:)];
	[self setRootPath: dir];
}

- (void) setRootPath: (NSString*) path
{
	[m_fileSystem release];	
	m_fileSystem = [[FileSystem alloc] initWithPath: path];
	[m_fileSystem setDelegate: self];
	[self setDataSource: m_fileSystem];
	[self reloadData];
	[self expandItem: [m_fileSystem root]];
}

- (void) keyDown: (NSEvent*) theEvent
{
	if([theEvent keyCode] == kVK_Return)
		[self sendAction: [self doubleAction] to: nil];
	else
		[super keyDown: theEvent];
}

- (void) onRefreshItem: (FileSystemItem*) item
{
	[self reloadItem: nil reloadChildren: YES];
}

@end

@implementation FileSystem (DataSource)

- (int) outlineView: (NSOutlineView*) outlineView numberOfChildrenOfItem: (id) item
{
	return (item == nil) ? 1 : [item numberOfChildren];
}

- (BOOL) outlineView: (NSOutlineView*) outlineView isItemExpandable: (id) item
{
	return (item == nil) ? YES : ([item numberOfChildren] != -1);
}

- (id) outlineView: (NSOutlineView*) outlineView child: (int) index ofItem: (id) item
{
	if(item)
		return [item childAtIndex: index];
	else
		return m_root;
}

- (id) outlineView: (NSOutlineView*) outlineView 
	objectValueForTableColumn: (NSTableColumn*) tableColumn 
	byItem: (id) item
{
	return (item == nil) ? [m_root fullPath] : [item relativePath];
}

@end

@interface FileSystem(Private)

- (void) onFSEvent: (NSString*) path 
		 withFlags: (FSEventStreamEventFlags) flags 
	   withEventId: (FSEventStreamEventId) eventId;

@end

@implementation FileSystem

void OnFSEventStreamCallback(ConstFSEventStreamRef streamRef, 
							 void* clientCallBackInfo, 
							 size_t numEvents,
							 void* eventPaths,
							 const FSEventStreamEventFlags eventFlags[],
							 const FSEventStreamEventId eventIds[])
{
	FileSystem* this = (FileSystem*)clientCallBackInfo;
	NSArray* paths = (NSArray*) eventPaths;
	for(int i = 0; i < numEvents; i++)
	{
		[this onFSEvent: [paths objectAtIndex: i] withFlags: eventFlags[i] withEventId: eventIds[i]];
	}
}

- (id) initWithPath: (NSString*) path
{
	if (self = [super init])
	{
		m_root = [[FileSystemItem alloc] initWithPath: path];
		NSArray* paths = [NSArray arrayWithObject: path];
		uint flags = kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagWatchRoot;
		m_context = malloc(sizeof(FSEventStreamContext));
		memset(m_context, 0, sizeof(FSEventStreamContext));
		m_context->info = self;
		m_stream = FSEventStreamCreate(kCFAllocatorDefault,
									   OnFSEventStreamCallback,
									   m_context,
									   (CFArrayRef) paths,
									   kFSEventStreamEventIdSinceNow,
									   1,
									   flags);
		
		FSEventStreamScheduleWithRunLoop(m_stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
		FSEventStreamStart(m_stream);
	}
	return self;
}

- (void) delloc
{
	FSEventStreamStop(m_stream);
	FSEventStreamUnscheduleFromRunLoop(m_stream, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	FSEventStreamRelease(m_stream);
	free(m_context);
}

- (id) delegate { return m_delegate; }
- (void) setDelegate: (id) delegate { m_delegate = delegate; }

- (FileSystemItem*) root
{
	return m_root;
}

- (void) onFSEvent: (NSString*) path 
		 withFlags: (FSEventStreamEventFlags) flags 
	   withEventId: (FSEventStreamEventId) eventId
{
	NSString* relativePath = [path substringFromIndex: [[m_root fullPath] length]];
	FileSystemItem* item = [m_root findItem: relativePath];
//	NSLog(@"Found item: %@", [item fullPath]);
	if(item)
	{
		[item refresh];
		if([m_delegate respondsToSelector: @selector(onRefreshItem:)])
			[m_delegate performSelector: @selector(onRefreshItem:) withObject: item];
	}
}

@end

@implementation FileSystemItem

#define IsALeafNode ((id)-1)

- (id) initWithPath: (NSString*) path
{
	if (self = [super init])
	{
		m_root = self;
		m_path = [path copy];
		m_parent = nil;
	}
	return self;
}

- (id) initWithPath: (NSString*) path parent: (FileSystemItem*) parent root: (FileSystemItem*) root
{
	if (self = [super init])
	{
		m_root = root;
		m_parent = parent;
		m_path = [[path lastPathComponent] copy];
	}
	return self;
}

- (FileSystemItem*) rootItem
{
	return m_root;
}

// Creates, caches, and returns the array of children
// Loads children incrementally
- (NSArray*) children
{
	if (m_children == NULL)
		[self refresh];
    return m_children;
}

- (void) refresh
{
	if (m_children != IsALeafNode) 
		[m_children release];
	
	NSFileManager* fileManager = [NSFileManager defaultManager];
	NSString* fullPath = [self fullPath];
	BOOL isDir;
	BOOL valid = [fileManager fileExistsAtPath: fullPath isDirectory: &isDir];
	
	if (valid && isDir)
	{
		NSArray* array = [fileManager directoryContentsAtPath: fullPath];
		int numChildren = [array count];
		m_children = [[NSMutableArray alloc] initWithCapacity: numChildren];
		
		for (int i = 0; i < numChildren; i++)
		{
			NSString* path = [array objectAtIndex: i];
			if([path characterAtIndex: 0] == '.')
				continue;
			
			FileSystemItem* newChild = [[FileSystemItem alloc] initWithPath: path parent: self root: m_root];
			[m_children addObject: newChild];
			[newChild release];
		}
	}
	else
	{
		m_children = IsALeafNode;
	}
}

- (NSString*) relativePath
{
    return m_path;
}

- (NSString*) fullPath
{
	// If no parent, return our own relative path
	if (m_parent == nil) 
		return m_path;
	
	// recurse up the hierarchy, prepending each parent’s path
	return [[m_parent fullPath] stringByAppendingPathComponent: m_path];
}

- (FileSystemItem*) childAtIndex:(int) index
{
	return [[self children] objectAtIndex: index];
}

- (int) numberOfChildren
{
	id tmp = [self children];
	return (tmp == IsALeafNode) ? (-1) : [tmp count];
}

- (NSArray*) popItem: (NSArray*) array
{
	int count = [array count];
	int location = 1;
	if(count == 1)
		location = 0;
	return [array subarrayWithRange: NSMakeRange(location, count - 1)];
}

- (FileSystemItem*) findItem: (NSString*) path
{
	NSArray* parts = [path pathComponents];
	//NSLog(@"findItem: %@, %x", parts);
	while([parts count])
	{
		NSString* part = [parts objectAtIndex: 0];
		parts = [self popItem: parts];
		if([part isEqualToString: @"/"])
			continue;

		if(!m_children)
			return nil;

		if (m_children == IsALeafNode)
			return self;

		for(FileSystemItem* child in m_children)
		{
			if([[child relativePath] isEqualToString: part])
			{
				NSString* newPath = [NSString pathWithComponents: parts];
				return [child findItem: newPath];
			}
		}
		return nil;
	}
	
	return self;
}

- (void) dealloc
{
	if (m_children != IsALeafNode) 
		[m_children release];
	[m_path release];
	[super dealloc];
}

@end
