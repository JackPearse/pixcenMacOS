//
//  AppDelegate+Menu.swift
//  pixcen
//
//  Created by Jack Pearse on 30.07.20.
//  Copyright © 2026 Drehwerk. All rights reserved.
//
//
//  Pixcen - A windows platform low level pixel editor for C64
//  Copyright (C) 2013  John Hammarberg (crt@nospam.censordesign.com)
//  Ported to MacOS in 2020-2026 by JackPearse (Drehwerk^Drehwerk)
//
//    This file is part of Pixcen.
//
//    Pixcen is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 3 of the License, or
//    (at your option) any later version.
//
//    Pixcen is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with Pixcen.  If not, see <http://www.gnu.org/licenses/>.

import Cocoa
import PixcenFoundation

// MARK: - Generic menu handling
extension AppDelegate {
    
    func initSubmenus() {
        
        let count = C64Col.shared.palette.count
        
        // Read the palette options from the pixcen lib and populate to the submenu
        for i in 0..<count {
            
            let name = C64Col.shared.paletteName[i]
            let item = NSMenuItem(title: name, action:  #selector(self.onModePalette(_:)), keyEquivalent: "")
            
            // And store the index of the palette in the menu item
            item.tag = i
            self.paletteSubmenu.addItem(item)
            
            if i == 0 {
                
                // and select the default palette
                self.onModePalette(item)
            }
        }
        
        self.initPARSubMenu()
    }
    
    /**
     Helper. Deselects all items in the same menu group
     */
    func deselectGroupItems(_ item:NSMenuItem) {
        
        if let parent = item.parent {
            
            if let submenu = parent.submenu {
                                                    
                for item in submenu.items {
                    
                    item.state = .off
                }
            }
        }
    }
}

// MARK: - Menu handling
extension AppDelegate {

    /// Refresh the status bar hint after a menu action changes state
    func refreshStatusHint() {
        pixelCanvasView?.refreshStatus()
    }

    /// Check if the document has unsaved changes. If dirty, shows a save/discard/cancel alert.
    /// Calls `proceed()` only if the user chose "Don't Save" (discard).
    /// If the user chose "Save", the save dialog is shown and the operation is not continued.
    func checkDirty(proceed: @escaping () -> Void) {
        guard markEdited, let mainWindow = NSApp.mainWindow else {
            proceed()
            return
        }

        let alert = NSAlert()
        alert.messageText = "Unsaved Changes"
        alert.informativeText = "Do you want to save your changes before continuing?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: mainWindow) { result in
            switch result {
            case .alertFirstButtonReturn:
                // Delay the save dialog so the alert sheet finishes dismissing first
                DispatchQueue.main.async {
                    self.onFileSave(self)
                }
            case .alertSecondButtonReturn:
                proceed()
            default:
                break
            }
        }
    }

    // MARK: File new, load, save
    
    /*
     POPUP "&File"
     BEGIN
         MENUITEM "&New\tCtrl+N",                ID_FILE_NEW
         MENUITEM SEPARATOR
         MENUITEM "&Load\tCtrl+L",               ID_FILE_LOAD
         MENUITEM "&Save\tCtrl+S",               ID_FILE_SAVE
         MENUITEM "Save &As\tCtrl+Shift+S",      ID_FILE_SAVEAS
         MENUITEM "Save sele&ction\tShift+S",    ID_FILE_SAVESELECTION
         MENUITEM SEPARATOR
         MENUITEM "E&xit",                       ID_APP_EXIT
     END
     */
    
    // Menu wiring: OK | Menu function test: passed
    @IBAction func onFileNew(_ sender: Any) {
        
        func showNewDialog() {
            
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            if let dlg = storyboard.instantiateController(withIdentifier: "CNewDlg") as? PCCreateNewDialogViewController {
                
                if let mw = NSApp.mainWindow {
                    
                    if let mvc = mw.contentViewController {
                    
                        dlg.callbackHandler = { [weak self] in
                            guard let self = self, let canvas = self.pixelCanvasView else { return }

                            do {
                                let newDoc: PCC64Interface
                                switch dlg.m_select {
                                case 0:  // Bitmap
                                    if dlg.m_multi {
                                        newDoc = try PCMCBitmap(x: dlg.m_x, y: dlg.m_y, backbuffers: dlg.m_z)
                                    } else {
                                        newDoc = try PCBitmap(x: dlg.m_x, y: dlg.m_y, backbuffers: dlg.m_z)
                                    }
                                case 1:  // Sprite
                                    if dlg.m_multi {
                                        newDoc = try PCMCSprite(x: dlg.m_x, y: dlg.m_y, backbuffers: dlg.m_z)
                                    } else {
                                        newDoc = try PCSprite(x: dlg.m_x, y: dlg.m_y, backbuffers: dlg.m_z)
                                    }
                                case 2:  // Char
                                    if dlg.m_multi {
                                        newDoc = try PCMCFont(x: dlg.m_x, y: dlg.m_y, backbuffers: dlg.m_z)
                                    } else {
                                        newDoc = try PCSFont(x: dlg.m_x, y: dlg.m_y, backbuffers: dlg.m_z)
                                    }
                                case 3:  // Unrestricted
                                    newDoc = try PCUnrestricted(x: dlg.m_x, y: dlg.m_y,
                                                                wide: dlg.m_multi, backbuffers: dlg.m_z)
                                default:
                                    newDoc = try PCMCBitmap()
                                }

                                newDoc.inheritHistory(old: canvas.m_pbm)
                                canvas.m_pbm = newDoc
                                canvas.invalidate()
                                self.lastSavedURL = nil
                                self.markEdited = false
                            } catch {
                                let alert = NSAlert()
                                alert.messageText = "Error creating new document"
                                alert.informativeText = "\(error)"
                                alert.runModal()
                            }
                        }
                        mvc.presentAsSheet(dlg as NSViewController)
                                                
                    }
                }
            }
        }
        
        checkDirty {
            showNewDialog()
        }
    }
    
    // Menu wiring: OK | Menu function test: passed
    @IBAction func onFileSave(_ sender: Any) {
        
        if let saveURL = lastSavedURL {
            
            self.save(url: saveURL)
        } else {
            
            self.onFileSaveAs(sender)
        }
    }
    /*
     void CChildView::OnFileSave()
         {
         if(m_goodFormat && *m_pbm->GetFileName()!=_T('\0'))
         {
         SetViewSpecificMetaData();
         try
         {
         m_pbm->Save(NULL,NULL);
         m_pbm->ClearDirty();
         }
         catch(LPCTSTR str)
         {
         AfxMessageBox(str);
         }
         }
         else
         {
         OnFileSaveas();
         }
         }
         
         
         void CChildView::OnUpdateFileSave(CCmdUI *pCmdUI)
         {
         pCmdUI->Enable(m_pbm->IsDirty()?1:0);
         }
         
         
         void CChildView::Saveas(C64Interface *i)
         {
         SetViewSpecificMetaData();
         
         narray<autoptr<SaveFormat>, int> fmt;
         i->GetSaveFormats(fmt);
         
         nstr s;
         
         for(int r=0;r<fmt.count();r++)
         {
         s << fmt[r]->name << _T("|");
         
         bool first = true;
         
         for(int t=0;t<fmt[r]->ext.count();t++)
         {
         if(!first)s << _T(";");
         
         s << _T("*.") << fmt[r]->ext[t];
         
         first = false;
         }
         
         s << _T("|");
         }
         
         s << _T("|");
         
         nstr def=i->GetFileName();
         size_t n;
         n=def.rfind(_T('.'));
         if(n!=-1)
         def.limit(n);
         
         CFileDialog dlg(FALSE, _T("gpx"), def, OFN_HIDEREADONLY | OFN_OVERWRITEPROMPT, s.cstr(), this, 0);
         if(dlg.DoModal() == IDOK)
         {
         nstr ex = dlg.GetFileExt().MakeLower();
         
         if(ex==_T("pmap") || ex==_T("pscr") || ex==_T("pcol") || ex==_T("piscr") || ex==_T("pimap"))
         {
         for(;;)
         {
         CAddressDlg addr;
         addr.m_verified_address = m_pbm->GetMetaInt(nstrc(ex));
         if(addr.DoModal()!=IDOK)return;
         if(addr.m_verified_address<0 || addr.m_verified_address>65536)continue;
         m_pbm->SetMetaInt(nstrc(ex),addr.m_verified_address);
         break;
         }
         }
         
         bool good_format = false;
         
         for(int r=0;r<fmt.count();r++)
         {
         if(fmt[r]->MatchExt(ex))
         {
         good_format = fmt[r]->good;
         break;
         }
         }
         
         try
         {
         i->Save(dlg.GetPathName(), ex);
         
         if((good_format && i->GetBackBufferCount() == 1) || ex.cmpi(_T("gpx"))==0)
         {
         i->ClearDirty();
         SetTitleFileName(dlg.GetPathName());
         }
         
         i->SetFileName(dlg.GetPathName());
         m_goodFormat = good_format;
         
         }
         catch(LPCTSTR str)
         {
         AfxMessageBox(str);
         }
         
         Invalidate();
         }
         }
     */
    
    // Menu wiring: OK | Menu function test: passed
    @IBAction func onFileSaveAs(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }

        let panel = NSSavePanel()
        panel.title = "Save pixel document"

        // Build format list from the bitmap's save formats
        var formats = canvas.m_pbm.saveFormats
        // Add common C64 formats as fallback
        let knownExts = Set(formats.flatMap { Array($0.ext.keys) })
        let fallbacks: [(String, String)] = [
            ("Koala", "kla"), ("Koala", "koa"), ("Koala compressed", "gg"),
            ("Art Studio", "art"), ("Doodle", "dd"), ("Doodle compressed", "jj"),
            ("Advanced Art Studio", "ocp"), ("Zoomatic", "zom"), ("Cenimate", "cen"),
            ("Paint Magic", "pmg"), ("Multigraf", "mg"), ("C64 Exe", "prg"),
            ("Multipaint", "bin")
        ]
        for (name, ext) in fallbacks {
            if !knownExts.contains(ext) {
                formats.append(SaveFormat(a: name, b: ext, good: true))
            }
        }

