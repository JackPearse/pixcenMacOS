/*
   Pixcen macOS Port - stdafx.h replacement

   This file replaces the original Windows stdafx.h precompiled header.
   It provides platform shims, threadpool wrappers, and MSVC compatibility
   defines needed to compile the original pixcen C++ sources on macOS.
*/

#pragma once

#include <cstdint>

#include "platform.h"
#include "threadpool.h"

// MSVC __super keyword emulation
// All format classes (MCBitmap, Bitmap, Sprite, Font, Unrestricted) inherit from C64Interface
#define __super C64Interface

// Threadpool global - defined in C64Interface.cpp
extern threadpool *g_pThreadPool;

typedef threadpool::waitable waitable;

template<typename Function>
waitable schedule(Function && fn)
{
	return g_pThreadPool->schedule(fn);
}

template<typename Function>
void fire_and_forget(Function && fn)
{
	g_pThreadPool->fire_and_forget(fn);
}

template<typename Function>
void paralell_for(int to, Function && fn)
{
	g_pThreadPool->paralell_for(to, fn);
}
