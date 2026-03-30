//
//  platform.h
//  pixcen
//
//  Created by Jack Pearse on 30.06.20.
//  Copyright © 2020 Drehwerk. All rights reserved.
//

#ifndef platform_h
#define platform_h

#ifdef __APPLE__
#include <stdint.h> // uint32_t, etc.
//#include <cstdlib.h>  // size_t
#include <stdlib.h>  // size_t
//#include <climits>  // INT_MAX, etc.
#include <limits.h>  // INT_MAX, etc.

#include <stdio.h>
#include <stdlib.h>
#include <wchar.h>
#include <string.h>
#include <assert.h>


/*
static char *_itoa(unsigned i, char *a, unsigned r)
{
    if (i/r > 0) a = _itoa(i/r,a,r);
    *a = "0123456789ABCDEF"[i%r];
    return a+1;
}

char *itoa(int i, char *a, int r)
{
    if ((r < 2) || (r > 16)) r = 10;
    if (i < 0)
    {
        *a = '-';
        *_itoa(-i,a+1,r) = 0;
    }
    else *_itoa(i,a,r) = 0;
    return a;
}
*/

// TODO: implement or find there functions
const wchar_t * _itow( int value, wchar_t *buffer, int radix );
int _wtoi( const wchar_t *string );


// Define Microsoft types for use in Apple platform
 
// When specifying an explicit RGB color,
// the COLORREF value has the following hexadecimal form:
// 0x00bbggrr
typedef uint32_t DWORD;
typedef DWORD COLORREF;
typedef DWORD* LPCOLORREF;
typedef unsigned char BYTE;


typedef char TCHAR;
typedef wchar_t WCHAR;
typedef char* LPSTR;
typedef const char* LPCSTR;
typedef wchar_t* LPWSTR;
typedef const wchar_t* LPCWSTR;

#ifdef UNICODE
 typedef LPCWSTR LPCTSTR;
#define _T(x) L(x)
#else
 typedef LPCSTR LPCTSTR;
#define _T(x) (x)
#endif
#endif /* __APPLE__ */

#define ASSERT(x) assert(x)
#define HRESULT uint32_t

#define ZeroMemory RtlZeroMemory
#define RtlZeroMemory(Destination,Length) memset((Destination),0,(Length))

#define __stdcall
#define lstrcmpi strcasecmp

// MSVC memory/file functions
#define _aligned_malloc(size, alignment) malloc(size)
#define _aligned_free(ptr) free(ptr)
#define _tfopen fopen

// MSVC 'byte' type (conflicts with std::byte on macOS)
#ifndef byte
#define byte unsigned char
#endif

#endif /* platform_h */
