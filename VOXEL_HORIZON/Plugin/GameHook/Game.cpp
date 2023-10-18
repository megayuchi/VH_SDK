#include "stdafx.h"
#include <Windows.h>
#include <stdio.h>
#include "../include/typedef.h"
#include "../include/IGameHookController.h"
#include "Util.h"
#include "ImageData.h"
#include "DisplayPanel.h"
#include "QueryPerfCounter.h"
#include "game_typedef.h"
#include "GameObject.h"
#include "FlightObject.h"
#include "Game.h"

CGame* g_pGame = nullptr;

CGame::CGame()
{
	m_dwCurFPS = 0;
	m_fTicksPerGameFrame = 1000.0f / (float)m_dwGameFPS;
	m_PrvGameFrameTick = GetTickCount64();
	m_PrvCounter = QCGetCounter();

	QCInit();
}

BOOL CGame::Initialize(IVHController* pVHController, const WCHAR* wchPluginPath)
{
	m_pVHController = pVHController;
	
	m_pVHController->DeleteAllVoxelObject();

	m_pDisplayPanel = new CDisplayPanel;
	m_pDisplayPanel->Initialize(m_pVHController, DISPLAY_PANEL_WIDTH, DISPLAY_PANEL_HEIGHT, LAYER_INDEX_COUNT);

	wcscpy_s(m_wchPluginPath, wchPluginPath);

	int iScreenWidth = (int)m_pDisplayPanel->GetWidth();
	int iScreenHeight = (int)m_pDisplayPanel->GetHeight();

	srand(GetTickCount());

	m_pPlayerImgData = CreateImageData("./data/galaga_player.png", m_pDisplayPanel, m_wchPluginPath, TRUE);
	if (!m_pPlayerImgData)
		__debugbreak();

	m_pAmmoImgData = CreateImageData("./data/ammo.png", m_pDisplayPanel, m_wchPluginPath, TRUE);
	if (!m_pAmmoImgData)
		__debugbreak();

	m_pEnemyImgData = CreateImageData("./data/galaga_enemy.png", m_pDisplayPanel, m_wchPluginPath, TRUE);
	if (!m_pEnemyImgData)
		__debugbreak();

	m_pMidScrollImageData = CreateImageData("./data/mid_scroll_image.png", m_pDisplayPanel, m_wchPluginPath, TRUE);
	if (!m_pMidScrollImageData)
		__debugbreak();

	m_pBackImage = CreateImageData("./data/space_back.png", m_pDisplayPanel, m_wchPluginPath, FALSE);
	if (!m_pBackImage)
		__debugbreak();
	int iBackHeight = m_pBackImage->GetHeight();
	m_iBackImagePosY = iScreenHeight - iBackHeight - 1;

	int iPlayerPosX = (iScreenWidth - (int)m_pPlayerImgData->GetWidth()) / 2;
	int iPlayerPosY = (iScreenHeight - (int)m_pPlayerImgData->GetHeight()) / 2;

	m_pPlayer = CreatePlayer(m_pPlayerImgData, iPlayerPosX, iPlayerPosY, DEFAULT_PLAYER_SPEED);


	return TRUE;
}
void CGame::CleanupDisplayPanel()
{
	if (m_pDisplayPanel)
	{
		delete m_pDisplayPanel;
		m_pDisplayPanel = nullptr;
	}
}
void CGame::Process()
{
	LARGE_INTEGER	CurCounter = QCGetCounter();
	float	fElpasedTick = QCMeasureElapsedTick(CurCounter, m_PrvCounter);
	ULONGLONG CurTick = GetTickCount64();

	if (fElpasedTick > m_fTicksPerGameFrame)
	{
		FixPostionPostion();

		if (m_bPause)
		{
		}
		else
		{
			OnGameFrame(CurTick);
		}
		m_PrvGameFrameTick = CurTick;
		m_PrvCounter = CurCounter;

	}
	else
	{
		float fAlpha = fElpasedTick / m_fTicksPerGameFrame;
		InterpolatePostion(fAlpha);
	}

	if (!m_bPause)
	{
		DrawScene();
	}
}

