//
//  MyTextView.h
//  Perfecto
//
//  Created by fried on 5/21/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

typedef struct _TextPosition 
{
	int line;
	int column;
	int character;
} TextPosition;

@interface MyTextView : NSTextView 
{
	int m_column;
	int m_seldir;
	int m_selpos;
	NSSound* m_beep;
}

- (TextPosition) textPosition;

@end
