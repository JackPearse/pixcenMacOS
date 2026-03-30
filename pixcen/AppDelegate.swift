//
//  AppDelegate.swift
//  pixcen
//
//  Created by JackPearse on 27.06.20.
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
//
// TODO: Nice to have: Develop a .gpx and other formats quickinfo procedure for Finder and MacOS.
// For the linux version we use swift gtk: https://github.com/rhx/SwiftGtk

import Cocoa

/**
 The App Delegate is the **main entry point** of the application. Here we create the palette windows and manage the menus and central data types of the application. This class is what CMainFrame is in Mainframe.h in the Windows version.
 In the windows version the menu handling is done in ChildView.h. In the MacOS version we receive the Menu-Selectinos here and
 forward it when neccesary.
 
 Program structure:
 - AppDelegate: Main entry point. Window creation. Creation of Tool palettes. Recent-Documents and MacOS signal handling.
 - AppDelegate+Menu: extension to AppDelegate. Handling of all pulldown Menu events.
 - ViewControllers  group: Models for the individual views
 - Views group: All inidividual views. Handling of the drawing/rendering and capturing of mouse and keyboard events.
 - Tools: Global helpers to enhance concurrent operations using multiple threads or inage manipulation
 - C64: Core data model.
   - C64Interface: Main Base class. This class contains all the pixcen finctionality and builds the foundation of this application
   - Types: Types used by C64Interface
   - Formats: Derived subclasses from C64Interface. Each implementing individual file formats.
 
 Some functions were outsourced to objectiveC / C++. The original C++ functionality for loading and saving data from the original windows implementation was extracted into a (reusable) C-library. To get a clean bridge between the C world and swift we use a framework wrapper that corresponds to the swift modules. We use objC to build a class-like structure as a bridge between C++ and swift.
 
 This application conforms to the GNU General Public License. See the copyright notice above. For more details,
 see the Credits.rtf file, which is part of this bundle.
 */
