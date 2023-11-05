#include "stdafx.h"
#include <Windows.h>
#include <stdio.h>
#include "../include/typedef.h"
#include "../include/IGameHookController.h"
#include "Util.h"
#include "DisplayPanel.h"
#include "../util/QueryPerfCounter.h"
#include "Midi/MidiFile.h"
#include "MidiPlayer.h"


const int FIRST_PIANO_KEY = 48;
const DWORD PIANO_KEY_NUM = 36;
const DWORD MIN_VELOCITY = 32;

CMidiPlayer::CMidiPlayer()
{
}
BOOL CMidiPlayer::Initialize(IVHController* pVHController, const WCHAR* wchPluginPath)
{
	m_pVHController = pVHController;
	wcscpy_s(m_wchPluginPath, wchPluginPath);
	m_pVHController->WriteTextToSystemDlgW(COLOR_VALUE_GOLD, L"MidiPlayer created.\n");
	return TRUE;
}
BOOL CMidiPlayer::OnPreConsoleCommand(const WCHAR* wchCmd, DWORD dwCmdLen)
{
	BOOL bProcessed = FALSE;

	WCHAR	wchStr[512] = {};
	wcscpy_s(wchStr, wchCmd);

	WCHAR*	token = nullptr;
	WCHAR*	next_token = nullptr;
	WCHAR*	seps = L" ";

	token = wcstok_s(wchStr, seps, &next_token);

	WCHAR wchTxt[256] = {};
	if (token)
	{
		if (!_wcsicmp(token, L"play_midi"))
		{
			if (next_token)
			{
				WCHAR*	wchFileName = next_token;
				if (wcslen(wchFileName))
				{
					char szFileName[_MAX_PATH] = {};
					sprintf_s(szFileName, "%S", wchFileName);
					if (PlayMidi(szFileName))
					{
						int iLen = swprintf_s(wchTxt, L"Playing %s...", wchFileName);
						m_pVHController->WriteTextToConsoleImmediately(wchTxt, iLen, COLOR_VALUE_GREEN);
					}
					else
					{
						int iLen = swprintf_s(wchTxt, L"Fild not found: %s", wchFileName);
						m_pVHController->WriteTextToConsoleImmediately(wchTxt, iLen, COLOR_VALUE_RED);
					}
					bProcessed = TRUE;
				}
			}
		}
		else if (!_wcsicmp(token, L"enable_keyboard"))
		{
			if (next_token)
			{
				WCHAR*	wchValue = next_token;
				int iValue = _wtoi(wchValue);
				if (iValue)
				{
					m_bUseKeyboardAsMidiKeyboard = TRUE;

					WCHAR* wchTxt = L"Keyboard as Midi-Keyboard Enabled.";
					int iLen = (int)wcslen(wchTxt);
					m_pVHController->WriteTextToConsoleImmediately(wchTxt, iLen, COLOR_VALUE_GOLD);
				}
				else
				{
					m_bUseKeyboardAsMidiKeyboard = FALSE;

					WCHAR* wchTxt = L"Keyboard as Midi-Keyboard Disabled.";
					int iLen = (int)wcslen(wchTxt);
					m_pVHController->WriteTextToConsoleImmediately(wchTxt, iLen, COLOR_VALUE_GRAY);
				}
				bProcessed = TRUE;
			}
		}
		else if (!_wcsicmp(token, L"enable_broadcast"))
		{
			if (next_token)
			{
				WCHAR*	wchValue = next_token;
				int iValue = _wtoi(wchValue);
				if (iValue)
				{
					m_pVHController->EnableBroadcastModeImmediately();

					WCHAR* wchTxt = L"Boradcast Mode Enabled.";
					int iLen = (int)wcslen(wchTxt);
					m_pVHController->WriteTextToConsoleImmediately(wchTxt, iLen, COLOR_VALUE_GOLD);
				}
				else
				{
					m_pVHController->DisableBroadcastModeImmediately();

					WCHAR* wchTxt = L"Boradcast Mode Disabled.";
					int iLen = (int)wcslen(wchTxt);
					m_pVHController->WriteTextToConsoleImmediately(wchTxt, iLen, COLOR_VALUE_GRAY);
				}
				bProcessed = TRUE;
			}
		}

	}
	return bProcessed;
}
BOOL CMidiPlayer::PlayMidi(const char* szFileName)
{
	BOOL	bResult = FALSE;

	WCHAR	wchOldPath[_MAX_PATH] = {};
	GetCurrentDirectory(_MAX_PATH, wchOldPath);

	SetCurrentDirectory(m_wchPluginPath);
	
	SetCurrentDirectory(L"./mid");


	smf::MidiFile midifile;
	if (midifile.read(szFileName))
	{
		m_pVHController->MidiReset();

		const DWORD MAX_MESSAGE_NUM = 1024 * 1024;
		MIDI_MESSAGE*	pMessageList = new MIDI_MESSAGE[MAX_MESSAGE_NUM];
		memset(pMessageList, 0, sizeof(MIDI_MESSAGE) * MAX_MESSAGE_NUM);
		DWORD dwMessageNum = midifile.GetMidiData(pMessageList, MAX_MESSAGE_NUM);

		SortMidiMessageList(pMessageList, dwMessageNum);

		m_pVHController->EnableBroadcastModeImmediately();

		m_pVHController->MidiBeginPushMessage();

		BOOL	bIsCompositingSysexMessage = FALSE;
		BYTE	pbSysexMessageValue[256] = {};
		DWORD	dwSysexMessageLen = 0;
		DWORD	dwAvailableSysexBufferCount = (DWORD)_countof(pbSysexMessageValue);
		DWORD	dwTickOnSysex = 0;
		for (DWORD i = 0; i < dwMessageNum; i++)
		{
			MIDI_MESSAGE* pMessage = pMessageList + i;
			float fNoteTick = (float)pMessage->GetTickFromBegin();	// 시작시간으로부터의 tick

			MIDI_MESSAGE_TYPE type = pMessage->GetSignalType();
			switch (type)
			{
				case MIDI_MESSAGE_TYPE_NOTE:
					if (pMessage->GetOnOff())
					{
						m_pVHController->MidiPushNoteOn(pMessage->GetChannel(), pMessage->GetKey(), pMessage->GetVelocity(), pMessage->GetTickFromBegin());
					}
					else
					{
						m_pVHController->MidiPushNoteOff(pMessage->GetChannel(), pMessage->GetKey(), pMessage->GetVelocity(), pMessage->GetTickFromBegin());
					}
					break;
				case MIDI_MESSAGE_TYPE_CONTROL:
					m_pVHController->MidiPushChangeControl(pMessage->GetChannel(), pMessage->GetController(), pMessage->GetControlValue(), pMessage->GetTickFromBegin());
					break;
				case MIDI_MESSAGE_TYPE_PITCH_BEND:
					m_pVHController->MidiPushChangePitchBend(pMessage->GetChannel(), pMessage->GetPitchBendFirstValue(), pMessage->GetPitchBendSecondValue(), pMessage->GetTickFromBegin());
					break;
				case MIDI_MESSAGE_TYPE_PROGRAM:
					m_pVHController->MidiPushChangeProgram(pMessage->GetChannel(), pMessage->GetProgram(), pMessage->GetTickFromBegin());
					break;
				case MIDI_MESSAGE_TYPE_SYSEX:
					{
						// MIDI_MESSAGE_TYPE_SYSEX의 경우 최대 사이즈가 얼마일지 모르고 일반적으로 10 Bytes를 넘기기 때문에 여러개의 MIDI_MESSAGE구조체에 나눠 담긴다.
						// MIDI_MESSAGE_TYPE_SYSEX메시지가 발견됐다면 원래의 SYSEX메시지를 모두 얻을 때까지 MIDI_MESSAGE_TYPE_SYSEX타입의 MIDI_MESSAGE구조체가 계속 발견된다.
						if (!bIsCompositingSysexMessage)
						{
							bIsCompositingSysexMessage = TRUE;
							dwAvailableSysexBufferCount = (DWORD)_countof(pbSysexMessageValue);
							memset(pbSysexMessageValue, 0, sizeof(pbSysexMessageValue));
							dwSysexMessageLen = 0;
							dwTickOnSysex = pMessage->GetTickFromBegin();
						}
						BOOL	bIsSysexEnd = FALSE;
						DWORD	dwValueCount = pMessage->GetSysexMessage(pbSysexMessageValue + dwSysexMessageLen, dwAvailableSysexBufferCount, &bIsSysexEnd);
						dwSysexMessageLen += dwValueCount;
						dwAvailableSysexBufferCount -= dwValueCount;

						if (bIsSysexEnd)
						{
							m_pVHController->MidiPushSysexMessage(pbSysexMessageValue, (unsigned char)dwSysexMessageLen, dwTickOnSysex);
							bIsCompositingSysexMessage = FALSE;
						}
					}
					break;
			}
		}
		m_pVHController->MidiEndPushMessage();

		//m_pVHController->DisableBroadcastModeDeferred();	Don't call this function. Since all messages have not been sent yet.
		m_pVHController->DisableBroadcastModeDeferred();	// Broadcast mode turns off after all messages are sent.

		if (pMessageList)
		{
			delete[] pMessageList;
			pMessageList = nullptr;
		}
		bResult = TRUE;
	}
	SetCurrentDirectory(wchOldPath);
	return bResult;
}
void CMidiPlayer::OnPianoKeyDown(DWORD dwKeyIndex)
{
	unsigned char ch = 0;
	unsigned char key = (unsigned char)(dwKeyIndex + FIRST_PIANO_KEY);
	unsigned char vel = 127;

	m_pVHController->MidiNoteOnImmediately((DWORD)ch, (DWORD)key, (DWORD)vel);
}
void CMidiPlayer::OnPianoKeyUp(DWORD dwKeyIndex)
{
	unsigned char ch = 0;
	unsigned char key = (unsigned char)(dwKeyIndex + FIRST_PIANO_KEY);
	unsigned char vel = 127;

	m_pVHController->MidiNoteOffImmediately((DWORD)ch, (DWORD)key, (DWORD)vel);
}

