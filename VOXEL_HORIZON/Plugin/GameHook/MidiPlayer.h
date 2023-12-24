#pragma once

class CMidiPlayer
{
	IVHController* m_pVHController = nullptr;
	WCHAR	m_wchPluginPath[_MAX_PATH] = {};

	BOOL	m_bUseKeyboardAsMidiKeyboard = FALSE;

	void	ListMidFiles();
	void	OnPianoKeyDown(DWORD dwKeyIndex);
	void	OnPianoKeyUp(DWORD dwKeyIndex);
	void	Cleanup();
public:

	BOOL	Initialize(IVHController* pVHController, const WCHAR* wchPluginPath);
	BOOL	OnPreConsoleCommand(const WCHAR* wchCmd, DWORD dwCmdLen);
	BOOL	OnKeyDown(UINT nChar);
	BOOL	OnKeyUp(UINT nChar);

	BOOL	PlayMidi(const char* szFileName);

	CMidiPlayer();
	~CMidiPlayer();
};

