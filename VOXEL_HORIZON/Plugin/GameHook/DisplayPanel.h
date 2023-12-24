#pragma once

class CDisplayPanel
{
	static const DWORD MAX_LAYER_COUNT = 8;
	static const DWORD COLOR_TABLE_COUNT = 32;

	IVHController* m_pVHController = nullptr;

	BYTE*	m_ppBits[MAX_LAYER_COUNT] = {};
	UINT	m_Width = 0;
	UINT	m_Height = 0;
	DWORD	m_dwLayerCount = 0;
	IVoxelObjectLite**	m_ppVoxelObjList = nullptr;
	UINT	m_VoxelObjWidth = 0;
	UINT	m_VoxelObjHeight = 0;
	DWORD	m_dwColorTableCount = 0;
	DWORD	m_pdwColorTable[COLOR_TABLE_COUNT] = {};
	BYTE*	m_pCvtTable = nullptr;
	AABB	m_aabb = {};
	void	InitColorConvertingTable(const DWORD* pdwColorTable, DWORD dwColorTableCount);
	
	void	CleanupColorConvertingTable();
	BOOL	CalcClipArea(INT_VECTOR2* pivOutSrcStart, INT_VECTOR2* pivOutDestStart, INT_VECTOR2* pivOutDestSize, const INT_VECTOR2* pivPos, const INT_VECTOR2* pivImageSize);
	BYTE	Convert32BitsColorToPaletteIndexRGBA_CVT(DWORD dwSrcColor);
	BYTE	Convert32BitsColorToPaletteIndexBGRA_CVT(DWORD dwSrcColor);
	void	Cleanup();
public:
	BOOL	Initialize(IVHController* pVHController, UINT Width, UINT Height, DWORD dwLayerCount);
	void	Convert32BitsImageTo8BitsPalettedImageRGBA(BYTE* pDest, const DWORD* pSrc, DWORD dwWidth, DWORD dwHeight);
	void	Convert32BitsImageTo8BitsPalettedImageBGRA(BYTE* pDest, const DWORD* pSrc, DWORD dwWidth, DWORD dwHeight);
	
	BYTE	Convert32BitsColorToPaletteIndexRGBA(DWORD dwSrcColor);
	BYTE	Convert32BitsColorToPaletteIndexBGRA(DWORD dwSrcColor);
	void	OnDeleteVoxelObject(IVoxelObjectLite* pVoxelObj);
	
	void	Clear(BYTE bColorIndex, DWORD dwLayerIndex);
	void	Set32BitImage(BYTE* pSrcBits, DWORD dwImageWidth, DWORD dwImageHeight);
	BOOL	DrawPalettedBitmap(int sx, int sy, int iBitmapWidth, int iBitmapHeight, const BYTE* pSrcBits, DWORD dwLayerIndex);
	BOOL	DrawPalettedBitmapWithTransparency(int sx, int sy, int iBitmapWidth, int iBitmapHeight, const BYTE* pSrcBits, DWORD dwLayerIndex);
	BOOL	DrawCompressedPalettedImageData(int sx, int sy, const CImageData* pImgData, DWORD dwLayerIndex);
	void	SetPalettedImage(const BYTE* pSrcBits, DWORD dwImageWidth, DWORD dwImageHeight, DWORD dwLayerIndex);
	void	UpdateBitmapToVoxelDataWithMultipleLayers(DWORD dwLayerStart, DWORD dwLayerCount);
	void	UpdateBitmapToVoxelDataWithSingleLayer(int voxel_z, DWORD dwLayerIndex);
	void	ResetVoxelData();
	UINT	GetWidth() const { return m_Width; }
	UINT	GetHeight() const { return m_Height; }
	BOOL	GetScreenPosWithVoxelObjPos(int* piOutX, int* piOutY, IVoxelObjectLite* pVoxelObjSrc, int x, int y);
	BOOL	GetScreenPosWithWorldPos(int* piOutX, int* piOutY, const VECTOR3* pv3Point, int iScreenWidth, int iScreenHeight);
	CDisplayPanel();
	~CDisplayPanel();
};