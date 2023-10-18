#pragma once

#ifdef VH_PLUGIN
#include <initguid.h>
#include <ole2.h>
#include "typedef.h"
class CStack;
#endif

interface IVoxelObjectLite
{
	virtual		void	__stdcall	GetVoxelObjectPtr(void** ppOutVoxelObj) const = 0;		// Get IVoxelObject from IVoxelObjectLite
	virtual		void	__stdcall	GetVoxelObjectBodyPtr(void** ppOutVoxelObj) const = 0;	// Get CVoxelObject from IVoxelObjectLite
	virtual		void	__stdcall	GetVoxelObjectProperty(VOXEL_OBJ_PROPERTY* pOutProperty) const = 0;
	virtual		BOOL	__stdcall	GetColorTable(BYTE* pOutColorTable, DWORD dwMaxBufferSize, UINT WidthDepthHeight) const = 0;
	virtual 	BOOL	__stdcall	SetColorTable(const BYTE* pColorTable, UINT WidthDepthHeight) = 0;
	virtual		BOOL	__stdcall	SetColorTableWithStream(const BYTE* pColorTable, UINT WidthDepthHeight) = 0;
	virtual		BOOL	__stdcall	SetCompressedColorTable2x2x2(const void* pCompressedData, DWORD dwSize, UINT WidthDepthHeight) = 0;
	virtual		BOOL	__stdcall	ScluptToRoundBox() = 0;
	virtual		BOOL	__stdcall	SculptToSphere() = 0;
	virtual		void	__stdcall	UpdateGeometry(BOOL bImmediate) = 0;
	virtual		void	__stdcall	UpdateLighting() = 0;
	virtual		BOOL	__stdcall	GetVoxel(BOOL* pbOutValue, DWORD x, DWORD y, DWORD z) const = 0;
	virtual		BOOL	__stdcall	GetColorPerVoxel(BYTE* pbOutValue, DWORD x, DWORD y, DWORD z) const = 0;
	virtual		BOOL	__stdcall	GetFirstVoxelPos(INT_VECTOR3* pivOutVoxelPos) const = 0;
	virtual		void	__stdcall	GetAABB(AABB* pOutAABB) const = 0;
	virtual		BOOL	__stdcall	GetBitTable(unsigned long* pOutBitTable, DWORD dwMaxBufferSize, UINT* puiOutWidthDepthHeight) const = 0;
	virtual		BOOL	__stdcall	SetBitTable(const unsigned long* pBitTable, UINT WidthDepthHeight, BOOL bImmediateUpdate) = 0;
	virtual		BOOL	__stdcall	ClearAndAddVoxel(DWORD x, DWORD y, DWORD z, BOOL bImmediateUpdate) = 0;
	virtual		BOOL	__stdcall	AddVoxelWithAutoResize(UINT* pOutWidthDepthHeight, DWORD x, DWORD y, DWORD z, BYTE bColorIndex, UINT ReqWidthDepthHeight) = 0;
	virtual		BOOL	__stdcall	RemoveVoxelWithAutoResize(UINT* pOutWidthDepthHeight, BOOL* pbOutObjDeleted, DWORD x, DWORD y, DWORD z, UINT ReqWidthDepthHeight) = 0;
	virtual		BOOL	__stdcall	SetVoxelColor(int x, int y, int z, BYTE bColorIndex) = 0;
	virtual		BOOL	__stdcall	SetVoxelColorWithAutoResize(UINT* pOutWidthDepthHeight, int x, int y, int z, BYTE bColorIndex, UINT ReqWidthDepthHeight) = 0;

	virtual		void	__stdcall	GetPosition(VECTOR3* pv3OutPos) const = 0;
	virtual		void	__stdcall	GetPositionInGridSpace(INT_VECTOR3* pivOutPos) const = 0;

