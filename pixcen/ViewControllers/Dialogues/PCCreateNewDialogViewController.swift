//
//  PCCreateNewDialogViewController.swift
//  pixcen
//
//  Created by JackPearse on 29.06.20.
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
/**
 This class implements the "New" dialog. The user can configure his pixel document here. It is the first dialog that is used to set the pixel settings. This class is what CNewDlg is in NewDlg.h in the Windows version.
 */
class PCCreateNewDialogViewController: NSViewController {
    
    // MARK: Outlets
    @IBOutlet weak var modePopupButton: NSPopUpButton!
    @IBOutlet weak var multiColorCheckbox: NSButton!
    @IBOutlet weak var widthTextField: NSTextField!
    @IBOutlet weak var heightTextField: NSTextField!
    @IBOutlet weak var backBuffersTextField: NSTextField!
    @IBOutlet weak var infoLabel: NSTextField!
    @IBOutlet weak var m_ok: NSButton!
    
    // MARK: Vars
    var m_snap_x:Int = 0
    var m_snap_y:Int = 0
    
    var m_last_select:Int = -1
    var m_select:Int = 0
    
    var m_last_multi:Bool = false
    var m_multi:Bool = true
    
    var m_x:Int = 160
    var m_y:Int = 200
    var m_z:Int = 1
    
    var m_std_x:Int = 160
    var m_std_y:Int = 200
    
    var m_info:String = ""
    
    var callbackHandler:(()->())?
    
    // MARK: ViewController
    override func viewDidLoad() {
        super.viewDidLoad()

        // Write defaults to UI first, then trigger info update
        updateData(false)
        updateInfo()
    }
    
    // MARK: Actions
    @IBAction func modePopupButtonDidChange(_ sender: Any) {
        updateData(true)
        if m_x == m_std_x && m_y == m_std_y {
            updateInfo()
            resetButtonWasPushed(sender)
        } else {
            updateInfo()
        }
    }

    @IBAction func multiColorCheckboxDidChange(_ sender: Any) {
        modePopupButtonDidChange(sender)
    }
    
    @IBAction func resetButtonWasPushed(_ sender: Any) {
        
        /*
         void CNewDlg::OnBnClickedReset()
         {
         // TODO: Add your control notification handler code here
         m_x = m_std_x;
         m_y = m_std_y;
         UpdateInfo();
         }
         */
        
        m_x = m_std_x
        m_y = m_std_y
        updateInfo()
    }
    
    @IBAction func okButtonWasPushed(_ sender: Any) {
        
        if callbackHandler != nil {
            
            callbackHandler!()
        }
        self.dismiss(self)
    }
    
    @IBAction func cancelWasPushed(_ sender: Any) {
        
        self.dismiss(self)
    }
    
    // MARK: Methods
    func snap(_ n:Int, _ snap:Int) -> Int {
        
        var n = n
        n += snap/2;
        return n - (n%snap)
    }
    
