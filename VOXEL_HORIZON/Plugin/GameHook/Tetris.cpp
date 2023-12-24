#include "stdafx.h"
#include <Windows.h>
#include <stdio.h>
#include "../include/typedef.h"
#include "../include/IGameHookController.h"
#include "Util.h"
#include "DisplayPanel.h"
#include "../util/QueryPerfCounter.h"
#include "Tetris.h"


const BYTE g_pBlockData_0[4] =
{
	15, 15,
	15, 15
};

const BYTE g_pBlockData_1[4][6] =
{
	{
		0xff, 15, 0xff,
		  15, 15,   15
	},
	{
		0xff, 15,
		  15, 15,
		0xff, 15
	},
	{
		15,   15,   15,
		0xff, 15, 0xff
		  
	},
	{
		15, 0xff,
		15, 15,
		15, 0xff
	}
};
const BYTE g_pBlockData_2[2][6] =
{
	{
		15,	  15, 0xff,
		0xff, 15,   15
	},
	{
		0xff, 15,
		15,	  15,
		15,	  0xff
	}
};
const BYTE g_pBlockData_3[4] =
{
	15,
	15,
	15,
	15
};
const BYTE g_pBlockData_4[4][8] =
{
	{
		15,   15,
		15, 0xff,
		15, 0xff,
		15, 0xff
	},
	{
		15, 0xff, 0xff, 0xff,
		15,   15,   15,   15
	},
	{
		0xff, 15,
		0xff, 15,
		0xff, 15,
		  15, 15
	},
	{
		  15,   15,   15, 15,
		0xff, 0xff, 0xff, 15,
	}
};
const BLOCK_TEMPLATE g_pBlockData[TETRIS_BLOCK_TYPE_COUNT][TETRIS_BLOCK_TRANFORM_TYPE_COUNT] =
{
	{
		//  **
		//  **
		g_pBlockData_0, 2, 2,
		g_pBlockData_0, 2, 2,
		g_pBlockData_0, 2, 2,
		g_pBlockData_0, 2, 2
	},
	{	
		//  *     *     ***    *
		// ***   **      *     **
		//        *            * 
		g_pBlockData_1[0], 3, 2,
		g_pBlockData_1[1], 2, 3,
		g_pBlockData_1[2], 3, 2,
		g_pBlockData_1[3], 2, 3
	},
	{	// **     *    **     *
		//  **   **     **   **
		//       *           *
		g_pBlockData_2[0], 3, 2,
		g_pBlockData_2[1], 2, 3,
		g_pBlockData_2[0], 3, 2,
		g_pBlockData_2[1], 2, 3
	}
	,
	{
		//  *          *
		//  *   ****   *   ****
		//  *          *
		//  *          *
		g_pBlockData_3, 1, 4,
		g_pBlockData_3, 4, 1,
		g_pBlockData_3, 1, 4,
		g_pBlockData_3, 4, 1
	},
	{
		//  *             *     **
		//  *    ****     *     *
		//  *       *     *     * 
		// **            **     *
		g_pBlockData_4[0], 2, 4,
		g_pBlockData_4[1], 4, 2,
		g_pBlockData_4[2], 2, 4,
		g_pBlockData_4[3], 4, 2
	}

};


CTetris::CTetris()
{
	m_dwCurFPS = 0;
	m_fTicksPerGameFrame = 1000.0f / (float)m_dwGameFPS;
	m_PrvGameFrameTick = GetTickCount64();
	m_PrvCounter = QCGetCounter();
}

BOOL CTetris::Initialize(IVHController* pVHController, const WCHAR* wchPluginPath)
{
	m_pVHController = pVHController;
	
	m_pVHController->DeleteAllVoxelObject();

	m_pDisplayPanel = new CDisplayPanel;
	m_pDisplayPanel->Initialize(m_pVHController, m_iFrameWidth, m_iFrameHeight, TETRIS_LAYER_INDEX_COUNT);

	m_pFrameBuffer = new BYTE[m_iFrameWidth * m_iFrameHeight];
	memset(m_pFrameBuffer, 0xff, m_iFrameWidth * m_iFrameHeight);

	wcscpy_s(m_wchPluginPath, wchPluginPath);

	int iScreenWidth = (int)m_pDisplayPanel->GetWidth();
	int iScreenHeight = (int)m_pDisplayPanel->GetHeight();

	srand(GetTickCount());

	InitFrame(m_pFrameBuffer, m_iFrameWidth, m_iFrameHeight);

	EnableMultipleLayresMode(TRUE);

	return TRUE;
}
void CTetris::InitFrame(BYTE* pBuffer, int iWidth, int iHeight)
{
	// 바닥
	BYTE* pDest = nullptr;
	pDest = pBuffer + (iHeight - 1) * iWidth;
	for (int x = 0; x < iWidth; x++)
	{
		pDest[x] = 0;
	}

	// 왼쪽 세로벽
	pDest = pBuffer;
	for (int y = 0; y < iHeight; y++)
	{
		*pDest = 0;
		pDest += iWidth;
	}
	
	// 오른쪽 세로벽
	pDest = pBuffer + (iWidth-1);
	for (int y = 0; y < iHeight; y++)
	{
		*pDest = 0;
		pDest += iWidth;
	}
}
BOOL CTetris::OnPreConsoleCommand(const WCHAR* wchCmd, DWORD dwCmdLen)
{
	return FALSE;
}
void CTetris::CleanupDisplayPanel()
{
	if (m_pDisplayPanel)
	{
		delete m_pDisplayPanel;
		m_pDisplayPanel = nullptr;
	}
}
void CTetris::Process()
{
	LARGE_INTEGER	CurCounter = QCGetCounter();
	float	fElpasedTick = QCMeasureElapsedTick(CurCounter, m_PrvCounter);
	ULONGLONG CurTick = GetTickCount64();

	if (fElpasedTick > m_fTicksPerGameFrame)
	{

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
		//InterpolatePostion(fAlpha);
	}

	if (!m_bPause)
	{
		DrawScene();
	}
}