BOOL CMidiPlayer::OnKeyDown(UINT nChar)
{
	BOOL	bProcessed = FALSE;

	if (m_bUseKeyboardAsMidiKeyboard)
	{
		switch (nChar)
		{
			case 'A':
				{
					OnPianoKeyDown(0);
					bProcessed = TRUE;
				}
				break;
			case 'W':
				{
					OnPianoKeyDown(1);
					bProcessed = TRUE;
				}
				break;
			case 'S':
				{
					OnPianoKeyDown(2);
					bProcessed = TRUE;
				}
				break;
			case 'E':
				{
					OnPianoKeyDown(3);
					bProcessed = TRUE;
				}
				break;
			case 'D':
				{
					OnPianoKeyDown(4);
					bProcessed = TRUE;
				}
				break;
			case 'F':
				{
					OnPianoKeyDown(5);
					bProcessed = TRUE;
				}
				break;
			case 'T':
				{
					OnPianoKeyDown(6);
					bProcessed = TRUE;
				}
				break;
			case 'G':
				{
					OnPianoKeyDown(7);
					bProcessed = TRUE;
				}
				break;
			case 'Y':
				{
					OnPianoKeyDown(8);
					bProcessed = TRUE;
				}
				break;
			case 'H':
				{
					OnPianoKeyDown(9);
					bProcessed = TRUE;
				}
				break;
			case 'U':
				{

					OnPianoKeyDown(10);
					bProcessed = TRUE;

				}
				break;
			case 'J':
				{
					OnPianoKeyDown(11);
					bProcessed = TRUE;
				}
				break;
			case 'K':
				{
					OnPianoKeyDown(12);
					bProcessed = TRUE;
				}
				break;

		}
	}
	return bProcessed;
}
BOOL CMidiPlayer::OnKeyUp(UINT nChar)
{
	BOOL	bProcessed = FALSE;
	if (m_bUseKeyboardAsMidiKeyboard)
	{
		switch (nChar)
		{
			case 'A':
				{
					OnPianoKeyUp(0);
					bProcessed = TRUE;
				}
				break;
			case 'W':
				{
					OnPianoKeyUp(1);
					bProcessed = TRUE;
				}
				break;
			case 'S':
				{
					OnPianoKeyUp(2);
					bProcessed = TRUE;
				}
				break;
			case 'E':
				{
					OnPianoKeyUp(3);
					bProcessed = TRUE;
				}
				break;
			case 'D':
				{
					OnPianoKeyUp(4);
					bProcessed = TRUE;
				}
				break;
			case 'F':
				{
					OnPianoKeyUp(5);
					bProcessed = TRUE;
				}
				break;
			case 'T':
				{
					OnPianoKeyUp(6);
					bProcessed = TRUE;
				}
				break;
			case 'G':
				{
					OnPianoKeyUp(7);
					bProcessed = TRUE;
				}
				break;
			case 'Y':
				{
					OnPianoKeyUp(8);
					bProcessed = TRUE;
				}
				break;
			case 'H':
				{
					OnPianoKeyUp(9);
					bProcessed = TRUE;
				}
				break;
			case 'U':
				{
					OnPianoKeyUp(10);
					bProcessed = TRUE;
				}
				break;
			case 'J':
				{
					OnPianoKeyUp(11);
					bProcessed = TRUE;
				}
				break;
			case 'K':
				{
					OnPianoKeyUp(12);
					bProcessed = TRUE;
				}
				break;
		}
	}
	return bProcessed;
}
void CMidiPlayer::Cleanup()
{
}
CMidiPlayer::~CMidiPlayer()
{
	Cleanup();
}

