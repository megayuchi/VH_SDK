#include "stdafx.h"
#include "../include/BooleanTable.inl"
#include "../util/VoxelUtil.h"
#include "../util/WriteDebugString.h"
#include "Util.h"
#include "GameHook.h"
#include "TestVoxelEditor.h"


CTestVoxelEditor::CTestVoxelEditor()
{

}

BOOL CTestVoxelEditor::Initialize(IVHController* pVHController, IVHNetworkLayer* pVHNetworkLayer)
{
	m_pVHController = pVHController;
	m_pNetworkLayer = pVHNetworkLayer;

	m_dwMaxSelectedObjPosNum = MAX_SELECTED_VOXEL_OBJ_POS_NUM;
	m_pivSelectedObjPosList = new INT_VECTOR3[m_dwMaxSelectedObjPosNum];
	memset(m_pivSelectedObjPosList, 0, sizeof(INT_VECTOR3) * m_dwMaxSelectedObjPosNum);
	return TRUE;
}
BOOL CTestVoxelEditor::OnPreConsoleCommand(const WCHAR* wchCmd, DWORD dwCmdLen)
{
	return FALSE;
}


void CTestVoxelEditor::SetVoxelColorRecursive(unsigned long* pBitTable, BYTE* pColorTable, const VECTOR3* pv3ObjPos, int x, int y, int z, BYTE bColorIndex, BYTE bCmpColorIndex, UINT CursorWidthDepthHeight, INT_VECTOR3* pivOutVoxelPosList, DWORD* pdwInOutVoxelCount, PLANE_AXIS_TYPE planeType)
{
	if (x >= (int)CursorWidthDepthHeight)
		return;

	if (y >= (int)CursorWidthDepthHeight)
		return;

	if (z >= (int)CursorWidthDepthHeight)
		return;

	if (x < 0)
		return;

	if (y < 0)
		return;

	if (z < 0)
		return;

	if (FALSE == ::GetVoxelValue(pBitTable, CursorWidthDepthHeight, x, y, z))
		return;

	if (::GetVoxelColor(pColorTable, CursorWidthDepthHeight, x, y, z) != bCmpColorIndex)
	{
		// 지정한 색과 다르면 스킵.
		return;
	}
	if (::GetVoxelColor(pColorTable, CursorWidthDepthHeight, x, y, z) == bColorIndex)
	{
		// 목표 복셀의 색상이 설정하려는 색과 이미 같다면 스킵
		return;
	}
	INT_VECTOR3		ivCursorVoxelPos = { x, y, z };
	::SetVoxelValue(pBitTable, CursorWidthDepthHeight, x, y, z, FALSE);
	::SetVoxelColor(pColorTable, CursorWidthDepthHeight, x, y, z, bColorIndex);

	if ((*pdwInOutVoxelCount) < MAX_RECURSIVE_PLANE_COLLECT_VOXEL_COUNT)
	{
		pivOutVoxelPosList[*pdwInOutVoxelCount] = { x, y, z };
		(*pdwInOutVoxelCount)++;
	}
	switch (planeType)
	{
		case PLANE_AXIS_TYPE_XZ:
			{
				SetVoxelColorRecursive(pBitTable, pColorTable, pv3ObjPos, x + 1, y, z, bColorIndex, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				SetVoxelColorRecursive(pBitTable, pColorTable, pv3ObjPos, x - 1, y, z, bColorIndex, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				SetVoxelColorRecursive(pBitTable, pColorTable, pv3ObjPos, x, y, z + 1, bColorIndex, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				SetVoxelColorRecursive(pBitTable, pColorTable, pv3ObjPos, x, y, z - 1, bColorIndex, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
			}
			break;
		case PLANE_AXIS_TYPE_XY:
			{
				SetVoxelColorRecursive(pBitTable, pColorTable, pv3ObjPos, x + 1, y, z, bColorIndex, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				SetVoxelColorRecursive(pBitTable, pColorTable, pv3ObjPos, x - 1, y, z, bColorIndex, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				SetVoxelColorRecursive(pBitTable, pColorTable, pv3ObjPos, x, y + 1, z, bColorIndex, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				SetVoxelColorRecursive(pBitTable, pColorTable, pv3ObjPos, x, y - 1, z, bColorIndex, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
			}
			break;
		case PLANE_AXIS_TYPE_YZ:
			{
				SetVoxelColorRecursive(pBitTable, pColorTable, pv3ObjPos, x, y + 1, z, bColorIndex, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				SetVoxelColorRecursive(pBitTable, pColorTable, pv3ObjPos, x, y - 1, z, bColorIndex, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				SetVoxelColorRecursive(pBitTable, pColorTable, pv3ObjPos, x, y, z + 1, bColorIndex, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				SetVoxelColorRecursive(pBitTable, pColorTable, pv3ObjPos, x, y, z - 1, bColorIndex, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
			}
			break;
	}
}
void CTestVoxelEditor::CollectVoxelPosListRecursiveXYZ(unsigned long* pBitTable, const BYTE* pColorTable, const VECTOR3* pv3ObjPos, int x, int y, int z, BYTE bCmpColorIndex, UINT CursorWidthDepthHeight, INT_VECTOR3* pivOutVoxelPosList, DWORD* pdwInOutVoxelCount)
{
	if (x >= (int)CursorWidthDepthHeight)
		return;

	if (y >= (int)CursorWidthDepthHeight)
		return;

	if (z >= (int)CursorWidthDepthHeight)
		return;

	if (x < 0)
		return;

	if (y < 0)
		return;

	if (z < 0)
		return;

	if (FALSE == ::GetVoxelValue(pBitTable, CursorWidthDepthHeight, x, y, z))
		return;

	if (::GetVoxelColor(pColorTable, CursorWidthDepthHeight, x, y, z) != bCmpColorIndex)
	{
		// 지정한 색과 다르면 스킵.
		return;
	}
	INT_VECTOR3		ivCursorVoxelPos = { x, y, z };
	::SetVoxelValue(pBitTable, CursorWidthDepthHeight, x, y, z, FALSE);	// 다시 방문하지 않도록 복셀값을 0으로 설정

	if (*pdwInOutVoxelCount >= MAX_RECURSIVE_XYZ_COLLECT_VOXEL_COUNT)
		__debugbreak();

	if ((*pdwInOutVoxelCount) < MAX_RECURSIVE_XYZ_COLLECT_VOXEL_COUNT)
	{
		pivOutVoxelPosList[*pdwInOutVoxelCount] = { x, y, z };
		(*pdwInOutVoxelCount)++;
	}


	CollectVoxelPosListRecursiveXYZ(pBitTable, pColorTable, pv3ObjPos, x + 1, y, z, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount);
	CollectVoxelPosListRecursiveXYZ(pBitTable, pColorTable, pv3ObjPos, x - 1, y, z, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount);
	CollectVoxelPosListRecursiveXYZ(pBitTable, pColorTable, pv3ObjPos, x, y + 1, z, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount);
	CollectVoxelPosListRecursiveXYZ(pBitTable, pColorTable, pv3ObjPos, x, y - 1, z, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount);
	CollectVoxelPosListRecursiveXYZ(pBitTable, pColorTable, pv3ObjPos, x, y, z + 1, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount);
	CollectVoxelPosListRecursiveXYZ(pBitTable, pColorTable, pv3ObjPos, x, y, z - 1, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount);
}
BOOL CTestVoxelEditor::RemoveVoxel(BOOL bRecursivePlane)
{
	BOOL	bResult = FALSE;

	VOXEL_DESC_LITE	voxelDesc = {};
	m_pVHController->GetSelectedVoxelObjDesc(&voxelDesc);

	IVoxelObjectLite*	pVoxelObj = voxelDesc.pVoxelObj;
	if (!pVoxelObj)
		return FALSE;

	// 먼저 보낸 request에 대해 아직 응답을 받지 못했다면 스킵해야한다.

	VECTOR3	v3CursorObjPos = {};
	INT_VECTOR3	ivCursorVoxelPos = {};
	UINT	CursorWidthDepthHeight = 1;
	float	fCursorVoxelSize = 0.0f;
	BYTE	bCurColorIndex = 0xff;

	if (!m_pVHController->GetCursorStatus(&v3CursorObjPos, &ivCursorVoxelPos, &CursorWidthDepthHeight, &fCursorVoxelSize, &bCurColorIndex))
		return FALSE;

	VECTOR3	v3ObjPos = {};
	pVoxelObj->GetPosition(&v3ObjPos);

	if (!m_pVHController->IsValidVoxelObjectPosition(&v3ObjPos))
	{
	#ifdef _DEBUG
		__debugbreak();
	#endif
		return FALSE;
	}

	//BOOL	bObjDeleted = FALSE;
	//pVoxelObj->RemoveVoxel(&bObjDeleted,m_pSelectedVoxelObjDesc->x,m_pSelectedVoxelObjDesc->y,m_pSelectedVoxelObjDesc->z);
	//if (bObjDeleted)
	//{
	//	g_pGame->WriteTextW(COLOR_VALUE_ORANGE,L"Voxel Object Deleted.\n");
	//}
	//m_bExistPickedPoint = TestPicking(&m_v3PickedPoint,&m_fDistPickedPoint,x,y,TRUE);


	VOXEL_OBJ_PROPERTY prop;
	pVoxelObj->GetVoxelObjectProperty(&prop);

	if (bRecursivePlane)
	{
		PLANE_AXIS_TYPE	planeType = m_pVHController->GetCurrentPlaneType();

		DWORD	dwVoxelCount = 0;
		INT_VECTOR3		pivVoxelPosList[MAX_RECURSIVE_PLANE_COLLECT_VOXEL_COUNT] = {};

		BYTE	bCmpColorIndex = voxelDesc.ColorIndex;
		unsigned long	pTempBitTable[MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS / 32] = {};
		BYTE			pTempColorTable[MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS] = {};
		for (DWORD y = 0; y < CursorWidthDepthHeight; y++)
		{
			for (DWORD z = 0; z < CursorWidthDepthHeight; z++)
			{
				for (DWORD x = 0; x < CursorWidthDepthHeight; x++)
				{
					BOOL	bVoxelValue = FALSE;
					if (pVoxelObj->GetVoxel(&bVoxelValue, x, y, z))
					{
						::SetVoxelValue(pTempBitTable, CursorWidthDepthHeight, x, y, z, bVoxelValue);
					}

					BYTE	bColorIndex = 0;
					if (pVoxelObj->GetColorPerVoxel(&bColorIndex, x, y, z))
					{
						::SetVoxelColor(pTempColorTable, CursorWidthDepthHeight, x, y, z, bColorIndex);
					}
				}
			}
		}
		RemoveVoxelRecursive(pTempBitTable, pTempColorTable, &v3ObjPos, ivCursorVoxelPos.x, ivCursorVoxelPos.y, ivCursorVoxelPos.z, bCmpColorIndex, CursorWidthDepthHeight, pivVoxelPosList, &dwVoxelCount, planeType);
		m_pNetworkLayer->Send_RequestRemoveMultipleVoxels(&v3ObjPos, pivVoxelPosList, dwVoxelCount, CursorWidthDepthHeight, planeType);
		ClearPreviewMeshInRecursiveMode();
		bResult = TRUE;
	}
	else
	{
		m_pNetworkLayer->Send_RequestRemoveVoxel(&v3ObjPos, &ivCursorVoxelPos, CursorWidthDepthHeight);
		bResult = TRUE;
	}
	return bResult;
}
void CTestVoxelEditor::RemoveVoxelRecursive(unsigned long* pBitTable, BYTE* pColorTable, const VECTOR3* pv3ObjPos, int x, int y, int z, BYTE bCmpColorIndex, UINT CursorWidthDepthHeight, INT_VECTOR3* pivOutVoxelPosList, DWORD* pdwInOutVoxelCount, PLANE_AXIS_TYPE planeType)
{
	if (x >= (int)CursorWidthDepthHeight)
		return;

	if (y >= (int)CursorWidthDepthHeight)
		return;

	if (z >= (int)CursorWidthDepthHeight)
		return;

	if (x < 0)
		return;

	if (y < 0)
		return;

	if (z < 0)
		return;

	if (FALSE == ::GetVoxelValue(pBitTable, CursorWidthDepthHeight, x, y, z))
		return;

	if (::GetVoxelColor(pColorTable, CursorWidthDepthHeight, x, y, z) != bCmpColorIndex)
	{
		// 지정한 색과 다르면 스킵.
		return;
	}
	INT_VECTOR3		ivCursorVoxelPos = { x, y, z };
	::SetVoxelValue(pBitTable, CursorWidthDepthHeight, x, y, z, FALSE);

	if ((*pdwInOutVoxelCount) < MAX_RECURSIVE_PLANE_COLLECT_VOXEL_COUNT)
	{
		pivOutVoxelPosList[*pdwInOutVoxelCount] = { x, y, z };
		(*pdwInOutVoxelCount)++;
	}
	switch (planeType)
	{
		case PLANE_AXIS_TYPE_XZ:
			{
				RemoveVoxelRecursive(pBitTable, pColorTable, pv3ObjPos, x + 1, y, z, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				RemoveVoxelRecursive(pBitTable, pColorTable, pv3ObjPos, x - 1, y, z, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				RemoveVoxelRecursive(pBitTable, pColorTable, pv3ObjPos, x, y, z + 1, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				RemoveVoxelRecursive(pBitTable, pColorTable, pv3ObjPos, x, y, z - 1, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
			}
			break;
		case PLANE_AXIS_TYPE_XY:
			{
				RemoveVoxelRecursive(pBitTable, pColorTable, pv3ObjPos, x + 1, y, z, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				RemoveVoxelRecursive(pBitTable, pColorTable, pv3ObjPos, x - 1, y, z, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				RemoveVoxelRecursive(pBitTable, pColorTable, pv3ObjPos, x, y + 1, z, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				RemoveVoxelRecursive(pBitTable, pColorTable, pv3ObjPos, x, y - 1, z, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
			}
			break;
		case PLANE_AXIS_TYPE_YZ:
			{
				RemoveVoxelRecursive(pBitTable, pColorTable, pv3ObjPos, x, y + 1, z, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				RemoveVoxelRecursive(pBitTable, pColorTable, pv3ObjPos, x, y - 1, z, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				RemoveVoxelRecursive(pBitTable, pColorTable, pv3ObjPos, x, y, z + 1, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				RemoveVoxelRecursive(pBitTable, pColorTable, pv3ObjPos, x, y, z - 1, bCmpColorIndex, CursorWidthDepthHeight, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
			}
			break;
	}
}

BOOL CTestVoxelEditor::CreateNewVoxelObject(const VECTOR3* pv3Pos, BOOL bSetFirstVoxel, BYTE bFirstVoxelPosX, BYTE bFirstVoxelPosY, BYTE bFirstVoxelPosZ, BYTE bFirstVoxelColor, BOOL bRebuildArea)
{
	// 먼저 보낸 request에 대해 아직 응답을 받지 못했다면 스킵해야한다.
	if (!m_pVHController->IsValidVoxelObjectPosition(pv3Pos))
		return FALSE;

	WORD	wFirstVoxelPos = 0;
	if (bSetFirstVoxel)
	{
		wFirstVoxelPos = 0x8000 | (bFirstVoxelPosZ << 8) | (bFirstVoxelPosY << 4) | (bFirstVoxelPosX);
	}
	float	fVoxelSize = 0.0f;
	UINT WidthDepthHeight = m_pVHController->GetCursorVoxelObjectPropery(&fVoxelSize);

	m_pNetworkLayer->Send_RequestCreateVoxelObject(pv3Pos, WidthDepthHeight, fVoxelSize, wFirstVoxelPos, bFirstVoxelColor, bRebuildArea);
	return TRUE;
}
BOOL CTestVoxelEditor::AddVoxel(BOOL bRebuildArea, BOOL bRecursivePlane)
{
	BOOL	bResult = FALSE;

	VECTOR3	v3CursorObjPos = {};
	INT_VECTOR3	ivCursorVoxelPos = {};
	UINT	CursorWidthDepthHeight = 1;
	float	fCursorVoxelSize = 0.0f;
	BYTE	bCurColorIndex = 0xff;

	if (!m_pVHController->GetCursorStatus(&v3CursorObjPos, &ivCursorVoxelPos, &CursorWidthDepthHeight, &fCursorVoxelSize, &bCurColorIndex))
		return FALSE;

	// 커서 오브젝트의 위치에 이미 복셀 오브젝트가 존재하는 경우
	BOUNDING_SPHERE bs = { v3CursorObjPos, 1.0f };
	IVoxelObjectLite*	pVoxelObj = nullptr;
	BOOL			bInsufficient = FALSE;
	m_pVHController->FindVoxelObjectListWithSphere(&pVoxelObj, 1, &bs, &bInsufficient);

	if (!pVoxelObj)
	{
		if (!m_pVHController->IsValidVoxelObjectPosition(&v3CursorObjPos))
			return FALSE;

		bResult = CreateNewVoxelObject(&v3CursorObjPos, TRUE, (BYTE)ivCursorVoxelPos.x, (BYTE)ivCursorVoxelPos.y, (BYTE)ivCursorVoxelPos.z, bCurColorIndex, bRebuildArea);
		return bResult;
	}
	else
	{
		VOXEL_OBJ_PROPERTY prop;
		pVoxelObj->GetVoxelObjectProperty(&prop);

		VECTOR3	v3ObjPos = {};
		pVoxelObj->GetPosition(&v3ObjPos);

		if (!m_pVHController->IsValidVoxelObjectPosition(&v3ObjPos))
			return FALSE;

		if (bRecursivePlane)
		{
			PLANE_AXIS_TYPE	planeType = m_pVHController->GetCurrentPlaneType();

			DWORD	dwVoxelCount = 0;
			INT_VECTOR3		pivVoxelPosList[MAX_RECURSIVE_PLANE_COLLECT_VOXEL_COUNT] = {};
			unsigned long	pTempBitTable[MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS / 32] = {};
			for (DWORD y = 0; y < CursorWidthDepthHeight; y++)
			{
				for (DWORD z = 0; z < CursorWidthDepthHeight; z++)
				{
					for (DWORD x = 0; x < CursorWidthDepthHeight; x++)
					{
						BOOL	bVoxelValue = FALSE;
						if (pVoxelObj->GetVoxel(&bVoxelValue, x, y, z))
						{
							::SetVoxelValue(pTempBitTable, CursorWidthDepthHeight, x, y, z, bVoxelValue);
						}
					}
				}
			}
			AddVoxelRecursive(pTempBitTable, &v3ObjPos, ivCursorVoxelPos.x, ivCursorVoxelPos.y, ivCursorVoxelPos.z, bCurColorIndex, CursorWidthDepthHeight, bRebuildArea, pivVoxelPosList, &dwVoxelCount, planeType);
			m_pNetworkLayer->Send_RequestAddMultipleVoxels(&v3ObjPos, pivVoxelPosList, dwVoxelCount, CursorWidthDepthHeight, bCurColorIndex, planeType, bRebuildArea);
			ClearPreviewMeshInRecursiveMode();
			bResult = TRUE;
		}
		else
		{
			m_pNetworkLayer->Send_RequestAddVoxel(&v3ObjPos, &ivCursorVoxelPos, CursorWidthDepthHeight, bCurColorIndex, bRebuildArea);
			bResult = TRUE;
		}
	}
	return bResult;
}
void CTestVoxelEditor::AddVoxelRecursive(unsigned long* pBitTable, const VECTOR3* pv3ObjPos, int x, int y, int z, BYTE bColorIndex, UINT CursorWidthDepthHeight, BOOL bRebuildArea, INT_VECTOR3* pivOutVoxelPosList, DWORD* pdwInOutVoxelCount, PLANE_AXIS_TYPE planeType)
{
	if (x >= (int)CursorWidthDepthHeight)
		return;

	if (y >= (int)CursorWidthDepthHeight)
		return;

	if (z >= (int)CursorWidthDepthHeight)
		return;

	if (x < 0)
		return;

	if (y < 0)
		return;

	if (z < 0)
		return;

	if (::GetVoxelValue(pBitTable, CursorWidthDepthHeight, x, y, z))
		return;

	INT_VECTOR3		ivCursorVoxelPos = { x, y, z };
	::SetVoxelValue(pBitTable, CursorWidthDepthHeight, x, y, z, TRUE);

	if ((*pdwInOutVoxelCount) < MAX_RECURSIVE_PLANE_COLLECT_VOXEL_COUNT)
	{
		pivOutVoxelPosList[*pdwInOutVoxelCount] = { x, y, z };
		(*pdwInOutVoxelCount)++;
	}

	switch (planeType)
	{
		case PLANE_AXIS_TYPE_XZ:
			{
				AddVoxelRecursive(pBitTable, pv3ObjPos, x + 1, y, z, bColorIndex, CursorWidthDepthHeight, bRebuildArea, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				AddVoxelRecursive(pBitTable, pv3ObjPos, x - 1, y, z, bColorIndex, CursorWidthDepthHeight, bRebuildArea, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				AddVoxelRecursive(pBitTable, pv3ObjPos, x, y, z + 1, bColorIndex, CursorWidthDepthHeight, bRebuildArea, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				AddVoxelRecursive(pBitTable, pv3ObjPos, x, y, z - 1, bColorIndex, CursorWidthDepthHeight, bRebuildArea, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
			}
			break;
		case PLANE_AXIS_TYPE_XY:
			{
				AddVoxelRecursive(pBitTable, pv3ObjPos, x + 1, y, z, bColorIndex, CursorWidthDepthHeight, bRebuildArea, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				AddVoxelRecursive(pBitTable, pv3ObjPos, x - 1, y, z, bColorIndex, CursorWidthDepthHeight, bRebuildArea, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				AddVoxelRecursive(pBitTable, pv3ObjPos, x, y + 1, z, bColorIndex, CursorWidthDepthHeight, bRebuildArea, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				AddVoxelRecursive(pBitTable, pv3ObjPos, x, y - 1, z, bColorIndex, CursorWidthDepthHeight, bRebuildArea, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
			}
			break;
		case PLANE_AXIS_TYPE_YZ:
			{
				AddVoxelRecursive(pBitTable, pv3ObjPos, x, y + 1, z, bColorIndex, CursorWidthDepthHeight, bRebuildArea, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				AddVoxelRecursive(pBitTable, pv3ObjPos, x, y - 1, z, bColorIndex, CursorWidthDepthHeight, bRebuildArea, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				AddVoxelRecursive(pBitTable, pv3ObjPos, x, y, z + 1, bColorIndex, CursorWidthDepthHeight, bRebuildArea, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
				AddVoxelRecursive(pBitTable, pv3ObjPos, x, y, z - 1, bColorIndex, CursorWidthDepthHeight, bRebuildArea, pivOutVoxelPosList, pdwInOutVoxelCount, planeType);
			}
			break;
	}
}
BOOL CTestVoxelEditor::SetVoxelColor(BOOL bRecursivePlane)
{
	BOOL	bResult = FALSE;

	VOXEL_DESC_LITE	voxelDesc = {};
	m_pVHController->GetSelectedVoxelObjDesc(&voxelDesc);

	IVoxelObjectLite*	pVoxelObj = voxelDesc.pVoxelObj;
	if (!pVoxelObj)
		return FALSE;

	VECTOR3	v3CursorObjPos = {};
	INT_VECTOR3	ivCursorVoxelPos = {};
	UINT	CursorWidthDepthHeight = 1;
	float	fCursorVoxelSize = 0.0f;
	BYTE	bCurColorIndex = 0xff;

	if (!m_pVHController->GetCursorStatus(&v3CursorObjPos, &ivCursorVoxelPos, &CursorWidthDepthHeight, &fCursorVoxelSize, &bCurColorIndex))
		return FALSE;

	VECTOR3	v3ObjPos = {};
	pVoxelObj->GetPosition(&v3ObjPos);

	if (!m_pVHController->IsValidVoxelObjectPosition(&v3ObjPos))
		return FALSE;

	VOXEL_OBJ_PROPERTY prop;
	pVoxelObj->GetVoxelObjectProperty(&prop);

	if (bRecursivePlane)
	{
		PLANE_AXIS_TYPE	planeType = m_pVHController->GetCurrentPlaneType();

		DWORD	dwVoxelCount = 0;
		INT_VECTOR3		pivVoxelPosList[MAX_RECURSIVE_PLANE_COLLECT_VOXEL_COUNT] = {};

		BYTE	bCmpColorIndex = voxelDesc.ColorIndex;
		unsigned long	pTempBitTable[MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS / 32] = {};
		BYTE			pTempColorTable[MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS] = {};

		for (DWORD y = 0; y < CursorWidthDepthHeight; y++)
		{
			for (DWORD z = 0; z < CursorWidthDepthHeight; z++)
			{
				for (DWORD x = 0; x < CursorWidthDepthHeight; x++)
				{
					BOOL	bVoxelValue = FALSE;
					if (pVoxelObj->GetVoxel(&bVoxelValue, x, y, z))
					{
						::SetVoxelValue(pTempBitTable, CursorWidthDepthHeight, x, y, z, bVoxelValue);
					}

					BYTE	bColorIndex = 0;
					if (pVoxelObj->GetColorPerVoxel(&bColorIndex, x, y, z))
					{
						::SetVoxelColor(pTempColorTable, CursorWidthDepthHeight, x, y, z, bColorIndex);
					}
				}
			}
		}
		SetVoxelColorRecursive(pTempBitTable, pTempColorTable, &v3ObjPos, ivCursorVoxelPos.x, ivCursorVoxelPos.y, ivCursorVoxelPos.z, bCurColorIndex, bCmpColorIndex, CursorWidthDepthHeight, pivVoxelPosList, &dwVoxelCount, planeType);
		m_pNetworkLayer->Send_RequestSetMultipleVoxelsColor(&v3ObjPos, pivVoxelPosList, dwVoxelCount, bCurColorIndex, CursorWidthDepthHeight, planeType);
		ClearPreviewMeshInRecursiveMode();
		bResult = TRUE;
	}
	else
	{
		m_pNetworkLayer->Send_RequestSetVoxelColor(&v3ObjPos, &ivCursorVoxelPos, bCurColorIndex, CursorWidthDepthHeight);
		bResult = TRUE;
	}
	return bResult;
}
DWORD CTestVoxelEditor::AddOrRemoveSelecteVoxelObjPosList(IVoxelObjectLite* pVoxelObj)
{
	INT_VECTOR3		ivObjPos = {};
	pVoxelObj->GetPositionInGridSpace(&ivObjPos);

	for (DWORD i = 0; i < m_dwSelectedObjPosNum; i++)
	{
		if (ivObjPos == m_pivSelectedObjPosList[i])
		{
			m_pivSelectedObjPosList[i] = m_pivSelectedObjPosList[m_dwSelectedObjPosNum - 1];
			m_dwSelectedObjPosNum--;
			goto lb_return;
		}
	}

	if (m_dwSelectedObjPosNum < m_dwMaxSelectedObjPosNum)
	{
		m_pivSelectedObjPosList[m_dwSelectedObjPosNum] = ivObjPos;
		m_dwSelectedObjPosNum++;
	}
lb_return:
	UpdateSelectedVoxelObjListMesh();
	return m_dwSelectedObjPosNum;
}
DWORD CTestVoxelEditor::AddSelecteVoxelObjPosList(IVoxelObjectLite* pVoxelObj)
{
	INT_VECTOR3		ivObjPos = {};
	pVoxelObj->GetPositionInGridSpace(&ivObjPos);

	for (DWORD i = 0; i < m_dwSelectedObjPosNum; i++)
	{
		if (ivObjPos == m_pivSelectedObjPosList[i])
		{
			goto lb_return;
		}
	}

	if (m_dwSelectedObjPosNum < m_dwMaxSelectedObjPosNum)
	{
		m_pivSelectedObjPosList[m_dwSelectedObjPosNum] = ivObjPos;
		m_dwSelectedObjPosNum++;
	}
lb_return:
	UpdateSelectedVoxelObjListMesh();
	return m_dwSelectedObjPosNum;
}
DWORD CTestVoxelEditor::RemoveSelecteVoxelObjPosList(IVoxelObjectLite* pVoxelObj)
{
	INT_VECTOR3		ivObjPos = {};
	pVoxelObj->GetPositionInGridSpace(&ivObjPos);

	for (DWORD i = 0; i < m_dwSelectedObjPosNum; i++)
	{
		if (ivObjPos == m_pivSelectedObjPosList[i])
		{
			m_pivSelectedObjPosList[i] = m_pivSelectedObjPosList[m_dwSelectedObjPosNum - 1];
			m_dwSelectedObjPosNum--;
			goto lb_return;
		}
	}
lb_return:
	UpdateSelectedVoxelObjListMesh();
	return m_dwSelectedObjPosNum;
}
BOOL CTestVoxelEditor::RemoveSelecteVoxelObjPos(const INT_VECTOR3* pivObjPos)
{
	BOOL	bResult = FALSE;
	for (DWORD i = 0; i < m_dwSelectedObjPosNum; i++)
	{
		if (*pivObjPos == m_pivSelectedObjPosList[i])
		{
			m_pivSelectedObjPosList[i] = m_pivSelectedObjPosList[m_dwSelectedObjPosNum - 1];
			m_dwSelectedObjPosNum--;
			bResult = TRUE;
			goto lb_return;
		}
	}
lb_return:
	return bResult;
}
void CTestVoxelEditor::ClearSelectedVoxelObjPosList()
{
	m_dwSelectedObjPosNum = 0;
	UpdateSelectedVoxelObjListMesh();
}
void CTestVoxelEditor::UpdateSelectedVoxelObjListMesh()
{
	/*
	m_dwSelectedObjPosListTriNum = 0;
	AABB	aabbSelectedObjList =
	{
		999999.0f, 999999.0f, 999999.0f,
		 -999999.0f, -999999.0f, -999999.0f
	};

	if (!m_dwSelectedObjPosNum)
		return;

	D3DVLVERTEX*	pVertexEntry = m_pSelectedObjPosListTriList;
	for (DWORD i = 0; i < m_dwSelectedObjPosNum; i++)
	{
		INT_VECTOR3		ivPos = m_pivSelectedObjPosList[i];
		IVoxelObjectLite* pVoxelObj = m_pVHController->GetVoxelObjectWithGridCoord(&ivPos);
		if (!pVoxelObj)
			continue;

		AABB	objAABB = {};
		pVoxelObj->GetAABB(&objAABB);

		objAABB.Min = objAABB.Min - MAKE_VECTOR3(20.0f, 20.0f, 20.0f);
		objAABB.Max = objAABB.Max + MAKE_VECTOR3(20.0f, 20.0f, 20.0f);

		BOUNDING_BOX	box;
		CreateBoxWithAABB(&box, &objAABB.Min, &objAABB.Max);

		TRIANGLE pTriListPerBox[12];
		CreateVertexListWithBox((char*)pTriListPerBox, sizeof(VECTOR3), box.v3Oct);

		if (m_dwSelectedObjPosListTriNum + TRI_NUM_PER_BOX > m_dwMaxSelectedObjPosListTriNum)
		{
			break;
		}
		WriteTriVector3ToD3DVLVERTEX_Normal(pVertexEntry, pTriListPerBox, TRI_NUM_PER_BOX);
		pVertexEntry += (TRI_NUM_PER_BOX * 3);
		m_dwSelectedObjPosListTriNum += TRI_NUM_PER_BOX;

		AddAABB(&aabbSelectedObjList, &objAABB);
	}
	// 선택된 모든 오브젝트들을 감싸는 박스

	aabbSelectedObjList.Min = aabbSelectedObjList.Min - MAKE_VECTOR3(25.0f, 25.0f, 25.0f);
	aabbSelectedObjList.Max = aabbSelectedObjList.Max + MAKE_VECTOR3(25.0f, 25.0f, 25.0f);

	BOUNDING_BOX	box;
	CreateBoxWithAABB(&box, &aabbSelectedObjList.Min, &aabbSelectedObjList.Max);

	TRIANGLE pTriListPerBox[12];
	CreateVertexListWithBox((char*)pTriListPerBox, sizeof(VECTOR3), box.v3Oct);
	WriteTriVector3ToD3DVLVERTEX_Normal(m_pSelectedObjPosListAABBTriList, pTriListPerBox, TRI_NUM_PER_BOX);
	*/
}
void CTestVoxelEditor::ClearPreviewMeshInRecursiveMode()
{
	m_dwPreviewVoxelPosNum = 0;
}
void CTestVoxelEditor::Process()
{
	
}
BOOL CTestVoxelEditor::AddVoxelsAsCube(const VECTOR3* pv3VoxelPos, UINT WidthDepthHeight, BYTE bColorIndex, int width, int height, int depth)
{
	BOOL	bResult = FALSE;

	float fVoxelSize = VOXEL_OBJECT_SIZE / (float)WidthDepthHeight;
	
	DWORD dwCouunt = 0;

	// pv3VoxelPos의 -x, +x축으로 width/2개씩 추가 , -z, +z축으로 depth/2개씩 추갸
	// pv3VoxelPos의 +y축으로 height개씩 추가
	VECTOR3 v3NegOffset =
	{
		(float)(width / 2) * fVoxelSize,
		0.0f,
		(float)(depth / 2) * fVoxelSize
	};
	for (int y = 0; y < height; y++)
	{
		for (int z = 0; z < depth; z++)
		{
			for (int x = 0; x < width; x++)
			{
				//bColorIndex = (BYTE)(dwCouunt % 32);	//랜덤 컬러
				VECTOR3 v3VoxelPos = *pv3VoxelPos - v3NegOffset + MAKE_VECTOR3(x * fVoxelSize, y * fVoxelSize, z * fVoxelSize);
				SINGLE_VOXEL_EDIT_RESULT result = m_pVHController->SetSingleVoxelWithFloatCoord(&v3VoxelPos, WidthDepthHeight, bColorIndex);
				if (SINGLE_VOXEL_EDIT_RESULT_OK != result)
				{
					switch (result)
					{
						case SINGLE_VOXEL_EDIT_RESULT_INVALID_POSITION:
							WriteDebugStringW(DEBUG_OUTPUT_TYPE_DEBUG_CONSOLE, L"Failed - SetSingleVoxelWithFloatCoord() - SINGLE_VOXEL_EDIT_RESULT_INVALID_POSITION\n");
							break;
						case SINGLE_VOXEL_EDIT_RESULT_BUFFER_NOT_ENOUGH:
							WriteDebugStringW(DEBUG_OUTPUT_TYPE_DEBUG_CONSOLE, L"Failed - SetSingleVoxelWithFloatCoord() - SINGLE_VOXEL_EDIT_RESULT_BUFFER_NOT_ENOUGH\n");
							break;
						case SINGLE_VOXEL_EDIT_RESULT_UNKNWON_ERROR:
							WriteDebugStringW(DEBUG_OUTPUT_TYPE_DEBUG_CONSOLE, L"Failed - SetSingleVoxelWithFloatCoord() - SINGLE_VOXEL_EDIT_RESULT_UNKNWON_ERROR\n");
							break;
					}
				}
				WriteDebugStringW(DEBUG_OUTPUT_TYPE_DEBUG_CONSOLE, L"(x:%.1f, y:%.1f, z:%.1f), Color:%u, WidthDepthHeight:%u\n", v3VoxelPos.x, v3VoxelPos.y, v3VoxelPos.z, bColorIndex, WidthDepthHeight);
				dwCouunt++;
			}
		}
	}
	return TRUE;
}
BOOL CTestVoxelEditor::RemoveVoxel(const VECTOR3* pv3VoxelPos, UINT WidthDepthHeight)
{
	BOOL	bResult = FALSE;

	float fVoxelSize = VOXEL_OBJECT_SIZE / (float)WidthDepthHeight;
	m_pVHController->RemoveSingleVoxelWithFloatCoord(pv3VoxelPos, WidthDepthHeight);
	return TRUE;
}
BOOL CTestVoxelEditor::RemoveVoxelsAsCube(const VECTOR3* pv3VoxelPos, UINT WidthDepthHeight, int width, int height, int depth)
{
	BOOL	bResult = FALSE;

	float fVoxelSize = VOXEL_OBJECT_SIZE / (float)WidthDepthHeight;
	
	// pv3VoxelPos의 -x, +x축으로 width/2개씩 제거 , -z, +z축으로 depth/2개씩 제거
	// pv3VoxelPos의 +y축으로 height개씩 제거
	VECTOR3 v3NegOffset =
	{
		(float)(width / 2) * fVoxelSize,
		0.0f,
		(float)(depth / 2) * fVoxelSize
	};

	for (int y = 0; y < height; y++)
	{
		for (int z = 0; z < depth; z++)
		{
			for (int x = 0; x < width; x++)
			{
				VECTOR3 v3VoxelPos = *pv3VoxelPos - v3NegOffset + MAKE_VECTOR3(x * fVoxelSize, y * fVoxelSize, z * fVoxelSize);
				m_pVHController->RemoveSingleVoxelWithFloatCoord(&v3VoxelPos, WidthDepthHeight);
			}
		}
	}
	return TRUE;
}

BOOL CTestVoxelEditor::GetVoxel(const VECTOR3* pv3VoxelPos, UINT WidthDepthHeight)
{
	BOOL bResult = FALSE;

	float fVoxelSize = VOXEL_OBJECT_SIZE / (float)WidthDepthHeight;
		
	BYTE bColorIndex = 0xff;
	if (SINGLE_VOXEL_EDIT_RESULT_OK == m_pVHController->GetSingleVoxelColorWithFloatCoord(&bColorIndex, pv3VoxelPos, WidthDepthHeight))
	{
		m_pVHController->WriteTextToSystemDlgW(COLOR_VALUE_CYAN, L"[%02u]\n", (DWORD)bColorIndex);
	}
	else
	{
		m_pVHController->WriteTextToSystemDlgW(COLOR_VALUE_RED, L"[%02u]\n", 99);
	}

	return TRUE;
}
BOOL CTestVoxelEditor::GetVoxelsAsCube(const VECTOR3* pv3VoxelPos, UINT WidthDepthHeight, int width, int height, int depth)
{
	BOOL bResult = FALSE;

	float fVoxelSize = VOXEL_OBJECT_SIZE / (float)WidthDepthHeight;
	
	// pv3VoxelPos 기준으로 x축으로 width, y축으로 height, z축으로 depth개만큼 스캔
	for (int y = 0; y < height; y++)
	{
		for (int z = 0; z < depth; z++)
		{
			for (int x = 0; x < width; x++)
			{
				if (y == 1 && x == 3 && z == 0)
					int a = 0;

				VECTOR3 v3VoxelPos = *pv3VoxelPos + MAKE_VECTOR3(x * fVoxelSize, y * fVoxelSize, z * fVoxelSize);
				BYTE bColorIndex = 0xff;
				if (SINGLE_VOXEL_EDIT_RESULT_OK == m_pVHController->GetSingleVoxelColorWithFloatCoord(&bColorIndex, &v3VoxelPos, WidthDepthHeight))
				{
					m_pVHController->WriteTextToSystemDlgW(COLOR_VALUE_CYAN, L"[%02u]", (DWORD)bColorIndex);
				}
				else
				{
					m_pVHController->WriteTextToSystemDlgW(COLOR_VALUE_RED, L"[%02u]", 99);
				}
			}
			m_pVHController->WriteTextToSystemDlgW(COLOR_VALUE_CYAN, L"\n");
		}
		m_pVHController->WriteTextToSystemDlgW(COLOR_VALUE_CYAN, L"\n");
	}
	
	return TRUE;
}
BOOL CTestVoxelEditor::OnMouseLButtonDown(int x, int y, UINT nFlags)
{
	BOOL	bProcessed = FALSE;

	//const UINT TEST_WIDTH_DETPTH_HEIGHT = 8;
	const DWORD MAX_TEST_WIDTH = 8;
	const DWORD MAX_TEST_HEIGHT = 8;
	const DWORD MAX_TEST_DEPTH = 8;

	VECTOR3 v3PickedPos = {};
	VECTOR3 v3PickedAxis = {};
	float fDist = 0.0f;
	if (m_pVHController->GetPicekdPosition(&v3PickedPos, &v3PickedAxis, &fDist))
	{
		VECTOR3	v3CursorObjPos = {};
		INT_VECTOR3	ivCursorVoxelPos = {};
		UINT	CursorWidthDepthHeight = 1;
		float	fCursorVoxelSize = 0.0f;
		BYTE	bCurColorIndex = 0xff;

		VECTOR3	v3TargetPos = v3PickedPos;

		if (m_pVHController->GetCursorStatus(&v3CursorObjPos, &ivCursorVoxelPos, &CursorWidthDepthHeight, &fCursorVoxelSize, &bCurColorIndex))
		{
			VECTOR3 v3ObjBasePos = v3CursorObjPos - MAKE_VECTOR3(VOXEL_OBJECT_SIZE_HALF, VOXEL_OBJECT_SIZE_HALF, VOXEL_OBJECT_SIZE_HALF);
			VECTOR3 v3VoxelPosOffset =
			{
				(float)ivCursorVoxelPos.x * fCursorVoxelSize + (fCursorVoxelSize * 0.5f),
				(float)ivCursorVoxelPos.y * fCursorVoxelSize + (fCursorVoxelSize * 0.5f),
				(float)ivCursorVoxelPos.z * fCursorVoxelSize + (fCursorVoxelSize * 0.5f)
			};
			VECTOR3 v3CursorPos = v3ObjBasePos + v3VoxelPosOffset;
			v3TargetPos = v3CursorPos;
		}
		else
		{
			CursorWidthDepthHeight = m_pVHController->GetLatestursorWidthDepthHeightLatest(&fCursorVoxelSize);
			bCurColorIndex = m_pVHController->GetSelectedColorIndex();
		}
		DWORD TestWidth = min(MAX_TEST_WIDTH, CursorWidthDepthHeight);
		DWORD TestHeight = min(MAX_TEST_HEIGHT, CursorWidthDepthHeight);
		DWORD TestDepth = min(MAX_TEST_DEPTH, CursorWidthDepthHeight);

		//DWORD TestWidth = 64;
		//DWORD TestHeight = 5;
		//DWORD TestDepth = 64;

		VH_EDIT_MODE editMode = m_pVHController->GetCurrentEditMode();
		if (MK_CONTROL & nFlags)
		{
			switch (editMode)
			{
				case VH_EDIT_MODE_SET_VOXEL_COLOR:
				case VH_EDIT_MODE_ADD_VOXEL:
				case VH_EDIT_MODE_REMOVE_VOXEL:
					//bProcessed = GetVoxel(&v3TargetPos, CursorWidthDepthHeight);
					bProcessed = GetVoxelsAsCube(&v3TargetPos, CursorWidthDepthHeight, TestWidth, TestHeight, TestDepth);
					break;
			}
		}
		else
		{
			switch (editMode)
			{
				case VH_EDIT_MODE_SET_VOXEL_COLOR:
				case VH_EDIT_MODE_ADD_VOXEL:
					bProcessed = AddVoxelsAsCube(&v3TargetPos, CursorWidthDepthHeight, bCurColorIndex, TestWidth, TestHeight, TestDepth);
					break;
				case VH_EDIT_MODE_REMOVE_VOXEL:
					//bProcessed = RemoveVoxel(&v3TargetPos, CursorWidthDepthHeight);
					bProcessed = RemoveVoxelsAsCube(&v3TargetPos, CursorWidthDepthHeight, TestWidth, TestHeight, TestDepth);
					break;
			}
		}
	}
	/*
	VECTOR3	v3CursorObjPos = {};
	INT_VECTOR3	ivCursorVoxelPos = {};
	UINT	CursorWidthDepthHeight = 1;
	float	fCursorVoxelSize = 0.0f;
	BYTE	bCurColorIndex = 0xff;

	if (!m_pVHController->GetCursorStatus(&v3CursorObjPos, &ivCursorVoxelPos, &CursorWidthDepthHeight, &fCursorVoxelSize, &bCurColorIndex))
		return FALSE;

	VH_EDIT_MODE editMode = m_pVHController->GetCurrentEditMode();

	BOOL	bRebuildArea = FALSE;
	BOOL	bRecursivePlane = FALSE;
	BOOL	bSelectAdd = FALSE;

	if (MK_CONTROL & nFlags)
	{
		bRebuildArea = TRUE;
		bSelectAdd = TRUE;
	}
	if (MK_SHIFT & nFlags)
	{
		bRecursivePlane = TRUE;

	}
	VOXEL_DESC_LITE	voxelDesc = {};
	m_pVHController->GetSelectedVoxelObjDesc(&voxelDesc);
	switch (editMode)
	{
		case VH_EDIT_MODE_SELECT:
			//OptimizeVoxelObject();
			if (bSelectAdd)
			{
				IVoxelObjectLite*	pVoxelObj = voxelDesc.pVoxelObj;
				if (pVoxelObj)
				{
					AddOrRemoveSelecteVoxelObjPosList(pVoxelObj);
					m_pVHController->WriteTextToSystemDlgW(COLOR_VALUE_CYAN, L"[Plug-in] VH_EDIT_MODE_SELECT-AddOrRemoveSelecteVoxelObjPosList() Processed.\n");
					bProcessed = TRUE;
				}
			}
			else
			{
				ClearSelectedVoxelObjPosList();
				m_pVHController->WriteTextToSystemDlgW(COLOR_VALUE_CYAN, L"[Plug-in] VH_EDIT_MODE_SELECT-ClearSelectedVoxelObjPosList() Processed.\n");
				bProcessed = TRUE;
			}
			break;
		case VH_EDIT_MODE_SET_VOXEL_COLOR:
			bProcessed = SetVoxelColor(bRecursivePlane);
			if (bProcessed)
			{
				m_pVHController->WriteTextToSystemDlgW(COLOR_VALUE_CYAN, L"[Plug-in] VH_EDIT_MODE_SET_VOXEL_COLOR-SetVoxelColor() Processed.\n");
			}
			break;
		case VH_EDIT_MODE_ADD_VOXEL:
			bProcessed = AddVoxel(bRebuildArea, bRecursivePlane);
			if (bProcessed)
			{
				m_pVHController->WriteTextToSystemDlgW(COLOR_VALUE_CYAN, L"[Plug-in] VH_EDIT_MODE_ADD_VOXEL-AddVoxel() Processed.\n");
			}
			break;
		case VH_EDIT_MODE_REMOVE_VOXEL:
			bProcessed = RemoveVoxel(bRecursivePlane);
			if (bProcessed)
			{
				m_pVHController->WriteTextToSystemDlgW(COLOR_VALUE_CYAN, L"[Plug-in] VH_EDIT_MODE_REMOVE_VOXEL-RemoveVoxel() Processed.\n");
			}
			break;
	}
	*/
	return bProcessed;
}
BOOL CTestVoxelEditor::OnMouseLButtonUp(int x, int y, UINT nFlags)
{
	return FALSE;
}

BOOL CTestVoxelEditor::OnMouseRButtonDown(int x, int y, UINT nFlags)
{
	return FALSE;
}
BOOL CTestVoxelEditor::OnMouseRButtonUp(int x, int y, UINT nFlags)
{
	return FALSE;
}
BOOL CTestVoxelEditor::OnMouseMove(int x, int y, UINT nFlags)
{
	return FALSE;
}

BOOL CTestVoxelEditor::OnMouseMoveHV(int iMoveX, int iMoveY, BOOL bLButtonPressed, BOOL bRButtonPressed, BOOL bMButtonPressed)
{
	return FALSE;
}
BOOL CTestVoxelEditor::OnMouseWheel(int iWheel)
{
	return FALSE;
}

void CTestVoxelEditor::OnDeleteVoxelObject(IVoxelObjectLite* pVoxelObj)
{

}
void CTestVoxelEditor::Cleanup()
{
	if (m_pivSelectedObjPosList)
	{
		delete[] m_pivSelectedObjPosList;
		m_pivSelectedObjPosList = nullptr;
	}
	m_dwSelectedObjPosNum = 0;
}
CTestVoxelEditor::~CTestVoxelEditor()
{
	Cleanup();
}