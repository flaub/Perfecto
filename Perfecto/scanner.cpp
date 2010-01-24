//
//  scanner.m
//  Perfecto
//
//  Created by fried on 5/25/08.
//  Copyright 2008 __MyCompanyName__. All rights reserved.
//

extern "C" 
{
	#include "yy.lex.h"
}

#include "colorer/viewer/TextLinesStore.h"
#include "colorer/ParserFactory.h"
#include "colorer/editor/BaseEditor.h"

#include <memory>
#include <vector>
#include <curses.h>

String* typeDescription = NULL;

//class MemoryLineSource : LineSource
//{
//private:
//	const char* m_source;
//	std::vector<const char*> m_lines;
//	
//public:
//	MemoryLineSource(const char* source)
//		: m_source(source)
//	{
//	}
//	
//	String* getLine(int lno)
//	{
//		return NULL;
//	}
//};


FileType* selectType(String* inputFileName, HRCParser* hrcParser, LineSource* lineSource)
{
	FileType* type = null;
	if (typeDescription != null)
	{
		type = hrcParser->getFileType(typeDescription);
		if (type == null)
		{
			for(int idx = 0;; idx++)
			{
				type = hrcParser->enumerateFileTypes(idx);
				if (type == null) break;
				if (type->getDescription() != null &&
					type->getDescription()->length() >= typeDescription->length() &&
					DString(type->getDescription(), 0, typeDescription->length()).equalsIgnoreCase(typeDescription))
					break;
				if (type->getName()->length() >= typeDescription->length() &&
					DString(type->getName(), 0, typeDescription->length()).equalsIgnoreCase(typeDescription))
					break;
				type = null;
			}
		}
	}
	
	if (typeDescription == null || type == null)
	{
		StringBuffer textStart;
		int totalLength = 0;
		for(int i = 0; i < 4; i++)
		{
			String* iLine = lineSource->getLine(i);
			if (iLine == null) break;
			textStart.append(iLine);
			textStart.append(DString("\n"));
			totalLength += iLine->length();
			if (totalLength > 500)
				break;
		}
		type = hrcParser->chooseFileType(inputFileName, &textStart, 0);
	}
	return type;
}

int main(int argc, char *argv[])
{
	YY_BUFFER_STATE buf = NULL;
	++argv;
	--argc;
	if(argc > 0)
		yyin = fopen(argv[0], "r");
	else
		buf = yy_scan_string("This is a string!\n");

	int x = 0;
	while(x = yylex())
	{
		printf("%d ", x);
	}
	
	if(buf)
		yy_delete_buffer(buf);
	
	printf("\n");
	
	std::auto_ptr<String> inputEncoding;
	std::auto_ptr<String> inputFileName(new DString("/Users/franklaub/src/Perfecto/main.m"));
	std::auto_ptr<String> catalogPath(new DString("/Users/franklaub/src/Colorer-take5.be5/catalog.xml"));
	std::auto_ptr<String> hrdClass(new DString("console"));
	std::auto_ptr<String> hrdName;

	TextLinesStore textLinesStore;
	textLinesStore.loadFile(inputFileName.get(), inputEncoding.get(), true);
	
	ParserFactory pf(catalogPath.get());
	BaseEditor editor(&pf, &textLinesStore);
	editor.setRegionMapper(hrdClass.get(), hrdName.get());
	FileType* type = selectType(inputFileName.get(), pf.getHRCParser(), &textLinesStore);
	editor.setFileType(type);
	editor.lineCountEvent(textLinesStore.getLineCount());

//	TextConsoleViewer viewer(&baseEditor, &textLinesStore, background, outputEncodingIndex);
//	viewer.view();
	
//	initscr();
	start_color();
	
	for(int i = 0; i < textLinesStore.getLineCount(); i++)
	{
		DString line = textLinesStore.getLine(i);		
//		printf("%s\n", line.getChars());
		printf("%d: %s\n", i, line.getChars());
		for(LineRegion* region = editor.getLineRegions(i); region != NULL; region = region->next)
		{
			if(region->special || region->rdef == NULL)
				continue;
			
			int end = region->end;
			if(end == -1)
				end = line.length();
			
			int len = end - region->start;
			int fore = region->styled()->fore;
			int back = region->styled()->back;
			printf("[%d - %d] %d: (%d, %d) ", region->start, region->end, len, fore, back);
		}
		printf("\n");
	}
	
	
	return 0;
}