@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    
    @IBOutlet weak var paletteSubmenu: NSMenu!
    @IBOutlet weak var previewPARSubmenu: NSMenu!
    
    // MARK: Windows
    // The two windows of the C64 palettes.
    var c64PalWindow:NSWindow!
    var cColCtrlWindow:NSWindow!
    
    var mainViewController:PixcenMainViewController!
    var pixelCanvasView:PCPixelCanvasView!

    var lastSavedURL:URL!
    var preferencesWindowController: PCPreferencesWindowController?
    var previewWindowController: PCPreviewWindowController?
    
    /**
     Mark document as edited
     */
    var markEdited:Bool = false {
        
        didSet {
            
            if let window = NSApplication.shared.mainWindow {
                
                window.windowController?.setDocumentEdited(markEdited)
            }
        }
    }
        
    /**
        Apples Application entry point. This method replaces the
        int CMainFrame::OnCreate(LPCREATESTRUCT lpCreateStruct)
        method of the windows version.
     */
    func applicationDidFinishLaunching(_ aNotification: Notification) {

        // Remove macOS auto-injected menu items (AutoFill, Dictation, Emoji)
        UserDefaults.standard.set(false, forKey: "NSAutomaticTextCompletionEnabled")

        // Set ourselves as window delegate to intercept close
        NSApp.mainWindow?.delegate = self

        // Taken from: int CMainFrame::OnCreate(LPCREATESTRUCT lpCreateStruct)
        // of the windows version
        // TODO: Init File Drag and Drop
        
        
        // Code to initialize the application
        /*
         m_pC64Pal = new C64Palette(&m_wndView);
         m_pC64Pal->Create(IDD_C64PAL, &m_wndView);
         m_pC64Pal->ShowWindow(SW_SHOW);
         
         
         m_pCColCtrl = new CColorCtrl(&m_wndView);
         m_pCColCtrl->Create(IDD_CONTROL, &m_wndView);
         m_pCColCtrl->ShowWindow(SW_SHOW);
         
         TCHAR *p=new TCHAR[16];
         lstrcpy(p, _T("Untitled"));
         Mail(MSG_FILE_TITLE, (UINT_PTR)p);
         
         OnHelpCheckforupdates();
         */
        
        initSubmenus()
        
        showC64PalWindow()
        showColCtrlWindow()
        onHelpCheckforupdates()
    }

    // MARK: - Preferences

    @IBAction func showPreferences(_ sender: Any?) {
        if preferencesWindowController == nil {
            preferencesWindowController = PCPreferencesWindowController()
        }
        preferencesWindowController?.showWindow(self)
        preferencesWindowController?.window?.makeKeyAndOrderFront(self)
    }

    func showC64PalWindow() {
        
        let x = UserDefaults.standard.float(forKey: "c64PalWindowPosX")
        let y = UserDefaults.standard.float(forKey: "c64PalWindowPosY")
        let lastOrigin = CGPoint(x: CGFloat(x), y: CGFloat(y))
        
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        if let m_pC64Pal = storyboard.instantiateController(withIdentifier: "m_pC64Pal") as? PCC64PalleteViewController {
            
            if self.c64PalWindow != nil {
                
                self.c64PalWindow.contentViewController = m_pC64Pal
            } else {
                
                /*
                 // Window-Style
                 self.c64PalWindow = NSWindow(contentViewController: m_pC64Pal)
                 */
                
                var rect = m_pC64Pal.view.bounds
                rect.origin = lastOrigin
                
                // HUD-Style
                self.c64PalWindow = NSPanel(contentRect: rect, styleMask: [.hudWindow, .titled, .utilityWindow], backing: .buffered, defer: true)
                self.c64PalWindow.contentViewController = m_pC64Pal
            }
            
            if self.c64PalWindow != nil {
                
                self.c64PalWindow.title = "VIC-II"
                self.c64PalWindow.level = .floating
                self.c64PalWindow.setFrameOrigin(lastOrigin)
                self.c64PalWindow.orderFront(self)
            }
        }
    }
    
    func showColCtrlWindow() {
        
        let x = UserDefaults.standard.float(forKey: "cColCtrlWindowPosX")
        let y = UserDefaults.standard.float(forKey: "cColCtrlWindowPosY")
        let lastOrigin = CGPoint(x: CGFloat(x), y: CGFloat(y))
        
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        if let m_pCColCtrl = storyboard.instantiateController(withIdentifier: "m_pCColCtrl") as? PCColorCtrlViewController {
            
            if self.cColCtrlWindow != nil {
                
                self.cColCtrlWindow.contentViewController = m_pCColCtrl
            } else {
                
                /*
                 // Window-Style
                 self.cColCtrlWindow = NSWindow(contentRect: m_pCColCtrl.view.bounds, styleMask: [.closable, .titled], backing: .buffered, defer: true)
                 self.cColCtrlWindow.contentViewController = m_pCColCtrl
                 */
                
                var rect = m_pCColCtrl.view.bounds
                rect.origin = lastOrigin
                
                // HUD-Style
                self.cColCtrlWindow = NSPanel(contentRect: rect, styleMask: [.hudWindow, .titled, .utilityWindow], backing: .buffered, defer: true)
                self.cColCtrlWindow.contentViewController = m_pCColCtrl
            }
            
            if self.cColCtrlWindow != nil {
                
                self.cColCtrlWindow.title = "Cell"
                self.cColCtrlWindow.level = .floating
                self.cColCtrlWindow.setFrameOrigin(lastOrigin)
                self.cColCtrlWindow.orderFront(self)
            }
        }
    }
    
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard markEdited else { return true }

        let alert = NSAlert()
        alert.messageText = "Unsaved Changes"
        alert.informativeText = "Do you want to save your changes before closing?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: sender) { result in
            switch result {
            case .alertFirstButtonReturn:
                DispatchQueue.main.async {
                    self.onFileSave(self)
                }
            case .alertSecondButtonReturn:
                self.markEdited = false
                sender.close()
            default:
                break
            }
        }

        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {

        guard markEdited, let mainWindow = NSApp.mainWindow else {
            return saveWindowPositionsAndTerminate()
        }

        let alert = NSAlert()
        alert.messageText = "Unsaved Changes"
        alert.informativeText = "Do you want to save your changes before quitting?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")

        alert.beginSheetModal(for: mainWindow) { result in
            switch result {
            case .alertFirstButtonReturn:
                // Cancel the quit, show save dialog instead — user can quit again after saving
                NSApp.reply(toApplicationShouldTerminate: false)
                DispatchQueue.main.async {
                    self.onFileSave(self)
                }
            case .alertSecondButtonReturn:
                _ = self.saveWindowPositionsAndTerminate()
                NSApp.reply(toApplicationShouldTerminate: true)
            default:
                NSApp.reply(toApplicationShouldTerminate: false)
            }
        }

        return .terminateLater
    }

    private func saveWindowPositionsAndTerminate() -> NSApplication.TerminateReply {
        let c64PalFrame = c64PalWindow.frame
        let cColCtrlFrame = cColCtrlWindow.frame

        UserDefaults.standard.setValue(c64PalFrame.origin.x, forKey: "c64PalWindowPosX")
        UserDefaults.standard.setValue(c64PalFrame.origin.y, forKey: "c64PalWindowPosY")
        UserDefaults.standard.setValue(cColCtrlFrame.origin.x, forKey: "cColCtrlWindowPosX")
        UserDefaults.standard.setValue(cColCtrlFrame.origin.y, forKey: "cColCtrlWindowPosY")

        c64PalWindow.close()
        cColCtrlWindow.close()
        c64PalWindow = nil
        cColCtrlWindow = nil

        return .terminateNow
    }
    
    // MARK: Methods
    func onHelpCheckforupdates() {
        
        // TODO: Implement this function
    }
    
    /*
    afx_msg void OnViewPreview();
    afx_msg void OnHelpCheckforupdates();
    afx_msg void OnUpdateHelpCheckforupdates(CCmdUI *pCmdUI);
    protected:
        afx_msg LRESULT OnUmUpdateVersion(WPARAM wParam, LPARAM lParam);
    public:
    afx_msg void OnHelpHelp();
    afx_msg void OnHelpDownloadsourcecode();
    afx_msg void OnHelpFacebook();
    afx_msg void OnHelpLemon64supportforum();
     */
    
    /*
     afx_msg LRESULT CMainFrame::OnUmGraphix(WPARAM wParam, LPARAM lParam)
     {
         unsigned short message = lParam&0xffff, extra = unsigned short(lParam >> 16);
         UINT_PTR data = UINT_PTR(wParam);
     
         Receive(message,data,extra);
         m_pC64Pal->Receive(message,data,extra);
         m_pCColCtrl->Receive(message,data,extra);
         m_wndView.Receive(message,data,extra);
     
         for(int r=0;r<m_pPreview.count();r++)
         {
             m_pPreview[r]->Receive(message,data,extra);
         }
     
         return 0;
     }
     */
    
    /*
     void CMainFrame::Receive(unsigned short message, UINT_PTR data, unsigned short extra)
     {
         switch(message)
         {
         case MSG_STATUS_TEXT:
             {
                 TCHAR *p=(TCHAR *)data;
                 m_wndStatusBar.SetPaneText(0,p);
                 delete [] p;
             }
             break;
     
         case MSG_PREV_CLOSE:
             {
                 CPreview *p=(CPreview *)data;
                 p->DestroyWindow();
                 delete p;
                 int n=m_pPreview.find(p);
                 if(n!=-1)
                 {
                     m_pPreview.remove(n);
                 }
             }
             break;
         case MSG_FILE_TITLE:
             {
                 TCHAR *p =(TCHAR *)data;
     
                 nstr tmp = _T("Pixcen - ");
                 tmp += p;
                 delete [] p;
                 SetWindowText(tmp);
             }
             break;
         default:
             break;
         }
     }
     
     
     void CMainFrame::OnViewPreview()
     {
         // TODO: Add your command handler code here
         CPreview *p=new CPreview(1.0/m_wndView.m_pbm->GetPARValue());
     
         LPCTSTR pClass=AfxRegisterWndClass(CS_DROPSHADOW|CS_HREDRAW,0,0,0);
         p->CreateEx(0,pClass,_T("Preview"),WS_OVERLAPPEDWINDOW|WS_VISIBLE,100,100,320,200,*this,(HMENU)0);
     
         p->m_ppInterface = &m_wndView.m_pbm;
     
         m_pPreview.add(p);
     }
     
     UINT CMainFrame::UpdateThread( LPVOID pParam )
     {
         try
         {
             CMainFrame *pWnd = (CMainFrame *)pParam;
             CInternetSession session;
             CHttpFile* file = NULL;
             file = (CHttpFile *)session.OpenURL(_T("http://binarybone.com/pixcen/ver"), 1UL, INTERNET_FLAG_TRANSFER_ASCII|INTERNET_FLAG_RELOAD);
     
             if (NULL != file)
             {
                 char txt[17];
     
                 UINT n=file->Read(txt,16);
     
                 file->Close();
     
                 if(n>0)
                 {
                     txt[n]=0;
                     ::PostMessage(*pWnd, UM_UPDATE_VERSION, WPARAM(atoi(txt)), NULL);
                 }
                 else
                 {
                     ::PostMessage(*pWnd, UM_UPDATE_VERSION, WPARAM(0), NULL);
                 }
     
                 //Do something here with the web request
                 //Clean up the file here to avoid a memory leak!!!!!!!
     
     
                 delete file;
     
             }
     
             session.Close();
         }
         catch(CInternetException *ex)
         {
             ex->Delete();
         }
     
         return 0;
     }
     
     afx_msg LRESULT CMainFrame::OnUmUpdateVersion(WPARAM wParam, LPARAM lParam)
     {
         int ver = int(wParam);
     
         if(ver > VERSION_NUM)
         {
             if(MessageBox(_T("There is an updated version of Pixcen.\nWould you like to download?"),_T("New version"),MB_YESNO|MB_ICONQUESTION) == IDYES)
             {
     #ifdef _M_X64
                 ShellExecute(NULL,L"open",L"http://binarybone.com/pixcen/pixcen64.zip",NULL,NULL,SW_SHOWNORMAL);
     #else
                 ShellExecute(NULL,L"open",L"http://binarybone.com/pixcen/pixcen.zip",NULL,NULL,SW_SHOWNORMAL);
     #endif
             }
         }
     
         //m_pUpdateThread->Delete();
     
         m_pUpdateThread = NULL;
         return 0;
     }
     
     */
    
    // MARK: Recent Files Menu
    
    /**
     We do not use NSDocumentController. However, we want to use the menu "Recent Files".
     When someone selects a recent file, this method is called.  Return true if you want to keep
     the file in the recent files menu.
     */
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        
        let fileURL = URL(fileURLWithPath: filename)
        self.load(url:fileURL)
        
        // return true, if you want to keep the file in the "Recent files" menu
        return true
        
    }
}