BOOL CGame::OnKeyDown(UINT nChar)
{
	BOOL	bProcessed = FALSE;
	switch (nChar)
	{
		case 'P':
			{
				m_bPause = m_bPause == 0;
				bProcessed = TRUE;
			}
			break;
		case 'T':
			{
				if (IsMultipleLayersMode())
				{
					EnableMultipleLayresMode(FALSE);
				}
				else
				{
					EnableMultipleLayresMode(TRUE);
				}
				bProcessed = TRUE;
			}
			break;

		case VK_LEFT:
			{
				if (!m_bPause)
				{
					m_bKeyDown_Left = TRUE;
					bProcessed = TRUE;
				}
			}
			break;
		case VK_RIGHT:
			{
				if (!m_bPause)
				{
					m_bKeyDown_Right = TRUE;
					bProcessed = TRUE;
				}
			}
			break;
		case VK_UP:
			{
				if (!m_bPause)
				{
					m_bKeyDown_Up = TRUE;
					bProcessed = TRUE;
				}
			}
			break;
		case VK_DOWN:
			{
				if (!m_bPause)
				{
					m_bKeyDown_Down = TRUE;
					bProcessed = TRUE;
				}
			}
			break;
		case VK_SPACE:
			{
				if (!m_bPause)
				{
					ShootFromPlayer();
					bProcessed = TRUE;
				}
			}
			break;
		case VK_RETURN:
			{
				//CaptureBackBuffer("backbuffer.tga");
			}
			break;
	}
	return bProcessed;
}
BOOL CGame::OnKeyUp(UINT nChar)
{
	BOOL	bProcessed = FALSE;
	switch (nChar)
	{
		case VK_LEFT:
			{
				if (!m_bPause)
				{
					m_bKeyDown_Left = FALSE;
					bProcessed = TRUE;
				}
			}
			break;
		case VK_RIGHT:
			{
				if (!m_bPause)
				{
					m_bKeyDown_Right = FALSE;
					bProcessed = TRUE;
				}
			}
			break;
		case VK_UP:
			{
				if (!m_bPause)
				{
					m_bKeyDown_Up = FALSE;
					bProcessed = TRUE;
				}
			}
			break;
		case VK_DOWN:
			{
				if (!m_bPause)
				{
					m_bKeyDown_Down = FALSE;
					bProcessed = TRUE;
				}
			}
			break;
	}
	return bProcessed;
}

void CGame::EnableMultipleLayresMode(BOOL bSwitch)
{
	m_bUseMultipleLayers = bSwitch; 
	m_pDisplayPanel->ResetVoxelData();
}


