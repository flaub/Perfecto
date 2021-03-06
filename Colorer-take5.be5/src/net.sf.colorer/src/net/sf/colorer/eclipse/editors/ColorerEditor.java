package net.sf.colorer.eclipse.editors;

import net.sf.colorer.FileType;
import net.sf.colorer.HRCParser;
import net.sf.colorer.ParserFactory;
import net.sf.colorer.eclipse.ColorerPlugin;
import net.sf.colorer.eclipse.IColorerReloadListener;
import net.sf.colorer.eclipse.Messages;
import net.sf.colorer.eclipse.PreferencePage;
import net.sf.colorer.eclipse.outline.ColorerContentOutlinePage;
import net.sf.colorer.eclipse.outline.OutlineSchemeElement;
import net.sf.colorer.editor.OutlineItem;
import net.sf.colorer.handlers.LineRegion;
import net.sf.colorer.impl.Logger;
import net.sf.colorer.swt.TextColorer;

import org.eclipse.jface.action.IMenuManager;
import org.eclipse.jface.action.Separator;
import org.eclipse.jface.dialogs.MessageDialog;
import org.eclipse.jface.preference.IPreferenceStore;
import org.eclipse.jface.resource.JFaceResources;
import org.eclipse.jface.text.source.ISourceViewer;
import org.eclipse.jface.util.IPropertyChangeListener;
import org.eclipse.jface.util.PropertyChangeEvent;
import org.eclipse.jface.viewers.DoubleClickEvent;
import org.eclipse.jface.viewers.IDoubleClickListener;
import org.eclipse.jface.viewers.IStructuredSelection;
import org.eclipse.swt.custom.StyledText;
import org.eclipse.swt.events.VerifyEvent;
import org.eclipse.swt.events.VerifyListener;
import org.eclipse.swt.graphics.Font;
import org.eclipse.swt.widgets.Composite;
import org.eclipse.ui.IEditorInput;
import org.eclipse.ui.IFileEditorInput;
import org.eclipse.ui.editors.text.TextEditor;
import org.eclipse.ui.texteditor.ITextEditorActionConstants;
import org.eclipse.ui.views.contentoutline.IContentOutlinePage;

public class ColorerEditor extends TextEditor implements IColorerReloadListener, IPropertyChangeListener{

    ISourceViewer sourceViewer;
    IPreferenceStore prefStore;
    TextColorer textColorer;
    StyledText text;

    ColorerContentOutlinePage contentOutliner;

    VerifyListener tabReplacer = new VerifyListener() {
        public void verifyText(VerifyEvent e) {
            if (e.text.equals("\t")) {
                StringBuffer tab = new StringBuffer();
                for (int idx = 0; idx < text.getTabs(); idx++)
                    tab.append(' ');
                e.text = tab.toString();
            }
        }
    };
    
    IDoubleClickListener doubleClickListener = new IDoubleClickListener(){
        public void doubleClick(DoubleClickEvent event) {
            if (text == null || event.getSelection().isEmpty()){
                return;
            }
            OutlineItem el = (OutlineItem)((IStructuredSelection)event.getSelection()).getFirstElement();
            if (el instanceof OutlineSchemeElement) {
                OutlineSchemeElement sel = (OutlineSchemeElement)el;
                int selstart = text.getOffsetAtLine(sel.lno)+sel.pos;
                int selength = text.getOffsetAtLine(sel.l2no) + sel.pos2 - selstart;
                if (sel.l2no == 0 && sel.pos2 == 0 || selength <= 0){
                    selength = 0;
                }
                if (Logger.TRACE){
                    Logger.trace("ColorerEditor", "doubleClick:"+sel.lno+":"+sel.pos+" - " +sel.l2no+":"+sel.pos2+" = "+selstart+"-"+selength);
                }
                text.setSelectionRange(selstart, selength);
            }else{
                text.setSelectionRange(text.getOffsetAtLine(el.lno)+el.pos, el.length);
            }
            text.showSelection();
            textColorer.stateChanged();
        }
    };

    public ColorerEditor() {
      super();
      ColorerPlugin.getDefault().addReloadListener(this);
      prefStore = ColorerPlugin.getDefault().getPreferenceStore();

      setSourceViewerConfiguration(new ColorerSourceViewerConfiguration());
    }

    public void createPartControl(Composite parent){
        super.createPartControl(parent);
        text = getSourceViewer().getTextWidget();
        
        prefStore.addPropertyChangeListener(this);
        JFaceResources.getFontRegistry().addListener(this);
        
        relinkColorer();
    }

    
    protected void initializeKeyBindingScopes(){
        setKeyBindingScopes(new String[] {
            "net.sf.colorer.eclipse.ColorerScope"
        });
    }

    /**
     * Selects filetype according to file name and first line of content
     */
    public void chooseFileType() {
        textColorer.chooseFileType(getTitle());
        text.redraw();
    }

    /**
     * Selects file's type according to the passed type name
     */
    public void setFileType(FileType type) {
        textColorer.setFileType(type);
        text.redraw();
    }

    /** Returns currently used file type */
    public FileType getFileType() {
        return textColorer.getFileType();
    }

    /**
     * Reloads coloring highlighting in this editor
     */
    public void relinkColorer() {
        if (textColorer != null) {
            textColorer.detach();
        }
        ParserFactory pf = ColorerPlugin.getDefaultPF();
        HRCParser hp = pf.getHRCParser();

        textColorer = new TextColorer(pf, ColorerPlugin.getDefault()
                .getColorManager());
        textColorer.attach(text);
        textColorer.chooseFileType(getTitle());

        if (contentOutliner != null) {
            contentOutliner.attach(textColorer);
            if (Logger.TRACE){
                Logger.trace("ColorerEditor", "contentOutliner.attach()");
            }
        }
        propertyChange(null);
    }