	virtual		BOOL	__stdcall	GetVoxelPosition(VECTOR3* pv3OutPos, DWORD x, DWORD y, DWORD z) const = 0;
	virtual		BOOL	__stdcall	GetVoxelPositionInObjSpace(INT_VECTOR3* pivOutPos, VECTOR3* pv3Pos) const = 0;
	virtual		BOOL	__stdcall	GetVoxelPositionInObjSpaceSpecifyDetail(INT_VECTOR3* pivOutPos, VECTOR3* pv3Pos, UINT WidthDepthHeight, float fVoxelSize) const = 0;
	virtual		BOOL	__stdcall	CalcCenterPoint(VECTOR3* pv3OutPoint, DWORD x, DWORD y, DWORD z) const = 0;

	virtual		void	__stdcall	SetPaletteWithRandom(DWORD dwMaxColorNum) = 0;
	virtual		void	__stdcall	SetPaletteWithIndexedColor(BYTE Index) = 0;
	virtual		void	__stdcall	GradationColorTable(BYTE bColorIndex, BYTE bLastColorIndex) = 0;
	virtual		void	__stdcall	ReplaceColorIndex(BYTE bReplaceIndex, BYTE bComparandIndex) = 0;
	virtual		BOOL	__stdcall	ResizeWidthDepthHeight(UINT WidthDepthHeight, BOOL bImmediateUpdate) = 0;
	virtual		BOOL	__stdcall	OptimizeGeometry() = 0;
	virtual		BOOL	__stdcall	OptimizeVoxels(BOOL bImmediateUpdate) = 0;
	virtual		void	__stdcall	SetSelected() = 0;
	virtual		void	__stdcall	ClearSelected() = 0;
	virtual		void	__stdcall	SetDestroyable(BOOL bSwitch) = 0;
	virtual		BOOL	__stdcall	IsDestroyable() const = 0;


};

#if defined(VH_PLUGIN) || defined(_CLIENT)


enum VH_EDIT_MODE
{
	VH_EDIT_MODE_SELECT,
	VH_EDIT_MODE_CREATE_NEW_OBJECT,
	VH_EDIT_MODE_SET_VOXEL_COLOR,
	VH_EDIT_MODE_ADD_VOXEL,
	VH_EDIT_MODE_REMOVE_VOXEL,
	VH_EDIT_MODE_COUNT
};