void CGame::DrawScene()
{
	DWORD	dwObjLayerIndex = LAYER_INDEX_DEFAULT;
	DWORD	dwMidScrollLayerIndex = LAYER_INDEX_DEFAULT;
	DWORD	dwBackgroundLayerIndex = LAYER_INDEX_DEFAULT;

	if (m_bUseMultipleLayers)
	{
		dwObjLayerIndex = LAYER_INDEX_OBJECT;
		dwMidScrollLayerIndex = LAYER_INDEX_BACK_0;
		dwBackgroundLayerIndex = LAYER_INDEX_BACK_1;
		
		// 오브젝트 레이어 클리어
		m_pDisplayPanel->Clear(0xff, dwObjLayerIndex);
		m_pDisplayPanel->Clear(0xff, dwMidScrollLayerIndex);
	}

	if (m_pBackImage)
	{
		// 배경 레이어에 배경 이미지 출력
		m_pDisplayPanel->DrawPalettedBitmap(m_iBackImagePosX, m_iBackImagePosY, m_pBackImage->GetWidth(), m_pBackImage->GetHeight(), m_pBackImage->GetUncompressedImage(), dwBackgroundLayerIndex);
	}
	else
	{
		m_pDisplayPanel->Clear(0, dwBackgroundLayerIndex);
	}

	// mid scroll image
	if (m_pMidScrollImageData)
	{
		m_pDisplayPanel->DrawCompressedPalettedImageData(m_iMidScrollImagePosX, m_iMidScrollImagePosY, m_pMidScrollImageData, dwMidScrollLayerIndex);
	}
	// 오브젝트 렌더링
	INT_VECTOR2		ivPos;
	m_pPlayer->GetInterpolatedPos(&ivPos);
	//m_pPlayer->GetPos(&ivPos);
	DrawFlightObject(m_pPlayer, ivPos.x, ivPos.y, dwObjLayerIndex);

	for (DWORD i = 0; i < m_dwCurEnemiesNum; i++)
	{
		m_ppEnemyList[i]->GetInterpolatedPos(&ivPos);
		DrawFlightObject(m_ppEnemyList[i], ivPos.x, ivPos.y, dwObjLayerIndex);
	}

	for (DWORD i = 0; i < m_dwCurAmmoNum; i++)
	{
		m_ppAmmoList[i]->GetInterpolatedPos(&ivPos);
		DrawFlightObject(m_ppAmmoList[i], ivPos.x, ivPos.y, dwObjLayerIndex);
	}

	// 복셀 오브젝트에 반영
	if (m_bUseMultipleLayers)
	{
		m_pDisplayPanel->UpdateBitmapToVoxelDataWithMultipleLayers(LAYER_INDEX_OBJECT, LAYER_INDEX_COUNT);
	}
	else
	{
		m_pDisplayPanel->UpdateBitmapToVoxelDataWithSingleLayer(0, LAYER_INDEX_DEFAULT);
	}
	
	//	m_pDDraw->CheckFPS();
}
void CGame::OnUpdateWindowSize()
{

}
void CGame::OnUpdateWindowPos()
{

}
void CGame::DrawFlightObject(CFlightObject* pFighter, int x, int y, DWORD dwLayerIndex)
{
	const CImageData* pImageData = pFighter->GetImageData();
	//m_pDisplayPanel->DrawPalettedBitmap(x, y, pImageData->GetWidth(), pImageData->GetHeight(), pImageData->GetUncompressedImage());
	m_pDisplayPanel->DrawCompressedPalettedImageData(x, y, pImageData, dwLayerIndex);
}
void CGame::InterpolatePostion(float fAlpha)
{
	if (m_pPlayer)
	{
		m_pPlayer->Interpolate(fAlpha);
	}

	for (DWORD i = 0; i < m_dwCurEnemiesNum; i++)
	{
		CFlightObject*	pEnemy = m_ppEnemyList[i];
		pEnemy->Interpolate(fAlpha);
	}
	for (DWORD i = 0; i < m_dwCurAmmoNum; i++)
	{
		CFlightObject*	pAmmo = m_ppAmmoList[i];
		pAmmo->Interpolate(fAlpha);
	}

}
void CGame::FixPostionPostion()
{
	if (m_pPlayer)
	{
		m_pPlayer->FixPos();
	}

	for (DWORD i = 0; i < m_dwCurEnemiesNum; i++)
	{
		CFlightObject*	pEnemy = m_ppEnemyList[i];
		pEnemy->FixPos();
	}
	for (DWORD i = 0; i < m_dwCurAmmoNum; i++)
	{
		CFlightObject*	pAmmo = m_ppAmmoList[i];
		pAmmo->FixPos();
	}

}
void CGame::OnGameFrame(ULONGLONG CurTick)
{
	int iScreenWidth = (int)m_pDisplayPanel->GetWidth();
	int iScreenHeight = (int)m_pDisplayPanel->GetHeight();


	// 배경 스크롤
	int iBackHeight = m_pBackImage->GetHeight();
	if (m_iBackImagePosY >= 0)
	{
		m_iBackImagePosY = iScreenHeight - iBackHeight - 1;
	}
	m_iBackImagePosY++;

	UpdatePlayerPos(iScreenWidth, iScreenHeight);

	// 사망한 적들 제거

	DeleteDestroyedEnemies(CurTick);
	ProcessCollision(CurTick);

	// 탄환이 맵 끝에 도달하면 자동 파괴
	DWORD	dwIndex = 0;
	while (dwIndex < m_dwCurAmmoNum)
	{
		CFlightObject*	pAmmo = m_ppAmmoList[dwIndex];
		INT_VECTOR2	ivPos;
		pAmmo->GetPos(&ivPos);
		if (ivPos.y < 0)
		{
			DeleteFlightObject(pAmmo);
			m_dwCurAmmoNum--;
			m_ppAmmoList[dwIndex] = m_ppAmmoList[m_dwCurAmmoNum];
			m_ppAmmoList[m_dwCurAmmoNum] = nullptr;
		}
		else
		{
			//ivPos.y--;
			ivPos.y -= pAmmo->GetSpeed();
			pAmmo->SetPos(&ivPos, TRUE);
			dwIndex++;
		}
	}

	ProcessEnemies();

	UpdateBackground();

}
void CGame::UpdateBackground()
{
	/*
	static ULONGLONG PrvUpdateTick = 0;
	ULONGLONG CurTick = GetTickCount64();

	if (CurTick - PrvUpdateTick < 1000)
		return;

	PrvUpdateTick = CurTick;

	DWORD	dwTotalPixels = (DWORD)(m_iScreenWidth * m_iScreenHeight);


	WCHAR* pSrc = m_pBackground + (m_iScreenHeight - 1) * m_iScreenWidth;
	WCHAR* pDest = m_pBackgroundLineBuffer;

	for (int y = 0; y < m_iScreenHeight; y++)
	{
		memcpy(pDest, pSrc, sizeof(WCHAR) * m_iScreenWidth);
		pDest = pSrc;
		pSrc -= m_iScreenWidth;
	}
	memcpy(m_pBackground, m_pBackgroundLineBuffer, sizeof(WCHAR) * m_iScreenWidth);
	//memcpy(m_pBackground, m_pBackground + m_iScreenWidth, sizeof(WCHAR) * (dwTotalPixels - (DWORD)m_iScreenWidth));
	//memcpy(m_pBackground + (dwTotalPixels - (DWORD)m_iScreenWidth), m_pBackgroundLineBuffer, sizeof(WCHAR) * m_iScreenWidth);
	*/
}
void CGame::UpdatePlayerPos(int iScreenWidth, int iScreenHeight)
{
	INT_VECTOR2		ivPlayerPos;
	m_pPlayer->GetPos(&ivPlayerPos);


	if (m_bKeyDown_Left)
	{
		//m_iPlayerPosX--;
		ivPlayerPos.x -= m_pPlayer->GetSpeed();
	}
	if (m_bKeyDown_Right)
	{
		//m_iPlayerPosX++;
		ivPlayerPos.x += m_pPlayer->GetSpeed();
	}
	if (m_bKeyDown_Up)
	{
		//m_iPlayerPosY--;
		ivPlayerPos.y -= m_pPlayer->GetSpeed();
	}
	if (m_bKeyDown_Down)
	{
		//m_iPlayerPosY++;
		ivPlayerPos.y += m_pPlayer->GetSpeed();
	}

	if (m_pPlayerImgData)
	{
		int iPlayerImageWidth = (int)m_pPlayerImgData->GetWidth();
		int iPlayerImageHeight = (int)m_pPlayerImgData->GetHeight();

		if (ivPlayerPos.x < -(iPlayerImageWidth / 2))
		{
			ivPlayerPos.x = -(iPlayerImageWidth / 2);
			m_iBackImagePosX++;
			m_iMidScrollImagePosX += 2;
		}
		if (ivPlayerPos.x > iScreenWidth - iPlayerImageWidth + (iPlayerImageWidth / 2))
		{
			ivPlayerPos.x = iScreenWidth - iPlayerImageWidth + (iPlayerImageWidth / 2);
			m_iBackImagePosX--;
			m_iMidScrollImagePosX -= 2;
		}

		if (ivPlayerPos.y < -(iPlayerImageHeight / 2))
		{
			ivPlayerPos.y = -(iPlayerImageHeight / 2);
			m_iMidScrollImagePosY += 2;
		}
		if (ivPlayerPos.y > iScreenHeight - iPlayerImageHeight + (iPlayerImageHeight / 2))
		{
			ivPlayerPos.y = iScreenHeight - iPlayerImageHeight + (iPlayerImageHeight / 2);
			m_iMidScrollImagePosY -= 2;
		}
	}
	if (m_pBackImage)
	{
		int iBackImageWidth = (int)m_pBackImage->GetWidth();
		int iBackImageHeight = (int)m_pBackImage->GetHeight();

		if (iBackImageWidth > iScreenWidth)
		{
			if (m_iBackImagePosX > 0)
			{
				m_iBackImagePosX = 0;
			}
			if (m_iBackImagePosX < iScreenWidth - iBackImageWidth)
			{
				m_iBackImagePosX = iScreenWidth - iBackImageWidth;
			}
		}
		if (iBackImageHeight > iScreenHeight)
		{
			if (m_iBackImagePosY > 0)
			{
				m_iBackImagePosY = 0;
			}
			if (m_iBackImagePosY < iScreenHeight - iBackImageHeight)
			{
				m_iBackImagePosY = iScreenHeight - iBackImageHeight;
			}
		}
	}
	if (m_pMidScrollImageData)
	{
		int iMidScrollImageWidth = (int)m_pMidScrollImageData->GetWidth();
		int iMidScrollImageHeight = (int)m_pMidScrollImageData->GetHeight();

		if (iMidScrollImageWidth > iScreenWidth)
		{
			if (m_iMidScrollImagePosX > 0)
			{
				m_iMidScrollImagePosX = 0;
			}
			if (m_iMidScrollImagePosX < iScreenWidth - iMidScrollImageWidth)
			{
				m_iMidScrollImagePosX = iScreenWidth - iMidScrollImageWidth;
			}
		}
		if (iMidScrollImageHeight > iScreenHeight)
		{
			if (m_iMidScrollImagePosY > 0)
			{
				m_iMidScrollImagePosY = 0;
			}
			if (m_iMidScrollImagePosY < iScreenHeight - iMidScrollImageHeight)
			{
				m_iMidScrollImagePosY = iScreenHeight - iMidScrollImageHeight;
			}
		}
	}
	m_pPlayer->SetPos(&ivPlayerPos, TRUE);
}
void CGame::DeleteDestroyedEnemies(ULONGLONG CurTick)
{
	DWORD	dwIndex = 0;
	while (dwIndex < m_dwCurEnemiesNum)
	{
		CFlightObject*	pEnemy = m_ppEnemyList[dwIndex];
		if (pEnemy->GetStatus() == FLIGHT_OBJECT_STATUS_DEAD && CurTick - pEnemy->GetDeadTick() > DEAD_STATUS_WAIT_TICK)
		{
			DeleteFlightObject(pEnemy);
			m_dwCurEnemiesNum--;
			m_ppEnemyList[dwIndex] = m_ppEnemyList[m_dwCurEnemiesNum];
			m_ppEnemyList[m_dwCurEnemiesNum] = nullptr;
		}
		else
		{
			dwIndex++;
		}
	}
}
void CGame::ProcessCollision(ULONGLONG CurTick)
{
	DWORD	dwIndex = 0;
	while (dwIndex < m_dwCurAmmoNum)
	{
		CFlightObject*	pAmmo = m_ppAmmoList[dwIndex];
		if (ProcessCollisionAmmoVsEnemies(pAmmo, CurTick))
		{
			DeleteFlightObject(pAmmo);
			m_dwCurAmmoNum--;
			m_ppAmmoList[dwIndex] = m_ppAmmoList[m_dwCurAmmoNum];
			m_ppAmmoList[m_dwCurAmmoNum] = nullptr;
		}
		else
		{
			dwIndex++;
		}
	}
}


