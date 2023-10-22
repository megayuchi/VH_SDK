#include "stdafx.h"
#include "../include/BooleanTable.inl"
#include "../util/VoxelUtil.h"
#include "Util.h"
#include "GameHook.h"
#include "DisplayPanel.h"
#include "Game.h"
#include "VoxelEditor.h"
#include "WebPage.h"
#include "lodepng.h"

const int FIRST_PIANO_KEY = 48;
const DWORD PIANO_KEY_NUM = 36;
const DWORD MIN_VELOCITY = 32;

//#define MIDI_INPUT_MODE

CGameHook* g_pGameHook = nullptr;

void __stdcall CALLBACK_OnDeleteVoxelObject(IVoxelObjectLite* pVoxelObj)
{
	// 복셀 오브젝트가 삭제될때 자동으로 호출된다.
	// pVoxelObj를 참조하는 변수가 있다면 여기서 초기화시켜야 한다.
	g_pGameHook->OnDeleteVoxelObject(pVoxelObj);
}

CGameHook::CGameHook()
{
#ifdef _DEBUG
	_CrtSetDbgFlag(_CRTDBG_ALLOC_MEM_DF | _CRTDBG_LEAK_CHECK_DF);
#endif
	g_pGameHook = this;

}
STDMETHODIMP CGameHook::QueryInterface(REFIID refiid, void** ppv)
{
	*ppv = nullptr;

	return E_NOINTERFACE;
}
STDMETHODIMP_(ULONG) CGameHook::AddRef()
{
	m_dwRefCount++;
	return m_dwRefCount;
}
STDMETHODIMP_(ULONG) CGameHook::Release()
{
	DWORD	ref_count = --m_dwRefCount;
	if (!m_dwRefCount)
		delete this;

	return ref_count;
}
void __stdcall CGameHook::OnStartScene(IVHController* pVHController, IVHNetworkLayer* pNetworkLayer, const WCHAR* wchPluginPath)
{
	const WCHAR* wchPulginName = L"GameHook";
	const WCHAR* wchArch = nullptr;
	const WCHAR* wchConfig = nullptr;
#if defined(_M_ARM64EC) || defined(_M_ARM64)
	wchArch = L"arm64";
#elif defined(_M_AMD64)
	wchArch = L"x64";
#elif defined(_M_IX86)
	wchArch = L"x86";
#endif

#ifdef _DEBUG
	wchConfig = L"debug";
#else
	wchConfig = L"release";
#endif

	m_pVHController = pVHController;
	m_pNetworkLayer = pNetworkLayer;

	m_pVHController->SetOnDeleteVoxelObjectFunc(CALLBACK_OnDeleteVoxelObject);

	m_pVHController->WriteTextToSystemDlgW(COLOR_VALUE_MAGENTA, L"[Plug-in] %s_%s_%s.dll Loading completed.\n", wchPulginName, wchArch, wchConfig);

	wcscpy_s(m_wchPluginPath, wchPluginPath);

	m_pVoxelEditor = new CVoxelEditor;
	m_pVoxelEditor->Initialize(m_pVHController, m_pNetworkLayer);
}