interface IVHController
{
	virtual		void			__stdcall	GetWorldInfo(DWORD* pdwOutObjNumWidth, DWORD* pdwOutObjNumDepth, DWORD* pdwOutObjNumHeight, AABB* pOutWorldAABB) const = 0;
	virtual		IVoxelObjectLite*	__stdcall	CreateVoxelObject(const VECTOR3* pv3Pos, DWORD dwWidthDepthHeight, DWORD Color, CREATE_VOXEL_OBJECT_ERROR* pOutErr) = 0;
	virtual		IVoxelObjectLite*	__stdcall	CreateVoxelObject(const INT_VECTOR3* piv3PosInGridSpace, DWORD dwWidthDepthHeight, const unsigned long* pBitTable, BYTE* pColorTable, DWORD Color, BOOL bImmdieateUpdate, CREATE_VOXEL_OBJECT_ERROR* pOutErr) = 0;
	virtual		void			__stdcall	DeleteVoxelObject(IVoxelObjectLite* pVoxelObjLite) = 0;
	virtual		void			__stdcall	DeleteAllVoxelObject() = 0;
	virtual		DWORD			__stdcall	GetIntPositionListWithSphere(INT_VECTOR3* pivOutPosList, DWORD dwMaxPosCount, const BOUNDING_SPHERE* pBS, BOOL* pbOutInsufficient) const = 0;
	virtual		void			__stdcall	GetIntPositionWithFloatCoord(INT_VECTOR3* pivOutPos, const VECTOR3* pv3Pos) const = 0;
	virtual		void			__stdcall	GetFloatPositionWithIntCoord(VECTOR3* pv3OutPos, const INT_VECTOR3* pivPos) const = 0;
	virtual		void			__stdcall	GetVoxelObjectAABBWithIntCoord(AABB* pOutAABB, const INT_VECTOR3* pivPos) const = 0;
	virtual		BOOL			__stdcall	GetRayWithScreenCoord(VECTOR3* pv3OutPos, VECTOR3* pv3OutDir, int x, int y) const = 0;
	virtual		IVoxelObjectLite*	__stdcall	IntersectVoxelWithRayAsTriMesh(VECTOR3* pv3OutIntersectPoint, float* pfOutT, const VECTOR3* pv3Orig, const VECTOR3* pv3Ray) const = 0;
	virtual		BOOL				__stdcall	IntersectVoxelWithRay(VECTOR3* pv3OutIntersectPoint, float* pfOutT, VECTOR3* pv3OutAxis, VOXEL_DESC_LITE* pOutVoxelDesc, const VECTOR3* pv3Orig, const VECTOR3* pv3Ray) const = 0;
	virtual		BOOL				__stdcall	IntersectBottomWithRay(VECTOR3* pv3OutIntersectPoint, const VECTOR3* pv3Orig, const VECTOR3* pv3Ray) const = 0;
	virtual		int					__stdcall	FindTriListWithCapsuleRay(TRIANGLE* pOutTriList, int iMaxTriNum, const VECTOR3* pv3Orig, const VECTOR3* pv3Ray, float fRs, BOOL* pbOutInsufficient) const = 0;
	virtual		IVoxelObjectLite*	__stdcall	GetVoxelObjectWithGridCoord(const INT_VECTOR3* pivPos) const = 0;
	virtual		IVoxelObjectLite*	__stdcall	GetVoxelObjectWithFloatCoord(const VECTOR3* pv3Pos) const = 0;
	virtual		DWORD			__stdcall GetVoxelObjectNum() const = 0;
	virtual		DWORD			__stdcall	GetPalettedColorNum() const = 0;


	virtual		void			__stdcall	SnapCoord(VECTOR3* pv3OutSnappedPos, const VECTOR3* pv3Pos) const = 0;
	virtual		void			__stdcall	SetCursorVoxelObjectPos(const VECTOR3* pv3Pos, BOOL bSelectVoxel, const VECTOR3* pv3PickedPos, const VECTOR3* pv3Normal) = 0;
	virtual		void			__stdcall	GetCursorVoxelObjectPos(VECTOR3* pv3OutPos, INT_VECTOR3* piv3OutVoxelPos) const = 0;
	virtual		void			__stdcall	SelectCursorVoxelObjectDetail(UINT WidthDepthHeight) = 0;
	virtual		void			__stdcall	SetCursorVoxelObjectScale(float fObjScale) = 0;
	virtual		void			__stdcall	SetCursorVoxelObjectVoxelScale(float fVoxelScale) = 0;
	virtual		void			__stdcall	SetCursorVoxelObjectRenderMode(RENDER_MODE mode) = 0;
	virtual		UINT			__stdcall	GetCursorVoxelObjectPropery(float* pfOutVoxelSize) const = 0;
	virtual		void			__stdcall	SetCursorVoxelObjectColor(BYTE bColorIndex) = 0;
	virtual		void			__stdcall	SetBrushVoxelObjectColor(BYTE bColorIndex) = 0;

	virtual		BOOL			__stdcall	IsValidVoxelObjectPosition(const VECTOR3* pv3Pos) const = 0;
	virtual		BOOL			__stdcall	IsValidVoxelObjectPosition(const INT_VECTOR3* pivPos) const = 0;
	virtual		DWORD			__stdcall	FindVoxelObjectListWithSphere(IVoxelObjectLite** ppOutVoxelObjLiteList, int iMaxBufferCount, const BOUNDING_SPHERE* pBS, BOOL* pbOutInsufficient) const = 0;
	virtual		DWORD			__stdcall	FindVoxelObjectListWithCapsule(IVoxelObjectLite** ppOutVoxelObjLiteList, int iMaxBufferCount, VECTOR3* pv3RayOrig, VECTOR3* pv3RayDir, float fRs, BOOL* pbOutInsufficient) const = 0;
	virtual		DWORD			__stdcall	FindVoxelObjectListWithAABB(IVoxelObjectLite** ppOutVoxelObjLiteList, int iMaxBufferCount, const AABB* pAABB, BOOL* pbOutInsufficient) const = 0;
	virtual		DWORD			__stdcall	FindVoxelObjectListWithScreenRect(IVoxelObjectLite** ppOutVoxelObjLiteList, int iMaxBufferCount, const RECT* pRect, float fDist, DWORD dwViewportIndex, BOOL* pbOutInsufficient) const = 0;

