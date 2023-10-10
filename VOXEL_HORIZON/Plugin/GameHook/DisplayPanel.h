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
	
	
	BOOL	CalcClipArea(INT_VECTOR2* pivOutSrcStart, INT_VECTOR2* pivOutDestStart, INT_VECTOR2* pivOutDestSize, const INT_VECTOR2* pivPos, const INT_VECTOR2* pivImageSize);
	void	Cleanup();
public:
	BOOL	Initialize(IVHController* pVHController, UINT Width, UINT Height, DWORD dwLayerCount);
	void	Convert32BitsImageTo8BitsPalettedImage(BYTE* pDest, const DWORD* pSrc, DWORD dwWidth, DWORD dwHeight);
	BYTE	Convert32BitsColorToPaletteIndex(DWORD dwColor);
	void	OnDeleteVoxelObject(IVoxelObjectLite* pVoxelObj);
	
	void	Clear(BYTE bColorIndex, DWORD dwLayerIndex);
	void	Set32BitImage(BYTE* pSrcBits, DWORD dwImageWidth, DWORD dwImageHeight);
	BOOL	DrawPalettedBitmap(int sx, int sy, int iBitmapWidth, int iBitmapHeight, const BYTE* pSrcBits, DWORD dwLayerIndex);
	BOOL	DrawCompressedPalettedImageData(int sx, int sy, const CImageData* pImgData, DWORD dwLayerIndex);
	void	SetPalettedImage(const BYTE* pSrcBits, DWORD dwImageWidth, DWORD dwImageHeight, DWORD dwLayerIndex);
	void	UpdateBitmapToVoxelDataWithMultipleLayers(DWORD dwLayerStart, DWORD dwLayerCount);
	void	UpdateBitmapToVoxelDataWithSingleLayer(int voxel_z, DWORD dwLayerIndex);
	void	ResetVoxelData();
	UINT	GetWidth() const { return m_Width; }
	UINT	GetHeight() const { return m_Height; }
	
	CDisplayPanel();
	~CDisplayPanel();
};