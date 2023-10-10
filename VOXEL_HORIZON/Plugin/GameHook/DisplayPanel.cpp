#include "stdafx.h"
#include "Util.h"
#include "ImageData.h"
#include "../include/IGameHookController.h"
#include "../include/BooleanTable.inl"
#include "DisplayPanel.h"

CDisplayPanel::CDisplayPanel()
{
}
void CDisplayPanel::OnDeleteVoxelObject(IVoxelObjectLite* pVoxelObj)
{
	if (m_ppVoxelObjList)
	{
		for (UINT y = 0; y < m_VoxelObjHeight; y++)
		{
			for (UINT x = 0; x < m_VoxelObjWidth; x++)
			{
				if (pVoxelObj == m_ppVoxelObjList[y * m_VoxelObjWidth + x])
				{
					m_ppVoxelObjList[y * m_VoxelObjWidth + x] = nullptr;
				}
			}
		}
	}
}

BOOL CDisplayPanel::Initialize(IVHController* pVHController, UINT Width, UINT Height, DWORD dwLayerCount)
{
	m_pVHController = pVHController;

	m_dwLayerCount = dwLayerCount;
	VECTOR3	v3BasePos = { VOXEL_OBJECT_SIZE / 2.0f, VOXEL_OBJECT_SIZE / 2.0f, VOXEL_OBJECT_SIZE / 2.0f };
	v3BasePos.y += DEFAULT_SCENE_MIN_Y;

	m_Width = Width;
	m_Height = Height;
	for (DWORD i = 0; i < m_dwLayerCount; i++)
	{
		m_ppBits[i] = new BYTE[m_Width * m_Height];
		memset(m_ppBits[i], 0, m_Width * m_Height);
	}
	m_VoxelObjWidth = Width / MAX_VOXELS_PER_AXIS + ((Width % MAX_VOXELS_PER_AXIS) != 0);
	m_VoxelObjHeight = Height / MAX_VOXELS_PER_AXIS + ((Height % MAX_VOXELS_PER_AXIS) != 0);

	m_ppVoxelObjList = new IVoxelObjectLite*[m_VoxelObjWidth * m_VoxelObjHeight];
	memset(m_ppVoxelObjList, 0, sizeof(IVoxelObjectLite*) * m_VoxelObjWidth * m_VoxelObjHeight);

	IVoxelObjectLite* pVoxelObj = nullptr;
	CREATE_VOXEL_OBJECT_ERROR	err = CREATE_VOXEL_OBJECT_ERROR_OK;

	VECTOR3		v3Pos = v3BasePos;
	for (UINT y = 0; y < m_VoxelObjHeight; y++)
	{
		for (UINT x = 0; x < m_VoxelObjWidth; x++)
		{
			pVoxelObj = m_pVHController->CreateVoxelObject(&v3Pos, MAX_VOXELS_PER_AXIS, 0xffffffff, &err);
			if (!pVoxelObj)
				__debugbreak();

			pVoxelObj->UpdateGeometry(FALSE);
			pVoxelObj->UpdateLighting();
			m_ppVoxelObjList[y * m_VoxelObjWidth + x] = pVoxelObj;
			v3Pos.x += VOXEL_OBJECT_SIZE;
		}
		v3Pos.x = v3BasePos.x;
		v3Pos.y += VOXEL_OBJECT_SIZE;
	}
	m_pVHController->UpdateVisibilityAll();
	m_pVHController->EnableDestroyableAll(TRUE);

	BOOL	bInsufficient = FALSE;
	m_dwColorTableCount = m_pVHController->GetColorTableFromPalette(m_pdwColorTable, (DWORD)_countof(m_pdwColorTable), &bInsufficient);

	return TRUE;
}
BYTE CDisplayPanel::Convert32BitsColorToPaletteIndex(DWORD dwSrcColor)
{
	DWORD	dwSelectedIndex = 0;
	float min_dist = (float)INT_MAX;
	for (DWORD i = 0; i < m_dwColorTableCount; i++)
	{
		DWORD sb = (dwSrcColor & 0x00ff0000) >> 16;
		DWORD sg = (dwSrcColor & 0x0000ff00) >> 8;
		DWORD sr = (dwSrcColor & 0x000000ff);

		DWORD	dwDestColor = m_pdwColorTable[i];
		DWORD dr = (dwDestColor & 0x00ff0000) >> 16;
		DWORD dg = (dwDestColor & 0x0000ff00) >> 8;
		DWORD db = (dwDestColor & 0x000000ff);

		int r_diff = ((int)sr - (int)dr);
		int g_diff = ((int)sg - (int)dg);
		int b_diff = ((int)sb - (int)db);

		float dist = sqrtf((float)(r_diff * r_diff + g_diff * g_diff + b_diff * b_diff));
		if (min_dist > dist)
		{
			min_dist = dist;
			dwSelectedIndex = i;
		}
	}
	return (BYTE)dwSelectedIndex;
}
void CDisplayPanel::Convert32BitsImageTo8BitsPalettedImage(BYTE* pDest, const DWORD* pSrc, DWORD dwWidth, DWORD dwHeight)
{
	for (DWORD y = 0; y < dwHeight; y++)
	{
		for (DWORD x = 0; x < dwWidth; x++)
		{
			pDest[x + y * dwWidth] = Convert32BitsColorToPaletteIndex(pSrc[x + dwWidth * y]);
		}
	}
}
void CDisplayPanel::Set32BitImage(BYTE* pBits, DWORD dwImageWidth, DWORD dwImageHeight)
{
	DWORD dwVoxelObjX = 0;
	DWORD dwVoxelObjY = 0;

	for (int y = 0; y < (int)dwImageHeight; y++)
	{
		for (int x = 0; x < (int)dwImageWidth; x++)
		{
			DWORD dwSrcOffset = x * 4 + y * dwImageWidth * 4;
			DWORD dwSrcColor = *(DWORD*)(pBits + dwSrcOffset);
			BYTE bColorIndex = Convert32BitsColorToPaletteIndex(dwSrcColor);

			int reverse_y = (int)dwImageHeight - y - 1;

			DWORD dwVoxelObjY = reverse_y / MAX_VOXELS_PER_AXIS;
			DWORD dwVoxelPosY = reverse_y % MAX_VOXELS_PER_AXIS;

			DWORD dwVoxelObjX = x / MAX_VOXELS_PER_AXIS;
			DWORD dwVoxelPosX = x % MAX_VOXELS_PER_AXIS;

			IVoxelObjectLite* pVoxelObj = m_ppVoxelObjList[dwVoxelObjX + m_VoxelObjWidth * dwVoxelObjY];
			pVoxelObj->SetVoxelColor((int)dwVoxelPosX, (int)dwVoxelPosY, 0, bColorIndex);
		}
	}
}