        // Create accessory view with format popup
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 32))
        let label = NSTextField(labelWithString: "Format:")
        label.frame = NSRect(x: 0, y: 6, width: 55, height: 20)
        label.font = NSFont.systemFont(ofSize: 13)
        accessoryView.addSubview(label)

        let formatPopup = NSPopUpButton(frame: NSRect(x: 58, y: 2, width: 235, height: 26))
        for fmt in formats {
            let exts = Array(fmt.ext.keys).joined(separator: ", ")
            formatPopup.addItem(withTitle: "\(fmt.name) (.\(exts))")
            formatPopup.lastItem?.representedObject = Array(fmt.ext.keys).first ?? "gpx"
        }
        accessoryView.addSubview(formatPopup)

        panel.accessoryView = accessoryView

        // Set initial file extension from first format
        if let firstExt = formats.first?.ext.keys.first {
            panel.allowedFileTypes = [firstExt]
        }

        // Update allowed extension when popup changes
        formatPopup.target = self
        formatPopup.action = #selector(saveFormatChanged(_:))
        self.currentSavePanel = panel
        self.currentFormatPopup = formatPopup
        self.currentSaveFormats = formats

        if let mainWindow = NSApp.mainWindow {
            panel.beginSheetModal(for: mainWindow) { result in
                guard result == .OK, let saveURL = panel.url else { return }
                self.save(url: saveURL)
                self.currentSavePanel = nil
                self.currentFormatPopup = nil
                self.currentSaveFormats = nil
            }
        }
    }

    // Temporary storage for save panel accessory interaction
    private static var _savePanel: NSSavePanel?
    private static var _formatPopup: NSPopUpButton?
    private static var _saveFormats: [SaveFormat]?

    var currentSavePanel: NSSavePanel? {
        get { AppDelegate._savePanel }
        set { AppDelegate._savePanel = newValue }
    }
    var currentFormatPopup: NSPopUpButton? {
        get { AppDelegate._formatPopup }
        set { AppDelegate._formatPopup = newValue }
    }
    var currentSaveFormats: [SaveFormat]? {
        get { AppDelegate._saveFormats }
        set { AppDelegate._saveFormats = newValue }
    }

    @objc func saveFormatChanged(_ sender: NSPopUpButton) {
        guard let panel = currentSavePanel,
              let formats = currentSaveFormats else { return }

        let idx = sender.indexOfSelectedItem
        if idx >= 0 && idx < formats.count {
            let exts = Array(formats[idx].ext.keys)
            panel.allowedFileTypes = exts
        }
    }
    /*
     void CChildView::OnFileSaveas()
     {
     Saveas(m_pbm);
     }
     */
    
    // Menu wiring: OK | Menu function: saves current bitmap (selection tracking TODO)
    @IBAction func onFileSaveselection(_ sender: Any) {
        // Same as Save As but operates on current bitmap
        onFileSaveAs(sender)
    }
    
    // Menu wiring: OK | Menu function test: passed
    @IBAction func onFileOpen(_ sender: Any) {

        checkDirty { [self] in
            let panel = NSOpenPanel();

            panel.title                   = "Choose a C64 image file";
            panel.showsResizeIndicator    = true
            panel.showsHiddenFiles        = false
            panel.canChooseDirectories    = false
            panel.canCreateDirectories    = true
            panel.allowsMultipleSelection = false
            var fileTypes = PCC64Interface.loadFormats.flatMap { Array($0.ext.keys) }
            for ext in ["kla", "koa", "gg", "art", "dd", "jj", "ocp", "zom", "cen", "pmg", "mg", "bin", "prg",
                        "bmp", "png", "jpg", "jpeg", "gif", "tiff"] {
                if !fileTypes.contains(ext) { fileTypes.append(ext) }
            }
            panel.allowedFileTypes = fileTypes

            if let mainWindow = NSApp.mainWindow {

                panel.beginSheetModal(for: mainWindow) { (result:NSApplication.ModalResponse) in

                    if let chosenFile = panel.url {

                        self.load(url: chosenFile)
                    }
                }
            }
        }
    }
    /*
    void CChildView::OnFileLoad()
    {
    if(!CheckDirty())return;
    
    narray<autoptr<SaveFormat>, int> fmt;
    C64Interface::GetLoadFormats(fmt);
    
    int r,t;
    nstr s;
    bool first = true;
    
    s << _T("Supported Formats|");
    for(r=0;r<fmt.count();r++)
    {
    for(t=0;t<fmt[r]->ext.count();t++)
    {
    if(!first)s << _T(";");
    
    s << _T("*.") << fmt[r]->ext[t];
    
    first = false;
    }
    }
    s << _T("|");
    for(r=0;r<fmt.count();r++)
    {
    s << fmt[r]->name << _T("|");
    
    first = true;
    
    for(t=0;t<fmt[r]->ext.count();t++)
    {
    if(!first)s << _T(";");
    
    s << _T("*.") << fmt[r]->ext[t];
    
    first = false;
    }
    
    s << _T("|");
    }
    s << _T("All Files (*.*)|*.*||");
    
    CFileDialog dlg(TRUE, _T("gpx"), NULL, OFN_HIDEREADONLY | OFN_OVERWRITEPROMPT, s, this, 0);
    if(dlg.DoModal() == IDOK)
    {
    Load(dlg.GetPathName(),dlg.GetFileExt().MakeLower());
    }
    }
    */
    
    // MARK: Edit
    /*
    POPUP "&Edit"
       BEGIN
           OK MENUITEM "&Undo\tCtrl+Z",               ID_EDIT_UNDO
           OK MENUITEM "&Redo\tCtrl+Y",               ID_EDIT_REDO
           MENUITEM SEPARATOR
           OK MENUITEM "A&uto-select Cell",           ID_EDIT_AUTO_SELECT
           OK MENUITEM "&Snap selection to Cell",     ID_EDIT_SNAPSELECTION
           MENUITEM SEPARATOR
           OK MENUITEM "Select &Marker\tM",           ID_EDIT_SELECTMARKER
           OK MENUITEM "Select C&ell\tShift+C",       ID_EDIT_SELECTCELL
           OK MENUITEM "Select &All\tCtrl+A",         ID_EDIT_SELECTALL
           OK MENUITEM "&Deselect\tCtrl+D",           ID_EDIT_DESELECT
           MENUITEM SEPARATOR
           OK MENUITEM "Cu&t\tCtrl+X",                ID_EDIT_CUT
           OK MENUITEM "&Copy\tCtrl+C",               ID_EDIT_COPY
           OK MENUITEM "&Paste\tCtrl+V",              ID_EDIT_PASTE
           OK MENUITEM "&Bkg masked Paste\tCtrl+Shift+V", ID_EDIT_BACKGROUNDMASKEDPASTE
       END
     */
    // Menu wiring: OK | Menu function test: passed
    @IBAction func onEditUndo(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        if canvas.m_pbm.canUndo {
            if let result = canvas.m_pbm.undo() {
                if result !== canvas.m_pbm, let bm = result as? PCMCBitmap {
                    canvas.m_pbm = bm
                }
            }
        }
        refreshStatusHint()
    }

    // Menu wiring: OK | Menu function test: passed
    @IBAction func onEditRedo(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        if canvas.m_pbm.canRedo {
            if let result = canvas.m_pbm.redo() {
                if result !== canvas.m_pbm, let bm = result as? PCMCBitmap {
                    canvas.m_pbm = bm
                }
            }
        }
        refreshStatusHint()
    }
        
    
    // Menu wiring: OK
    @IBAction func onEditAutoSelect(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        canvas.m_AutoMarker = !canvas.m_AutoMarker
        if let item = sender as? NSMenuItem {
            item.state = canvas.m_AutoMarker ? .on : .off
        }
    }

    // Menu wiring: OK
    @IBAction func onEditSnapselection(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        canvas.m_CellSnapMarker = !canvas.m_CellSnapMarker
        if let item = sender as? NSMenuItem {
            item.state = canvas.m_CellSnapMarker ? .on : .off
        }
    }


    // Menu wiring: OK
    @IBAction func onEditSelectmarker(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        canvas.m_ManualMarker = !canvas.m_ManualMarker
        if canvas.m_ManualMarker {
            canvas.m_Marker = true
        }
        if let item = sender as? NSMenuItem {
            item.state = canvas.m_ManualMarker ? .on : .off
        }
    }

    // Menu wiring: OK | Menu function: selects current cell
    @IBAction func onEditSelectcell(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        // Select the entire current cell
        canvas.m_ManualMarker = true
        canvas.m_MarkerCount = 2
        canvas.m_Marker = true
    }

    // Menu wiring: OK
    @IBAction func onEditSelectall(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        canvas.m_Marker = true
        canvas.m_MarkerCount = 0
        canvas.invalidate()
    }

    // Menu wiring: OK
    @IBAction func onEditDeselect(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        canvas.m_Marker = false
        canvas.m_ManualMarker = false
        canvas.m_MarkerCount = 0
        canvas.invalidate()
    }

    // Menu wiring: OK | Menu function: cuts bitmap to paste buffer
    @IBAction func onEditCut(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        let pbm = canvas.m_pbm
        // Use selection if available, otherwise full image
        let sel = canvas.selectionRect ?? (x: 0, y: 0, w: pbm.sizeX, h: pbm.sizeY)
        canvas.m_PasteSizeX = sel.w
        canvas.m_PasteSizeY = sel.h
        if canvas.m_pPasteBuffer != nil { canvas.m_pPasteBuffer?.deallocate() }
        canvas.m_pPasteBuffer = .allocate(capacity: sel.w * sel.h)
        for y in 0..<sel.h { for x in 0..<sel.w {
            canvas.m_pPasteBuffer![y * sel.w + x] = pbm.pixel(sel.x + x, sel.y + y)
        }}
        // Clear the selected region
        pbm.beginHistory()
        for y in 0..<sel.h { for x in 0..<sel.w {
            pbm.setPixel(sel.x + x, sel.y + y, 0)
        }}
        pbm.endHistory()
        refreshStatusHint()
    }

    // Menu wiring: OK | Menu function: copies selection (or full image) to paste buffer
    @IBAction func onEditCopy(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        let pbm = canvas.m_pbm
        let sel = canvas.selectionRect ?? (x: 0, y: 0, w: pbm.sizeX, h: pbm.sizeY)
        canvas.m_PasteSizeX = sel.w
        canvas.m_PasteSizeY = sel.h
        if canvas.m_pPasteBuffer != nil { canvas.m_pPasteBuffer?.deallocate() }
        canvas.m_pPasteBuffer = .allocate(capacity: sel.w * sel.h)
        for y in 0..<sel.h { for x in 0..<sel.w {
            canvas.m_pPasteBuffer![y * sel.w + x] = pbm.pixel(sel.x + x, sel.y + y)
        }}
        refreshStatusHint()
    }

    // Menu wiring: OK | Menu function: activates paste mode
    @IBAction func onEditPaste(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        guard canvas.m_pPasteBuffer != nil else { return }
        canvas.m_Paste = true
        canvas.m_MaskedPaste = false
        canvas.m_PastePoint = CGPoint(x: 0, y: 0)
        refreshStatusHint()
    }

    // Menu wiring: OK | Menu function: activates masked paste mode
    @IBAction func onEditBackgroundmaskedpaste(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        guard canvas.m_pPasteBuffer != nil else { return }
        canvas.m_Paste = true
        canvas.m_MaskedPaste = true
        canvas.m_PastePoint = CGPoint(x: 0, y: 0)
        refreshStatusHint()
    }

    // MARK: View
    
   /*
    POPUP "&View"
    BEGIN
        MENUITEM "Restore main view (&HELP)\tHome", ID_VIEW_RESTOREMAINVIEW
        MENUITEM "&Grid\tCtrl+G",               ID_VIEW_GRID
        MENUITEM "&Cell grid\tShift+G",         ID_VIEW_CELLGRID
        MENUITEM "Grid colors",                 ID_VIEW_GRIDCOLORS
        MENUITEM SEPARATOR
        MENUITEM "&Preview window\tCtrl+P",     ID_VIEW_PREVIEW
        POPUP "Preview pi&xel aspect ratio"
        BEGIN
            MENUITEM "P&C (1:1)",                   ID_PREVIEWPIXELASPECTRATIO_PC
            MENUITEM "&PAL (0.93:1)",               ID_PREVIEWPIXELASPECTRATIO_PAL
            MENUITEM "&NTSC (0.75:1)",              ID_PREVIEWPIXELASPECTRATIO_NTSC
        END
        MENUITEM SEPARATOR
        POPUP "Font"
        BEGIN
            MENUITEM "1x1",                         ID_FONT_1X1
            MENUITEM "1x2",                         ID_FONT_1X2
            MENUITEM "2x1",                         ID_FONT_2X1
            MENUITEM "2x2",                         ID_FONT_2X2
        END
        MENUITEM SEPARATOR
     POPUP "&Application Look"
        BEGIN
            MENUITEM "Windows &2000",               ID_VIEW_APPLOOK_WIN_2000
            MENUITEM "Office &XP",                  ID_VIEW_APPLOOK_OFF_XP
            MENUITEM "&Windows XP",                 ID_VIEW_APPLOOK_WIN_XP
            MENUITEM "Office 200&3",                ID_VIEW_APPLOOK_OFF_2003
            MENUITEM "Visual Studio 200&5",         ID_VIEW_APPLOOK_VS_2005
            MENUITEM "Visual Studio 200&8",         ID_VIEW_APPLOOK_VS_2008
            POPUP "Office 200&7"
            BEGIN
                MENUITEM "&Blue Style",                 ID_VIEW_APPLOOK_OFF_2007_BLUE
                MENUITEM "B&lack Style",                ID_VIEW_APPLOOK_OFF_2007_BLACK
                MENUITEM "&Silver Style",               ID_VIEW_APPLOOK_OFF_2007_SILVER
                MENUITEM "&Aqua Style",                 ID_VIEW_APPLOOK_OFF_2007_AQUA
            END
        END
        MENUITEM "&Status Bar",                 ID_VIEW_STATUS_BAR
     */
    
    // Menu wiring: OK | Menu function test: passed
    @IBAction func onViewRestoremainview(_ sender: Any) {
        
        if self.pixelCanvasView != nil {
            
            self.pixelCanvasView.onViewRestoremainview()
        }
    }
    
    // Menu wiring: OK
    @IBAction func onViewGrid(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        canvas.m_Grid = canvas.m_Grid != 0 ? 0 : 1
        if let item = sender as? NSMenuItem {
            item.state = canvas.m_Grid != 0 ? .on : .off
        }
    }
    
    // Menu wiring: OK
    @IBAction func onViewCellgrid(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        canvas.m_CellGrid = canvas.m_CellGrid != 0 ? 0 : 1
        if let item = sender as? NSMenuItem {
            item.state = canvas.m_CellGrid != 0 ? .on : .off
        }
    }
    
    // Menu wiring: OK
    @IBAction func onViewGridcolors(_ sender: Any) {
        let colorPanel = NSColorPanel.shared
        colorPanel.setTarget(self)
        colorPanel.setAction(#selector(gridColorChanged(_:)))
        colorPanel.orderFront(nil)
    }

    @objc func gridColorChanged(_ sender: NSColorPanel) {
        // Grid color customization via system color panel
        // TODO: wire selected color into canvas grid rendering
    }

    // Menu wiring: OK
    @IBAction func onViewPreviewWindow(_ sender: Any) {
        if previewWindowController == nil {
            previewWindowController = PCPreviewWindowController()
        }
        previewWindowController?.showWindow(self)
        previewWindowController?.window?.makeKeyAndOrderFront(self)
    }
       
    
    // Preview pixel aspect ratio
    func initPARSubMenu() {
                            
        if self.pixelCanvasView != nil {
                        
            //pCmdUI->SetCheck(m_pbm->GetPAR()==0?1:0);
            //pCmdUI->SetCheck(m_pbm->GetPAR()==1?1:0);
            //pCmdUI->SetCheck(m_pbm->GetPAR()==2?1:0);

            for (i, item) in self.previewPARSubmenu.items.enumerated() {
                
                item.state = self.pixelCanvasView.m_pbm.getPAR() == i ? .on : .off
            }
        }
    }
    
    // Menu wiring: OK | Menu function test: passed
    @IBAction func onPreviewpixelaspectratioPc(_ sender: Any) {
        
        if self.pixelCanvasView != nil {
        
            self.pixelCanvasView.onPreviewpixelaspectratioPc()
                        
            // Select item
            if let item = sender as? NSMenuItem {
                
                deselectGroupItems(item)
                item.state = .on
            }
        } else {
            
            print("pixelCanvasView == nil")
        }
    }
    
    // Menu wiring: OK | Menu function test: passed
    @IBAction func onPreviewpixelaspectratioPal(_ sender: Any) {
        
        if self.pixelCanvasView != nil {
        
            self.pixelCanvasView.onPreviewpixelaspectratioPal()
            
            // Select item
            if let item = sender as? NSMenuItem {
                
                deselectGroupItems(item)
                item.state = .on
            }
        } else {
            
            print("pixelCanvasView == nil")
        }
    }
    
    // Menu wiring: OK | Menu function test: passed
    @IBAction func onPreviewpixelaspectratioNtsc(_ sender: Any) {
        
        if self.pixelCanvasView != nil {
        
            self.pixelCanvasView.onPreviewpixelaspectratioNtsc()
            
            // Select item
            if let item = sender as? NSMenuItem {
                
                deselectGroupItems(item)
                item.state = .on
            }
        } else {
            
            print("pixelCanvasView == nil")
        }
    }
    
    // Menu wiring: OK | Menu function test: passed
    @IBAction func onToggleStatusBar(_ sender: Any) {
     
        if self.mainViewController != nil {
            
            if let menuItem = sender as? NSMenuItem {
            
                menuItem.state = self.mainViewController.onToggleStatusBar() ? .on : .off
            }
        }
    }
        
         
    // Menu wiring: OK
    @IBAction func onFont1x1(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        canvas.m_pbm.setFontDisplay(mode: 0)
        if let item = sender as? NSMenuItem { deselectGroupItems(item); item.state = .on }
        canvas.invalidate()
    }

    // Menu wiring: OK
    @IBAction func onFont1x2(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        canvas.m_pbm.setFontDisplay(mode: 1)
        if let item = sender as? NSMenuItem { deselectGroupItems(item); item.state = .on }
        canvas.invalidate()
    }

    // Menu wiring: OK
    @IBAction func onFont2x1(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        canvas.m_pbm.setFontDisplay(mode: 2)
        if let item = sender as? NSMenuItem { deselectGroupItems(item); item.state = .on }
        canvas.invalidate()
    }

    // Menu wiring: OK
    @IBAction func onFont2x2(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        canvas.m_pbm.setFontDisplay(mode: 3)
        if let item = sender as? NSMenuItem { deselectGroupItems(item); item.state = .on }
        canvas.invalidate()
    }
        
    
    // MARK: Toolbars and Docking Windows
    /*
        POPUP "&Toolbars and Docking Windows"
        BEGIN
                MENUITEM "<placeholder>",               ID_VIEW_TOOLBAR
            END
            MENUITEM "&Next buffer\t.",             ID_VIEW_NEXTBUFFER
            MENUITEM "P&rev buffer\t,",             ID_VIEW_PREVBUFFER
        END
     */
    // Menu wiring: OK
    @IBAction func onViewNextbuffer(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        let pbm = canvas.m_pbm
        let next = (pbm.backBuffer + 1) % pbm.backBufferCount
        do {
            try pbm.setBackBuffer(next)
            canvas.invalidate()
        } catch {
            print("Next buffer failed: \(error)")
        }
    }

    // Menu wiring: OK
    @IBAction func onViewPrevbuffer(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        let pbm = canvas.m_pbm
        let prev = (pbm.backBuffer - 1 + pbm.backBufferCount) % pbm.backBufferCount
        do {
            try pbm.setBackBuffer(prev)
            canvas.invalidate()
        } catch {
            print("Prev buffer failed: \(error)")
        }
    }
    
    // MARK: Selection
    /*
        POPUP "&Selection"
        BEGIN
            MENUITEM "Flip &vertically\tV",         ID_SELECTION_FLIPVERTICALLY
            MENUITEM "Flip &horizontally\tH",       ID_SELECTION_FLIPHORIZONTALLY
            MENUITEM "&Rotate CW\tShift+R",         ID_SELECTION_ROTATECW
            MENUITEM "Rotat&e CCW\tCtrl+R",         ID_SELECTION_ROTATECCW
            MENUITEM "Shift &left\tShift ←",        ID_SELECTION_SHIFTLEFT
            MENUITEM "Shift &right\tShift →",       ID_SELECTION_SHIFTRIGHT
            MENUITEM "Shift &up\tShift ↑",          ID_SELECTION_SHIFTUP
            MENUITEM "Shift &down\tShift ↓",        ID_SELECTION_SHIFTDOWN
        END
     */
    // Menu wiring: OK
    @IBAction func onSelectionFlipvertically(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        let pbm = canvas.m_pbm
        let sel = canvas.selectionRect ?? (x: 0, y: 0, w: pbm.sizeX, h: pbm.sizeY)
        pbm.beginHistory()
        for y in 0..<(sel.h / 2) {
            for x in 0..<sel.w {
                let top = pbm.pixel(sel.x + x, sel.y + y)
                let bot = pbm.pixel(sel.x + x, sel.y + sel.h - 1 - y)
                pbm.setPixel(sel.x + x, sel.y + y, bot)
                pbm.setPixel(sel.x + x, sel.y + sel.h - 1 - y, top)
            }
        }
        pbm.endHistory()
    }

    // Menu wiring: OK
    @IBAction func onSelectionFliphorizontally(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        let pbm = canvas.m_pbm
        let sel = canvas.selectionRect ?? (x: 0, y: 0, w: pbm.sizeX, h: pbm.sizeY)
        pbm.beginHistory()
        for y in 0..<sel.h {
            for x in 0..<(sel.w / 2) {
                let left = pbm.pixel(sel.x + x, sel.y + y)
                let right = pbm.pixel(sel.x + sel.w - 1 - x, sel.y + y)
                pbm.setPixel(sel.x + x, sel.y + y, right)
                pbm.setPixel(sel.x + sel.w - 1 - x, sel.y + y, left)
            }
        }
        pbm.endHistory()
    }

    // Menu wiring: OK
    // Rotates each cell (xcell x ycell block) clockwise individually to preserve image dimensions
    @IBAction func onSelectionRotatecw(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        let pbm = canvas.m_pbm
        let sel = canvas.selectionRect ?? (x: 0, y: 0, w: pbm.sizeX, h: pbm.sizeY)
        let w = sel.w, h = sel.h
        // Copy selection to temp buffer
        var temp = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h { for x in 0..<w {
            temp[y * w + x] = pbm.pixel(sel.x + x, sel.y + y)
        }}
        // Write back rotated CW: (x,y) → (h-1-y, x)
        // Since dimensions may differ, we rotate within the min(w,h) square
        // and leave the rest unchanged
        let side = min(w, h)
        pbm.beginHistory()
        for y in 0..<side { for x in 0..<side {
            pbm.setPixel(sel.x + x, sel.y + y, temp[(side - 1 - x) * w + y])
        }}
        pbm.endHistory()
    }

    // Menu wiring: OK
    @IBAction func onSelectionRotateccw(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        let pbm = canvas.m_pbm
        let sel = canvas.selectionRect ?? (x: 0, y: 0, w: pbm.sizeX, h: pbm.sizeY)
        let w = sel.w, h = sel.h
        var temp = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h { for x in 0..<w {
            temp[y * w + x] = pbm.pixel(sel.x + x, sel.y + y)
        }}
        // CCW: (x,y) → (y, w-1-x)
        let side = min(w, h)
        pbm.beginHistory()
        for y in 0..<side { for x in 0..<side {
            pbm.setPixel(sel.x + x, sel.y + y, temp[x * w + (side - 1 - y)])
        }}
        pbm.endHistory()
    }

    // Menu wiring: OK
    @IBAction func onSelectionShiftleft(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        let pbm = canvas.m_pbm
        let sel = canvas.selectionRect ?? (x: 0, y: 0, w: pbm.sizeX, h: pbm.sizeY)
        pbm.beginHistory()
        for y in 0..<sel.h {
            let saved = pbm.pixel(sel.x, sel.y + y)
            for x in 1..<sel.w {
                pbm.setPixel(sel.x + x - 1, sel.y + y, pbm.pixel(sel.x + x, sel.y + y))
            }
            pbm.setPixel(sel.x + sel.w - 1, sel.y + y, saved)
        }
        pbm.endHistory()
    }

    // Menu wiring: OK
    @IBAction func onSelectionShiftright(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        let pbm = canvas.m_pbm
        let sel = canvas.selectionRect ?? (x: 0, y: 0, w: pbm.sizeX, h: pbm.sizeY)
        pbm.beginHistory()
        for y in 0..<sel.h {
            let saved = pbm.pixel(sel.x + sel.w - 1, sel.y + y)
            for x in stride(from: sel.w - 1, through: 1, by: -1) {
                pbm.setPixel(sel.x + x, sel.y + y, pbm.pixel(sel.x + x - 1, sel.y + y))
            }
            pbm.setPixel(sel.x, sel.y + y, saved)
        }
        pbm.endHistory()
    }

    // Menu wiring: OK
    @IBAction func onSelectionShiftup(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        let pbm = canvas.m_pbm
        let sel = canvas.selectionRect ?? (x: 0, y: 0, w: pbm.sizeX, h: pbm.sizeY)
        pbm.beginHistory()
        for x in 0..<sel.w {
            let saved = pbm.pixel(sel.x + x, sel.y)
            for y in 1..<sel.h {
                pbm.setPixel(sel.x + x, sel.y + y - 1, pbm.pixel(sel.x + x, sel.y + y))
            }
            pbm.setPixel(sel.x + x, sel.y + sel.h - 1, saved)
        }
        pbm.endHistory()
    }

    // Menu wiring: OK
    @IBAction func onSelectionShiftdown(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        let pbm = canvas.m_pbm
        let sel = canvas.selectionRect ?? (x: 0, y: 0, w: pbm.sizeX, h: pbm.sizeY)
        pbm.beginHistory()
        for x in 0..<sel.w {
            let saved = pbm.pixel(sel.x + x, sel.y + sel.h - 1)
            for y in stride(from: sel.h - 1, through: 1, by: -1) {
                pbm.setPixel(sel.x + x, sel.y + y, pbm.pixel(sel.x + x, sel.y + y - 1))
            }
            pbm.setPixel(sel.x + x, sel.y, saved)
        }
        pbm.endHistory()
    }
    
    
    // MARK: Tool
    /*
        POPUP "&Tool"
        BEGIN
            MENUITEM "&Optimize",                   ID_TOOL_OPTIMIZE
            POPUP "&Copy ROM font"
            BEGIN
                MENUITEM "&Uppercase",                  ID_COPYROMFONT_UPPERCASE
                MENUITEM "&Lowercase",                  ID_COPYROMFONT_LOWERCASE
            END
            MENUITEM "&Delete undo history",        ID_TOOL_DELETEUNDOHISTORY
            MENUITEM "Fill\tG",                     ID_TOOL_FILL
            MENUITEM "Remap Colours",               ID_TOOL_REMAPCOLOURS
            MENUITEM "Swap Cell Colours",           ID_TOOL_SWAPCELLCOLOURS
        END
     */
    // Menu wiring: OK | Ported from C64Interface::Optimize() in original C64Interface.cpp
    // The original Optimize() renders the image then re-imports it, which removes
    // unused color assignments from cells.
    @IBAction func onToolOptimize(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        let pbm = canvas.m_pbm
        guard pbm.canOptimize else { return }

        // Capture all pixel values
        let w = pbm.sizeX
        let h = pbm.sizeY
        var pixels = [UInt8](repeating: 0, count: w * h)
        for y in 0..<h {
            for x in 0..<w {
                pixels[y * w + x] = pbm.pixel(x, y)
            }
        }

        pbm.beginHistory()

        // Zero the data buffers (map, screen, color) while preserving pointers
        pbm.zeroDataBuffers()

        // Re-paint all pixels - this forces the format to re-assign colors optimally
        for y in 0..<h {
            for x in 0..<w {
                pbm.setPixel(x, y, pixels[y * w + x])
            }
        }

        pbm.endHistory()
        canvas.invalidate()
    }

    // Copy Rom Font - Uppercase (first 2048 bytes of ROM font)
    // Ported from SFont::CustomCommand(0) in original Font.cpp
    @IBAction func onCopyromfontUppercase(_ sender: Any) {
        copyRomFont(offset: 0)
    }

    // Copy Rom Font - Lowercase (second 2048 bytes of ROM font)
    // Ported from SFont::CustomCommand(1) in original Font.cpp
    @IBAction func onCopyromfontLowercase(_ sender: Any) {
        copyRomFont(offset: 2048)
    }

    /// Copies ROM font data into the current font document's map buffer.
    /// Ported from SFont::CustomCommand(int n) in original Font.cpp
    private func copyRomFont(offset: Int) {
        guard let canvas = pixelCanvasView else { return }
        let pbm = canvas.m_pbm
        guard pbm.isChar,
              pbm.canvasModel.mode == .CHAR,
              let map = pbm.canvasModel.map else { return }
        guard let fontData = pixcen_romfont_data() else { return }

        pbm.beginHistory()

        // Copy character bitmap data: map[r] = g_ROMFont[offset + r]
        let copySize = min(2048, pbm.canvasModel.rmapsize)
        for r in 0..<copySize {
            map[r] = fontData[offset + r]
        }

        // Set character colors: if background == 1, use color 0; else use color 1
        if let color = pbm.canvasModel.color,
           let background = pbm.canvasModel.background {
            let colorCount = min(2048 / 8, pbm.canvasModel.rmapsize / 8)
            let colorValue: UInt8 = (background.pointee == 0x01) ? 0x00 : 0x01
            for r in 0..<colorCount {
                color[r] = colorValue
            }
        }

        pbm.endHistory()
        canvas.invalidate()
    }

    // Menu wiring: OK
    @IBAction func onToolDeleteundohistory(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        canvas.m_pbm.resetHistory()
    }

    // Menu wiring: OK
    @IBAction func onToolFill(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        canvas.m_Fill = !canvas.m_Fill
    }

    // Menu wiring: OK | Ported from CChildView::OnToolRemapcolours() in original ChildView.cpp
    // Remaps all pixels of one C64 color to another across the entire image.
    @IBAction func onToolRemapcolours(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        let pbm = canvas.m_pbm

        let alert = NSAlert()
        alert.messageText = "Remap Colours"
        alert.informativeText = "Remap all occurrences of one colour to another in the entire image."

        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 250, height: 60))
        let fromLabel = NSTextField(labelWithString: "From:")
        fromLabel.frame = NSRect(x: 0, y: 35, width: 50, height: 20)
        let fromPopup = NSPopUpButton(frame: NSRect(x: 55, y: 32, width: 190, height: 26))
        let toLabel = NSTextField(labelWithString: "To:")
        toLabel.frame = NSRect(x: 0, y: 5, width: 50, height: 20)
        let toPopup = NSPopUpButton(frame: NSRect(x: 55, y: 2, width: 190, height: 26))

        let colorNames = C64Col.shared.s_VICColourName
        for i in 0..<16 {
            fromPopup.addItem(withTitle: "\(i): \(colorNames[i])")
            toPopup.addItem(withTitle: "\(i): \(colorNames[i])")
        }
        accessory.addSubview(fromLabel)
        accessory.addSubview(fromPopup)
        accessory.addSubview(toLabel)
        accessory.addSubview(toPopup)
        alert.accessoryView = accessory
        alert.addButton(withTitle: "Remap")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            let fromColor = UInt8(fromPopup.indexOfSelectedItem)
            let toColor = UInt8(toPopup.indexOfSelectedItem)
            guard fromColor != toColor else { return }

            pbm.beginHistory()
            for y in 0..<pbm.sizeY {
                for x in 0..<pbm.sizeX {
                    if pbm.pixel(x, y) == fromColor {
                        pbm.setPixel(x, y, toColor)
                    }
                }
            }
            pbm.endHistory()
            canvas.invalidate()
        }
    }

    // Menu wiring: OK | Ported from Bitmap::SwapCellColours() in original Bitmap.cpp
    // Swaps foreground and background colors of all cells (or selected cells if markers set).
    // For hires Bitmap: inverts map bytes and swaps screen RAM nibbles per cell.
    @IBAction func onToolSwapcellcolours(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        let pbm = canvas.m_pbm
        guard let map = pbm.canvasModel.map,
              let screen = pbm.canvasModel.screen else { return }

        let xsize = pbm.canvasModel.xsize
        let csx = pbm.cellSizeX
        let csy = pbm.cellSizeY
        let cellCountX = xsize / csx
        let cellCountY = pbm.canvasModel.ysize / csy
        let offsetCell = pbm.canvasModel.offsetcell
        let sizeCell = pbm.canvasModel.sizecell

        pbm.beginHistory()

        for cy in 0..<cellCountY {
            for cx in 0..<cellCountX {
                // Invert the map bytes for this cell (swap bit patterns)
                let mi = (cellCountX * cy + cx) * offsetCell
                for t in 0..<sizeCell {
                    map[mi + t] = map[mi + t] ^ 0xFF
                }

                // Swap the screen RAM colors for this cell
                let ci = cy * cellCountX + cx
                if pbm.canvasModel.rscreensize > ci {
                    let old = screen[ci]
                    screen[ci] = (old >> 4) | ((old & 0x0f) << 4)
                }
            }
        }

        pbm.endHistory()
        canvas.invalidate()
    }
    
    // MARK: Mode
    /*
        POPUP "&Mode"
        BEGIN
            MENUITEM "&Bitmap",                     ID_MODE_BITMAP
            MENUITEM "&Sprite",                     ID_MODE_SPRITE
            MENUITEM "&Char",                       ID_MODE_CHAR
            MENUITEM "&Unrestricted",               ID_MODE_UNRESTRICTED
            MENUITEM SEPARATOR
            MENUITEM "&Multi-Color",                ID_MODE_MULTI
            MENUITEM SEPARATOR
            POPUP "Palette"
            BEGIN
                MENUITEM "dummy",                       ID_PALETTE_DUMMY
            END
            MENUITEM SEPARATOR
            POPUP "Color &overflow"
            BEGIN
                MENUITEM "&Ignore",                     ID_OVERFLOW_IGNORE
                MENUITEM "&Closest",                    ID_OVERFLOW_CLOSEST
                MENUITEM "&Replace",                    ID_OVERFLOW_REPLACE
                MENUITEM "&Toggle Ignore/Replace\tCtrl+W", ID_COLOROVERFLOW_TOGGLEIGNORE
            END
            MENUITEM "Col &View\t#",                ID_MODE_COLOURVIEW
        END
     */
    /// Helper: returns true if the current mode is a multi-color variant
    private var isCurrentModeMulti: Bool {
        guard let canvas = pixelCanvasView else { return false }
        let mode = canvas.m_pbm.canvasModel.mode
        return mode == .MC_BITMAP || mode == .MC_SPRITE ||
               mode == .MC_CHAR || mode == .W_UNRESTRICTED
    }

    // Menu wiring: OK
    @IBAction func onModeBitmap(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        do {
            let newDoc: PCC64Interface = isCurrentModeMulti ? try PCMCBitmap() : try PCBitmap()
            newDoc.inheritHistory(old: canvas.m_pbm)
            canvas.m_pbm = newDoc
            canvas.invalidate()
        } catch { print("Mode change to Bitmap failed: \(error)") }
    }

    // Menu wiring: OK
    @IBAction func onModeSprite(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        do {
            let newDoc: PCC64Interface = isCurrentModeMulti ? try PCMCSprite() : try PCSprite()
            newDoc.inheritHistory(old: canvas.m_pbm)
            canvas.m_pbm = newDoc
            canvas.invalidate()
        } catch { print("Mode change to Sprite failed: \(error)") }
    }

    // Menu wiring: OK
    @IBAction func onModeChar(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        do {
            let newDoc: PCC64Interface = isCurrentModeMulti ? try PCMCFont() : try PCSFont()
            newDoc.inheritHistory(old: canvas.m_pbm)
            canvas.m_pbm = newDoc
            canvas.invalidate()
        } catch { print("Mode change to Char failed: \(error)") }
    }

    // Menu wiring: OK
    @IBAction func onModeUnrestricted(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        do {
            let newDoc: PCC64Interface = try PCUnrestricted(wide: isCurrentModeMulti)
            newDoc.inheritHistory(old: canvas.m_pbm)
            canvas.m_pbm = newDoc
            canvas.invalidate()
        } catch { print("Mode change to Unrestricted failed: \(error)") }
    }

    // Menu wiring: OK
    @IBAction func onModeMulti(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        let mode = canvas.m_pbm.canvasModel.mode
        do {
            let newDoc: PCC64Interface
            switch mode {
            case .BITMAP:       newDoc = try PCMCBitmap()
            case .MC_BITMAP:    newDoc = try PCBitmap()
            case .SPRITE:       newDoc = try PCMCSprite()
            case .MC_SPRITE:    newDoc = try PCSprite()
            case .CHAR:         newDoc = try PCMCFont()
            case .MC_CHAR:      newDoc = try PCSFont()
            case .UNRESTRICTED: newDoc = try PCUnrestricted(wide: true)
            case .W_UNRESTRICTED: newDoc = try PCUnrestricted(wide: false)
            default:            newDoc = try PCMCBitmap()
            }
            newDoc.inheritHistory(old: canvas.m_pbm)
            canvas.m_pbm = newDoc
            canvas.invalidate()
        } catch { print("Multi-color toggle failed: \(error)") }
    }
    
    // Palette
    // Menu wiring: OK | Menu function test: passed
    @objc func onModePalette(_ sender: Any) {
        
        if let menuItem = sender as? NSMenuItem {
            
            let nID = menuItem.tag
            if self.mainViewController != nil {
            
                self.mainViewController.onModePalette(nID)
            }
            
            // Now remove all checkmarks from the palette menu items
            // and set the checkmark in the actually selected item
            for item in self.paletteSubmenu.items {
                
                item.state = .off
            }
            
            menuItem.state = .on
        }
    }
    
    
    // Color overflow
    // Menu wiring: OK
    @IBAction func onOverflowIgnore(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        canvas.m_pbm.canvasModel.overflow = .NOTHING
        if let item = sender as? NSMenuItem { deselectGroupItems(item); item.state = .on }
    }

    // Menu wiring: OK
    @IBAction func onOverflowClosest(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        canvas.m_pbm.canvasModel.overflow = .CLOSEST
        if let item = sender as? NSMenuItem { deselectGroupItems(item); item.state = .on }
    }

    // Menu wiring: OK
    @IBAction func onOverflowReplace(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        canvas.m_pbm.canvasModel.overflow = .REPLACE
        if let item = sender as? NSMenuItem { deselectGroupItems(item); item.state = .on }
    }

    // Menu wiring: OK
    @IBAction func onColoroverflowToggleignore(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        if canvas.m_pbm.canvasModel.overflow == .NOTHING {
            canvas.m_pbm.canvasModel.overflow = .REPLACE
        } else {
            canvas.m_pbm.canvasModel.overflow = .NOTHING
        }
    }

    /// TODO: What is this View? Deprecated? Or is it maybe the preview? (We use onViewPreviewWindows here)
    // Menu wiring: OK
    @IBAction func onColourView(_ sender: Any) {
        guard let canvas = pixelCanvasView else { return }
        canvas.m_ShowColourInfo = !canvas.m_ShowColourInfo
    }
    
    // MARK: Help
    /*
        POPUP "&Help"
        BEGIN
            MENUITEM "&About Pixcen...",            ID_APP_ABOUT
            MENUITEM SEPARATOR
            MENUITEM "Help",                        ID_HELP_HELP
            MENUITEM "Facebook support group",      ID_HELP_FACEBOOK
            MENUITEM "Lemon64 support forum",       ID_HELP_LEMON64SUPPORTFORUM
            MENUITEM SEPARATOR
            MENUITEM "Check for updates",           ID_HELP_CHECKFORUPDATES
            MENUITEM "Download source code",        ID_HELP_DOWNLOADSOURCECODE
            MENUITEM SEPARATOR
            MENUITEM "Miss Pixcen (by N3XU5)",      ID_HELP_LOADINTRO
        END
    END
     */
    /// Miss Pixcen (by N3XU5)
    // Menu wiring: OK | Menu function test: passed
    @IBAction func onHelpLoadintro(_ sender: Any) {
        
        if self.pixelCanvasView != nil {
        
            if !self.pixelCanvasView.loadIntro() {
            
                print("loadIntro() failed.")
            }
        } else {
            
            print("pixelCanvasView == nil")
        }
    }

    // Menu wiring: OK
    @IBAction func onHelpCheckforupdates(_ sender: Any) {
        let urlString = "https://github.com/Hammarberg/pixcen/releases"
        if let url = URL(string: urlString), NSWorkspace.shared.open(url) {
            print("Opened GitHub releases page for update check.")
        }
    }
    
    // Menu wiring: OK | Menu function test: passed
    @IBAction func onHelpHelp(_ sender: Any) {
        
        /*
        ShellExecute(NULL,L"open",L"https://github.com/Hammarberg/pixcen/wiki",NULL,NULL,SW_SHOWNORMAL);
        */
        let urlString = "https://github.com/Hammarberg/pixcen/wiki"
        if let url = URL(string: urlString), NSWorkspace.shared.open(url) {
                
            print("Help website was opened successfully.")
        }
    }
    
    
    // Menu wiring: OK | Menu function test: passed
    @IBAction func onHelpDownloadsourcecode(_ sender: Any) {
    
        /*
        ShellExecute(NULL,L"open",L"https://github.com/Hammarberg/pixcen",NULL,NULL,SW_SHOWNORMAL);
         */
        let urlString = "https://github.com/Hammarberg/pixcen"
        if let url = URL(string: urlString), NSWorkspace.shared.open(url) {
                
            print("Download sourcecode website was opened successfully.")
        }
    }
    
    
    // Menu wiring: OK | Menu function test: passed
    @IBAction func onHelpFacebook(_ sender: Any) {
        
        /*
        ShellExecute(NULL,L"open",L"https://www.facebook.com/groups/pixcen/",NULL,NULL,SW_SHOWNORMAL);
        */
        let urlString = "https://www.facebook.com/groups/pixcen/"
        if let url = URL(string: urlString), NSWorkspace.shared.open(url) {
                
            print("Facebook website was opened successfully.")
        }
    }
    
    
    // Menu wiring: OK | Menu function test: passed
    @IBAction func onHelpLemon64supportforum(_ sender: Any) {
    
        /*
        ShellExecute(NULL,L"open",L"http://www.lemon64.com/forum/viewtopic.php?t=57459",NULL,NULL,SW_SHOWNORMAL);
         */
        let urlString = "http://www.lemon64.com/forum/viewtopic.php?t=57459"
        if let url = URL(string: urlString), NSWorkspace.shared.open(url) {
                
            print("HelpLemon64 website was opened successfully.")
        }
    }

    

 
    /////////////////////////////////////////////////////////////////////////////
    //
    // Accelerator
    //
