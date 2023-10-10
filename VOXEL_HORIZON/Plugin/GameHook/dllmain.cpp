// dllmain.cpp : Defines the entry point for the DLL application.
#include "stdafx.h"
#include "../include/IGameHookController.h"
#include "GameHook.h"

BOOL APIENTRY DllMain( HMODULE hModule,
                       DWORD  ul_reason_for_call,
                       LPVOID lpReserved
                     )
{
    switch (ul_reason_for_call)
    {
    case DLL_PROCESS_ATTACH:
    case DLL_THREAD_ATTACH:
    case DLL_THREAD_DETACH:
    case DLL_PROCESS_DETACH:
        break;
    }
    return TRUE;
}



STDAPI DllCreateInstance(void** ppv)
{
	HRESULT hr;

    CGameHook* pGameHook = new CGameHook;
	hr = S_OK;
	*ppv = pGameHook;
lb_return:
	return hr;
}