BOOL CGame::IsCollisionFlightObjectVsFlightObject(const CFlightObject* pObj0, const CFlightObject* pObj1)
{
	BOOL bResult = FALSE;

	if (pObj0->GetStatus() != FLIGHT_OBJECT_STATUS_ALIVE || pObj1->GetStatus() != FLIGHT_OBJECT_STATUS_ALIVE)
	{
		return FALSE;
	}
	INT_VECTOR2	ivPos0;
	pObj0->GetPos(&ivPos0);

	INT_VECTOR2	ivPos1;
	pObj1->GetPos(&ivPos1);

	INT_RECT2	objRect0 =
	{
		ivPos0.x, ivPos0.y,
		ivPos0.x + pObj0->GetWidth(), ivPos0.y + pObj0->GetHeight()
	};
	INT_RECT2	objRect1 =
	{
		ivPos1.x, ivPos1.y,
		ivPos1.x + pObj1->GetWidth(), ivPos1.y + pObj1->GetHeight()
	};

	bResult = IsCollisionRectVsRect(&objRect0.min, &objRect0.max, &objRect1.min, &objRect1.max);

lb_return:
	return bResult;
}
BOOL CGame::ProcessCollisionAmmoVsEnemies(CFlightObject* pAmmo, ULONGLONG CurTick)
{
	BOOL	bCollision = FALSE;
	for (DWORD i = 0; i < m_dwCurEnemiesNum; i++)
	{
		CFlightObject*	pEnemy = m_ppEnemyList[i];
		if (IsCollisionFlightObjectVsFlightObject(pAmmo, pEnemy))
		{
			// 적 타격 성공
			OnHitEnemy(pEnemy, CurTick);

			bCollision = TRUE;
			break;
		}
	}
	return bCollision;
}
void CGame::ProcessEnemies()
{
	int iScreenWidth = (int)m_pDisplayPanel->GetWidth();
	int iScreenHeight = (int)m_pDisplayPanel->GetHeight();

	// 적이 맵 끝(바닥)에 도달하면 자동파괴
	DWORD	dwIndex = 0;
	while (dwIndex < m_dwCurEnemiesNum)
	{
		CFlightObject*	pEnemy = m_ppEnemyList[dwIndex];
		INT_VECTOR2		ivPos;
		pEnemy->GetPos(&ivPos);
		if (ivPos.y >= iScreenHeight)
		{
			DeleteFlightObject(pEnemy);
			m_dwCurEnemiesNum--;
			m_ppEnemyList[dwIndex] = m_ppEnemyList[m_dwCurEnemiesNum];
			m_ppEnemyList[m_dwCurEnemiesNum] = nullptr;
		}
		else
		{
			dwIndex++;
		}
	}
	MoveEnemies();
	FillEnemies();
}
void CGame::OnHitEnemy(CFlightObject* pEnemy, ULONGLONG CurTick)
{
	// 지금 삭제하지 않고 상태만 바꾼다.
	ChangeFlightObjectStatusToDead(pEnemy, CurTick);
	AddScore(SCORE_PER_ONE_KILL);
}
DWORD CGame::AddScore(DWORD dwAddval)
{
	/*
	m_dwCurScore += dwAddval;
	return m_dwCurScore;
	*/
	return 0;
}
void CGame::MoveEnemies()
{
	int iScreenWidth = (int)m_pDisplayPanel->GetWidth();
	int iScreenHeight = (int)m_pDisplayPanel->GetHeight();

	static ULONGLONG PrvEnemyMoveTick = 0;
	ULONGLONG CurTick = GetTickCount64();
	if (CurTick - PrvEnemyMoveTick < ENEMY_MOVE_ACTION_DELAY_TICK)
	{
		return;
	}
	PrvEnemyMoveTick = CurTick;

	for (DWORD i = 0; i < m_dwCurEnemiesNum; i++)
	{
		MoveEmemy(m_ppEnemyList[i], iScreenWidth);
	}
}