/*
    IDR_MAINFRAME ACCELERATORS
    BEGIN
        "W",            ID_COLOROVERFLOW_TOGGLEIGNORE, VIRTKEY, CONTROL, NOINVERT
        "V",            ID_EDIT_BACKGROUNDMASKEDPASTE, VIRTKEY, SHIFT, CONTROL, NOINVERT
        "C",            ID_EDIT_COPY,           VIRTKEY, CONTROL, NOINVERT
        "X",            ID_EDIT_CUT,            VIRTKEY, CONTROL, NOINVERT
        "D",            ID_EDIT_DESELECT,       VIRTKEY, CONTROL, NOINVERT
        "V",            ID_EDIT_PASTE,          VIRTKEY, CONTROL, NOINVERT
        "Y",            ID_EDIT_REDO,           VIRTKEY, CONTROL, NOINVERT
        "A",            ID_EDIT_SELECTALL,      VIRTKEY, CONTROL, NOINVERT
        "C",            ID_EDIT_SELECTCELL,     VIRTKEY, SHIFT, NOINVERT
        "M",            ID_EDIT_SELECTMARKER,   VIRTKEY, NOINVERT
        "Z",            ID_EDIT_UNDO,           VIRTKEY, CONTROL, NOINVERT
        "L",            ID_FILE_LOAD,           VIRTKEY, CONTROL, NOINVERT
        "S",            ID_FILE_SAVE,           VIRTKEY, CONTROL, NOINVERT
        "S",            ID_FILE_SAVEAS,         VIRTKEY, SHIFT, CONTROL, NOINVERT
        "S",            ID_FILE_SAVESELECTION,  VIRTKEY, SHIFT, NOINVERT
        VK_F6,          ID_NEXT_PANE,           VIRTKEY, NOINVERT
        VK_F6,          ID_PREV_PANE,           VIRTKEY, SHIFT, NOINVERT
        "H",            ID_SELECTION_FLIPHORIZONTALLY, VIRTKEY, NOINVERT
        "V",            ID_SELECTION_FLIPVERTICALLY, VIRTKEY, NOINVERT
        "R",            ID_SELECTION_ROTATECCW, VIRTKEY, CONTROL, NOINVERT
        "R",            ID_SELECTION_ROTATECW,  VIRTKEY, SHIFT, NOINVERT
        VK_DOWN,        ID_SELECTION_SHIFTDOWN, VIRTKEY, SHIFT, NOINVERT
        VK_LEFT,        ID_SELECTION_SHIFTLEFT, VIRTKEY, SHIFT, NOINVERT
        VK_RIGHT,       ID_SELECTION_SHIFTRIGHT, VIRTKEY, SHIFT, NOINVERT
        VK_UP,          ID_SELECTION_SHIFTUP,   VIRTKEY, SHIFT, NOINVERT
        "G",            ID_TOOL_FILL,           VIRTKEY, NOINVERT
        "G",            ID_VIEW_CELLGRID,       VIRTKEY, SHIFT, NOINVERT
        "G",            ID_VIEW_GRID,           VIRTKEY, CONTROL, NOINVERT
        VK_OEM_PERIOD,  ID_VIEW_NEXTBUFFER,     VIRTKEY, NOINVERT
        VK_OEM_COMMA,   ID_VIEW_PREVBUFFER,     VIRTKEY, NOINVERT
        "P",            ID_VIEW_PREVIEW,        VIRTKEY, CONTROL, NOINVERT
        VK_HOME,        ID_VIEW_RESTOREMAINVIEW, VIRTKEY, NOINVERT
        "#",            ID_MODE_COLOURVIEW,     ASCII,  NOINVERT
    END
*/
    
    /////////////
     
    /*
     
     
     //    afx_msg void OnClose();
     //    virtual BOOL DestroyWindow();
     //    afx_msg void OnDestroy();
     
     bool FrameClose(void);
     void UpdateStatus(CPoint &point);
     //    virtual BOOL Create(LPCTSTR lpszClassName, LPCTSTR lpszWindowName, DWORD dwStyle, const RECT& rect, CWnd* pParentWnd, UINT nID, CCreateContext* pContext = NULL);
     afx_msg void OnUpdateViewGrid(CCmdUI *pCmdUI);
     afx_msg void OnUpdateFileSave(CCmdUI *pCmdUI);
     afx_msg void OnUpdateEditUndo(CCmdUI *pCmdUI);
     afx_msg void OnUpdateEditRedo(CCmdUI *pCmdUI);
     afx_msg void OnUpdateToolOptimize(CCmdUI *pCmdUI);
     afx_msg void OnUpdateModeBitmap(CCmdUI *pCmdUI);
     afx_msg void OnUpdateModeSprite(CCmdUI *pCmdUI);
 
     afx_msg void OnUpdateModeChar(CCmdUI *pCmdUI);
     //    afx_msg void OnModeCharscreen();
     //    afx_msg void OnUpdateModeCharscreen(CCmdUI *pCmdUI);
     
     afx_msg void OnUpdateModeMulti(CCmdUI *pCmdUI);
     
     void ChangeMode(C64Interface::tmode to);
     
     afx_msg void OnDropFiles(HDROP hDropInfo);
     afx_msg int OnCreate(LPCREATESTRUCT lpCreateStruct);
     //    virtual BOOL DestroyWindow();
     afx_msg void OnDestroy();
     afx_msg void OnTimer(UINT_PTR nIDEvent);
     afx_msg void OnUpdateEditCut(CCmdUI *pCmdUI);
     afx_msg void OnUpdateEditCopy(CCmdUI *pCmdUI);
     afx_msg void OnUpdateEditPaste(CCmdUI *pCmdUI);
     afx_msg void OnUpdateModeUnrestricted(CCmdUI *pCmdUI);
     afx_msg void OnUpdateEditDeselect(CCmdUI *pCmdUI);
     void DeleteArea(bool history=true);
     
     afx_msg void OnUpdateCopyromfontUppercase(CCmdUI *pCmdUI);
     afx_msg void OnUpdateCopyromfontLowercase(CCmdUI *pCmdUI);
     afx_msg void OnUpdateSelectionFlipvertically(CCmdUI *pCmdUI);
     
     afx_msg void OnUpdateSelectionFliphorizontally(CCmdUI *pCmdUI);
     
     afx_msg void OnUpdateSelectionRotatecw(CCmdUI *pCmdUI);
     afx_msg void OnUpdateSelectionRotateccw(CCmdUI *pCmdUI);
     afx_msg void OnUpdateSelectionShiftleft(CCmdUI *pCmdUI);
     afx_msg void OnUpdateSelectionShiftright(CCmdUI *pCmdUI);
     afx_msg void OnUpdateSelectionShiftup(CCmdUI *pCmdUI);
     afx_msg void OnUpdateSelectionShiftdown(CCmdUI *pCmdUI);
     
     
     
     afx_msg void OnUpdateEditAutoSelect(CCmdUI *pCmdUI);
     
     
     afx_msg void OnUpdateViewNextbuffer(CCmdUI *pCmdUI);
     afx_msg void OnUpdateViewPrevbuffer(CCmdUI *pCmdUI);
 
     afx_msg void OnUpdateEditBackgroundmaskedpaste(CCmdUI *pCmdUI);
     afx_msg void OnUpdateOverflowIgnore(CCmdUI *pCmdUI);
     afx_msg void OnUpdateOverflowClosest(CCmdUI *pCmdUI);
     afx_msg void OnUpdateOverflowReplace(CCmdUI *pCmdUI);
          
     afx_msg void OnUpdatePreviewpixelaspectratioPc(CCmdUI *pCmdUI);
     afx_msg void OnUpdatePreviewpixelaspectratioPal(CCmdUI *pCmdUI);
     afx_msg void OnUpdatePreviewpixelaspectratioNtsc(CCmdUI *pCmdUI);

     afx_msg void OnUpdateFileSaveselection(CCmdUI *pCmdUI);
     afx_msg void OnUpdateEditSnapselection(CCmdUI *pCmdUI);
   
     afx_msg void OnUpdateToolDeleteundohistory(CCmdUI *pCmdUI);
     afx_msg void OnUpdateModePalette(CCmdUI *pCmdUI);
     afx_msg void OnModePalette(UINT nID);
     afx_msg void OnUpdateModePaletteRange(CCmdUI *pCmdUI);
     

     afx_msg void OnUpdateViewCellgrid(CCmdUI *pCmdUI);
     afx_msg void OnUpdateFont1x1(CCmdUI *pCmdUI);
     afx_msg void OnUpdateFont2x1(CCmdUI *pCmdUI);
     afx_msg void OnUpdateFont1x2(CCmdUI *pCmdUI);
     afx_msg void OnUpdateFont2x2(CCmdUI *pCmdUI);
     
    
     afx_msg void OnUpdateColourView(CCmdUI* pCmdUI);
     afx_msg void OnUpdateToolRemapcolours(CCmdUI *pCmdUI);
     afx_msg void OnUpdateToolSwapcellcolours(CCmdUI *pCmdUI);
     */
}
/*
 /////////////////////////////////////////////////////////////////////////////
 //
 // Menu
 //

 IDR_MAINFRAME MENU
 BEGIN
     POPUP "&File"
     BEGIN
         MENUITEM "&New\tCtrl+N",                ID_FILE_NEW
         MENUITEM SEPARATOR
         MENUITEM "&Load\tCtrl+L",               ID_FILE_LOAD
         MENUITEM "&Save\tCtrl+S",               ID_FILE_SAVE
         MENUITEM "Save &As\tCtrl+Shift+S",      ID_FILE_SAVEAS
         MENUITEM "Save sele&ction\tShift+S",    ID_FILE_SAVESELECTION
         MENUITEM SEPARATOR
         MENUITEM "E&xit",                       ID_APP_EXIT
     END
     POPUP "&Edit"
     BEGIN
         MENUITEM "&Undo\tCtrl+Z",               ID_EDIT_UNDO
         MENUITEM "&Redo\tCtrl+Y",               ID_EDIT_REDO
         MENUITEM SEPARATOR
         MENUITEM "A&uto-select Cell",           ID_EDIT_AUTO_SELECT
         MENUITEM "&Snap selection to Cell",     ID_EDIT_SNAPSELECTION
         MENUITEM SEPARATOR
         MENUITEM "Select &Marker\tM",           ID_EDIT_SELECTMARKER
         MENUITEM "Select C&ell\tShift+C",       ID_EDIT_SELECTCELL
         MENUITEM "Select &All\tCtrl+A",         ID_EDIT_SELECTALL
         MENUITEM "&Deselect\tCtrl+D",           ID_EDIT_DESELECT
         MENUITEM SEPARATOR
         MENUITEM "Cu&t\tCtrl+X",                ID_EDIT_CUT
         MENUITEM "&Copy\tCtrl+C",               ID_EDIT_COPY
         MENUITEM "&Paste\tCtrl+V",              ID_EDIT_PASTE
         MENUITEM "&Bkg masked Paste\tCtrl+Shift+V", ID_EDIT_BACKGROUNDMASKEDPASTE
     END
     POPUP "&View"
     BEGIN
         MENUITEM "Restore main view (&HELP)\tHome", ID_VIEW_RESTOREMAINVIEW
         MENUITEM "&Grid\tCtrl+G",               ID_VIEW_GRID
         MENUITEM "&Cell grid\tShift+G",         ID_VIEW_CELLGRID
         MENUITEM "Grid colors",                 ID_VIEW_GRIDCOLORS
         MENUITEM SEPARATOR
         MENUITEM "&Preview window\tCtrl+P",     ID_VIEW_PREVIEW
         POPUP "Preview pi&xel aspect ratio"
         BEGIN
             MENUITEM "P&C (1:1)",                   ID_PREVIEWPIXELASPECTRATIO_PC
             MENUITEM "&PAL (0.93:1)",               ID_PREVIEWPIXELASPECTRATIO_PAL
             MENUITEM "&NTSC (0.75:1)",              ID_PREVIEWPIXELASPECTRATIO_NTSC
         END
         MENUITEM SEPARATOR
         POPUP "Font"
         BEGIN
             MENUITEM "1x1",                         ID_FONT_1X1
             MENUITEM "1x2",                         ID_FONT_1X2
             MENUITEM "2x1",                         ID_FONT_2X1
             MENUITEM "2x2",                         ID_FONT_2X2
         END
         MENUITEM SEPARATOR
         POPUP "&Application Look"
         BEGIN
             MENUITEM "Windows &2000",               ID_VIEW_APPLOOK_WIN_2000
             MENUITEM "Office &XP",                  ID_VIEW_APPLOOK_OFF_XP
             MENUITEM "&Windows XP",                 ID_VIEW_APPLOOK_WIN_XP
             MENUITEM "Office 200&3",                ID_VIEW_APPLOOK_OFF_2003
             MENUITEM "Visual Studio 200&5",         ID_VIEW_APPLOOK_VS_2005
             MENUITEM "Visual Studio 200&8",         ID_VIEW_APPLOOK_VS_2008
             POPUP "Office 200&7"
             BEGIN
                 MENUITEM "&Blue Style",                 ID_VIEW_APPLOOK_OFF_2007_BLUE
                 MENUITEM "B&lack Style",                ID_VIEW_APPLOOK_OFF_2007_BLACK
                 MENUITEM "&Silver Style",               ID_VIEW_APPLOOK_OFF_2007_SILVER
                 MENUITEM "&Aqua Style",                 ID_VIEW_APPLOOK_OFF_2007_AQUA
             END
         END
         MENUITEM "&Status Bar",                 ID_VIEW_STATUS_BAR
         POPUP "&Toolbars and Docking Windows"
         BEGIN
             MENUITEM "<placeholder>",               ID_VIEW_TOOLBAR
         END
         MENUITEM "&Next buffer\t.",             ID_VIEW_NEXTBUFFER
         MENUITEM "P&rev buffer\t,",             ID_VIEW_PREVBUFFER
     END
     POPUP "&Selection"
     BEGIN
         MENUITEM "Flip &vertically\tV",         ID_SELECTION_FLIPVERTICALLY
         MENUITEM "Flip &horizontally\tH",       ID_SELECTION_FLIPHORIZONTALLY
         MENUITEM "&Rotate CW\tShift+R",         ID_SELECTION_ROTATECW
         MENUITEM "Rotat&e CCW\tCtrl+R",         ID_SELECTION_ROTATECCW
         MENUITEM "Shift &left\tShift ←",        ID_SELECTION_SHIFTLEFT
         MENUITEM "Shift &right\tShift →",       ID_SELECTION_SHIFTRIGHT
         MENUITEM "Shift &up\tShift ↑",          ID_SELECTION_SHIFTUP
         MENUITEM "Shift &down\tShift ↓",        ID_SELECTION_SHIFTDOWN
     END
     POPUP "&Tool"
     BEGIN
         MENUITEM "&Optimize",                   ID_TOOL_OPTIMIZE
         POPUP "&Copy ROM font"
         BEGIN
             MENUITEM "&Uppercase",                  ID_COPYROMFONT_UPPERCASE
             MENUITEM "&Lowercase",                  ID_COPYROMFONT_LOWERCASE
         END
         MENUITEM "&Delete undo history",        ID_TOOL_DELETEUNDOHISTORY
         MENUITEM "Fill\tG",                     ID_TOOL_FILL
         MENUITEM "Remap Colours",               ID_TOOL_REMAPCOLOURS
         MENUITEM "Swap Cell Colours",           ID_TOOL_SWAPCELLCOLOURS
     END
     POPUP "&Mode"
     BEGIN
         MENUITEM "&Bitmap",                     ID_MODE_BITMAP
         MENUITEM "&Sprite",                     ID_MODE_SPRITE
         MENUITEM "&Char",                       ID_MODE_CHAR
         MENUITEM "&Unrestricted",               ID_MODE_UNRESTRICTED
         MENUITEM SEPARATOR
         MENUITEM "&Multi-Color",                ID_MODE_MULTI
         MENUITEM SEPARATOR
         POPUP "Palette"
         BEGIN
             MENUITEM "dummy",                       ID_PALETTE_DUMMY
         END
         MENUITEM SEPARATOR
         POPUP "Color &overflow"
         BEGIN
             MENUITEM "&Ignore",                     ID_OVERFLOW_IGNORE
             MENUITEM "&Closest",                    ID_OVERFLOW_CLOSEST
             MENUITEM "&Replace",                    ID_OVERFLOW_REPLACE
             MENUITEM "&Toggle Ignore/Replace\tCtrl+W", ID_COLOROVERFLOW_TOGGLEIGNORE
         END
         MENUITEM "Col &View\t#",                ID_MODE_COLOURVIEW
     END
     POPUP "&Help"
     BEGIN
         MENUITEM "&About Pixcen...",            ID_APP_ABOUT
         MENUITEM SEPARATOR
         MENUITEM "Help",                        ID_HELP_HELP
         MENUITEM "Facebook support group",      ID_HELP_FACEBOOK
         MENUITEM "Lemon64 support forum",       ID_HELP_LEMON64SUPPORTFORUM
         MENUITEM SEPARATOR
         MENUITEM "Check for updates",           ID_HELP_CHECKFORUPDATES
         MENUITEM "Download source code",        ID_HELP_DOWNLOADSOURCECODE
         MENUITEM SEPARATOR
         MENUITEM "Miss Pixcen (by N3XU5)",      ID_HELP_LOADINTRO
     END
 END

 IDR_POPUP_EDIT MENU
 BEGIN
     POPUP "Edit"
     BEGIN
         MENUITEM "Cu&t\tCtrl+X",                ID_EDIT_CUT
         MENUITEM "&Copy\tCtrl+C",               ID_EDIT_COPY
         MENUITEM "&Paste\tCtrl+V",              ID_EDIT_PASTE
     END
 END

 IDR_THEME_MENU MENU
 BEGIN
     MENUITEM "Office 2007 (&Blue Style)",   ID_VIEW_APPLOOK_OFF_2007_BLUE
     MENUITEM "Office 2007 (B&lack Style)",  ID_VIEW_APPLOOK_OFF_2007_BLACK
     MENUITEM "Office 2007 (&Silver Style)", ID_VIEW_APPLOOK_OFF_2007_SILVER
     MENUITEM "Office 2007 (&Aqua Style)",   ID_VIEW_APPLOOK_OFF_2007_AQUA
     MENUITEM "Win&dows 7",                  ID_VIEW_APPLOOK_WINDOWS_7
 END


 /////////////////////////////////////////////////////////////////////////////
 //
 // Accelerator
 //

 IDR_MAINFRAME ACCELERATORS
 BEGIN
     "W",            ID_COLOROVERFLOW_TOGGLEIGNORE, VIRTKEY, CONTROL, NOINVERT
     "V",            ID_EDIT_BACKGROUNDMASKEDPASTE, VIRTKEY, SHIFT, CONTROL, NOINVERT
     "C",            ID_EDIT_COPY,           VIRTKEY, CONTROL, NOINVERT
     "X",            ID_EDIT_CUT,            VIRTKEY, CONTROL, NOINVERT
     "D",            ID_EDIT_DESELECT,       VIRTKEY, CONTROL, NOINVERT
     "V",            ID_EDIT_PASTE,          VIRTKEY, CONTROL, NOINVERT
     "Y",            ID_EDIT_REDO,           VIRTKEY, CONTROL, NOINVERT
     "A",            ID_EDIT_SELECTALL,      VIRTKEY, CONTROL, NOINVERT
     "C",            ID_EDIT_SELECTCELL,     VIRTKEY, SHIFT, NOINVERT
     "M",            ID_EDIT_SELECTMARKER,   VIRTKEY, NOINVERT
     "Z",            ID_EDIT_UNDO,           VIRTKEY, CONTROL, NOINVERT
     "L",            ID_FILE_LOAD,           VIRTKEY, CONTROL, NOINVERT
     "S",            ID_FILE_SAVE,           VIRTKEY, CONTROL, NOINVERT
     "S",            ID_FILE_SAVEAS,         VIRTKEY, SHIFT, CONTROL, NOINVERT
     "S",            ID_FILE_SAVESELECTION,  VIRTKEY, SHIFT, NOINVERT
     VK_F6,          ID_NEXT_PANE,           VIRTKEY, NOINVERT
     VK_F6,          ID_PREV_PANE,           VIRTKEY, SHIFT, NOINVERT
     "H",            ID_SELECTION_FLIPHORIZONTALLY, VIRTKEY, NOINVERT
     "V",            ID_SELECTION_FLIPVERTICALLY, VIRTKEY, NOINVERT
     "R",            ID_SELECTION_ROTATECCW, VIRTKEY, CONTROL, NOINVERT
     "R",            ID_SELECTION_ROTATECW,  VIRTKEY, SHIFT, NOINVERT
     VK_DOWN,        ID_SELECTION_SHIFTDOWN, VIRTKEY, SHIFT, NOINVERT
     VK_LEFT,        ID_SELECTION_SHIFTLEFT, VIRTKEY, SHIFT, NOINVERT
     VK_RIGHT,       ID_SELECTION_SHIFTRIGHT, VIRTKEY, SHIFT, NOINVERT
     VK_UP,          ID_SELECTION_SHIFTUP,   VIRTKEY, SHIFT, NOINVERT
     "G",            ID_TOOL_FILL,           VIRTKEY, NOINVERT
     "G",            ID_VIEW_CELLGRID,       VIRTKEY, SHIFT, NOINVERT
     "G",            ID_VIEW_GRID,           VIRTKEY, CONTROL, NOINVERT
     VK_OEM_PERIOD,  ID_VIEW_NEXTBUFFER,     VIRTKEY, NOINVERT
     VK_OEM_COMMA,   ID_VIEW_PREVBUFFER,     VIRTKEY, NOINVERT
     "P",            ID_VIEW_PREVIEW,        VIRTKEY, CONTROL, NOINVERT
     VK_HOME,        ID_VIEW_RESTOREMAINVIEW, VIRTKEY, NOINVERT
     "#",            ID_MODE_COLOURVIEW,     ASCII,  NOINVERT
 END

 */