    /** Tries to match paired construction */
    public void matchPair() {
        if (!textColorer.matchPair()) {
            showPairError();
        }
    }

    /** Selects paired construction */
    public void selectPair() {
        if (!textColorer.selectPair()) {
            showPairError();
        }
    }

    /** Selects content of paired construction */
    public void selectContentPair() {
        if (!textColorer.selectContentPair()) {
            showPairError();
        }
    }

    /**
     * Retrieves current LineRegion under caret.
     * 
     * @return LineRegion currently under Caret
     */
    public LineRegion getCaretRegion() {
        return textColorer.getCaretRegion();
    }

    void showPairError() {
        MessageDialog.openInformation(null, Messages.get("editor.pairerr.title"),
                Messages.get("editor.pairerr.msg"));
    }
    
    /**
     * Selects region under the cursor
     */
    public void selectCursorRegion() {
        LineRegion lr = textColorer.getCaretRegion();
        if (lr == null) return;
        
        int loffset = text.getOffsetAtLine(text.getLineAtOffset(text.getCaretOffset()));
        int selstart = loffset+lr.start;
        int selend = lr.end-lr.start;
        if (lr.end == -1){
            selend = 0;
        }
        text.setSelectionRange(selstart, selend);
    }

    protected void editorContextMenuAboutToShow(IMenuManager parentMenu) {
        super.editorContextMenuAboutToShow(parentMenu);
        if (!textColorer.pairAvailable())
            return;
        ColorerActionContributor ec = (ColorerActionContributor) getEditorSite().getActionBarContributor();
        parentMenu.insertBefore(ITextEditorActionConstants.GROUP_UNDO, ec.pairMatchAction);
        parentMenu.insertBefore(ITextEditorActionConstants.GROUP_UNDO, ec.pairSelectAction);
        parentMenu.insertBefore(ITextEditorActionConstants.GROUP_UNDO, ec.pairSelectContentAction);
        parentMenu.insertBefore(ITextEditorActionConstants.GROUP_UNDO, new Separator());
    }

    public void notifyReload() {
        if (Logger.TRACE){
            Logger.trace("ColorerEditor", "notifyReload()");
        }
        relinkColorer();
    }

    public void propertyChange(PropertyChangeEvent e) {
        if (textColorer == null)
            return;
        if (e == null || e.getProperty().equals(PreferencePage.USE_BACK) ||
            e.getProperty().equals(PreferencePage.HRD_SET))
        {
            textColorer.setRegionMapper(
                    prefStore.getString(PreferencePage.HRD_SET),
                    prefStore.getBoolean(PreferencePage.USE_BACK));
        }
        if (e == null || e.getProperty().equals(PreferencePage.FULL_BACK)){
            textColorer.setFullBackground(prefStore.getBoolean(PreferencePage.FULL_BACK));
        }
        if (e == null || e.getProperty().equals(PreferencePage.HORZ_CROSS) ||
            e.getProperty().equals(PreferencePage.VERT_CROSS))
        {
            textColorer.setCross(
                    prefStore.getBoolean(PreferencePage.HORZ_CROSS),
                    prefStore.getBoolean(PreferencePage.VERT_CROSS));
        }

        if (e == null || e.getProperty().equals(PreferencePage.WORD_WRAP))
        {
            text.setWordWrap(prefStore.getBoolean(PreferencePage.WORD_WRAP));
        }
        if (e == null || e.getProperty().equals(PreferencePage.TAB_WIDTH))
            if (text.getTabs() != prefStore.getInt(PreferencePage.TAB_WIDTH)){
                text.setTabs(prefStore.getInt(PreferencePage.TAB_WIDTH));
            }

        if (e == null || e.getProperty().equals(PreferencePage.SPACES_FOR_TABS)) {
            if (prefStore.getBoolean(PreferencePage.SPACES_FOR_TABS))
                text.addVerifyListener(tabReplacer);
            else
                text.removeVerifyListener(tabReplacer);
        }

        if (e == null || e.getProperty().equals(PreferencePage.PAIRS_MATCH)) {
            String pairs = prefStore.getString(PreferencePage.PAIRS_MATCH);
            int pmode = TextColorer.HLS_XOR;
            if (pairs.equals("PAIRS_OUTLINE"))
                pmode = TextColorer.HLS_OUTLINE;
            if (pairs.equals("PAIRS_OUTLINE2"))
                pmode = TextColorer.HLS_OUTLINE2;
            textColorer.setPairsPainter(!pairs.equals("PAIRS_NO"), pmode);
        }

        if (e == null || e.getProperty().equals(PreferencePage.TEXT_FONT)){
            Font textFont = JFaceResources.getFont(PreferencePage.TEXT_FONT);
            text.setFont(textFont);
        }
    }

    public Object getAdapter(Class key) {
        if (key.equals(IContentOutlinePage.class)) {
            IEditorInput input = getEditorInput();
            if (input instanceof IFileEditorInput) {
                if (contentOutliner == null){
                    contentOutliner = new ColorerContentOutlinePage();
                    contentOutliner.addDoubleClickListener(doubleClickListener);
                    contentOutliner.attach(textColorer);
                }
                return contentOutliner;
            }
        }
        return super.getAdapter(key);
    }

    public void dispose() {
        super.dispose();
        if (contentOutliner != null) {
            contentOutliner.detach();
        }
        prefStore.removePropertyChangeListener(this);
        JFaceResources.getFontRegistry().removeListener(this);
        ColorerPlugin.getDefault().removeReloadListener(this);
    }
}
/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is the Colorer Library.
 *
 * The Initial Developer of the Original Code is
 * Cail Lomecb <cail@nm.ru>.
 * Portions created by the Initial Developer are Copyright (C) 1999-2005
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */
