#include "stdafx.h"
#include <Windows.h>
#include <stdio.h>
#include "../include/typedef.h"
#include "../include/IGameHookController.h"
#include "Util.h"
#include "DisplayPanel.h"
#include "../util/QueryPerfCounter.h"
#include "WebPage.h"


HRESULT typedef (__stdcall *CREATE_INSTANCE_FUNC)(void* ppv);

CWebPage::CWebPage()
{
	m_dwCurFPS = 0;
	m_fTicksPerGameFrame = 1000.0f / (float)m_dwGameFPS;
	m_PrvGameFrameTick = GetTickCount64();
	m_PrvCounter = QCGetCounter();
}
BOOL CWebPage::Initialize(IVHController* pVHController, char* szURL, DWORD dwWidth, DWORD dwHeight)
{
	m_pVHController = pVHController;

	m_pVHController->DeleteAllVoxelObject();

	m_pDisplayPanel = new CDisplayPanel;
	m_pDisplayPanel->Initialize(m_pVHController, DISPLAY_PANEL_WIDTH, DISPLAY_PANEL_HEIGHT, 1);

	DWORD dwDisplayWidth = m_pDisplayPanel->GetWidth();
	DWORD dwDisplayHeight = m_pDisplayPanel->GetHeight();

	m_dwWidth = dwWidth;
	m_dwHeight = dwHeight;
	
	m_pBits32 = (BYTE*)malloc(m_dwWidth * m_dwHeight * 4);
	memset(m_pBits32, 0, m_dwWidth * m_dwHeight);

	m_pBits8 = (BYTE*)malloc(dwDisplayWidth * dwDisplayHeight);
	memset(m_pBits8, 0, dwDisplayWidth * dwDisplayHeight);

	m_pBits32Resized = (BYTE*)malloc(dwDisplayWidth * dwDisplayHeight * 4);
	memset(m_pBits32Resized, 0, dwDisplayWidth * dwDisplayHeight * 4);

	srand(GetTickCount());

	m_pWebHandle = m_pVHController->BrowseWeb(szURL, m_dwWidth, m_dwHeight, TRUE);

	return TRUE;
}
BOOL CWebPage::OnPreConsoleCommand(const WCHAR* wchCmd, DWORD dwCmdLen)
{
	return FALSE;
}
BOOL CWebPage::OnKeyDown(UINT nChar)
{
	return FALSE;
}
BOOL CWebPage::OnKeyUp(UINT nChar)
{
	return FALSE;
}
BOOL CWebPage::OnMouseLButtonDown(int x, int y, UINT nFlags)
{
	BOOL bResult = FALSE;
	VECTOR3 v3RayOrig = {};
	VECTOR3 v3RayDir = {};
	if (m_pVHController->GetRayWithScreenCoord(&v3RayOrig, &v3RayDir, x, y))
	{
		VECTOR3 v3IntersectPoint = {};
		float t = 0.0f;
		VECTOR3 v3Axis = {};
		VOXEL_DESC_LITE voxelDesc = {};
		if (m_pVHController->IntersectVoxelWithRay(&v3IntersectPoint, &t, &v3Axis, &voxelDesc, &v3RayOrig, &v3RayDir))
		{
			int sx = 0;
			int sy = 0;
			if (m_pDisplayPanel->GetScreenPosWithWorldPos(&sx, &sy, &v3IntersectPoint, (int)m_dwWidth, (int)m_dwHeight))
			{
				m_pVHController->OnWebMouseLButtonDown(m_pWebHandle, sx, sy, 0);
				bResult = TRUE;
			}
			/*
			if (m_pDisplayPanel->GetScreenPosWithVoxelObjPos(&sx, &sy, voxelDesc.pVoxelObj, voxelDesc.x, voxelDesc.y))
			{
				m_pVHController->OnWebMouseLButtonDown(m_pWebHandle, sx, sy, 0);
				bResult = TRUE;
			}
			*/
		}
	}
	return bResult;
}