    func updateInfo() {
        
        /*
         if(m_last_select != m_select || m_last_multi != m_multi)
         {
         m_last_select = m_select;
         m_last_multi = m_multi;
         m_z = 1;
         switch(m_select)
         {
         case 0:    //Bitmap
         m_snap_x = m_multi ? 4 : 8;
         m_snap_y = 8;
         m_std_x = m_multi ? 160 : 320;
         m_std_y = 200;
         break;
         case 1:    //Sprite
         m_snap_x = m_multi ? 12 : 24;
         m_snap_y = 21;
         m_std_x = m_multi ? 96 : 192;
         m_std_y = 21 * 8;
         break;
         case 2:    //Char
         m_snap_x = m_multi ? 4 : 8;
         m_snap_y = 8;
         m_std_x = m_multi ? 128: 256;
         m_std_y =  8 * 8;
         break;
         case 3:    //Unrestricted
         m_snap_x = 1;
         m_snap_y = 1;
         m_std_x = m_multi ? 32 : 64;
         m_std_y = 64;
         break;
         };
         }
         
         if(m_x < 0)
         m_x = 1;
         
         if(m_y < 0)
         m_y = 1;
         
         if(m_z < 1)
         m_z = 1;
         
         //m_x = Snap(m_x,m_snap_x);
         //m_y = Snap(m_y,m_snap_y);
         //m_z = Snap(m_z,1);
         
         CString sbitmaps;
         {
         int cx = m_x/(m_multi ? 4 : 8);
         int cy = m_y/8;
         sbitmaps.Format(_T("Bitmaps: X:%0.2f Y:%0.2f\n"),m_x/double(m_multi ? 160 : 320),  m_y/double(200));
         }
         
         CString schars;
         {
         int cx = m_x/(m_multi ? 4 : 8);
         int cy = m_y/8;
         schars.Format(_T("Characters X:%d Y:%d Sum:%d\n"),cx, cy, cx*cy);
         }
         
         CString ssprites;
         {
         int cx = m_x/(m_multi ? 12 : 24);
         int cy = m_y/21;
         ssprites.Format(_T("Sprites: X:%d Y:%d Sum:%d\n"),cx, cy, cx*cy);
         }
         
         
         switch(m_select)
         {
         case 0:
         m_info = sbitmaps + schars;
         break;
         case 1:    //Sprite
         m_info = ssprites;
         break;
         case 2:    //Char
         m_info = schars;
         break;
         case 3:    //Unrestricted
         m_info.Format(_T("%s: X:%0.2f Y:%0.2f\n"),m_multi ? _T("Wide"): _T("Square"), double(m_x),  double(m_y));
         break;
         };
         
         bool good = true;
         
         if(m_x != Snap(m_x,m_snap_x))
         {
         CString tmp;
         tmp.Format(_T("Warning: Width must be divisible by %d\n"),m_snap_x);
         m_info+=tmp;
         good = false;
         }
         
         if(m_y != Snap(m_y,m_snap_y))
         {
         CString tmp;
         tmp.Format(_T("Warning: Height must be divisible by %d\n"),m_snap_y);
         m_info+=tmp;
         good = false;
         }
         
         m_ok.EnableWindow(good?1:0);
         
         UpdateData(FALSE);
         */
        
        if m_last_select != m_select || m_last_multi != m_multi {
            
            m_last_select = m_select
            m_last_multi = m_multi
            m_z = 1
            
            switch m_select {
                
            case 0:    // Bitmap
                m_snap_x = m_multi ? 4 : 8
                m_snap_y = 8
                m_std_x = m_multi ? 160 : 320
                m_std_y = 200
                
            case 1:    // Sprite
                m_snap_x = m_multi ? 12 : 24
                m_snap_y = 21
                m_std_x = m_multi ? 96 : 192
                m_std_y = 21 * 8
                
            case 2:    // Char
                m_snap_x = m_multi ? 4 : 8
                m_snap_y = 8
                m_std_x = m_multi ? 128: 256
                m_std_y =  8 * 8
                
            case 3:    //Unrestricted
                m_snap_x = 1
                m_snap_y = 1
                m_std_x = m_multi ? 32 : 64
                m_std_y = 64
                
            default:
                break
            }
        }
        
        if m_x < 0 {
            
            m_x = 1
        }
        
        if m_y < 0 {
            
            m_y = 1
        }
        
        if m_z < 1 {
            
            m_z = 1
        }
        
        //m_x = snap(m_x,m_snap_x)
        //m_y = snap(m_y,m_snap_y)
        //m_z = snap(m_z,1)
        
        let sbitmaps:String = { () -> String in
            
            //let cx = self.m_x/(self.m_multi ? 4 : 8)
            //let cy = self.m_y/8
            return "Bitmaps: X:" + String(format:"%0.2f", Double(m_x)/Double(m_multi ? 160 : 320)) + " Y:" + String(format:"%0.2f", Double(m_y)/Double(200)) + "\n"
        }()
        
        let schars:String = { () -> String in
            
            let cx = m_x/(m_multi ? 4 : 8)
            let cy = m_y/8
            return "Characters X:" + String(format:"%d", cx) + " Y:" + String(format:"%d", cy) + " Sum:" + String(format:"%d", cx*cy) + "\n"
        }()
        
        let ssprites:String = { () -> String in
            
            let cx = m_x/(m_multi ? 12 : 24)
            let cy = m_y/21
            return "Sprites: X:" + String(cx) + " Y:" + String(cy) + "Sum:" + String(cx*cy)
        }()
        
        
        switch m_select {
            
        case 0:
            m_info = sbitmaps + schars;
            
        case 1:    //Sprite
            m_info = ssprites;
            
        case 2:    //Char
            m_info = schars;
            
        case 3:    //Unrestricted
            if m_multi {
                
                m_info = "Wide"
            } else {
                
                m_info = "Square"
            }
            m_info += "X:" + String(format:"%0.2f", Double(m_x))
            m_info += "Y:" + String(format:"%0.2f", Double(m_y))
            m_info += "\n"
            
        default:
            break
        }
        
        var good = true
        
        if m_x != snap(m_x,m_snap_x) {
            
            let tmp = "Warning: Width must be divisible by " + String(m_snap_x) + "\n"
            m_info += tmp
            good = false
        }
        
        if m_y != snap(m_y,m_snap_y) {
            
            let tmp = "Warning: Height must be divisible by " + String(m_snap_y) + "\n"
            m_info+=tmp;
            good = false;
        }
        
        m_ok.isEnabled = good
        
        updateData(false)
    }
    