BOOL CDisplayPanel::CalcClipArea(INT_VECTOR2* pivOutSrcStart, INT_VECTOR2* pivOutDestStart, INT_VECTOR2* pivOutDestSize, const INT_VECTOR2* pivPos, const INT_VECTOR2* pivImageSize)
{
	INT_VECTOR2	ivBufferSize = { (int)m_Width, (int)m_Height };
	BOOL bResult = ::CalcClipArea(pivOutSrcStart, pivOutDestStart, pivOutDestSize, pivPos, pivImageSize, &ivBufferSize);
	return bResult;
}

void CDisplayPanel::Clear(BYTE bColorIndex, DWORD dwLayerIndex)
{
	// bColorIndex == 0xff인 경우 VoxelObject 업데이트 할때 복셀이 비어있는 것으로 간주된다.
	memset(m_ppBits[dwLayerIndex], bColorIndex, m_Width * m_Height);
}
BOOL CDisplayPanel::DrawPalettedBitmap(int sx, int sy, int iBitmapWidth, int iBitmapHeight, const BYTE* pSrcBits, DWORD dwLayerIndex)
{
	BOOL	bResult = FALSE;

	INT_VECTOR2	ivSrcStart = {};
	INT_VECTOR2	ivDestStart = {};

	INT_VECTOR2	ivPos = { sx, sy };
	INT_VECTOR2	ivImageSize = { iBitmapWidth, iBitmapHeight };
	INT_VECTOR2 ivDestSize = {};

	if (!CalcClipArea(&ivSrcStart, &ivDestStart, &ivDestSize, &ivPos, &ivImageSize))
		goto lb_return;

	const BYTE* pSrc = pSrcBits + ivSrcStart.x + (ivSrcStart.y * iBitmapWidth);
	BYTE* pDest = m_ppBits[dwLayerIndex] + ivDestStart.x + (ivDestStart.y * m_Width);

	for (int y = 0; y < ivDestSize.y; y++)
	{
		for (int x = 0; x < ivDestSize.x; x++)
		{
			*pDest = *pSrc;
			pSrc++;
			pDest++;
		}
		pSrc -= ivDestSize.x;
		pSrc += iBitmapWidth;
		pDest -= ivDestSize.x;
		pDest += m_Width;
	}
	//
	bResult = TRUE;
lb_return:
	return bResult;
}