void __stdcall CGameHook::OnRun()
{
	if (m_pGame)
	{
		m_pGame->Process();
	}
	if (m_pWebPage)
	{
		m_pWebPage->Process();
	}


}
void CGameHook::OnDeleteVoxelObject(IVoxelObjectLite* pVoxelObj)
{
	if (m_pGame)
	{
		m_pGame->OnDeleteVoxelObject(pVoxelObj);
	}
	if (m_pVoxelEditor)
	{
		m_pVoxelEditor->OnDeleteVoxelObject(pVoxelObj);
	}
}
void __stdcall CGameHook::OnDestroyScene()
{
	//
	// 이 플러그인에서 할당한 IVoxelObjectLite가 있다면 여기서 해제한다. 이 함수가 리턴한 이후로는 해제해서는 안된다.
	//
	if (m_pGame)
	{
		delete m_pGame;
		m_pGame = nullptr;
	}
	if (m_pVoxelEditor)
	{
		delete m_pVoxelEditor;
		m_pVoxelEditor = nullptr;
	}
	if (m_pWebPage)
	{
		delete m_pWebPage;
		m_pWebPage = nullptr;
	}
}
BOOL __stdcall CGameHook::OnMouseLButtonDown(int x, int y, UINT nFlags)
{
	BOOL	bProcessed = FALSE;
	if (m_pWebPage)
	{
		bProcessed = m_pWebPage->OnMouseLButtonDown(x, y, nFlags);
		if (bProcessed)
			goto lb_return;
	}
	if (m_pVoxelEditor)
	{
		bProcessed = m_pVoxelEditor->OnMouseLButtonDown(x, y, nFlags);
	}
lb_return:
	return bProcessed;
}
BOOL __stdcall CGameHook::OnMouseLButtonUp(int x, int y, UINT nFlags)
{
	BOOL	bProcessed = FALSE;
	if (m_pWebPage)
	{
		bProcessed = m_pWebPage->OnMouseLButtonUp(x, y, nFlags);
		if (bProcessed)
			goto lb_return;
	}
	if (m_pVoxelEditor)
	{
		bProcessed = m_pVoxelEditor->OnMouseLButtonUp(x, y, nFlags);
	}
lb_return:
	return bProcessed;
}

BOOL __stdcall CGameHook::OnMouseRButtonDown(int x, int y, UINT nFlags)
{
	return FALSE;
}
BOOL __stdcall CGameHook::OnMouseRButtonUp(int x, int y, UINT nFlags)
{
	return FALSE;
}
BOOL __stdcall CGameHook::OnMouseMove(int x, int y, UINT nFlags)
{
	return FALSE;
}

BOOL __stdcall CGameHook::OnMouseMoveHV(int iMoveX, int iMoveY, BOOL bLButtonPressed, BOOL bRButtonPressed, BOOL bMButtonPressed)
{
	return FALSE;
}
BOOL __stdcall CGameHook::OnMouseWheel(int iWheel)
{
	return FALSE;
}

void CGameHook::OnPianoKeyDown(DWORD dwKeyIndex)
{
	m_pVHController->WriteNoteOrControl(MIDI_SIGNAL_TYPE_NOTE, TRUE, (unsigned char)(FIRST_PIANO_KEY + dwKeyIndex), 127);
}
void CGameHook::OnPianoKeyUp(DWORD dwKeyIndex)
{
	m_pVHController->WriteNoteOrControl(MIDI_SIGNAL_TYPE_NOTE, FALSE, (unsigned char)(FIRST_PIANO_KEY + dwKeyIndex), 127);
}

