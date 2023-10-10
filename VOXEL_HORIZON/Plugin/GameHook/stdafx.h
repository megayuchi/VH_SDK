// pch.h: This is a precompiled header file.
// Files listed below are compiled only once, improving build performance for future builds.
// This also affects IntelliSense performance, including code completion and many code browsing features.
// However, files listed here are ALL re-compiled if any one of them is updated between builds.
// Do not add files here that you will be updating frequently as this negates the performance advantage.

#ifndef PCH_H
#define PCH_H


#define WINVER 0x0A00
#define _WIN32_WINNT 0x0A00
#define WIN32_LEAN_AND_MEAN             // Exclude rarely-used stuff from Windows headers

#ifdef _DEBUG
	#define _CRTDBG_MAP_ALLOC
	#include <crtdbg.h>
	#define new new(_NORMAL_BLOCK, __FILE__, __LINE__)
#endif

// Windows Header Files
#include <initguid.h>
#include <ole2.h>
#include <stdlib.h>
#include <windows.h>
#include "../include/typedef.h"
#include "../include/IGameHookController.h"
#include "../include/BooleanTable.inl"
#include "../util/VoxelUtil.h"
#include "Util.h"


#endif //PCH_H