// MARK: File Handling
extension AppDelegate {
    
    func load(url:URL) {

        NSDocumentController.shared.noteNewRecentDocumentURL(url) // Add to "Recent Files" menu
        self.markEdited = false // And remove the dot in the red "close window dot"

        let ext = url.pathExtension.lowercased()

        guard let rawData = try? Data(contentsOf: url) else {
            let alert = NSAlert()
            alert.messageText = "Could not read file"
            alert.informativeText = url.lastPathComponent
            alert.runModal()
            return
        }

        do {
            let canvas = pixelCanvasView!

            if ext == "gpx" {
                // GPX: entire file is zlib-compressed
                let maxDecompressed = 1024 * 1024 * 20  // 20 MB, matching original C++
                var decompressed = try ZlibCompression.decompress(rawData, maxSize: maxDecompressed)

                // Read version and mode from decompressed header
                var version:UInt32 = 0
                var modeRaw:UInt32 = 0
                decompressed >> version
                decompressed >> modeRaw

                // Map integer mode to tmode and create the right subclass
                let newDoc:PCC64Interface = try AppDelegate.createForMode(Int(modeRaw))
                newDoc.canvasModel.mode = AppDelegate.tmodeFromInt(Int(modeRaw))
                newDoc.inheritHistory(old: canvas.m_pbm)
                canvas.m_pbm = newDoc
                try canvas.m_pbm.load(file: &decompressed, type: ext, version: Int(version))
                canvas.invalidate()
                self.lastSavedURL = url

            } else {
                // Non-GPX formats — detect by extension and create the right class
                var fileData = rawData
                let newDoc: PCC64Interface

                let mcBitmapExts: Set<String> = ["kla", "koa", "ocp", "cen", "mg", "pmg", "binmc"]
                let bitmapExts: Set<String> = ["art", "dd", "ddl", "jj", "binhi"]
                let spriteExts: Set<String> = ["spr"]
                let mcSpriteExts: Set<String> = ["mcspr"]

                // For .bin files, identify as binmc or binhi by magic bytes
                var resolvedExt = ext
                if ext == "bin" && rawData.count == 88000 {
                    let bytes = [UInt8](rawData)
                    let mcMagic: [UInt8] = [0x00, 0x0A, 0x0F, 0x28, 0x00, 0x19]
                    let hiMagic: [UInt8] = [0xFF, 0x00, 0x00, 0x0F, 0x28, 0x00, 0x19]
                    if bytes.count > 8 && Array(bytes[2..<8]) == mcMagic {
                        resolvedExt = "binmc"
                    } else if bytes.count > 8 && Array(bytes[1..<8]) == hiMagic {
                        resolvedExt = "binhi"
                    } else {
                        resolvedExt = "binmc"  // default to MC
                    }
                }

                if mcBitmapExts.contains(resolvedExt) {
                    newDoc = try PCMCBitmap()
                } else if bitmapExts.contains(resolvedExt) {
                    newDoc = try PCBitmap()
                } else if spriteExts.contains(resolvedExt) {
                    newDoc = try PCSprite()
                } else if mcSpriteExts.contains(resolvedExt) {
                    newDoc = try PCMCSprite()
                } else if ["bmp", "png", "jpg", "jpeg", "gif", "tiff", "tif"].contains(resolvedExt) {
                    // Image import with color reduction
                    guard let image = NSImage(contentsOf: url) else {
                        throw C64InterfaceError.failed(0, "Could not load image")
                    }
                    let imported = try ImageImporter.importToMCBitmap(image, palette: C64Col.shared)
                    imported.inheritHistory(old: canvas.m_pbm)
                    canvas.m_pbm = imported
                    canvas.invalidate()
                    return
                } else {
                    // Default to MCBitmap for unknown extensions
                    newDoc = try PCMCBitmap()
                }

                newDoc.inheritHistory(old: canvas.m_pbm)
                canvas.m_pbm = newDoc
                try canvas.m_pbm.load(file: &fileData, type: resolvedExt, version: 0)
                canvas.invalidate()
            }

        } catch {
            let alert = NSAlert()
            alert.messageText = "Error loading file"
            alert.informativeText = "\(error)"
            alert.runModal()
        }
    }

