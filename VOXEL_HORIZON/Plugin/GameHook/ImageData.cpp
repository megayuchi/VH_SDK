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

	// ������ �ȼ� ��Ʈ���� �� ������ ��ũ���Ͱ� �Ǵ� COMPRESSED_LINE�޸𸮸� �ѹ��� �Ҵ��Ѵ�.
	dwUsedMemSize += sizeof(COMPRESSED_LINE) * dwHeight;
	m_pCompressedImage = (COMPRESSED_LINE*)malloc(dwUsedMemSize);
	BYTE*	pPixelStreamDataEntry = (BYTE*)m_pCompressedImage + sizeof(COMPRESSED_LINE) * dwHeight;

	for (DWORD i = 0; i < dwHeight; i++)
	{
		BYTE*	pSrcPixelStreamData = pWorkingMemory + pLineList[i].dwOffset;	// �ռ� ������ �ȼ� ��Ʈ���� ����� �޸�
		pLineList[i].pPixelStream = (PIXEL_STREAM*)pPixelStreamDataEntry;					// ����� �޸�
		memcpy(pPixelStreamDataEntry, pSrcPixelStreamData, pLineList[i].dwLineDataSize);	// ������ �ȼ� ��Ʈ���� Ȯ���� �޸𸮷� ī��.
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
		// �÷�Ű�� �ƴ� �ȼ��� ���������� x������ ����
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

		// ���� �ȼ��� �ٸ� �ȼ�(�÷�Ű ����)�� ���������� ����
		while (pSrcBits[x] == bCurPixel && x < dwWidth)
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
