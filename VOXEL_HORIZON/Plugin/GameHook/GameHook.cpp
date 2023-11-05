#include "stdafx.h"
#include "../include/BooleanTable.inl"
#include "../util/VoxelUtil.h"
#include "../util/Stack.h"
#include "Util.h"
#include "GameHook.h"
#include "DisplayPanel.h"
#include "TestGame.h"
#include "VoxelEditor.h"
#include "WebPage.h"
#include "MidiPlayer.h"
#include "./lodepng/lodepng.h"
#include "../util/QueryPerfCounter.h"



//#define MIDI_INPUT_MODE

CTestGameHook* g_pGameHook = nullptr;

void __stdcall CALLBACK_OnDeleteVoxelObject(IVoxelObjectLite* pVoxelObj)
{
	// 복셀 오브젝트가 삭제될때 자동으로 호출된다.
	// pVoxelObj를 참조하는 변수가 있다면 여기서 초기화시켜야 한다.
	g_pGameHook->OnDeleteVoxelObject(pVoxelObj);
}

CTestGameHook::CTestGameHook()
{
#ifdef _DEBUG
	_CrtSetDbgFlag(_CRTDBG_ALLOC_MEM_DF | _CRTDBG_LEAK_CHECK_DF);
#endif
	QCInit();
	g_pGameHook = this;

}
STDMETHODIMP CTestGameHook::QueryInterface(REFIID refiid, void** ppv)
{
	*ppv = nullptr;

	return E_NOINTERFACE;
}
STDMETHODIMP_(ULONG) CTestGameHook::AddRef()
{
	m_dwRefCount++;
	return m_dwRefCount;
}
STDMETHODIMP_(ULONG) CTestGameHook::Release()
{
	DWORD	ref_count = --m_dwRefCount;
	if (!m_dwRefCount)
		delete this;

	return ref_count;
}
void __stdcall CTestGameHook::OnStartScene(IVHController* pVHController, IVHNetworkLayer* pNetworkLayer, const WCHAR* wchPluginPath)
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