    /// Create the right PCC64Interface subclass based on the integer mode from the GPX header.
    static func createForMode(_ modeInt: Int) throws -> PCC64Interface {
        switch modeInt {
        case 0: return try PCBitmap()
        case 1: return try PCMCBitmap()
        case 2: return try PCSprite()
        case 3: return try PCMCSprite()
        case 4: return try PCSFont()
        case 5: return try PCMCFont()
        // 6, 7: UNUSED1, UNUSED2
        case 8: return try PCUnrestricted(wide: false)
        case 9: return try PCUnrestricted(wide: true)  // W_UNRESTRICTED
        default:
            throw C64InterfaceError.failed(Int32(modeInt), "Unknown GPX mode: \(modeInt)")
        }
    }

    /// Convert integer mode value from GPX header to tmode enum.
    static func tmodeFromInt(_ modeInt: Int) -> PCC64Interface.tmode {
        switch modeInt {
        case 0: return .BITMAP
        case 1: return .MC_BITMAP
        case 2: return .SPRITE
        case 3: return .MC_SPRITE
        case 4: return .CHAR
        case 5: return .MC_CHAR
        case 8: return .UNRESTRICTED
        case 9: return .W_UNRESTRICTED
        default: return .MC_BITMAP
        }
    }
    
    func save(url:URL) {

        NSDocumentController.shared.noteNewRecentDocumentURL(url)

        let ext = url.pathExtension.lowercased()
        guard let canvas = pixelCanvasView else { return }

        do {
            let data = try canvas.m_pbm.saveToFile(type: ext.isEmpty ? "gpx" : ext)
            try data.write(to: url)
            self.markEdited = false
            self.lastSavedURL = url
        } catch {
            let alert = NSAlert()
            alert.messageText = "Error saving file"
            alert.informativeText = "\(error)"
            alert.runModal()
        }
    }
    