	virtual		BOOL			__stdcall 	GetPicekdPosition(VECTOR3* pv3OutPos, VECTOR3* pv3OutPickedAxis, float* pfOutDist) const = 0;
	virtual		BOOL			__stdcall	AddVoxel(const VECTOR3* pv3CursorObjPos, const INT_VECTOR3* pivCursorVoxelPos, BYTE bColorIndex, BOOL bRecursivePlane, BOOL bRebuildArea) = 0;
	virtual		BOOL			__stdcall	SetVoxelColor(IVoxelObjectLite* pVoxelObj, const VECTOR3* pv3CursorObjPos, const INT_VECTOR3* pivCursorVoxelPos, BYTE bColorIndex, BOOL bRecursivePlane) = 0;
	virtual		DWORD			__stdcall	GetColorTableFromPalette(DWORD* pdwOutColorTable, DWORD dwMaxBufferCount, BOOL* pbOutInsufficient) const = 0;


	virtual		DWORD			__stdcall	AddVoxelsWithAABBAutoResize(const AABB* pAABB, const PLANE* pClipPlane, UINT WidthDepthHeight, BYTE bColorIndex) = 0;
	virtual		void			__stdcall	PaintVoxelsWithAABBAutoResize(const AABB* pAABB, UINT WidthDepthHeight, BYTE bColorIndex) = 0;
	virtual		void			__stdcall	RemoveVoxelsWithAABBAutoResize(const AABB* pAABB, UINT WidthDepthHeight) = 0;
	virtual		DWORD			__stdcall	AddVoxelsWithSphereAutoResize(const VECTOR3* pv3Pos, float fRs, const PLANE* pClipPlane, UINT WidthDepthHeight, BYTE bColorIndex) = 0;
	virtual 	void			__stdcall	PaintVoxelsWithSphereAutoResize(const VECTOR3* pv3Pos, float fRs, const PLANE* pClipPlane, UINT WidthDepthHeight, BYTE bColorIndex) = 0;
	virtual		void			__stdcall	RemoveVoxelsWithSphereAutoResize(const VECTOR3* pv3Pos, float fRs, UINT WidthDepthHeight) = 0;
	virtual		void			__stdcall	RemoveVoxelsWithSphereByObjListAutoResize(const VECTOR3* pv3Pos, float fRs, const VECTOR3* pv3ObjList, DWORD dwObjNum, UINT WidthDepthHeight) = 0;
	virtual		void			__stdcall	RemoveVoxelsWithCapsuleAutoResize(const VECTOR3* pv3RayOrig, const VECTOR3* pv3RayDir, float fRs, UINT WidthDepthHeight) = 0;
	virtual		void			__stdcall	RemoveVoxelsWithCapsuleByObjListAutoResize(VECTOR3* pv3RayOrig, VECTOR3* pv3RayDir, float fRs, const VECTOR3* pv3ObjList, DWORD dwObjNum, UINT WidthDepthHeight) = 0;

	virtual		void			__stdcall	WriteTextToSystemDlgW(DWORD dwColor, const WCHAR* wchFormat, ...) = 0;

	virtual		void			__stdcall	SetFirstVoxelObject() = 0;
	virtual		IVoxelObjectLite*	__stdcall	GetVoxelObjectAndNext() = 0;

