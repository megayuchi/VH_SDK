#include "stdafx.h"
#include <crtdbg.h>
#include <Windows.h>
#include "../include/typedef.h"
#include "ImageData.h"

CImageData::CImageData()
{
}
BOOL CImageData::CreateFromPalettedImage(const BYTE* pSrcBits, DWORD dwWidth, DWORD dwHeight, BYTE bColorKeyIndex)
{

	DWORD	dwWorkingMemSize = sizeof(PIXEL_STREAM) * dwWidth * dwHeight;
	BYTE*	pWorkingMemory = (BYTE*)malloc(dwWorkingMemSize);
	memset(pWorkingMemory, 0, dwWorkingMemSize);

	COMPRESSED_LINE*	pLineList = (COMPRESSED_LINE*)malloc(sizeof(COMPRESSED_LINE) * dwHeight);
	const BYTE*	pSrcEntry = pSrcBits;
	const BYTE* pDestEntry = pWorkingMemory;
	DWORD	dwUsedMemSize = 0;
	for (DWORD i = 0; i < dwHeight; i++)
	{
		DWORD	dwStreamNumPerLine = CreatePerLineFromPalettedImage(pDestEntry, dwWorkingMemSize, pSrcEntry, dwWidth, bColorKeyIndex);

		DWORD	dwLineMemSize = sizeof(PIXEL_STREAM) * dwStreamNumPerLine;
		pSrcEntry += (dwWidth);

		DWORD dwOffset = (DWORD)((DWORD_PTR)pDestEntry - (DWORD_PTR)pWorkingMemory);
		if ((int)dwWorkingMemSize - (int)dwLineMemSize < 0)
			__debugbreak();

		dwWorkingMemSize -= dwLineMemSize;
		dwUsedMemSize += dwLineMemSize;
		pDestEntry += dwLineMemSize;
		pLineList[i].dwLineDataSize = dwLineMemSize;
		pLineList[i].dwStreamNum = dwStreamNumPerLine;
		pLineList[i].dwOffset = dwOffset;
	}

	// 수집한 픽셀 스트림과 각 라인의 디스크립터가 되는 COMPRESSED_LINE메모리를 한번에 할당한다.
	dwUsedMemSize += sizeof(COMPRESSED_LINE) * dwHeight;
	m_pCompressedImage = (COMPRESSED_LINE*)malloc(dwUsedMemSize);
	BYTE*	pPixelStreamDataEntry = (BYTE*)m_pCompressedImage + sizeof(COMPRESSED_LINE) * dwHeight;

	for (DWORD i = 0; i < dwHeight; i++)
	{
		BYTE*	pSrcPixelStreamData = pWorkingMemory + pLineList[i].dwOffset;	// 앞서 수집한 픽셀 스트림이 저장된 메모리
		pLineList[i].pPixelStream = (PIXEL_STREAM*)pPixelStreamDataEntry;					// 써넣을 메모리
		memcpy(pPixelStreamDataEntry, pSrcPixelStreamData, pLineList[i].dwLineDataSize);	// 수집한 픽셀 스트림을 확정된 메모리로 카피.
		pPixelStreamDataEntry += pLineList[i].dwLineDataSize;
	}
	memcpy(m_pCompressedImage, pLineList, sizeof(COMPRESSED_LINE) * dwHeight);

	free(pWorkingMemory);
	free(pLineList);

	m_dwWidth = dwWidth;
	m_dwHeight = dwHeight;
	m_bCompressed = TRUE;
#ifdef _DEBUG
	_ASSERT(_CrtCheckMemory());
#endif
	return TRUE;
}

DWORD CImageData::CreatePerLineFromPalettedImage(const BYTE* pDest, int iMaxMemSize, const BYTE* pSrcBits, DWORD dwWidth, BYTE bColorKeyIndex)
{
	PIXEL_STREAM*	pStreamList = (PIXEL_STREAM*)pDest;
	DWORD	dwStreamCount = 0;
	BOOL	bStarted = FALSE;

	DWORD x = 0;

	while (x < dwWidth)
	{
		// 컬러키가 아닌 픽셀을 만날때까지 x축으로 진행
		while (pSrcBits[x] == bColorKeyIndex)
		{
			x++;
			if (x >= dwWidth)
			{
				goto lb_return;
			}
			
		}
		BYTE bCurPixel = pSrcBits[x];

		if (iMaxMemSize - sizeof(PIXEL_STREAM) < 0)
			__debugbreak();

		pStreamList[dwStreamCount].wPosX = (WORD)x;
		pStreamList[dwStreamCount].bPixel = bCurPixel;
		iMaxMemSize -= sizeof(PIXEL_STREAM);

		// 현재 픽셀과 다른 픽셀(컬러키 포함)을 만날때까지 진행
		while (x < dwWidth && pSrcBits[x] == bCurPixel)
		{
			pStreamList[dwStreamCount].wPixelNum++;
			x++;
		}
		dwStreamCount++;
	}
	
lb_return:
	return dwStreamCount;
}

void CImageData::SetPalettedImage(BYTE* pBits, DWORD dwWidth, DWORD dwHeight, BYTE bColorKeyIndex)
{
	m_pUncompressedPalettedImage = pBits;
	m_dwWidth = dwWidth;
	m_dwHeight = dwHeight;
	m_bColorKeyIndex = bColorKeyIndex;
	m_bCompressed = FALSE;
}
CImageData::~CImageData()
{
	if (m_pCompressedImage)
	{
		free(m_pCompressedImage);
		m_pCompressedImage = nullptr;
	}
	if (m_pUncompressedPalettedImage)
	{
		free(m_pUncompressedPalettedImage);
		m_pUncompressedPalettedImage = nullptr;
	}
}
