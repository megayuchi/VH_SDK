#include "stdafx.h"
#include "../include/typedef.h"
#include "../include/BooleanTable.inl"
#include "VoxelUtil.h"

BOOL GetVoxelValue(const unsigned long* pBitTable, UINT WidthDepthHeight, DWORD x, DWORD y, DWORD z)
{
	unsigned long Index = x + z * WidthDepthHeight + y * WidthDepthHeight * WidthDepthHeight;
	BOOL	bValue = BTGet(pBitTable, Index);
	return bValue;
}
void SetVoxelValueAsTrue(unsigned long* pBitTable, UINT WidthDepthHeight, DWORD x, DWORD y, DWORD z)
{
	unsigned long Index = x + z * WidthDepthHeight + y * WidthDepthHeight * WidthDepthHeight;
	BTSetBit(pBitTable, Index);
}
void SetVoxelValue(unsigned long* pBitTable, UINT WidthDepthHeight, DWORD x, DWORD y, DWORD z, unsigned long value)
{
	unsigned long Index = x + z * WidthDepthHeight + y * WidthDepthHeight * WidthDepthHeight;
	BTSet(pBitTable, Index, value);
}
void ClearVoxelValue(unsigned long* pBitTable, UINT WidthDepthHeight, DWORD x, DWORD y, DWORD z)
{
	unsigned long Index = x + z * WidthDepthHeight + y * WidthDepthHeight * WidthDepthHeight;
	BTClearBit(pBitTable, Index);
}
BYTE GetVoxelColor(const BYTE* pColorTable, UINT WidthDepthHeight, int x, int y, int z)
{
	BYTE	Color = pColorTable[x + (z * WidthDepthHeight) + (y * WidthDepthHeight * WidthDepthHeight)];
	return Color;
}
void SetVoxelColor(BYTE* pDestColorTable, UINT WidthDepthHeight, int x, int y, int z, BYTE ColorIndex)
{
	pDestColorTable[x + (z * WidthDepthHeight) + (y * WidthDepthHeight * WidthDepthHeight)] = ColorIndex;
}
DWORD GetVoxelsCount(const unsigned long* pBitTable, UINT WidthDepthHeight)
{
	DWORD	dwVoxelsCount = BTGetBitCount(pBitTable, WidthDepthHeight * WidthDepthHeight * WidthDepthHeight);
	return dwVoxelsCount;
}
void UpScaleVoxels(unsigned long* pDestBitTable, UINT DestWidthDepthHeight, const unsigned long* pSrcBitTable, UINT SrcWidthDepthHeight)
{
	// Upscale
	// OldWidthDepthHeight = 1
	// m_WidthDepthHeight = 8
	DWORD	scale = DestWidthDepthHeight / SrcWidthDepthHeight;
	for (DWORD y = 0; y < DestWidthDepthHeight; y++)
	{
		for (DWORD z = 0; z < DestWidthDepthHeight; z++)
		{
			for (DWORD x = 0; x < DestWidthDepthHeight; x++)
			{
				BOOL	value = GetVoxelValue(pSrcBitTable, SrcWidthDepthHeight, x / scale, y / scale, z / scale);
				SetVoxelValue(pDestBitTable, DestWidthDepthHeight, x, y, z, value);
			}
		}
	}
}
void UpScaleVoxelsAndColorTable(unsigned long* pDestBitTable, BYTE* pDestColorTable, UINT DestWidthDepthHeight, const unsigned long* pSrcBitTable, const BYTE* pSrcColorTable, UINT SrcWidthDepthHeight)
{
	// Upscale
	// OldWidthDepthHeight = 1
	// m_WidthDepthHeight = 8
	DWORD	scale = DestWidthDepthHeight / SrcWidthDepthHeight;
	for (DWORD y = 0; y < DestWidthDepthHeight; y++)
	{
		for (DWORD z = 0; z < DestWidthDepthHeight; z++)
		{
			for (DWORD x = 0; x < DestWidthDepthHeight; x++)
			{
				BOOL	value = GetVoxelValue(pSrcBitTable, SrcWidthDepthHeight, x / scale, y / scale, z / scale);
				BYTE	Color = GetVoxelColor(pSrcColorTable, SrcWidthDepthHeight, x / scale, y / scale, z / scale);
				SetVoxelValue(pDestBitTable, DestWidthDepthHeight, x, y, z, value);
				SetVoxelColor(pDestColorTable, DestWidthDepthHeight, x, y, z, Color);
			}
		}
	}
}