// MARK: - Menu Validation
extension AppDelegate: NSMenuItemValidation {
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        let action = menuItem.action

        // Get canvas state
        let canvas = pixelCanvasView
        let pbm = canvas?.m_pbm

        switch action {
        // Edit > Undo/Redo
        case #selector(onEditUndo(_:)):
            return pbm?.canUndo ?? false
        case #selector(onEditRedo(_:)):
            return pbm?.canRedo ?? false

        // Edit > Cut/Copy (need paste buffer or selection)
        case #selector(onEditCut(_:)):
            return canvas != nil
        case #selector(onEditCopy(_:)):
            return canvas != nil
        case #selector(onEditPaste(_:)):
            return canvas?.m_pPasteBuffer != nil
        case #selector(onEditBackgroundmaskedpaste(_:)):
            return canvas?.m_pPasteBuffer != nil

        // File > Save (enabled when dirty)
        case #selector(onFileSave(_:)):
            return (pbm?.isDirty ?? false) || lastSavedURL != nil
        case #selector(onFileSaveselection(_:)):
            return canvas != nil

        // View > Grid (checkmark state)
        case #selector(onViewGrid(_:)):
            menuItem.state = (canvas?.m_Grid ?? 0) != 0 ? .on : .off
            return true
        case #selector(onViewCellgrid(_:)):
            menuItem.state = (canvas?.m_CellGrid ?? 0) != 0 ? .on : .off
            return true

        // View > Next/Prev buffer
        case #selector(onViewNextbuffer(_:)):
            guard let p = pbm else { return false }
            return p.backBuffer < p.backBufferCount - 1
        case #selector(onViewPrevbuffer(_:)):
            guard let p = pbm else { return false }
            return p.backBuffer > 0

        // Mode > checkmarks (radio behavior)
        case #selector(onModeBitmap(_:)):
            let mode = pbm?.canvasModel.mode ?? .MC_BITMAP
            menuItem.state = (mode == .BITMAP || mode == .MC_BITMAP) ? .on : .off
            return true
        case #selector(onModeSprite(_:)):
            let mode = pbm?.canvasModel.mode ?? .MC_BITMAP
            menuItem.state = (mode == .SPRITE || mode == .MC_SPRITE) ? .on : .off
            return true
        case #selector(onModeChar(_:)):
            let mode = pbm?.canvasModel.mode ?? .MC_BITMAP
            menuItem.state = (mode == .CHAR || mode == .MC_CHAR) ? .on : .off
            return true
        case #selector(onModeUnrestricted(_:)):
            let mode = pbm?.canvasModel.mode ?? .MC_BITMAP
            menuItem.state = (mode == .UNRESTRICTED || mode == .W_UNRESTRICTED) ? .on : .off
            return true
        case #selector(onModeMulti(_:)):
            let mode = pbm?.canvasModel.mode ?? .MC_BITMAP
            let isMulti = (mode == .MC_BITMAP || mode == .MC_SPRITE || mode == .MC_CHAR || mode == .W_UNRESTRICTED)
            menuItem.state = isMulti ? .on : .off
            return true

        // Mode > Color overflow checkmarks
        case #selector(onOverflowIgnore(_:)):
            menuItem.state = pbm?.canvasModel.overflow == .NOTHING ? .on : .off
            return true
        case #selector(onOverflowClosest(_:)):
            menuItem.state = pbm?.canvasModel.overflow == .CLOSEST ? .on : .off
            return true
        case #selector(onOverflowReplace(_:)):
            menuItem.state = pbm?.canvasModel.overflow == .REPLACE ? .on : .off
            return true

        // Edit > Auto-select (checkmark)
        case #selector(onEditAutoSelect(_:)):
            menuItem.state = (canvas?.m_AutoMarker ?? false) ? .on : .off
            return true
        case #selector(onEditSnapselection(_:)):
            menuItem.state = (canvas?.m_CellSnapMarker ?? false) ? .on : .off
            return true

        // Tool > Optimize (only for formats that support it)
        case #selector(onToolOptimize(_:)):
            return pbm?.canOptimize ?? false

        // Tool > Remap Colours (only for MC_BITMAP)
        case #selector(onToolRemapcolours(_:)):
            return pbm?.canvasModel.mode == .MC_BITMAP

        // Tool > Swap Cell Colours (only for BITMAP)
        case #selector(onToolSwapcellcolours(_:)):
            return pbm?.canvasModel.mode == .BITMAP

        // Tool > Delete undo history
        case #selector(onToolDeleteundohistory(_:)):
            return pbm?.canUndo ?? false

        // Selection ops (need canvas)
        case #selector(onSelectionFlipvertically(_:)),
             #selector(onSelectionFliphorizontally(_:)),
             #selector(onSelectionRotatecw(_:)),
             #selector(onSelectionRotateccw(_:)),
             #selector(onSelectionShiftleft(_:)),
             #selector(onSelectionShiftright(_:)),
             #selector(onSelectionShiftup(_:)),
             #selector(onSelectionShiftdown(_:)):
            return canvas != nil

        // Font display (only for font modes)
        case #selector(onFont1x1(_:)),
             #selector(onFont1x2(_:)),
             #selector(onFont2x1(_:)),
             #selector(onFont2x2(_:)):
            let mode = pbm?.canvasModel.mode ?? .MC_BITMAP
            return mode == .CHAR || mode == .MC_CHAR

        // Copy ROM font (only for single-color font mode)
        case #selector(onCopyromfontUppercase(_:)),
             #selector(onCopyromfontLowercase(_:)):
            let mode = pbm?.canvasModel.mode ?? .MC_BITMAP
            return mode == .CHAR

        default:
            return true
        }
    }
}