	virtual		DWORD			__stdcall	CreateVoxelPointListWithWorldAABB(VECTOR3* pv3OutPointList, DWORD dwMaxBufferCount, const AABB* pAABB, const PLANE* pClipPlane, UINT WidthDepthHeight) = 0;
	virtual		DWORD			__stdcall	CreateVoxelPointListWithWorldAABBForRemove(VECTOR3* pv3OutPointList, DWORD dwMaxBufferCount, const AABB* pAABB, const PLANE* pClipPlane, UINT WidthDepthHeight) = 0;
	virtual		DWORD			__stdcall	CreateVoxelPointListWithWorldSphere(VECTOR3* pv3OutPointList, DWORD dwMaxBufferCount, const BOUNDING_SPHERE* pBS, const PLANE* pClipPlane, UINT WidthDepthHeight) = 0;
	virtual		DWORD			__stdcall	CreateVoxelPointListWithWorldSphereForRemove(VECTOR3* pv3OutPointList, DWORD dwMaxBufferCount, const BOUNDING_SPHERE* pBS, const PLANE* pClipPlane, UINT WidthDepthHeight) = 0;

	virtual		BOOL			__stdcall	GetFootrestBaseObjPos(INT_VECTOR4* pivOutObjPos, const VECTOR3* pv3Pos, float fAdjHeight) const = 0;
	virtual		DWORD			__stdcall	GetFootrestQuadList(IVERTEX_QUAD* pOutQuadList, DWORD dwMaxQuadCount, const INT_VECTOR4* pivBaseObjPos, int iTexRepeat, BOOL* pbOutInsuffcient) const = 0;
	virtual		float			__stdcall	GetFootrestHeight(const INT_VECTOR4* pivBaseObjPos) const = 0;
	virtual		void			__stdcall	SetSelectedVoxel(IVoxelObjectLite* pVoxelObjLite, int x, int y, int z) = 0;
	virtual		void			__stdcall	SetSelected(IVoxelObjectLite* pVoxelObjLite) = 0;
	virtual		void			__stdcall	ClearSelectedVoxel(IVoxelObjectLite* pVoxelObjLite, int x, int y, int z) = 0;
	virtual		void			__stdcall	ClearSelectedAll() = 0;

	virtual		BOOL			__stdcall	WriteFile(const WCHAR* wchFileName) = 0;
	virtual		BOOL			__stdcall	ReadFile(const WCHAR* wchFileName, BOOL bDelayedUpdate, BOOL bLighting) = 0;

	virtual		void			__stdcall	BeginWriteTextToConsole() = 0;
	virtual		void			__stdcall	WriteTextToConsole(const WCHAR* wchTxt, int iLen, DWORD dwColor) = 0;
	virtual		void			__stdcall	EndWriteTextToConsole() = 0;

	virtual		BYTE			__stdcall	GetCurrentColorIndex() const = 0;
	virtual		VH_EDIT_MODE	__stdcall	GetCurrentEditMode() const = 0;
	virtual		PLANE_AXIS_TYPE __stdcall	GetCurrentPlaneType() const = 0;
	virtual		BOOL			__stdcall	GetSelectedVoxelObjDesc(VOXEL_DESC_LITE* pOutVoxelObjDesc) const = 0;
	virtual		BOOL			__stdcall	GetCursorStatus(VECTOR3* pv3OutCursorObjPos, INT_VECTOR3* pivOutCursorVoxelPos, UINT* puiOutWidthDepthHeight, float* pfOutCursorVoxelSize, BYTE* pbOutColorIndex) const = 0;

	virtual		BOOL			__stdcall	IsUpdating() const = 0;
	virtual		void			__stdcall	UpdateVisibilityAll() = 0;

	virtual		void			__stdcall	EnableDestroyableAll(BOOL bSwitch) = 0;
	virtual		void			__stdcall	EnableAutoRestoreAll(BOOL bSwitch) = 0;
	virtual		void			__stdcall	SetOnDeleteVoxelObjectFunc(ON_DELETE_VOXEL_OBJ_LITE_FUNC pFunc) = 0;

