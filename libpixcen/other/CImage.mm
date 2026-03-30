//
//  CImage.c
//  libpixcen
//
//  Created by Jack Pearse on 24.11.20.
//

#include "CImage.h"

CImage::CImage()
{
    
}

CImage::~CImage()
{
}

void* CImage::GetPixelAddress(int x, int y) throw() {
    
    return NULL;
}

bool CImage::Create(int nWidth, int nHeight, int nBPP, uint32_t dwFlags) throw() {
    
    return true;
}

HRESULT CImage::Load(LPCTSTR pszFileName) throw() {
    
    return 0;
}
/*
HRESULT CImage::Load(IStream* pStream) throw() {
    
    return 0;
}
 */

int CImage::GetWidth() const throw() {
    
    return 0;
}

int CImage::GetHeight() const throw() {
    
    return 0;
}
