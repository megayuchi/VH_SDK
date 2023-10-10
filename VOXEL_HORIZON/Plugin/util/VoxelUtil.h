#pragma once

#include "../include/typedef.h"
#include "../include/BooleanTable.inl"

BOOL GetVoxelValue(const unsigned long* pBitTable, UINT WidthDepthHeight, DWORD x, DWORD y, DWORD z);
void SetVoxelValueAsTrue(unsigned long* pBitTable, UINT WidthDepthHeight, DWORD x, DWORD y, DWORD z);
void SetVoxelValue(unsigned long* pBitTable, UINT WidthDepthHeight, DWORD x, DWORD y, DWORD z, unsigned long value);
void ClearVoxelValue(unsigned long* pBitTable, UINT WidthDepthHeight, DWORD x, DWORD y, DWORD z);
BYTE GetVoxelColor(const BYTE* pColorTable, UINT WidthDepthHeight, int x, int y, int z);
void SetVoxelColor(BYTE* pDestColorTable, UINT WidthDepthHeight, int x, int y, int z, BYTE ColorIndex);
DWORD GetVoxelsCount(const unsigned long* pBitTable, UINT WidthDepthHeight);
void UpScaleVoxels(unsigned long* pDestBitTable, UINT DestWidthDepthHeight, const unsigned long* pSrcBitTable, UINT SrcWidthDepthHeight);
void UpScaleVoxelsAndColorTable(unsigned long* pDestBitTable, BYTE* pDestColorTable, UINT DestWidthDepthHeight, const unsigned long* pSrcBitTable, const BYTE* pSrcColorTable, UINT SrcWidthDepthHeight);