BOOL CDisplayPanel::DrawCompressedPalettedImageData(int sx, int sy, const CImageData* pImgData, DWORD dwLayerIndex)
{
	BOOL	bResult = FALSE;

	int iScreenWidth = (int)m_Width;

	int iBitmapWidth = (int)pImgData->GetWidth();
	int iBitmapHeight = (int)pImgData->GetHeight();

	INT_VECTOR2	ivSrcStart = {};
	INT_VECTOR2	ivDestStart = {};

	INT_VECTOR2	ivPos = { sx, sy };
	INT_VECTOR2	ivImageSize = { iBitmapWidth, iBitmapHeight };
	INT_VECTOR2 ivDestSize = {};

	if (!CalcClipArea(&ivSrcStart, &ivDestStart, &ivDestSize, &ivPos, &ivImageSize))
		goto lb_return;

	const COMPRESSED_LINE* pLineDesc = pImgData->GetCompressedImage(ivSrcStart.y);
	BYTE* pDestPerLine = m_ppBits[dwLayerIndex] + (ivDestStart.y) * m_Width;

	for (int y = 0; y < ivDestSize.y; y++)
	{
		for (DWORD i = 0; i < pLineDesc->dwStreamNum; i++)
		{
			PIXEL_STREAM*	pStream = pLineDesc->pPixelStream + i;
			BYTE	bPixelColor = pStream->bPixel;
			int		iPixelNum = (int)pStream->wPixelNum;

			int dest_x = sx + (int)pStream->wPosX;
			if (dest_x < 0)
			{
				iPixelNum += dest_x;
				dest_x = 0;
			}
			if (dest_x + iPixelNum > iScreenWidth)
			{
				iPixelNum = iScreenWidth - dest_x;
			}
			BYTE* pDest = pDestPerLine + dest_x;
			for (int x = 0; x < iPixelNum; x++)
			{
				*pDest = bPixelColor;
				pDest++;
			}
		}
		pLineDesc++;
		pDestPerLine += m_Width;
	}
	//
	bResult = TRUE;
lb_return:
	return bResult;

}
void CDisplayPanel::SetPalettedImage(const BYTE* pSrcBits, DWORD dwImageWidth, DWORD dwImageHeight, DWORD dwLayerIndex)
{
	//
	// 일단은 사이즈가 같거나 작다고 간주하지만 나중에 클리핑 처리 할 것.
	//
	if (dwImageWidth > m_Width)
		__debugbreak();

	if (dwImageHeight > m_Height)
		__debugbreak();

	if (dwLayerIndex >= m_dwLayerCount)
		__debugbreak();

	memcpy(m_ppBits[dwLayerIndex], pSrcBits, dwImageWidth * dwImageHeight);
}
void CDisplayPanel::ResetVoxelData()
{
	const UINT WIDTH_DEPTH_HEIGHT = MAX_VOXELS_PER_AXIS;

	unsigned long pBitTable[MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS / 8 / 4];
	memset(pBitTable, 0xff, sizeof(pBitTable));
	for (DWORD obj_y = 0; obj_y < m_VoxelObjHeight; obj_y++)
	{
		for (DWORD obj_x = 0; obj_x < m_VoxelObjWidth; obj_x++)
		{

			IVoxelObjectLite* pVoxelObj = m_ppVoxelObjList[obj_x + m_VoxelObjWidth * obj_y];
			pVoxelObj->SetBitTable(pBitTable, WIDTH_DEPTH_HEIGHT, FALSE);
		}
	}
}
void CDisplayPanel::UpdateBitmapToVoxelDataWithMultipleLayers(DWORD dwLayerStart, DWORD dwLayerCount)
{
	const UINT WIDTH_DEPTH_HEIGHT = MAX_VOXELS_PER_AXIS;
	BYTE	pColorTable[MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS] = {};
	unsigned long pBitTable[MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS / 8 / 4];
	memset(pBitTable, 0xff, sizeof(pBitTable));

	for (DWORD obj_y = 0; obj_y < m_VoxelObjHeight; obj_y++)
	{
		for (DWORD obj_x = 0; obj_x < m_VoxelObjWidth; obj_x++)
		{
			IVoxelObjectLite* pVoxelObj = m_ppVoxelObjList[obj_x + m_VoxelObjWidth * obj_y];

			BOOL	bVoxelObjBitTableModified = FALSE;
			UINT WidthDepthHeight = 0;
			pVoxelObj->GetBitTable(pBitTable, (DWORD)sizeof(pBitTable), &WidthDepthHeight);

			if (WidthDepthHeight != WIDTH_DEPTH_HEIGHT)
				__debugbreak();

			for (int voxel_y = 0; voxel_y < (int)WIDTH_DEPTH_HEIGHT; voxel_y++)
			{
				int pixel_y = obj_y * (int)WIDTH_DEPTH_HEIGHT + voxel_y;
				int r_pixel_y = (int)m_Height - pixel_y - 1;
				if (r_pixel_y < 0)
					__debugbreak();

				if (r_pixel_y >= (int)m_Height)
					__debugbreak();

				for (int voxel_x = 0; voxel_x < (int)WIDTH_DEPTH_HEIGHT; voxel_x++)
				{
					int pixel_x = obj_x * (int)WIDTH_DEPTH_HEIGHT + voxel_x;

					for (int voxel_z = (int)dwLayerStart; voxel_z < (int)(dwLayerStart + dwLayerCount); voxel_z++)
					{
						DWORD 	dwVoxelIndex = (DWORD)voxel_x + (DWORD)voxel_z * WIDTH_DEPTH_HEIGHT + (DWORD)voxel_y * WIDTH_DEPTH_HEIGHT * WIDTH_DEPTH_HEIGHT;
						DWORD 	dwPixelIndex = (DWORD)pixel_x + (DWORD)r_pixel_y * m_Width;
						BYTE*	pBits = m_ppBits[voxel_z];
						BYTE	bColorIndex = pBits[dwPixelIndex];
						pColorTable[dwVoxelIndex] = bColorIndex;

						unsigned long	BitIndex = voxel_x + voxel_z * WIDTH_DEPTH_HEIGHT + voxel_y * WIDTH_DEPTH_HEIGHT * WIDTH_DEPTH_HEIGHT;
						unsigned long	OldBit = BTGet(pBitTable, BitIndex);
						unsigned long	NewBit = 1;
						if (bColorIndex == 0xff)
						{
							NewBit = 0;
						}
						if (OldBit != NewBit)
						{
							BTSet(pBitTable, BitIndex, NewBit);
							bVoxelObjBitTableModified = TRUE;
						}
						else
						{
							int a = 0;
						}
					}
				}
			}
			pVoxelObj->SetColorTable(pColorTable, WIDTH_DEPTH_HEIGHT);
			if (bVoxelObjBitTableModified)
			{
				pVoxelObj->SetBitTable(pBitTable, WIDTH_DEPTH_HEIGHT, FALSE);
			}
			else
			{
				int a = 0;
			}
		}
	}
}