BOOL CTetris::OnKeyDown(UINT nChar)
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
					if (IsCanMove(m_pCurObj, -1, 0))
					{
						m_pCurObj->ivPos.x--;
					}
					bProcessed = TRUE;
				}
			}
			break;
		case VK_RIGHT:
			{
				if (!m_bPause)
				{
					m_bKeyDown_Right = TRUE;
					if (IsCanMove(m_pCurObj, 1, 0))
					{
						m_pCurObj->ivPos.x++;
					}
					bProcessed = TRUE;
				}
			}
			break;
		case VK_UP:
			{
				if (!m_bPause)
				{
					m_bKeyDown_Up = TRUE;
									
					UINT NewTransformType = (m_pCurObj->TranformType + 1) % TETRIS_BLOCK_TRANFORM_TYPE_COUNT;
					if (IsCanTransform(m_pCurObj, NewTransformType))
					{
						const BLOCK_TEMPLATE*	pSrcData = &g_pBlockData[m_pCurObj->BlockType][NewTransformType];
						m_pCurObj->pShapeData = pSrcData->pShapeData;
						m_pCurObj->iWidth = pSrcData->iWidth;
						m_pCurObj->iHeight = pSrcData->iHeight;
						m_pCurObj->TranformType = NewTransformType;
					}
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
					ChangeShape();
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
BOOL CTetris::OnKeyUp(UINT nChar)
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

void CTetris::EnableMultipleLayresMode(BOOL bSwitch)
{
	m_bUseMultipleLayers = bSwitch; 
	m_pDisplayPanel->ResetVoxelData();
}


void CTetris::DrawScene()
{
	//m_pFrameBuffer
	
	DWORD	dwObjLayerIndex = TETRIS_LAYER_INDEX_OBJECT;
	DWORD	dwBackgroundLayerIndex = TETRIS_LAYER_INDEX_OBJECT;

	if (m_bUseMultipleLayers)
	{
		dwObjLayerIndex = TETRIS_LAYER_INDEX_OBJECT;
		dwBackgroundLayerIndex = TETRIS_LAYER_INDEX_OBJECT;
		
		// 오브젝트 레이어 클리어
		m_pDisplayPanel->Clear(0xff, dwObjLayerIndex);
	}

	if (m_pFrameBuffer)
	{
		// 배경 레이어에 배경 이미지 출력
		m_pDisplayPanel->DrawPalettedBitmap(0, 0, m_iFrameWidth, m_iFrameHeight, m_pFrameBuffer, dwBackgroundLayerIndex);
	}
	else
	{
		m_pDisplayPanel->Clear(0, dwBackgroundLayerIndex);
	}
	if (m_pCurObj)
	{
		m_pDisplayPanel->DrawPalettedBitmapWithTransparency(m_pCurObj->ivPos.x, m_pCurObj->ivPos.y, m_pCurObj->iWidth, m_pCurObj->iHeight, m_pCurObj->pShapeData, dwBackgroundLayerIndex);
	}

	/*
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
	*/
	// 복셀 오브젝트에 반영
	if (m_bUseMultipleLayers)
	{
		m_pDisplayPanel->UpdateBitmapToVoxelDataWithMultipleLayers(TETRIS_LAYER_INDEX_OBJECT, TETRIS_LAYER_INDEX_COUNT);
	}
	else
	{
		m_pDisplayPanel->UpdateBitmapToVoxelDataWithSingleLayer(0, TETRIS_LAYER_INDEX_OBJECT);
	}
	//	m_pDDraw->CheckFPS();
}
void CTetris::OnUpdateWindowSize()
{

}
void CTetris::OnUpdateWindowPos()
{

}
void CTetris::DrawObjBoard(DWORD dwLayerIndex)
{
	/*
	const CImageData* pImageData = pFighter->GetImageData();
	//m_pDisplayPanel->DrawPalettedBitmap(x, y, pImageData->GetWidth(), pImageData->GetHeight(), pImageData->GetUncompressedImage());
	m_pDisplayPanel->DrawCompressedPalettedImageData(x, y, pImageData, dwLayerIndex);
	*/
}


BLOCK_OBJECT* CTetris::CreateBlockObject(UINT BlockType)
{
	const BLOCK_TEMPLATE*	pSrcData = &g_pBlockData[BlockType][0];

	BLOCK_OBJECT* pObj = new BLOCK_OBJECT;
	memset(pObj, 0, sizeof(BLOCK_OBJECT));
	pObj->pShapeData = pSrcData->pShapeData;
	pObj->iWidth = pSrcData->iWidth;
	pObj->iHeight = pSrcData->iHeight;
	pObj->BlockType = BlockType;
	pObj->TranformType = 0;
	pObj->LastMoveDownTick = 0;

	int mid_pos = (m_iFrameWidth / 2) - (pObj->iWidth / 2);
	pObj->ivPos = {mid_pos, 0};
	
	//CalcRect(&pObj->ivRect, pObj->pData, pObj->Width, pObj->Height, pObj->Width);
	return pObj;
}

void CTetris::MergeObject(BLOCK_OBJECT** ppInOutObj)
{
	BLOCK_OBJECT* pObj = *ppInOutObj;
	
	// 이미 쌓여있는 블럭들에 대한 체크
	for (int y = 0; y < pObj->iHeight; y++)
	{
		int dest_y = y + pObj->ivPos.y;
		for (int x = 0; x < pObj->iWidth; x++)
		{
			int dest_x = x + pObj->ivPos.x;
	
			BYTE bSrcValue = pObj->pShapeData[x + y * pObj->iWidth];
			
			if (bSrcValue != 0xff)
			{
				m_pFrameBuffer[dest_x + dest_y * m_iFrameWidth] = bSrcValue;
			}
		}
	}
	delete pObj;
	*ppInOutObj = nullptr;
}
BOOL CTetris::IsCanMove(BLOCK_OBJECT* pObj, int iMoveX, int iMoveY)
{
	BOOL	bResult = FALSE;
	
	INT_VECTOR2 ivPos =
	{
		pObj->ivPos.x + iMoveX,
		pObj->ivPos.y + iMoveY
	};
	bResult = IsCanExist(pObj->pShapeData, &ivPos, pObj->iWidth, pObj->iHeight);

	return bResult;
}
BOOL CTetris::IsCanTransform(BLOCK_OBJECT* pObj, UINT TransformType)
{
	BOOL	bResult = FALSE;
	
	const BLOCK_TEMPLATE*	pSrcData = &g_pBlockData[pObj->BlockType][TransformType];
	bResult = IsCanExist(pSrcData->pShapeData, &pObj->ivPos, pSrcData->iWidth, pSrcData->iHeight);

	return bResult;
}
BOOL CTetris::IsCanExist(const BYTE* pData, const INT_VECTOR2* pivPos, int iWidth, int iHeight)
{
	BOOL	bResult = FALSE;
	
	// 상하좌우 가동범위
	int range_width = m_iFrameWidth - 1 - 1;
	int range_start_x = 1;
	int range_end_x = range_start_x + range_width;
	
	int range_height = m_iFrameHeight - 1;
	int range_start_y = 0;
	int range_end_y = range_start_y + range_height;
	
	int sx = pivPos->x;
	int sy = pivPos->y;

	// 상하좌우 테스트
	if (sx < range_start_x)
		goto lb_return;

	if (sx + iWidth > range_end_x)
		goto lb_return;

	if (sy < range_start_y)
		goto lb_return;

	if (sy + iHeight > range_end_y)
		goto lb_return;

	// 이미 쌓여있는 블럭들에 대한 체크
	for (int y = 0; y < iHeight; y++)
	{
		int dest_y = sy + y;
		for (int x = 0; x < iWidth; x++)
		{
			int dest_x = sx + x;
	
			BYTE bSrcValue = pData[x + y * iWidth];
			BYTE bDestValue = m_pFrameBuffer[dest_x + dest_y * m_iFrameWidth];
			if (bSrcValue != 0xff)
			{
				if (bDestValue != 0xff)
				{
					// 이미 쌓여있는 블럭과 충돌한다.
					goto lb_return;
				}
			}
		}
	}
	bResult = TRUE;
lb_return:
	return bResult;
}


void CTetris::OnGameFrame(ULONGLONG CurTick)
{
	BOOL bMustUpdateBack = FALSE;
	if (TETRIS_PROCESS_MODE_MOVING == m_CurMode)
	{
		if (m_pCurObj)
		{
			if (m_bKeyDown_Down)
			{
				if (CurTick - m_pCurObj->LastMoveDownForcedTick > 66)
				{
					if (IsCanMove(m_pCurObj, 0, 1))
					{
						m_pCurObj->ivPos.y++;
						m_pCurObj->LastMoveDownForcedTick = CurTick;
					}
				}
			}
			int iScreenWidth = (int)m_pDisplayPanel->GetWidth();
			int iScreenHeight = (int)m_pDisplayPanel->GetHeight();

			// 이동할 시간에 도달하지 못한 경우 bUpdated== FALSE, bMerged도 FALSE
			BOOL bMerged = FALSE;
			BOOL bUpdated = UpdateObjPos(CurTick, &bMerged);
			if (bUpdated)
			{
				bMustUpdateBack = TRUE;
			}
			else
			{
				if (bMerged)
				{
					bMustUpdateBack = TRUE;
					// 한줄 완료됐는지 테스트
					m_iCompletedCount = CheckCompletedLines(m_piCompltedLineIndexList, FRAME_HEIGHT);
					if (m_iCompletedCount)
					{
						// 완료된 라인이 있으면 애니메이션 모드로 전환
						m_CurMode = TETRIS_PROCESS_MODE_SHOW_EFFECT_FLASH;
						m_BeginEffectTick = CurTick;
					}
					
					
				}
			}
		}
		else
		{
			UINT BlockType = rand() % TETRIS_BLOCK_TYPE_COUNT;
			m_pCurObj = CreateBlockObject(BlockType);
			bMustUpdateBack = TRUE;
		}
	}
	else if (TETRIS_PROCESS_MODE_SHOW_EFFECT_FLASH == m_CurMode)
	{
		if (CurTick - m_BeginEffectTick < 500)
		{
			ProcessCompletedLines(m_piCompltedLineIndexList, m_iCompletedCount);
		}
		else
		{
			RemoveCompletedLines(m_piCompltedLineIndexList, m_iCompletedCount);
			m_CurMode = TETRIS_PROCESS_MODE_SHOW_EFFECT_REMOVE;
			//m_CurMode = TETRIS_PROCESS_MODE_MOVING;
			
			
		}
	}
	else if (TETRIS_PROCESS_MODE_SHOW_EFFECT_REMOVE == m_CurMode)
	{
		CompactMergedBlocks(m_piCompltedLineIndexList, m_iCompletedCount);
		m_CurMode = TETRIS_PROCESS_MODE_MOVING;
	}
	else
	{
		bMustUpdateBack = TRUE;
		int a = 0;
	}
	if (bMustUpdateBack)
	{
		
	}
}
int CTetris::CheckCompletedLines(int* piOutBuffer, int iMaxBufferCount)
{
	int iCompletedLineCount = 0;

	for (int y = 0; y < m_iFrameHeight - 1; y++)
	{
		for (int x = 1; x < m_iFrameWidth - 1; x++)
		{
			if (0xff == m_pFrameBuffer[x + y * m_iFrameWidth])
				goto lb_next_line;
		}
		// 여기까지 왔으면 한줄 완료
		if (iCompletedLineCount < iMaxBufferCount)
		{
			piOutBuffer[iCompletedLineCount] = y;
			iCompletedLineCount++;
		}
	lb_next_line:
		int a = 0;
	}
	return iCompletedLineCount;
}
void CTetris::ProcessCompletedLines(const int* piCompltedLineIndexList, int iCompletedCount)
{
	BYTE	pbColorIndexList[2] = { 5, 16 };
	BYTE bColorIndex = pbColorIndexList[m_dwEffectProcessCount];

	for (int line_index = 0; line_index < iCompletedCount; line_index++)
	{
		int y = piCompltedLineIndexList[line_index];
		for (int x = 1; x < m_iFrameWidth - 1; x++)
		{
			m_pFrameBuffer[x + y * m_iFrameWidth] = bColorIndex;
		}
	}
	m_dwEffectProcessCount++;
	m_dwEffectProcessCount = m_dwEffectProcessCount % 2;
}
void CTetris::RemoveCompletedLines(const int* piCompltedLineIndexList, int iCompletedCount)
{
	for (int line_index = 0; line_index < iCompletedCount; line_index++)
	{
		int y = piCompltedLineIndexList[line_index];
		for (int x = 1; x < m_iFrameWidth - 1; x++)
		{
			m_pFrameBuffer[x + y * m_iFrameWidth] = 0xff;
		}
	}
}
void CTetris::CompactMergedBlocks(const int* piCompltedLineIndexList, int iCompletedCount)
{
	for (int line_index = 0; line_index < iCompletedCount; line_index++)
	{
		CompactMergedBlocks(piCompltedLineIndexList[line_index]);
	}
}
void CTetris::CompactMergedBlocks(int iLineIndex)
{
	int dest_line_index = iLineIndex;
	int src_line_index = iLineIndex - 1;
	while (dest_line_index >= 0)
	{
		if (src_line_index < 0)
		{
			memset(&m_pFrameBuffer[1 + dest_line_index * m_iFrameWidth], 0xff, FRAME_WIDTH - 2);
		}
		else
		{
			memcpy(&m_pFrameBuffer[1 + dest_line_index * m_iFrameWidth], &m_pFrameBuffer[1 + src_line_index * m_iFrameWidth], FRAME_WIDTH - 2);
		}
		dest_line_index--;
		src_line_index--;
	}	
}
BOOL CTetris::UpdateObjPos(ULONGLONG CurTick, BOOL* pbOutMerged)
{
	BOOL bResult = FALSE;
	if (CurTick - m_pCurObj->LastMoveDownTick < 500)
		goto lb_return;
	
	m_pCurObj->LastMoveDownTick = CurTick;

	if (IsCanMove(m_pCurObj, 0, 1))
	{
		m_pCurObj->ivPos.y++;
	}
	else
	{
		// 더 이상 아래로 움직일 수 없다면 바닥에 닿은 것
		MergeObject(&m_pCurObj);
		*pbOutMerged = TRUE;
	}
lb_return:
	return bResult;
}
void CTetris::Cleanup()
{
	CleanupDisplayPanel();

	if (m_pFrameBuffer)
	{
		delete[] m_pFrameBuffer;
		m_pFrameBuffer = nullptr;
	}
	if (m_pCurObj)
	{
		delete m_pCurObj;
		m_pCurObj;
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
}
void CTetris::ChangeShape()
{
	/*
	if (m_dwCurAmmoNum >= MAX_AMMO_NUM)
		return;

	CFlightObject*	pAmmo = CreateAmmo(m_pPlayer, m_pAmmoImgData, DEFAULT_AMMO_SPEED);
	m_ppAmmoList[m_dwCurAmmoNum] = pAmmo;
	m_dwCurAmmoNum++;
	*/
}

void CTetris::DrawScore(int x, int y)
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
void CTetris::OnDeleteVoxelObject(IVoxelObjectLite* pVoxelObj)
{
	if (m_pDisplayPanel)
	{
		m_pDisplayPanel->OnDeleteVoxelObject(pVoxelObj);
	}
}
CTetris::~CTetris()
{
	Cleanup();
}