BOOL CWebPage::OnMouseLButtonUp(int x, int y, UINT nFlags)
{
	BOOL bResult = FALSE;
	VECTOR3 v3RayOrig = {};
	VECTOR3 v3RayDir = {};
	if (m_pVHController->GetRayWithScreenCoord(&v3RayOrig, &v3RayDir, x, y))
	{
		VECTOR3 v3IntersectPoint = {};
		float t = 0.0f;
		VECTOR3 v3Axis = {};
		VOXEL_DESC_LITE voxelDesc = {};
		if (m_pVHController->IntersectVoxelWithRay(&v3IntersectPoint, &t, &v3Axis, &voxelDesc, &v3RayOrig, &v3RayDir))
		{
			int sx = 0;
			int sy = 0;
			if (m_pDisplayPanel->GetScreenPosWithWorldPos(&sx, &sy, &v3IntersectPoint, (int)m_dwWidth, (int)m_dwHeight))
			{
				m_pVHController->OnWebMouseLButtonUp(m_pWebHandle, sx, sy, 0);
				bResult = TRUE;
			}
			/*
			if (m_pDisplayPanel->GetScreenPosWithVoxelObjPos(&sx, &sy, voxelDesc.pVoxelObj, voxelDesc.x, voxelDesc.y))
			{
				m_pVHController->OnWebMouseLButtonUp(m_pWebHandle, sx, sy, 0);
				bResult = TRUE;
			}
			*/
		}
	}
	return bResult;
}
BOOL CWebPage::OnMouseMove(int x, int y, UINT nFlags)
{
	if (!(nFlags & MK_LBUTTON))
		return FALSE;

	BOOL bResult = FALSE;
	VECTOR3 v3RayOrig = {};
	VECTOR3 v3RayDir = {};
	if (m_pVHController->GetRayWithScreenCoord(&v3RayOrig, &v3RayDir, x, y))
	{
		VECTOR3 v3IntersectPoint = {};
		float t = 0.0f;
		VECTOR3 v3Axis = {};
		VOXEL_DESC_LITE voxelDesc = {};
		if (m_pVHController->IntersectVoxelWithRay(&v3IntersectPoint, &t, &v3Axis, &voxelDesc, &v3RayOrig, &v3RayDir))
		{
			int sx = 0;
			int sy = 0;
			if (m_pDisplayPanel->GetScreenPosWithWorldPos(&sx, &sy, &v3IntersectPoint, (int)m_dwWidth, (int)m_dwHeight))
			{
				m_pVHController->OnWebMouseMove(m_pWebHandle, sx, sy, nFlags);
				bResult = TRUE;
			}
			/*
			if (m_pDisplayPanel->GetScreenPosWithVoxelObjPos(&sx, &sy, voxelDesc.pVoxelObj, voxelDesc.x, voxelDesc.y))
			{
				m_pVHController->OnWebMouseLButtonUp(m_pWebHandle, sx, sy, 0);
				bResult = TRUE;
			}
			*/
		}
	}
	return bResult;
}
BOOL CWebPage::OnMouseWheel(int x, int y, int iWheel)
{
	BOOL bResult = FALSE;
	VECTOR3 v3RayOrig = {};
	VECTOR3 v3RayDir = {};
	if (m_pVHController->GetRayWithScreenCoord(&v3RayOrig, &v3RayDir, x, y))
	{
		VECTOR3 v3IntersectPoint = {};
		float t = 0.0f;
		VECTOR3 v3Axis = {};
		VOXEL_DESC_LITE voxelDesc = {};
		if (m_pVHController->IntersectVoxelWithRay(&v3IntersectPoint, &t, &v3Axis, &voxelDesc, &v3RayOrig, &v3RayDir))
		{
			int sx = 0;
			int sy = 0;
			if (m_pDisplayPanel->GetScreenPosWithWorldPos(&sx, &sy, &v3IntersectPoint, (int)m_dwWidth, (int)m_dwHeight))
			{
				m_pVHController->OnWebMouseWheel(m_pWebHandle, sx, sy, iWheel);
				bResult = TRUE;
			}
			/*
			if (m_pDisplayPanel->GetScreenPosWithVoxelObjPos(&sx, &sy, voxelDesc.pVoxelObj, voxelDesc.x, voxelDesc.y))
			{
				m_pVHController->OnWebMouseLButtonUp(m_pWebHandle, sx, sy, 0);
				bResult = TRUE;
			}
			*/
		}
	}
	return bResult;
}
void CWebPage::DrawScene()
{
	if (m_pBits8)
	{
		if (m_pVHController->GetWebImage(m_pBits32, m_dwWidth, m_dwHeight, m_dwWidth * 4, m_pWebHandle))
		{
			// resize
			DownSample_FPU((DWORD*)m_pBits32Resized, (DWORD*)m_pBits32, m_dwWidth, m_dwHeight);

			DWORD dwDisplayWidth = m_pDisplayPanel->GetWidth();
			DWORD dwDisplayHeight = m_pDisplayPanel->GetHeight();

			// convert 32 bits to 8 bits
			m_pDisplayPanel->Convert32BitsImageTo8BitsPalettedImageBGRA(m_pBits8, (DWORD*)m_pBits32Resized, dwDisplayWidth, dwDisplayHeight);

			// 배경 레이어에 배경 이미지 출력
			m_pDisplayPanel->DrawPalettedBitmap(0, 0, dwDisplayWidth, dwDisplayHeight, m_pBits8, 0);
			m_pDisplayPanel->UpdateBitmapToVoxelDataWithSingleLayer(0, 0);
		}
	}
}
void CWebPage::Process()
{
	LARGE_INTEGER	CurCounter = QCGetCounter();
	float	fElpasedTick = QCMeasureElapsedTick(CurCounter, m_PrvCounter);
	ULONGLONG CurTick = GetTickCount64();

	if (fElpasedTick > m_fTicksPerGameFrame)
	{

		m_PrvGameFrameTick = CurTick;
		m_PrvCounter = CurCounter;

	}
	DrawScene();
}

CWebPage::~CWebPage()
{
	if (m_pBits8)
	{
		free(m_pBits8);
		m_pBits8 = nullptr;
	}
	if (m_pBits32Resized)
	{
		free(m_pBits32Resized);
		m_pBits32Resized = nullptr;
	}
	if (m_pBits32Resized)
	{
		free(m_pBits32Resized);
		m_pBits32Resized = nullptr;
	}
	if (m_pWebHandle)
	{
		m_pVHController->CloseWeb(m_pWebHandle);
		m_pWebHandle = nullptr;
	}
	if (m_pDisplayPanel)
	{
		delete m_pDisplayPanel;
		m_pDisplayPanel = nullptr;
	}
}