	virtual		WEB_CLIENT_HANDLE __stdcall BrowseWeb(const char* szURL, DWORD dwWidth, DWORD dwHeight, BOOL bUserSharedMemory) = 0;
	virtual		void	__stdcall CloseWeb(WEB_CLIENT_HANDLE pHandle) = 0;
	virtual		BOOL	__stdcall GetWebImage(BYTE* pOutBits32, DWORD dwWidth, DWORD dwHeight, DWORD dwDestPitch, WEB_CLIENT_HANDLE pHandle) const = 0;
	virtual		void	__stdcall OnWebMouseLButtonDown(WEB_CLIENT_HANDLE pHandle, int x, int y, UINT nFlags) = 0;
	virtual		void	__stdcall OnWebMouseLButtonUp(WEB_CLIENT_HANDLE pHandle, int x, int y, UINT nFlags) = 0;

	// midi
	virtual		BOOL	__stdcall SetMidiOutDevice(const WCHAR* wchDeviceName) = 0;
	virtual		BOOL	__stdcall GetSelectedMidiOutDevice(MIDI_DEVICE_INFO* pOutInfo) = 0;
	virtual		BOOL	__stdcall SetMidiInDevice(const WCHAR* wchDeviceName) = 0;
	virtual		BOOL	__stdcall GetSelectedMidiInDevice(MIDI_DEVICE_INFO* pOutInfo) = 0;
	virtual		BOOL	__stdcall SetVolume(unsigned char channel, unsigned char Volume) = 0;
	virtual		BOOL	__stdcall SetSustainPedal(unsigned char channel, unsigned char Value) = 0;
	virtual		BOOL	__stdcall NoteOn(unsigned char channel, unsigned char note, unsigned char Velocity) = 0;
	virtual		BOOL	__stdcall NoteOff(unsigned char channel, unsigned char note, unsigned char Velocity) = 0;
	virtual		DWORD	__stdcall GetMidiInDeviceList(MIDI_DEVICE_INFO* pOutInfoList, DWORD dwMaxBufferCount) = 0;
	virtual		DWORD	__stdcall GetMidiOutDeviceList(MIDI_DEVICE_INFO* pOutInfoList, DWORD dwMaxBufferCount) = 0;
	virtual		BOOL	__stdcall WriteNoteOrControl(MIDI_SIGNAL_TYPE type, BOOL bOnOff, DWORD dwKey, DWORD dwVelocity) = 0;
};

interface IVHNetworkLayer
{
	// voxel edit
	virtual		void	Send_RequestAddMultipleVoxels(const VECTOR3* pv3ObjPos, const INT_VECTOR3* pivVoxelPosList, DWORD dwVoxelNum, BYTE bWidthDepthHeight, BYTE bColorIndex, PLANE_AXIS_TYPE planeType, BOOL bRebuildArea) = 0;
	virtual		void	Send_RequestSetMultipleVoxelsColor(const VECTOR3* pv3ObjPos, const INT_VECTOR3* pivVoxelPosList, DWORD dwVoxelNum, BYTE bColorIndex, BYTE WidthDepthHeight, PLANE_AXIS_TYPE planeType) = 0;
	virtual		void	Send_RequestRemoveMultipleVoxels(const VECTOR3* pv3ObjPos, const INT_VECTOR3* pivVoxelPosList, DWORD dwVoxelNum, BYTE bWidthDepthHeight, PLANE_AXIS_TYPE planeType) = 0;
	virtual		void	Send_RequestCreateVoxelObject(const VECTOR3* pv3ObjPos, UINT WidthDepthHeight, float fVoxelSize, WORD wFirstVoxelPos, BYTE bFirstVoxelColor, BOOL bRebuildArea) = 0;
	virtual		void	Send_RequestAddVoxel(const VECTOR3* pv3ObjPos, const INT_VECTOR3* pVoxelPos, BYTE bWidthDepthHeight, BYTE bVoxelColor, BOOL bRebuildArea) = 0;
	virtual		void	Send_RequestRemoveVoxel(const VECTOR3* pv3ObjPos, const INT_VECTOR3* pVoxelPos, BYTE bWidthDepthHeight) = 0;
	virtual		void	Send_RequestSetVoxelColor(const VECTOR3* pv3ObjPos, const INT_VECTOR3* pVoxelPos, BYTE bColorIndex, BYTE WidthDepthHeight) = 0;
	virtual		void	Send_RequestResizeVoxelDetail(const VECTOR3* pv3ObjPos, BYTE WidthDepthHeight) = 0;
};


