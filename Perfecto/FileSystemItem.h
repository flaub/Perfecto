//
//  FileSystemItem.h
//  Perfecto
//
//  Created by fried on 5/23/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface FileSystemItem : NSObject 
{
	NSString* m_path;
	FileSystemItem* m_root;
	FileSystemItem* m_parent;
	NSMutableArray* m_children;
}

- (id) initWithPath: (NSString*) path;
- (FileSystemItem*) rootItem;
- (int) numberOfChildren; // Returns -1 for leaf nodes
- (FileSystemItem*) childAtIndex: (int) index; // Invalid to call on leaf nodes
- (NSString*) fullPath;
- (NSString*) relativePath;
- (FileSystemItem*) findItem: (NSString*) path;
- (void) refresh;

@end

@interface FileSystem : NSObject <NSOutlineViewDataSource>
{
	FileSystemItem* m_root;
	FSEventStreamContext* m_context;
	FSEventStreamRef m_stream;
	id m_delegate;
}

- (FileSystemItem*) root;
- (id) delegate;
- (void) setDelegate: (id) delegate;
- (id) initWithPath: (NSString*) path;

@end

@interface FileSystemView : NSOutlineView
{
	FileSystem* m_fileSystem;
}

- (void) setRootPath: (NSString*) path;

@end