void CGame::FillEnemies()
{
	static ULONGLONG PrvFillEnemyTick = 0;

	int iScreenWidth = (int)m_pDisplayPanel->GetWidth();
	int iScreenHeight = (int)m_pDisplayPanel->GetHeight();

	if (m_dwCurEnemiesNum >= MAX_ENEMY_NUM)
	{
		return;
	}

	ULONGLONG CurTick = GetTickCount64();
	if (CurTick - PrvFillEnemyTick < 3000)
	{
		return;
	}
	PrvFillEnemyTick = CurTick;

	DWORD	dwNeyEnemyNum = MAX_ENEMY_NUM - m_dwCurEnemiesNum;
	for (DWORD i = 0; i < dwNeyEnemyNum; i++)
	{
		CFlightObject*	pEnemy = CreateEnemyRandom(m_pEnemyImgData, iScreenWidth, iScreenHeight, DEFAULT_ENEMY_SPEED);
		m_ppEnemyList[m_dwCurEnemiesNum] = pEnemy;
		m_dwCurEnemiesNum++;
	}
}
void CGame::DeleteAllEnemies()
{
	for (DWORD i = 0; i < m_dwCurEnemiesNum; i++)
	{
		DeleteFlightObject(m_ppEnemyList[i]);
		m_ppEnemyList[i] = nullptr;
	}
	m_dwCurEnemiesNum = 0;
}
void CGame::DeleteAllAmmos()
{
	for (DWORD i = 0; i < m_dwCurAmmoNum; i++)
	{
		DeleteFlightObject(m_ppAmmoList[i]);
		m_ppAmmoList[i] = nullptr;
	}
	m_dwCurAmmoNum = 0;
}
void CGame::Cleanup()
{
	CleanupDisplayPanel();

	DeleteAllEnemies();
	DeleteAllAmmos();
	if (m_pPlayer)
	{
		DeleteFlightObject(m_pPlayer);
		m_pPlayer = nullptr;
	}
	if (m_pPlayerImgData)
	{
		delete m_pPlayerImgData;
		m_pPlayerImgData = nullptr;
	}
	if (m_pAmmoImgData)
	{
		delete m_pAmmoImgData;
		m_pAmmoImgData = nullptr;
	}
	if (m_pEnemyImgData)
	{
		delete m_pEnemyImgData;
		m_pEnemyImgData = nullptr;
	}
	if (m_pMidScrollImageData)
	{
		delete m_pMidScrollImageData;
		m_pMidScrollImageData = nullptr;
	}
	//if (m_pCircleImage)
	//{
	//	delete m_pCircleImage;
	//	m_pCircleImage = nullptr;
	//}
	//if (m_pCircleImgData)
	//{
	//	delete m_pCircleImgData;
	//	m_pCircleImgData = nullptr;
	//}
	if (m_pBackImage)
	{
		delete m_pBackImage;
		m_pBackImage = nullptr;
	}
}
void CGame::ShootFromPlayer()
{
	if (m_dwCurAmmoNum >= MAX_AMMO_NUM)
		return;

	CFlightObject*	pAmmo = CreateAmmo(m_pPlayer, m_pAmmoImgData, DEFAULT_AMMO_SPEED);
	m_ppAmmoList[m_dwCurAmmoNum] = pAmmo;
	m_dwCurAmmoNum++;
}

void CGame::DrawScore(int x, int y)
{
	//
	// IMegayuchiRenderer로부터 텍스트 출력 함수를 빼준다.
	//
	/*
	DWORD	dwOffset = x + y * m_iScreenWidth;
	WCHAR*	wchDest = m_pBackBuffer + dwOffset;
	DWORD	dwDesBufferLen = (DWORD)((m_iScreenWidth * m_iScreenHeight - (int)dwOffset));

	WCHAR	wchTxt[32];
	DWORD	dwLen = swprintf_s(wchTxt, L"Score:%08u", m_dwCurScore);
	memcpy(wchDest, wchTxt, sizeof(WCHAR) * dwLen);
	*/
}
void CGame::OnDeleteVoxelObject(IVoxelObjectLite* pVoxelObj)
{
	if (m_pDisplayPanel)
	{
		m_pDisplayPanel->OnDeleteVoxelObject(pVoxelObj);
	}
}
CGame::~CGame()
{
	Cleanup();
}