void CDisplayPanel::UpdateBitmapToVoxelDataWithSingleLayer(int voxel_z, DWORD dwLayerIndex)
{
	const UINT WIDTH_DEPTH_HEIGHT = MAX_VOXELS_PER_AXIS;
	BYTE	pColorTable[MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS] = {};

	for (DWORD obj_y = 0; obj_y < m_VoxelObjHeight; obj_y++)
	{
		for (DWORD obj_x = 0; obj_x < m_VoxelObjWidth; obj_x++)
		{
			IVoxelObjectLite* pVoxelObj = m_ppVoxelObjList[obj_x + m_VoxelObjWidth * obj_y];

			for (int voxel_y = 0; voxel_y < (int)WIDTH_DEPTH_HEIGHT; voxel_y++)
			{
				int pixel_y = obj_y * (int)WIDTH_DEPTH_HEIGHT + voxel_y;
				int r_pixel_y = (int)m_Height - pixel_y - 1;
				if (r_pixel_y < 0)
					__debugbreak();

				if (r_pixel_y >= (int)m_Height)
					__debugbreak();

				for (int voxel_x = 0; voxel_x < (int)WIDTH_DEPTH_HEIGHT; voxel_x++)
				{
					int pixel_x = obj_x * (int)WIDTH_DEPTH_HEIGHT + voxel_x;

					DWORD 	dwVoxelIndex = (DWORD)voxel_x + (DWORD)voxel_z * WIDTH_DEPTH_HEIGHT + (DWORD)voxel_y * WIDTH_DEPTH_HEIGHT * WIDTH_DEPTH_HEIGHT;
					DWORD 	dwPixelIndex = (DWORD)pixel_x + (DWORD)r_pixel_y * m_Width;
					BYTE*	pBits = m_ppBits[dwLayerIndex];
					BYTE	bColorIndex = pBits[dwPixelIndex];
					pColorTable[dwVoxelIndex] = bColorIndex;
				}
			}
			pVoxelObj->SetColorTable(pColorTable, WIDTH_DEPTH_HEIGHT);
		}
	}
}

