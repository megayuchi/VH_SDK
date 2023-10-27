#pragma once

#include "../include/typedef.h"
#include "game_typedef.h"

interface IVHController;
interface IVoxelObjectLiteManager;
interface IVHNetworkLayer;

class CVoxelEditor
{
	// voxel editor
	static const DWORD MAX_RECURSIVE_PLANE_COLLECT_VOXEL_COUNT = 64;
	static const DWORD MAX_RECURSIVE_XYZ_COLLECT_VOXEL_COUNT = 512;
	static const DWORD	MAX_SELECTED_VOXEL_OBJ_POS_NUM = 256;

	IVHController* m_pVHController = nullptr;
	IVHNetworkLayer*	m_pNetworkLayer = nullptr;

	INT_VECTOR3*	m_pivSelectedObjPosList = nullptr;	// select모드에서 선택한 복셀 오브젝트의 좌표 목록
	DWORD			m_dwSelectedObjPosNum = 0;
	DWORD			m_dwMaxSelectedObjPosNum = MAX_SELECTED_VOXEL_OBJ_POS_NUM;
	float			m_fPreviewVoxelWidthDepthHeight = 0.0f;
	DWORD			m_dwPreviewVoxelPosNum = 0;
	VECTOR3			m_pv3PreviewVoxelPosList[MAX_RECURSIVE_PLANE_COLLECT_VOXEL_COUNT] = {};
	
	DWORD	AddOrRemoveSelecteVoxelObjPosList(IVoxelObjectLite* pVoxelObj);
	DWORD	AddSelecteVoxelObjPosList(IVoxelObjectLite* pVoxelObj);
	DWORD	RemoveSelecteVoxelObjPosList(IVoxelObjectLite* pVoxelObj);
	BOOL	RemoveSelecteVoxelObjPos(const INT_VECTOR3* pivObjPos);
	void	ClearSelectedVoxelObjPosList();
	void	UpdateSelectedVoxelObjListMesh();

	BOOL	CreateNewVoxelObject(const VECTOR3* pv3Pos, BOOL bSetFirstVoxel, BYTE bFirstVoxelPosX, BYTE bFirstVoxelPosY, BYTE bFirstVoxelPosZ, BYTE bFirstVoxelColor, BOOL bRebuildArea);
	BOOL	AddVoxel(BOOL bRebuildArea, BOOL bRecursivePlane);
	void	AddVoxelRecursive(unsigned long* pBitTable, const VECTOR3* pv3ObjPos, int x, int y, int z, BYTE bColorIndex, UINT CursorWidthDepthHeight, BOOL bRebuildArea, INT_VECTOR3* pivOutVoxelPosList, DWORD* pdwInOutVoxelCount, PLANE_AXIS_TYPE planeType);
	BOOL	SetVoxelColor(BOOL bRecursivePlane);
	void	SetVoxelColorRecursive(unsigned long* pBitTable, BYTE* pColorTable, const VECTOR3* pv3ObjPos, int x, int y, int z, BYTE bColorIndex, BYTE bCmpColorIndex, UINT CursorWidthDepthHeight, INT_VECTOR3* pivOutVoxelPosList, DWORD* pdwInOutVoxelCount, PLANE_AXIS_TYPE planeType);
	void	CollectVoxelPosListRecursiveXYZ(unsigned long* pBitTable, const BYTE* pColorTable, const VECTOR3* pv3ObjPos, int x, int y, int z, BYTE bCmpColorIndex, UINT CursorWidthDepthHeight, INT_VECTOR3* pivOutVoxelPosList, DWORD* pdwInOutVoxelCount);
	BOOL	RemoveVoxel(BOOL bRecursivePlane);
	void	RemoveVoxelRecursive(unsigned long* pBitTable, BYTE* pColorTable, const VECTOR3* pv3ObjPos, int x, int y, int z, BYTE bCmpColorIndex, UINT CursorWidthDepthHeight, INT_VECTOR3* pivOutVoxelPosList, DWORD* pdwInOutVoxelCount, PLANE_AXIS_TYPE planeType);
	void	ClearPreviewMeshInRecursiveMode();
	
	void	Cleanup();
public:
	BOOL	Initialize(IVHController* pVHController, IVHNetworkLayer* pVHNetworkLayer);
	BOOL	OnPreConsoleCommand(const WCHAR* wchCmd, DWORD dwCmdLen);
	BOOL 	OnMouseLButtonDown(int x, int y, UINT nFlags);
	BOOL 	OnMouseLButtonUp(int x, int y, UINT nFlags);
	BOOL 	OnMouseRButtonDown(int x, int y, UINT nFlags);
	BOOL 	OnMouseRButtonUp(int x, int y, UINT nFlags);
	BOOL 	OnMouseMove(int x, int y, UINT nFlags);
	BOOL 	OnMouseMoveHV(int iMoveX, int iMoveY, BOOL bLButtonPressed, BOOL bRButtonPressed, BOOL bMButtonPressed);
	BOOL 	OnMouseWheel(int iWheel);

	void	OnDeleteVoxelObject(IVoxelObjectLite* pVoxelObj);
	CVoxelEditor();
	~CVoxelEditor();

};