    /// Miss Pixcen (by N3XU5)
    func loadIntro() -> Bool {
        
        return false
    }
    
    /*
     bool CChildView::CheckDirty(void)
     {
     if(m_pbm->IsDirty())
     {
     switch(MessageBox(_T("You have unsaved changes!\nDo you want to save?"),_T("New/Load"),MB_YESNOCANCEL|MB_ICONWARNING))
     {
     case IDCANCEL:
     return false;
     case IDYES:
     OnFileSave();
     break;
     default:
     break;
     }
     }
     return true;
     }
     
     
     void CChildView::Load(LPCTSTR file, LPCTSTR iex)
     {
     nstr path=file,tex=_T("gpx");
     nstr ex = iex;
     nstr id;
     
     int w=0, h=0;
     
     size_t n;
     
     while((n=path.find(_T('\"')))!=-1)
     {
     path.cut(n,1);
     }
     
     if(ex.isempty())
     {
     
     n=path.rfind(_T('.'));
     if(n!=-1)
     {
     tex=path.mid(n+1);
     }
     
     ex = tex;
     }
     
     
     narray<autoptr<SaveFormat>, int> fmt;
     C64Interface::GetLoadFormats(fmt);
     
     bool good_format = false;
     //bool unknown_format = true;
     
     C64Interface::tmode mode = C64Interface::tmode(-1);
     
     if(ex.cmpi(_T("gpx"))!=0)
     id = C64Interface::IdentifyFile(path);
     
     if(id.isnotempty())
     ex = id;
     
     if(ex.isempty())
     {
     ex=_T("raw");
     }
     else
     {
     //Check again
     for(int r=0;r<fmt.count();r++)
     {
     if(fmt[r]->MatchExt(ex))
     {
     mode = C64Interface::tmode(fmt[r]->type);
     good_format = fmt[r]->good;
     w = fmt[r]->width;
     h = fmt[r]->height;
     goto found;
     }
     }
     
     if(lstrcmpi(_T("bmp"),ex)==0 || lstrcmpi(_T("png"),ex)==0 || lstrcmpi(_T("jpg"),ex)==0 || lstrcmpi(_T("gif"),ex)==0 || lstrcmpi(_T("gpx"),ex)==0)
     {
     }
     else
     {
     ex=_T("raw");
     }
     }
     
     found:
     if(lstrcmpi(_T("bmp"),ex)==0 || lstrcmpi(_T("png"),ex)==0 || lstrcmpi(_T("jpg"),ex)==0 || lstrcmpi(_T("gif"),ex)==0 || lstrcmpi(_T("raw"),ex)==0)
     {
     CImportDlg dlg;
     
     if(dlg.DoModal() != IDOK)
     return;
     
     switch(dlg.m_nSelect)
     {
     case 0:
     mode = C64Interface::MC_BITMAP;
     w = 160;
     h = 200;
     break;
     case 1:
     mode = C64Interface::BITMAP;
     w = 320;
     h = 200;
     break;
     case 2:
     mode = C64Interface::MC_CHAR;
     w = 160;
     h = 64;
     break;
     case 3:
     mode = C64Interface::CHAR;
     w = 320;
     h = 64;
     break;
     case 4:
     mode = C64Interface::UNRESTRICTED;
     w = 320;
     h = 200;
     break;
     case 5:
     mode = C64Interface::W_UNRESTRICTED;
     w = 160;
     h = 200;
     break;
     case 6:
     mode = C64Interface::SPRITE;
     w = 192;
     h = 168;
     break;
     case 7:
     mode = C64Interface::MC_SPRITE;
     w = 96;
     h = 168;
     break;
     default:
     return;
     break;
     }
     }
     
     try
     {
     C64Interface *i=C64Interface::Load(path,ex,mode,w,h);
     //i->InheritHistory(m_pbm);
     delete m_pbm;
     m_pbm = i;
     
     //View specific meta data
     if(ex.cmpi(_T("gpx"))==0)
     {
     m_AutoMarker = m_pbm->GetMetaInt("autoselect") ? true : false;
     m_CellSnapMarker = m_pbm->GetMetaInt("cellsnap") ? true : false;
     }
     
     Invalidate();
     Mail(MSG_PREV_PAR,UINT_PTR((1.0/m_pbm->GetPARValue())*10000000));
     Mail(MSG_REFRESH);
     
     m_pbm->SetFileName(path);
     m_goodFormat = good_format;
     
     this->SetTitleFileName(path);
     
     if(!good_format)
     {
     m_pbm->SetDirty();
     }
     }
     catch(LPCTSTR str)
     {
     AfxMessageBox(str);
     }
     }
     */
}
