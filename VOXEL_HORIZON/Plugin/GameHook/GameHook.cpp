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
	// ���� ������Ʈ�� �����ɶ� �ڵ����� ȣ��ȴ�.
	// pVoxelObj�� �����ϴ� ������ �ִٸ� ���⼭ �ʱ�ȭ���Ѿ� �Ѵ�.
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
	// �� �÷����ο��� �Ҵ��� IVoxelObjectLite�� �ִٸ� ���⼭ �����Ѵ�. �� �Լ��� ������ ���ķδ� �����ؼ��� �ȵȴ�.
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

	// ���� ���̾�� �� �̻� ó������ �ʱ⸦ ���Ѵٸ� TRUE�� ����
	// ���� ���̾�� ��� ó���ϱ⸦ ���Ѵٸ� FALSE�� ����

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
		// ä�� ���̾�α� �ý��� ���â�� ���
		m_pVHController->WriteTextToSystemDlgW(COLOR_VALUE_CYAN, L"[Plug-in] OnPreConsoleCommand:\"%s\".\n", wchCmd);

		// �ܼ�â�� ���
		m_pVHController->BeginWriteTextToConsole();

		WCHAR wchTxt[128] = {};
		int iLen = (int)swprintf_s(wchTxt, L"[Plug-in] OnPreConsoleCommand:\"%s\"", wchCmd);

		//WriteTextToConsole()�Լ��� �������ڸ� ������� ����.
		m_pVHController->WriteTextToConsole(wchTxt, iLen, COLOR_VALUE_MAGENTA);

		m_pVHController->EndWriteTextToConsole();
	}
	return bProcessed;
}

BOOL __stdcall CTestGameHook::OnMidiInput(const MIDI_MESSAGE_L* pMessage, BOOL bBroadcastMode, LARGE_INTEGER BeginCounter)
{
	// BeginCounter is counter when broacast mode enabled.
	// BeginCounter is valid, only if bBroadcastMode == TRUE.
	
	// �̵� �ǹ��� ���� �Է��� ���� ���
	// ��ε�ĳ��Ʈ ��尡 ���� ���¶�� bBroadcastMode���� TRUE�̰�, ��ε� ĳ��Ʈ ��尡 ������ ���� ī���� BeginCounter�� ���޵ȴ�.
	// ��ε�ĳ��Ʈ ��尡 ���� �ִٸ� bBroadcastMode���� FALSE�̰�, BeginCounter�� ��ȿ���� ���� ���̴�.

	LARGE_INTEGER	CurCounter = QCGetCounter();
	float fElapsedTick = QCMeasureElapsedTick(CurCounter, BeginCounter);	// ��ε�ĳ��Ʈ ��尡 ���� ���ķ� ���� �Է��� ���ö����� �ɸ� �ð�(ms). �޸� �Ǵ� ���Ͽ� �����ϰų� MidiPushXXXX() �Լ��� ���� �Է����� ����� �� �ִ�.


	BOOL	bResult = FALSE;
	
	return bResult;
}
BOOL __stdcall CTestGameHook::OnMidiEventProcessed(const MIDI_MESSAGE_L* pMessage, MIDI_EVENT_FROM_TYPE FromType)
{
	// ���ÿ��� ��ǻ�� Ű��, �̵� UI, �̵� �ǹ����� �Է��� ���̽��� �ƴ�, ���� �����͸����� ���۵� �̵� �̺�Ʈ�� ó�� ���� �� ȣ��Ǵ� �ݹ��Լ�.
	// ������ ��쿡 �ش�ȴ�.
	// 1) �ٸ� �÷��̾ ������ �̵� ���� ��Ʈ��ũ�� ���ŵ� ���
	// 2) .mid������ MidiBeginPushMessage()/MidiPushXXX()/MidiEndPushMessage()�� ������ ���
	// 
	// ȭ�鿡 �ǹ��� ǥ���ϰų� ��Ʈ �Է��� ǥ���ϱ� ���� �ݹ��̴�.
	// 
	
	
	// ���������� ����� �̵� �̺�Ʈ�� ó�� ����.
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
	
	// ���� ���̾�� ���ó���� �� �ֵ��� FALSE�� ����
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
	// ���⼭ IVoxelObjectLite�� �����ؼ� �ȵȴ�.
	//

	m_pVHController->WriteTextToSystemDlgW(COLOR_VALUE_RED, L"[Plug-in] GameHook will be unloaded.\n");
	g_pGameHook = nullptr;
#ifdef _DEBUG
	_ASSERT(_CrtCheckMemory());
#endif
}