BOOL __stdcall CGameHook::OnKeyDown(UINT nChar)
{
	BOOL	bProcessed = FALSE;

	switch (nChar)
	{
		case 'A':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyDown(0);
					bProcessed = TRUE;
				}
			}
			break;
		case 'W':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyDown(1);
					bProcessed = TRUE;
				}
			}
			break;
		case 'S':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyDown(2);
					bProcessed = TRUE;
				}
			}
			break;
		case 'E':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyDown(3);
					bProcessed = TRUE;
				}
			}
			break;
		case 'D':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyDown(4);
					bProcessed = TRUE;
				}
			}
			break;
		case 'F':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyDown(5);
					bProcessed = TRUE;
				}
			}
			break;
		case 'T':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyDown(6);
					bProcessed = TRUE;
				}
			}
			break;
		case 'G':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyDown(7);
					bProcessed = TRUE;
				}
			}
			break;
		case 'Y':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyDown(8);
					bProcessed = TRUE;
				}
			}
			break;
		case 'H':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyDown(9);
					bProcessed = TRUE;
				}
			}
			break;
		case 'U':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyDown(10);
					bProcessed = TRUE;
				}
			}
			break;
		case 'J':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyDown(11);
					bProcessed = TRUE;
				}
			}
			break;
		case 'K':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyDown(12);
					bProcessed = TRUE;
				}
			}
			break;
		case 'M':
			{
				if (m_bMidiInputMode)
				{
					m_bMidiInputMode = FALSE;
					m_pVHController->WriteTextToSystemDlgW(COLOR_VALUE_GREEN, L"Midi Mode Off.\n");
				}
				else
				{
					m_bMidiInputMode = TRUE;
					m_pVHController->WriteTextToSystemDlgW(COLOR_VALUE_GREEN, L"Midi Mode On.\n");
				}
				bProcessed = TRUE;

			}
			break;
		/*
		case VK_UP:
			{
				if (m_pDisplayPanel)
				{
					m_bUpKeyPressed = TRUE;
					bProcessed = TRUE;
				}
			}
			break;
		case VK_DOWN:
			{
				if (m_pDisplayPanel)
				{
					m_bDownKeyPressed = TRUE;
					bProcessed = TRUE;
				}
			}
			break;
		case VK_LEFT:
			{
				if (m_pDisplayPanel)
				{
					m_bLeftKeyPressed = TRUE;
					bProcessed = TRUE;
				}
			}
			break;
		case VK_RIGHT:
			{
				if (m_pDisplayPanel)
				{
					m_bRightKeyPressed = TRUE;
					bProcessed = TRUE;
				}
			}
			break;
			*/
		case VK_RETURN:
			{
				StartGame();
				bProcessed = TRUE;
			}
			break;
	}
	if (m_pGame)
	{
		bProcessed |= m_pGame->OnKeyDown(nChar);
	}
	return bProcessed;
}
BOOL __stdcall CGameHook::OnKeyUp(UINT nChar)
{
	BOOL	bProcessed = FALSE;
	switch (nChar)
	{
		case 'A':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyUp(0);
					bProcessed = TRUE;
				}
			}
			break;
		case 'W':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyUp(1);
					bProcessed = TRUE;
				}
			}
			break;
		case 'S':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyUp(2);
					bProcessed = TRUE;
				}
			}
			break;
		case 'E':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyUp(3);
					bProcessed = TRUE;
				}
			}
			break;
		case 'D':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyUp(4);
					bProcessed = TRUE;
				}
			}
			break;
		case 'F':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyUp(5);
					bProcessed = TRUE;
				}
			}
			break;
		case 'T':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyUp(6);
					bProcessed = TRUE;
				}
			}
			break;
		case 'G':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyUp(7);
					bProcessed = TRUE;
				}
			}
			break;
		case 'Y':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyUp(8);
					bProcessed = TRUE;
				}
			}
			break;
		case 'H':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyUp(9);
					bProcessed = TRUE;
				}
			}
			break;
		case 'U':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyUp(10);
					bProcessed = TRUE;
				}
			}
			break;
		case 'J':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyUp(11);
					bProcessed = TRUE;
				}
			}
			break;
		case 'K':
			{
				if (m_bMidiInputMode)
				{
					OnPianoKeyUp(12);
					bProcessed = TRUE;
				}
			}
			break;
	}
	if (m_pGame)
	{
		bProcessed |= m_pGame->OnKeyUp(nChar);
	}
	return bProcessed;
}
BOOL __stdcall CGameHook::OnCharUnicode(UINT nChar)
{
	return FALSE;
}
BOOL __stdcall CGameHook::OnDPadLB()
{
	return FALSE;
}
BOOL __stdcall CGameHook::OffDPadLB()
{
	return FALSE;
}
BOOL __stdcall CGameHook::OnDPadRB()
{
	return FALSE;
}
BOOL __stdcall CGameHook::OffDPadRB()
{
	return FALSE;
}
BOOL __stdcall CGameHook::OnDPadUp()
{
	return FALSE;
}
BOOL __stdcall CGameHook::OnDPadDown()
{
	return FALSE;
}
BOOL __stdcall CGameHook::OnDPadLeft()
{
	return FALSE;
}
BOOL __stdcall CGameHook::OnDPadRight()
{
	return FALSE;
}
BOOL __stdcall CGameHook::OffDPadUp()
{
	return FALSE;
}
BOOL __stdcall CGameHook::OffDPadDown()
{
	return FALSE;
}
BOOL __stdcall CGameHook::OffDPadLeft()
{
	return FALSE;
}
BOOL __stdcall CGameHook::OffDPadRight()
{
	return FALSE;
}
BOOL __stdcall	CGameHook::OnPadPressedA()
{
	return FALSE;
}
BOOL __stdcall	CGameHook::OnPadPressedB()
{
	return FALSE;
}
BOOL __stdcall	CGameHook::OnPadPressedX()
{
	return FALSE;
}
BOOL __stdcall	CGameHook::OnPadPressedY()
{
	return FALSE;
}
BOOL __stdcall	CGameHook::OffPadPressedA()
{
	return FALSE;
}
BOOL __stdcall	CGameHook::OffPadPressedB()
{
	return FALSE;
}
BOOL __stdcall	CGameHook::OffPadPressedX()
{
	return FALSE;
}
BOOL __stdcall	CGameHook::OffPadPressedY()
{
	return FALSE;
}
BOOL __stdcall	CGameHook::OnKeyDownFunc(UINT nChar)
{
	return FALSE;
}
BOOL __stdcall	CGameHook::OnKeyDownCtrlFunc(UINT nChar)
{
	BOOL	bProcessed = FALSE;
	switch (nChar)
	{
		case VK_F11:
			{
				if (m_pWebPage)
				{
					delete m_pWebPage;
					m_pWebPage = nullptr;
				}
				m_pWebPage = new CWebPage;
			
			
				//m_pWebPage->Initialize(m_pVHController, "https://www.shadertoy.com/view/XsXXDB");
				m_pWebPage->Initialize(m_pVHController, "https://youtu.be/bhPXCkqfSkk?si=F9Sc8kPFn7RJNaea");
				//m_pWebPage->Initialize(m_pVHController, "https://bing.com");
				bProcessed = TRUE;
			}
			break;
	}
	return bProcessed;
}
BOOL __stdcall CGameHook::OnPreConsoleCommand(const WCHAR* wchCmd, DWORD dwCmdLen)
{
	BOOL	bResult = FALSE;
	
	// 채팅 다이얼로그 시스템 출력창에 출력
	m_pVHController->WriteTextToSystemDlgW(COLOR_VALUE_CYAN, L"[Plug-in] OnPreConsoleCommand:\"%s\".\n", wchCmd);

	// 콘솔창에 출력
	m_pVHController->BeginWriteTextToConsole();

	WCHAR wchTxt[128] = {};
	int iLen = (int)swprintf_s(wchTxt, L"[Plug-in] OnPreConsoleCommand:\"%s\"", wchCmd);
			
	//WriteTextToConsole()함수는 가변인자를 허용하지 않음.
	m_pVHController->WriteTextToConsole(wchTxt, iLen, COLOR_VALUE_MAGENTA);
			
	m_pVHController->EndWriteTextToConsole();

	// 게임 레이어에서 더 이상 처리하지 않기를 바란다면 TRUE를 리턴
	//bResult = TRUE;

	// 게임 레이어에서 계속 처리하지를 원한다면 FALSE를 리턴
	bResult = FALSE;

	return bResult;
}