void __stdcall CTestGameHook::OnRun()
{
	if (m_pTestGame)
	{
		m_pTestGame->Process();
	}
	if (m_pWebPage)
	{
		m_pWebPage->Process();
	}
	if (m_pVoxelEditor)
	{
		m_pVoxelEditor->Process();
	}
}
void CTestGameHook::OnDeleteVoxelObject(IVoxelObjectLite* pVoxelObj)
{
	if (m_pTestGame)
	{
		m_pTestGame->OnDeleteVoxelObject(pVoxelObj);
	}
	if (m_pVoxelEditor)
	{
		m_pVoxelEditor->OnDeleteVoxelObject(pVoxelObj);
	}
}
void __stdcall CTestGameHook::OnDestroyScene()
{
	//
	// 이 플러그인에서 할당한 IVoxelObjectLite가 있다면 여기서 해제한다. 이 함수가 리턴한 이후로는 해제해서는 안된다.
	//
	if (m_pTestGame)
	{
		delete m_pTestGame;
		m_pTestGame = nullptr;
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
	if (m_pMidiPlayer)
	{
		delete m_pMidiPlayer;
		m_pMidiPlayer = nullptr;
	}
}
BOOL __stdcall CTestGameHook::OnMouseLButtonDown(int x, int y, UINT nFlags)
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
BOOL __stdcall CTestGameHook::OnMouseLButtonUp(int x, int y, UINT nFlags)
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

BOOL __stdcall CTestGameHook::OnMouseRButtonDown(int x, int y, UINT nFlags)
{
	return FALSE;
}
BOOL __stdcall CTestGameHook::OnMouseRButtonUp(int x, int y, UINT nFlags)
{
	return FALSE;
}
BOOL __stdcall CTestGameHook::OnMouseMove(int x, int y, UINT nFlags)
{
	BOOL	bProcessed = FALSE;
	if (nFlags & MK_LBUTTON)
	{	
		if (m_pWebPage)
		{
			bProcessed = m_pWebPage->OnMouseMove(x, y, nFlags);
		}
	}
lb_return:
	return bProcessed;
}

BOOL __stdcall CTestGameHook::OnMouseMoveHV(int iMoveX, int iMoveY, BOOL bLButtonPressed, BOOL bRButtonPressed, BOOL bMButtonPressed)
{
	return FALSE;
}
BOOL __stdcall CTestGameHook::OnMouseWheel(int x, int y, int iWheel)
{
	BOOL	bProcessed = FALSE;
	if (m_pWebPage)
	{
		bProcessed = m_pWebPage->OnMouseWheel(x, y, iWheel);
	}
lb_return:
	return bProcessed;
}



BOOL __stdcall CTestGameHook::OnKeyDown(UINT nChar)
{
	BOOL	bProcessed = FALSE;

	switch (nChar)
	{

		case VK_RETURN:
			{
				StartGame();
				bProcessed = TRUE;
			}
			break;
	}
	
	if (m_pTestGame)
	{
		bProcessed |= m_pTestGame->OnKeyDown(nChar);
	}
	if (m_pWebPage)
	{
		bProcessed |= m_pWebPage->OnKeyDown(nChar);
	}
	if (m_pMidiPlayer)
	{
		bProcessed |= m_pMidiPlayer->OnKeyDown(nChar);
	}
	return bProcessed;
}
BOOL __stdcall CTestGameHook::OnKeyUp(UINT nChar)
{
	BOOL	bProcessed = FALSE;
	
	if (m_pTestGame)
	{
		bProcessed |= m_pTestGame->OnKeyUp(nChar);
	}
	if (m_pWebPage)
	{
		bProcessed |= m_pWebPage->OnKeyUp(nChar);
	}
	if (m_pMidiPlayer)
	{
		bProcessed |= m_pMidiPlayer->OnKeyUp(nChar);
	}
	return bProcessed;
}
BOOL __stdcall CTestGameHook::OnCharUnicode(UINT nChar)
{
	return FALSE;
}
BOOL __stdcall CTestGameHook::OnDPadLB()
{
	return FALSE;
}
BOOL __stdcall CTestGameHook::OffDPadLB()
{
	return FALSE;
}
BOOL __stdcall CTestGameHook::OnDPadRB()
{
	return FALSE;
}
BOOL __stdcall CTestGameHook::OffDPadRB()
{
	return FALSE;
}
BOOL __stdcall CTestGameHook::OnDPadUp()
{
	return FALSE;
}
BOOL __stdcall CTestGameHook::OnDPadDown()
{
	return FALSE;
}
BOOL __stdcall CTestGameHook::OnDPadLeft()
{
	return FALSE;
}
BOOL __stdcall CTestGameHook::OnDPadRight()
{
	return FALSE;
}
BOOL __stdcall CTestGameHook::OffDPadUp()
{
	return FALSE;
}
BOOL __stdcall CTestGameHook::OffDPadDown()
{
	return FALSE;
}
BOOL __stdcall CTestGameHook::OffDPadLeft()
{
	return FALSE;
}
BOOL __stdcall CTestGameHook::OffDPadRight()
{
	return FALSE;
}
BOOL __stdcall	CTestGameHook::OnPadPressedA()
{
	return FALSE;
}
BOOL __stdcall	CTestGameHook::OnPadPressedB()
{
	return FALSE;
}
BOOL __stdcall	CTestGameHook::OnPadPressedX()
{
	return FALSE;
}
BOOL __stdcall	CTestGameHook::OnPadPressedY()
{
	return FALSE;
}
BOOL __stdcall	CTestGameHook::OffPadPressedA()
{
	return FALSE;
}
BOOL __stdcall	CTestGameHook::OffPadPressedB()
{
	return FALSE;
}
BOOL __stdcall	CTestGameHook::OffPadPressedX()
{
	return FALSE;
}
BOOL __stdcall	CTestGameHook::OffPadPressedY()
{
	return FALSE;
}
BOOL __stdcall	CTestGameHook::OnKeyDownFunc(UINT nChar)
{
	return FALSE;
}
BOOL __stdcall	CTestGameHook::OnKeyDownCtrlFunc(UINT nChar)
{
	BOOL	bProcessed = FALSE;
	switch (nChar)
	{
		case VK_F10:
			{
				if (m_pMidiPlayer)
				{
					delete m_pMidiPlayer;
					m_pMidiPlayer = nullptr;
				}
				m_pMidiPlayer = new CMidiPlayer;
				m_pMidiPlayer->Initialize(m_pVHController, m_wchPluginPath);
			}
			break;
		case VK_F11:
			{
				if (m_pWebPage)
				{
					delete m_pWebPage;
					m_pWebPage = nullptr;
				}
				m_pWebPage = new CWebPage;


				//m_pWebPage->Initialize(m_pVHController, "https://www.shadertoy.com/view/XsXXDB", 640, 480);	// shader toy
				m_pWebPage->Initialize(m_pVHController, "https://youtu.be/bhPXCkqfSkk?si=F9Sc8kPFn7RJNaea", 640, 480);	// bad apple
				//m_pWebPage->Initialize(m_pVHController, "https://youtu.be/zjCDJOyHTfw?si=PLcuNDr7_uLPlx3S", 640, 480);	// ultima midi
				//m_pWebPage->Initialize(m_pVHController, "https://bing.com", 640, 480);
				bProcessed = TRUE;
			}
			break;
		

	}
	return bProcessed;
}
BOOL __stdcall CTestGameHook::OnPreConsoleCommand(const WCHAR* wchCmd, DWORD dwCmdLen)
{
	BOOL	bProcessed = FALSE;

	// 게임 레이어에서 더 이상 처리하지 않기를 원한다면 TRUE를 리턴
	// 게임 레이어에서 계속 처리하기를 원한다면 FALSE를 리턴

	if (m_pTestGame)
	{
		bProcessed |= m_pTestGame->OnPreConsoleCommand(wchCmd, dwCmdLen);
	}
	if (m_pVoxelEditor)
	{
		bProcessed |= m_pVoxelEditor->OnPreConsoleCommand(wchCmd, dwCmdLen);
	}
	if (m_pWebPage)
	{
		bProcessed |= m_pWebPage->OnPreConsoleCommand(wchCmd, dwCmdLen);
	}
	if (m_pMidiPlayer)
	{
		bProcessed |= m_pMidiPlayer->OnPreConsoleCommand(wchCmd, dwCmdLen);
	}
	if (!bProcessed)
	{
		// 채팅 다이얼로그 시스템 출력창에 출력
		m_pVHController->WriteTextToSystemDlgW(COLOR_VALUE_CYAN, L"[Plug-in] OnPreConsoleCommand:\"%s\".\n", wchCmd);

		// 콘솔창에 출력
		m_pVHController->BeginWriteTextToConsole();

		WCHAR wchTxt[128] = {};
		int iLen = (int)swprintf_s(wchTxt, L"[Plug-in] OnPreConsoleCommand:\"%s\"", wchCmd);

		//WriteTextToConsole()함수는 가변인자를 허용하지 않음.
		m_pVHController->WriteTextToConsole(wchTxt, iLen, COLOR_VALUE_MAGENTA);

		m_pVHController->EndWriteTextToConsole();
	}
	return bProcessed;
}

BOOL __stdcall CTestGameHook::OnMidiInput(const MIDI_MESSAGE_L* pMessage, BOOL bBroadcastMode, LARGE_INTEGER BeginCounter)
{
	// BeginCounter is counter when broacast mode enabled.
	// BeginCounter is valid, only if bBroadcastMode == TRUE.
	
	// 미디 건반을 통해 입력이 들어온 경우
	// 브로드캐스트 모드가 켜진 상태라면 bBroadcastMode값이 TRUE이고, 브로드 캐스트 모드가 켜졌을 때의 카운터 BeginCounter가 전달된다.
	// 브로드캐스트 모드가 꺼져 있다면 bBroadcastMode값이 FALSE이고, BeginCounter는 유효하지 않은 값이다.

	LARGE_INTEGER	CurCounter = QCGetCounter();
	float fElapsedTick = QCMeasureElapsedTick(CurCounter, BeginCounter);	// 브로드캐스트 모드가 켜진 이후로 현재 입력이 들어올때까지 걸린 시간(ms). 메모리 또는 파일에 저장하거나 MidiPushXXXX() 함수에 대한 입력으로 사용할 수 있다.


	BOOL	bResult = FALSE;
	
	return bResult;
}
BOOL __stdcall CTestGameHook::OnMidiEventProcessed(const MIDI_MESSAGE_L* pMessage, MIDI_EVENT_FROM_TYPE FromType)
{
	// 로컬에서 컴퓨터 키볻, 미디 UI, 미디 건반으로 입력한 케이스가 아닌, 순수 데이터만으로 전송된 미디 이벤트가 처리 됐을 때 호출되는 콜백함수.
	// 다음의 경우에 해당된다.
	// 1) 다른 플레이어가 연주한 미디 곡이 네트워크로 수신된 경우
	// 2) .mid파일을 MidiBeginPushMessage()/MidiPushXXX()/MidiEndPushMessage()로 연주한 경우
	// 
	// 화면에 건반을 표시하거나 노트 입력을 표시하기 위한 콜백이다.
	// 
	
	
	// 원격지에서 날라온 미디 이벤트면 처리 안함.
	if (MIDI_EVENT_FROM_TYPE_REMOTE == FromType)
		return FALSE;

	DWORD dwTextColor = COLOR_VALUE_WHITE;
	WCHAR wchTxt[64] = {};

	MIDI_MESSAGE_TYPE type = pMessage->GetSignalType();
	if (MIDI_MESSAGE_TYPE_NOTE == type)
	{
		DWORD	dwChannel = pMessage->GetChannel();
		BOOL	bOnOff = pMessage->GetOnOff();
		DWORD	dwKey = pMessage->GetKey();
		DWORD	dwVelocity = pMessage->GetVelocity();
		if (bOnOff)
		{
			dwTextColor = COLOR_VALUE_GREEN;
			swprintf_s(wchTxt, L"[Midi] Note On , Ch:%u, Key:%u, Vel:%u\n", dwChannel, dwKey, dwVelocity);
		}
		else
		{
			dwTextColor = COLOR_VALUE_GRAY;
			swprintf_s(wchTxt, L"[Midi] Note Off , Ch:%u, Key:%u, Vel:%u\n", dwChannel, dwKey, dwVelocity);
		}
		
	}
	else if (MIDI_MESSAGE_TYPE_CONTROL == type)
	{
		DWORD	dwChannel = pMessage->GetChannel();
		DWORD	dwController = pMessage->GetController();
		DWORD	dwControlValue = pMessage->GetControlValue();
		dwTextColor = COLOR_VALUE_MAGENTA;
		swprintf_s(wchTxt, L"[Midi] Change Control, Ch:%u, Controller:%u, Value:%u\n", dwChannel, dwController, dwControlValue);
		
	}
	else if (MIDI_MESSAGE_TYPE_PROGRAM == type)
	{
		DWORD	dwChannel = pMessage->GetChannel();
		DWORD	dwProgram = pMessage->GetProgram();
		dwTextColor = COLOR_VALUE_DARK_ORANGE;
		swprintf_s(wchTxt, L"[Midi] Change Program, Ch:%u, Program:%u\n", dwChannel, dwProgram);
	}
	else if (MIDI_MESSAGE_TYPE_PITCH_BEND == type)
	{
		DWORD	dwChannel = pMessage->GetChannel();
		DWORD	dwFirstValue = pMessage->GetPitchBendFirstValue();
		DWORD	dwSecondValue = pMessage->GetPitchBendSecondValue();
		dwTextColor = COLOR_VALUE_CYAN;
		swprintf_s(wchTxt, L"[Midi] Pitch Bend, Ch:%u, p1:%u p2:%u\n", dwChannel, dwFirstValue, dwSecondValue);
	}
	else if (MIDI_MESSAGE_TYPE_SYSEX == type)
	{
		//BYTE* pSysexMessage = nullptr;
		//DWORD dwSysexMsgLen = pMessage->GetSysexMessagePtr(&pSysexMessage);
		//dwTextColor = COLOR_VALUE_BLUE;
		//swprintf_s(wchTxt, L"[Midi] Sysex Message(%u), First Message:[%x] p2:%u\n", dwSysexMsgLen, pSysexMessage[1]);
	}
	m_pVHController->WriteTextToSystemDlgW(dwTextColor, wchTxt);
	
	// 상위 레이어에서 계속처리할 수 있도록 FALSE를 리턴
	return FALSE;
}
/*
IVoxelObjectLite* CSceneBattleField::CreateVoxelObject(VECTOR3* pv3Pos, UINT WidthDepthHeight, CREATE_VOXEL_OBJECT_ERROR* pOutErr)
{
	IVoxelObjectLite*	pVoxelObj = m_pVoxelObjectManager->CreateVoxelObject(pv3Pos, WidthDepthHeight, 0xffffffff, pOutErr);


	return pVoxelObj;
}
*/
void CTestGameHook::StartGame()
{
	if (m_pTestGame)
	{
		delete m_pTestGame;
		m_pTestGame = nullptr;
	}
	m_pTestGame = new CTestGame;
	m_pTestGame->Initialize(m_pVHController, m_wchPluginPath);
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

CTestGameHook::~CTestGameHook()
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