void CDisplayPanel::Cleanup()
{
	if (m_ppVoxelObjList)
	{
		for (UINT y = 0; y < m_VoxelObjHeight; y++)
		{
			for (UINT x = 0; x < m_VoxelObjWidth; x++)
			{
				IVoxelObjectLite* pVoxelObj = m_ppVoxelObjList[y * m_VoxelObjWidth + x];
				if (pVoxelObj)
				{
					m_pVHController->DeleteVoxelObject(pVoxelObj);
				}
				else
				{
					int a = 0;
				}
				m_ppVoxelObjList[y * m_VoxelObjWidth + x] = nullptr;
			}
		}
		delete[] m_ppVoxelObjList;
		m_ppVoxelObjList = nullptr;
	}
	for (DWORD i = 0; i < m_dwLayerCount; i++)
	{
		if (m_ppBits[i])
		{
			delete[] m_ppBits[i];
			m_ppBits[i] = nullptr;
		}
	}
}
CDisplayPanel::~CDisplayPanel()
{
	Cleanup();
}

/*
void CDisplayPanel::UpdateBitmapToVoxelData()
{
	//
	//SetVoxelColor대신 오브젝트 하나를 한번에 바꾸는 방식으로 수정할 것
	//
	DWORD dwVoxelObjX = 0;
	DWORD dwVoxelObjY = 0;

	for (int y = 0; y < (int)m_Height; y++)
	{
		for (int x = 0; x < (int)m_Width; x++)
		{
			BYTE bColorIndex = m_pBits[x + y * m_Width];

			int reverse_y = (int)m_Height - y - 1;

			DWORD dwVoxelObjY = reverse_y / MAX_VOXELS_PER_AXIS;
			DWORD dwVoxelPosY = reverse_y % MAX_VOXELS_PER_AXIS;

			DWORD dwVoxelObjX = x / MAX_VOXELS_PER_AXIS;
			DWORD dwVoxelPosX = x % MAX_VOXELS_PER_AXIS;

			IVoxelObjectLite* pVoxelObj = m_ppVoxelObjList[dwVoxelObjX + m_VoxelObjWidth * dwVoxelObjY];
			pVoxelObj->SetVoxelColor((int)dwVoxelPosX, (int)dwVoxelPosY, 0, bColorIndex);
		}
	}
}
*/