#pragma once

#include "../include/IGameHookController.h"

class CDisplayPanel;
class CGame;
class CVoxelEditor;
class CGameHook : public IGameHook
{
	DWORD	m_dwRefCount = 1;
	IVHController* m_pVHController = nullptr;
	IVHNetworkLayer*	m_pNetworkLayer = nullptr;

	WCHAR	m_wchPluginPath[_MAX_PATH] = {};

	CGame*	m_pGame = nullptr;
	BOOL	m_bUpKeyPressed = FALSE;
	BOOL	m_bLeftKeyPressed = FALSE;
	BOOL	m_bRightKeyPressed = FALSE;
	BOOL	m_bDownKeyPressed = FALSE;

	CVoxelEditor*	m_pVoxelEditor = nullptr;
	
	

	void	StartGame();
	
public:
	STDMETHODIMP					QueryInterface(REFIID, void** ppv);
	STDMETHODIMP_(ULONG)			AddRef();
	STDMETHODIMP_(ULONG)			Release();

	// implements IGameHook
	void __stdcall	OnStartScene(IVHController* pVHController, IVHNetworkLayer* pNetworkLayer, const WCHAR* wchPluginPath);
	void __stdcall	OnRun();
	void __stdcall	OnDestroyScene();

	// input
	BOOL __stdcall	OnMouseLButtonDown(int x, int y, UINT nFlags);
	BOOL __stdcall	OnMouseLButtonUp(int x, int y, UINT nFlags);
	BOOL __stdcall	OnMouseRButtonDown(int x, int y, UINT nFlags);
	BOOL __stdcall	OnMouseRButtonUp(int x, int y, UINT nFlags);
	BOOL __stdcall	OnMouseMove(int x, int y, UINT nFlags);
	BOOL __stdcall	OnMouseMoveHV(int iMoveX, int iMoveY, BOOL bLButtonPressed, BOOL bRButtonPressed, BOOL bMButtonPressed);
	BOOL __stdcall	OnMouseWheel(int iWheel);

	BOOL __stdcall	OnKeyDown(UINT nChar);
	BOOL __stdcall	OnKeyUp(UINT nChar);
	BOOL __stdcall	OnCharUnicode(UINT nChar);

	BOOL __stdcall	OnDPadLB();
	BOOL __stdcall	OffDPadLB();
	BOOL __stdcall	OnDPadRB();
	BOOL __stdcall	OffDPadRB();

	BOOL __stdcall	OnDPadUp();
	BOOL __stdcall	OnDPadDown();
	BOOL __stdcall	OnDPadLeft();
	BOOL __stdcall	OnDPadRight();
	BOOL __stdcall	OffDPadUp();
	BOOL __stdcall	OffDPadDown();
	BOOL __stdcall	OffDPadLeft();
	BOOL __stdcall	OffDPadRight();

	BOOL __stdcall	OnPadPressedA();
	BOOL __stdcall	OnPadPressedB();
	BOOL __stdcall	OnPadPressedX();
	BOOL __stdcall	OnPadPressedY();
	BOOL __stdcall	OffPadPressedA();
	BOOL __stdcall	OffPadPressedB();
	BOOL __stdcall	OffPadPressedX();
	BOOL __stdcall	OffPadPressedY();

	BOOL __stdcall	OnKeyDownFunc(UINT nChar);
	BOOL __stdcall	OnKeyDownCtrlFunc(UINT nChar);
	BOOL __stdcall	OnPreConsoleCommand(const WCHAR* wchCmd, DWORD dwCmdLen);

	void	OnDeleteVoxelObject(IVoxelObjectLite* pVoxelObj);
	CGameHook();
	~CGameHook();
};

extern CGameHook* g_pGameHook;
