//
//  CImage.h
//  libpixcen
//
//  Created by Jack Pearse on 24.11.20.
//

#ifndef CImage_h
#define CImage_h

#include <stdio.h>
#include <stdint.h> // uint32_t, etc.
#include "platform.h"
/**
 Wrapper. Mimics the CImage class and wraps it to the platform specific class.
 */
class CImage
{
public:
   
    CImage();
    virtual ~CImage();
    
    void* GetPixelAddress(int x, int y) throw();
    bool Create(int nWidth, int nHeight, int nBPP, uint32_t dwFlags = 0) throw();
    
    HRESULT Load(LPCTSTR pszFileName) throw();
    //HRESULT Load(IStream* pStream) throw();
    
    int GetWidth() const throw();
    int GetHeight() const throw();
};

#endif /* CImage_h */