interface IGameHook : public IUnknown
{
	virtual	void __stdcall	OnStartScene(IVHController* pVHController, IVHNetworkLayer* pNetworkLayer, const WCHAR* wchPluginPath) = 0;
	virtual	void __stdcall	OnRun() = 0;
	virtual	void __stdcall	OnDestroyScene() = 0;

	virtual BOOL __stdcall	OnMouseLButtonDown(int x, int y, UINT nFlags) = 0;
	virtual BOOL __stdcall	OnMouseLButtonUp(int x, int y, UINT nFlags) = 0;
	virtual BOOL __stdcall	OnMouseRButtonDown(int x, int y, UINT nFlags) = 0;
	virtual BOOL __stdcall	OnMouseRButtonUp(int x, int y, UINT nFlags) = 0;
	virtual BOOL __stdcall	OnMouseMove(int x, int y, UINT nFlags) = 0;
	virtual BOOL __stdcall	OnMouseMoveHV(int iMoveX, int iMoveY, BOOL bLButtonPressed, BOOL bRButtonPressed, BOOL bMButtonPressed) = 0;
	virtual BOOL __stdcall	OnMouseWheel(int iWheel) = 0;

	virtual BOOL __stdcall	OnKeyDown(UINT nChar) = 0;
	virtual BOOL __stdcall	OnKeyUp(UINT nChar) = 0;
	virtual BOOL __stdcall	OnCharUnicode(UINT nChar) = 0;

	virtual BOOL __stdcall	OnDPadLB() = 0;
	virtual BOOL __stdcall	OffDPadLB() = 0;
	virtual BOOL __stdcall	OnDPadRB() = 0;
	virtual BOOL __stdcall	OffDPadRB() = 0;

	virtual BOOL __stdcall	OnDPadUp() = 0;
	virtual BOOL __stdcall	OnDPadDown() = 0;
	virtual BOOL __stdcall	OnDPadLeft() = 0;
	virtual BOOL __stdcall	OnDPadRight() = 0;
	virtual BOOL __stdcall	OffDPadUp() = 0;
	virtual BOOL __stdcall	OffDPadDown() = 0;
	virtual BOOL __stdcall	OffDPadLeft() = 0;
	virtual BOOL __stdcall	OffDPadRight() = 0;

	virtual BOOL __stdcall	OnPadPressedA() = 0;
	virtual BOOL __stdcall	OnPadPressedB() = 0;
	virtual BOOL __stdcall	OnPadPressedX() = 0;
	virtual BOOL __stdcall	OnPadPressedY() = 0;
	virtual BOOL __stdcall	OffPadPressedA() = 0;
	virtual BOOL __stdcall	OffPadPressedB() = 0;
	virtual BOOL __stdcall	OffPadPressedX() = 0;
	virtual BOOL __stdcall	OffPadPressedY() = 0;
	virtual BOOL __stdcall	OnKeyDownFunc(UINT nChar) = 0;
	virtual BOOL __stdcall	OnKeyDownCtrlFunc(UINT nChar) = 0;
	virtual BOOL __stdcall	OnPreConsoleCommand(const WCHAR* wchCmd, DWORD dwCmdLen) = 0;

};
#endif