BOOL __stdcall CGameHook::OnMidiInput(const MIDI_NOTE_L* pNote)
{
	BOOL	bResult = FALSE;
	
	if (!m_bMidiInputMode)
		return FALSE;

	MIDI_SIGNAL_TYPE type = MIDI_SIGNAL_TYPE_NOTE;
	if (pNote->IsControl())
	{
		type = MIDI_SIGNAL_TYPE_CONTROL;
	}
	if (MIDI_SIGNAL_TYPE_NOTE == type)
	{
		BOOL	bOnOff = pNote->GetOnOff();
		DWORD	dwKey = pNote->GetKey();
		DWORD	dwVelocity = pNote->GetVelocity() + MIN_VELOCITY;
		if (dwVelocity > 127)
			dwVelocity = 127;

		m_pVHController->WriteNoteOrControl(MIDI_SIGNAL_TYPE_NOTE, bOnOff, dwKey, dwVelocity);

		DWORD dwButtonIndex = dwKey - FIRST_PIANO_KEY;

		if (dwButtonIndex < PIANO_KEY_NUM)
		{
			if (bOnOff)
			{
				// draw that piano key pressed
				bResult = TRUE;
			}
			else
			{
				// draw that piano key released
				bResult = TRUE;
			}
		}
		else
		{
			int a = 0;
		}
	}
	else if (MIDI_SIGNAL_TYPE_CONTROL == type)
	{
		DWORD	dwController = pNote->GetController();
		DWORD	dwControlValue = pNote->GetControlValue();

		m_pVHController->WriteNoteOrControl(MIDI_SIGNAL_TYPE_CONTROL, TRUE, dwController, dwControlValue);
		if (64 == dwController)
		{
			if (127 == dwControlValue)
			{
				// draw that sustain pedal pressed
				bResult = TRUE;
			}
			else
			{
				// draw that sustain pedal released
				bResult = TRUE;
			}
		}
	}
	return bResult;
}
/*
IVoxelObjectLite* CSceneBattleField::CreateVoxelObject(VECTOR3* pv3Pos, UINT WidthDepthHeight, CREATE_VOXEL_OBJECT_ERROR* pOutErr)
{
	IVoxelObjectLite*	pVoxelObj = m_pVoxelObjectManager->CreateVoxelObject(pv3Pos, WidthDepthHeight, 0xffffffff, pOutErr);


	return pVoxelObj;
}
*/
void CGameHook::StartGame()
{
	if (m_pGame)
	{
		delete m_pGame;
		m_pGame = nullptr;
	}
	m_pGame = new CGame;
	m_pGame->Initialize(m_pVHController, m_wchPluginPath);
	/*
	WCHAR	wchOldPath[_MAX_PATH] = {};
	GetCurrentDirectory(_MAX_PATH, wchOldPath);

	SetCurrentDirectory(m_wchPluginPath);


	DWORD	dwImageWidth = 0;
	DWORD	dwImageHeight = 0;
	//const char* szImageFileName = "videogirl.png";
	const char* szImageFileName = "madoka.png";
	if (LoadPngImageAsPalettedImage(&m_pBackImage, &dwImageWidth, &dwImageHeight, szImageFileName))
	{
		m_ivBackImageSize.x = dwImageWidth;
		m_ivBackImageSize.y = dwImageHeight;

		//m_pDisplayPanel->SetPalettedImage(m_pBackImage, dwImageWidth, dwImageHeight);

		m_pDisplayPanel->DrawPalettedBitmap(m_ivBackImagePos.x, m_ivBackImagePos.y, m_ivBackImageSize.x, m_ivBackImageSize.y, m_pBackImage);

		m_pDisplayPanel->UpdateBitmapToVoxelData(0);
		//m_pDisplayPanel->UpdateBitmapToVoxelData(7);
	}
	SetCurrentDirectory(wchOldPath);
	*/
}

CGameHook::~CGameHook()
{
	//
	// 여기서 IVoxelObjectLite를 제거해선 안된다.
	//

	m_pVHController->WriteTextToSystemDlgW(COLOR_VALUE_RED, L"[Plug-in] GameHook will be unloaded.\n");
	g_pGameHook = nullptr;
#ifdef _DEBUG
	_ASSERT(_CrtCheckMemory());
#endif
}

