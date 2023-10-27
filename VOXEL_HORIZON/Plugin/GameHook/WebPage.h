#pragma once

class CWebPage
{
	static const DWORD DISPLAY_PANEL_WIDTH = 320;
	static const DWORD DISPLAY_PANEL_HEIGHT = 240;

	IVHController* m_pVHController = nullptr;
	CDisplayPanel*	m_pDisplayPanel = nullptr;
	//BYTE*	m_pBits32_OrigSize = nullptr;
	BYTE*	m_pBits32 = nullptr;
	BYTE*	m_pBits32Resized = nullptr;
	BYTE*	m_pBits8 = nullptr;
	DWORD	m_dwWidth = 0;
	DWORD	m_dwHeight = 0;
	char	m_szURL[1024] = {};
	WEB_CLIENT_HANDLE	m_pWebHandle = nullptr;
	DWORD m_dwGameFPS = 60;
	DWORD m_dwCurFPS = 0;
	float m_fTicksPerGameFrame = 16.6f;
	ULONGLONG m_PrvGameFrameTick = 0;
	LARGE_INTEGER	m_PrvCounter = {};
	BOOL m_bPause = FALSE;

	void	DrawScene();
public:
	BOOL			Initialize(IVHController* pVHController, char* szURL, DWORD dwWidth, DWORD dwHeight);
	BOOL			OnPreConsoleCommand(const WCHAR* wchCmd, DWORD dwCmdLen);
	BOOL			OnMouseLButtonDown(int x, int y, UINT nFlags);
	BOOL			OnMouseLButtonUp(int x, int y, UINT nFlags);
	BOOL			OnMouseMove(int x, int y, UINT nFlags);
	BOOL			OnMouseWheel(int x, int y, int iWheel);
	BOOL			OnKeyDown(UINT nChar);
	BOOL			OnKeyUp(UINT nChar);
	
	void			Process();
	CWebPage();
	~CWebPage();

};