/*
 *  ColoringBridge.cpp
 *  Perfecto
 *
 *  Created by fried on 5/27/08.
 *  Copyright 2008 __MyCompanyName__. All rights reserved.
 *
 */

extern "C"
{
	#include "ColoringBridge.h"
}

#include "colorer/viewer/TextLinesStore.h"
#include "colorer/ParserFactory.h"
#include "colorer/editor/BaseEditor.h"

#include <memory>
#include <string>
#include <vector>

struct Range
{
	size_t pos;
	size_t len;
};

class StringLineSource : public LineSource
{
private:
	std::vector<Range> m_lines;
	const char* m_source;
	
public:
	StringLineSource(const char* source) 
		: m_source(source)
	{
		int len = strlen(source);
		int pos = 0;
		for(int i = 0; i < len; i++)
		{
			if(source[i] == '\n')
			{
				Range range;
				range.pos = pos;
				range.len = i - pos;
				m_lines.push_back(range);
				pos = i + 1;
			}
		}
	}
	
	String* getLine(int index)
	{
		if(index < m_lines.size())
		{
			const Range& range = m_lines[index];
			return new DString(m_source, range.pos, range.len);
		}
		return NULL;
	}
	
	size_t getLineCount() const
	{
		return m_lines.size();
	}
};

void SimpleLineRegionRelease(CFAllocatorRef allocator, const void* value)
{
	CFAllocatorDeallocate(allocator, (SimpleLineRegion*)value);
}

const void* SimpleLineRegionRetain(CFAllocatorRef allocator, const void* value)
{
	LineRegion* rhs = (LineRegion*) value;
	SimpleLineRegion* ret = (SimpleLineRegion*) CFAllocatorAllocate(kCFAllocatorDefault, sizeof(SimpleLineRegion), 0);
	ret->start = rhs->start;
	ret->end = rhs->end;
	ret->foreground = rhs->styled()->fore;
	ret->background = rhs->styled()->back;
	return ret;
}

CFMutableArrayRef parse_syntax(const char* filename, const char* preview, const char* text, const char* style)
{
	std::auto_ptr<String> inputFileName(new DString(filename));
	StringBuffer textStart(preview);
	std::auto_ptr<String> catalogPath(new DString("/Users/franklaub/src/Colorer-take5.be5/catalog.xml"));
	std::auto_ptr<String> hrdClass(new DString("rgb"));
	std::auto_ptr<String> hrdName(new DString(style));;
		
	CFMutableArrayRef lines = CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
	StringLineSource source(text);
	
	ParserFactory pf(catalogPath.get());
	BaseEditor editor(&pf, &source);
	editor.setRegionMapper(hrdClass.get(), hrdName.get());
	FileType* type = pf.getHRCParser()->chooseFileType(inputFileName.get(), &textStart, 0);
	editor.setFileType(type);
	editor.lineCountEvent(source.getLineCount());
		
	for(int i = 0; i < source.getLineCount(); i++)
	{
		CFArrayCallBacks callbacks = kCFTypeArrayCallBacks;
		callbacks.retain = SimpleLineRegionRetain;
		callbacks.release = SimpleLineRegionRelease;
		
		CFMutableArrayRef regions = CFArrayCreateMutable(kCFAllocatorDefault, 0, &callbacks);
		for(LineRegion* region = editor.getLineRegions(i); region != NULL; region = region->next)
		{
			if(region->special || region->rdef == NULL)
				continue;
			CFArrayAppendValue(regions, region);
		}
		
		CFArrayAppendValue(lines, regions);		
	}
	
	return lines;
}