    /**
     This function simulates the Microsoft MFC function UpdateData(TRUE/FALSE).
     - Parameter state: With false the variable values are written to the visual control, with true the data of the control is written to the variables.
     */
    func updateData(_ state:Bool) {
        
        if state {
            
            // Write control values to vars
            if let selItem = self.modePopupButton.selectedItem {
            
                m_select = selItem.tag
            }
            
            if self.multiColorCheckbox.state == .on {
                
                m_multi = true
            } else {
                
                m_multi = false
            }
            
            m_x = Int(self.widthTextField.stringValue) ?? 0
            m_y = Int(self.heightTextField.stringValue) ?? 0
            m_z = Int(self.backBuffersTextField.stringValue) ?? 0
            m_info = self.infoLabel.stringValue
        } else {
            
            // Write vars to controls
            self.modePopupButton.selectItem(withTag: m_select)
            if m_multi {
            
                self.multiColorCheckbox.state = .on
            } else {
                
                self.multiColorCheckbox.state = .off
            }
            
            self.widthTextField.stringValue = String(m_x)
            self.heightTextField.stringValue = String(m_y)
            self.backBuffersTextField.stringValue = String(m_z)
            self.infoLabel.stringValue = m_info
        }
    }
}


// HEADER
/*
 // CNewDlg dialog
 
 class CNewDlg : public CDialogEx
 {
 DECLARE_DYNAMIC(CNewDlg)
 
 public:
 CNewDlg(CWnd* pParent = NULL);   // standard constructor
 virtual ~CNewDlg();
 
 // Dialog Data
 enum { IDD = IDD_NEW };
 
 protected:
 virtual void DoDataExchange(CDataExchange* pDX);    // DDX/DDV support
 
 DECLARE_MESSAGE_MAP()
 public:
 afx_msg void OnCbnSelchangeComboSelect();
 afx_msg void OnBnClickedCheckMulti();
 afx_msg void OnDeltaposSpinX(NMHDR *pNMHDR, LRESULT *pResult);
 afx_msg void OnDeltaposSpinY(NMHDR *pNMHDR, LRESULT *pResult);
 afx_msg void OnDeltaposSpinZ(NMHDR *pNMHDR, LRESULT *pResult);
 afx_msg void OnEnChangeEditX();
 afx_msg void OnEnChangeEditY();
 afx_msg void OnEnChangeEditZ();
 virtual BOOL OnInitDialog();
 virtual void OnOK();
 
 void UpdateInfo(void);
 
 int m_snap_x;
 int m_snap_y;
 
 static int Snap(int n, int snap)
 {
 n+=snap/2;
 return n - (n%snap);
 }
 
 int m_last_select;
 int m_select;
 
 BOOL m_last_multi;
 BOOL m_multi;
 
 int m_x;
 int m_y;
 int m_z;
 
 int m_std_x;
 int m_std_y;
 
 CString m_info;
 afx_msg void OnBnClickedReset();
 CButton m_ok;
 };
 */

///
/// IMPLEMENTATION
/*
 // CNewDlg dialog
 
 IMPLEMENT_DYNAMIC(CNewDlg, CDialogEx)
 
 CNewDlg::CNewDlg(CWnd* pParent /*=NULL*/)
 : CDialogEx(CNewDlg::IDD, pParent)
 , m_select(0)
 , m_multi(TRUE)
 , m_x(160)
 , m_y(200)
 , m_std_x(160)
 , m_std_y(200)
 , m_z(0)
 , m_info(_T(""))
 {
 m_last_select = -1;
 m_last_multi = -1;
 
 }
 
 CNewDlg::~CNewDlg()
 {
 }
 
 void CNewDlg::DoDataExchange(CDataExchange* pDX)
 {
 CDialogEx::DoDataExchange(pDX);
 DDX_CBIndex(pDX, IDC_COMBO_SELECT, m_select);
 DDX_Check(pDX, IDC_CHECK_MULTI, m_multi);
 DDX_Text(pDX, IDC_EDIT_X, m_x);
 DDX_Text(pDX, IDC_EDIT_Y, m_y);
 DDX_Text(pDX, IDC_EDIT_Z, m_z);
 DDX_Text(pDX, IDC_STATIC_INFO, m_info);
 DDX_Control(pDX, IDOK, m_ok);
 }
 
 
 BEGIN_MESSAGE_MAP(CNewDlg, CDialogEx)
 ON_CBN_SELCHANGE(IDC_COMBO_SELECT, &CNewDlg::OnCbnSelchangeComboSelect)
 ON_BN_CLICKED(IDC_CHECK_MULTI, &CNewDlg::OnBnClickedCheckMulti)
 ON_NOTIFY(UDN_DELTAPOS, IDC_SPIN_X, &CNewDlg::OnDeltaposSpinX)
 ON_NOTIFY(UDN_DELTAPOS, IDC_SPIN_Y, &CNewDlg::OnDeltaposSpinY)
 ON_NOTIFY(UDN_DELTAPOS, IDC_SPIN_Z, &CNewDlg::OnDeltaposSpinZ)
 ON_EN_CHANGE(IDC_EDIT_X, &CNewDlg::OnEnChangeEditX)
 ON_EN_CHANGE(IDC_EDIT_Y, &CNewDlg::OnEnChangeEditY)
 ON_EN_CHANGE(IDC_EDIT_Z, &CNewDlg::OnEnChangeEditZ)
 ON_BN_CLICKED(IDC_RESET, &CNewDlg::OnBnClickedReset)
 END_MESSAGE_MAP()
 
 
 // CNewDlg message handlers
 
 
 void CNewDlg::OnCbnSelchangeComboSelect()
 {
 // TODO: Add your control notification handler code here
 UpdateData(TRUE);
 
 if(m_x == m_std_x && m_y == m_std_y)
 {
 UpdateInfo();
 OnBnClickedReset();
 }
 else
 {
 UpdateInfo();
 }
 }
 
 
 void CNewDlg::OnBnClickedCheckMulti()
 {
 // TODO: Add your control notification handler code here
 OnCbnSelchangeComboSelect();
 }
 
 
 void CNewDlg::OnDeltaposSpinX(NMHDR *pNMHDR, LRESULT *pResult)
 {
 LPNMUPDOWN pNMUpDown = reinterpret_cast<LPNMUPDOWN>(pNMHDR);
 // TODO: Add your control notification handler code here
 *pResult = 0;
 UpdateData(TRUE);
 
 m_x -= pNMUpDown->iDelta * m_snap_x;
 m_x = Snap(m_x,m_snap_x);
 
 UpdateInfo();
 }
 
 
 void CNewDlg::OnDeltaposSpinY(NMHDR *pNMHDR, LRESULT *pResult)
 {
 LPNMUPDOWN pNMUpDown = reinterpret_cast<LPNMUPDOWN>(pNMHDR);
 // TODO: Add your control notification handler code here
 *pResult = 0;
 UpdateData(TRUE);
 
 m_y -= pNMUpDown->iDelta * m_snap_y;
 m_y = Snap(m_y,m_snap_y);
 
 UpdateInfo();
 }
 
 
 void CNewDlg::OnDeltaposSpinZ(NMHDR *pNMHDR, LRESULT *pResult)
 {
 LPNMUPDOWN pNMUpDown = reinterpret_cast<LPNMUPDOWN>(pNMHDR);
 // TODO: Add your control notification handler code here
 *pResult = 0;
 UpdateData(TRUE);
 
 m_z -= pNMUpDown->iDelta;
 
 UpdateInfo();
 }
 
 
 void CNewDlg::OnEnChangeEditX()
 {
 // TODO:  If this is a RICHEDIT control, the control will not
 // send this notification unless you override the CDialogEx::OnInitDialog()
 // function and call CRichEditCtrl().SetEventMask()
 // with the ENM_CHANGE flag ORed into the mask.
 
 // TODO:  Add your control notification handler code here
 UpdateData(TRUE);
 UpdateInfo();
 }
 
 
 void CNewDlg::OnEnChangeEditY()
 {
 // TODO:  If this is a RICHEDIT control, the control will not
 // send this notification unless you override the CDialogEx::OnInitDialog()
 // function and call CRichEditCtrl().SetEventMask()
 // with the ENM_CHANGE flag ORed into the mask.
 
 // TODO:  Add your control notification handler code here
 UpdateData(TRUE);
 UpdateInfo();
 }
 
 
 void CNewDlg::OnEnChangeEditZ()
 {
 // TODO:  If this is a RICHEDIT control, the control will not
 // send this notification unless you override the CDialogEx::OnInitDialog()
 // function and call CRichEditCtrl().SetEventMask()
 // with the ENM_CHANGE flag ORed into the mask.
 
 // TODO:  Add your control notification handler code here
 UpdateData(TRUE);
 UpdateInfo();
 }
 
 void CNewDlg::UpdateInfo(void)
 {
 
 if(m_last_select != m_select || m_last_multi != m_multi)
 {
 m_last_select = m_select;
 m_last_multi = m_multi;
 m_z = 1;
 switch(m_select)
 {
 case 0:    //Bitmap
 m_snap_x = m_multi ? 4 : 8;
 m_snap_y = 8;
 m_std_x = m_multi ? 160 : 320;
 m_std_y = 200;
 break;
 case 1:    //Sprite
 m_snap_x = m_multi ? 12 : 24;
 m_snap_y = 21;
 m_std_x = m_multi ? 96 : 192;
 m_std_y = 21 * 8;
 break;
 case 2:    //Char
 m_snap_x = m_multi ? 4 : 8;
 m_snap_y = 8;
 m_std_x = m_multi ? 128: 256;
 m_std_y =  8 * 8;
 break;
 case 3:    //Unrestricted
 m_snap_x = 1;
 m_snap_y = 1;
 m_std_x = m_multi ? 32 : 64;
 m_std_y = 64;
 break;
 };
 }
 
 if(m_x < 0)
 m_x = 1;
 
 if(m_y < 0)
 m_y = 1;
 
 if(m_z < 1)
 m_z = 1;
 
 //m_x = Snap(m_x,m_snap_x);
 //m_y = Snap(m_y,m_snap_y);
 //m_z = Snap(m_z,1);
 
 CString sbitmaps;
 {
 int cx = m_x/(m_multi ? 4 : 8);
 int cy = m_y/8;
 sbitmaps.Format(_T("Bitmaps: X:%0.2f Y:%0.2f\n"),m_x/double(m_multi ? 160 : 320),  m_y/double(200));
 }
 
 CString schars;
 {
 int cx = m_x/(m_multi ? 4 : 8);
 int cy = m_y/8;
 schars.Format(_T("Characters X:%d Y:%d Sum:%d\n"),cx, cy, cx*cy);
 }
 
 CString ssprites;
 {
 int cx = m_x/(m_multi ? 12 : 24);
 int cy = m_y/21;
 ssprites.Format(_T("Sprites: X:%d Y:%d Sum:%d\n"),cx, cy, cx*cy);
 }
 
 
 switch(m_select)
 {
 case 0:
 m_info = sbitmaps + schars;
 break;
 case 1:    //Sprite
 m_info = ssprites;
 break;
 case 2:    //Char
 m_info = schars;
 break;
 case 3:    //Unrestricted
 m_info.Format(_T("%s: X:%0.2f Y:%0.2f\n"),m_multi ? _T("Wide"): _T("Square"), double(m_x),  double(m_y));
 break;
 };
 
 bool good = true;
 
 if(m_x != Snap(m_x,m_snap_x))
 {
 CString tmp;
 tmp.Format(_T("Warning: Width must be divisible by %d\n"),m_snap_x);
 m_info+=tmp;
 good = false;
 }
 
 if(m_y != Snap(m_y,m_snap_y))
 {
 CString tmp;
 tmp.Format(_T("Warning: Height must be divisible by %d\n"),m_snap_y);
 m_info+=tmp;
 good = false;
 }
 
 m_ok.EnableWindow(good?1:0);
 
 UpdateData(FALSE);
 }
 
 
 
 void CNewDlg::OnOK()
 {
 // TODO: Add your specialized code here and/or call the base class
 
 CDialogEx::OnOK();
 }
 
 
 */
