#include "stdafx.h"
#include "../include/typedef.h"
#include "../util/Stack.h"
#include "Util.h"
#include "./lodepng/lodepng.h"
#include "DisplayPanel.h"
#include "ImageData.h"


size_t GetFileSize(FILE* fp)
{
	size_t OldPos = ftell(fp);

	fseek(fp, 0, SEEK_END);
	size_t Size = ftell(fp);

	fseek(fp, OldPos, SEEK_SET);

	return Size;
}
BOOL CalcClipArea(INT_VECTOR2* pivOutSrcStart, INT_VECTOR2* pivOutDestStart, INT_VECTOR2* pivOutDestSize, const INT_VECTOR2* pivPos, const INT_VECTOR2* pivImageSize, const INT_VECTOR2* pivBufferSize)
{
	BOOL	bResult = FALSE;
	//
	int dest_start_x = max(pivPos->x, 0);
	int dest_start_y = max(pivPos->y, 0);
	dest_start_x = min(dest_start_x, pivBufferSize->x);
	dest_start_y = min(dest_start_y, pivBufferSize->y);

	int dest_end_x = max(pivPos->x + pivImageSize->x, 0);
	int dest_end_y = max(pivPos->y + pivImageSize->y, 0);
	dest_end_x = min(dest_end_x, pivBufferSize->x);
	dest_end_y = min(dest_end_y, pivBufferSize->y);

	int	width = dest_end_x - dest_start_x;
	int	height = dest_end_y - dest_start_y;

	if (width <= 0 || height <= 0)
		goto lb_return;

	int src_start_x = dest_start_x - pivPos->x;
	int src_start_y = dest_start_y - pivPos->y;
	pivOutSrcStart->x = src_start_x;
	pivOutSrcStart->y = src_start_y;
	pivOutDestStart->x = dest_start_x;
	pivOutDestStart->y = dest_start_y;
	pivOutDestSize->x = width;
	pivOutDestSize->y = height;
	bResult = TRUE;
lb_return:
	return bResult;
}


BOOL IsCollisionRectVsRect(const INT_VECTOR2* pv3MinA, const INT_VECTOR2* pv3MaxA, const INT_VECTOR2* pv3MinB, const INT_VECTOR2* pv3MaxB)
{
	const int*	a_min = &pv3MinA->x;
	const int*	a_max = &pv3MaxA->x;
	const int*	b_min = &pv3MinB->x;
	const int*	b_max = &pv3MaxB->x;

	for (DWORD i = 0; i < 2; i++)
	{
		if (a_min[i] > b_max[i] || a_max[i] < b_min[i])
		{
			return FALSE;
		}
	}
	return TRUE;
}
void CalcRect(INT_RECT2* pOutRect, const BYTE* pSrcData, int iWidth, int iHeight, int iPitch)
{
	INT_VECTOR2 ivMin = { INT_MAX, INT_MAX };
	INT_VECTOR2 ivMax = { INT_MIN, INT_MIN };
	
	for (int y = 0; y < iHeight; y++)
	{
		for (int x = 0; x < iWidth; x++)
		{
			BYTE bValue = pSrcData[x + y * iPitch];
			if (bValue != 0xff)
			{
				ivMin.x = min(ivMin.x, x);
				ivMin.y = min(ivMin.y, y);
				ivMax.x = max(ivMax.x, x);
				ivMax.y = max(ivMax.y, y);
			}
		}
	}
	pOutRect->min = ivMin;
	pOutRect->max = ivMax;
}
BOOL LoadPngImage(BYTE** ppOutBits, DWORD* pdwOutWidth, DWORD* pdwOutHeight, DWORD* pdwOutColorKey, const char* szFileName)
{
	BOOL	bResult = FALSE;

	BYTE*	pRGB = NULL;
	DWORD	dwImageWidth = 0;
	DWORD	dwImageHeight = 0;
	DWORD	dwSrcPitch = 0;
	DWORD	dwSrcBPP = 0;
	FILE*	fp = NULL;
	fopen_s(&fp, szFileName, "rb");
	if (fp)
	{
		size_t FileSize = GetFileSize(fp);
		BYTE*	pStream = (BYTE*)malloc(FileSize);
		fread(pStream, FileSize, 1, fp);

		//error = lodepng_decode32(&pRGB, (unsigned int*)&g_dwImageWidth, (unsigned int*)&g_dwImageHeight,pStream,FileSize);
		//LCT_RGB
		//LCT_RGBA
		LodePNGState	state;
		size_t size = sizeof(state);
		lodepng_state_init(&state);
		state.decoder.color_convert = 0;


		unsigned int error;
		error = lodepng_decode(&pRGB, (unsigned int*)&dwImageWidth, (unsigned int*)&dwImageHeight, &state, pStream, FileSize);
		if (error)
		{
			printf("decoder error %u: %s\n", error, lodepng_error_text(error));
			__debugbreak();
		}

		if (LCT_RGB == state.info_raw.colortype)
		{
			dwSrcBPP = 3;
		}
		else if (LCT_RGBA == state.info_raw.colortype)
		{
			dwSrcBPP = 4;
		}
		else
		{
			__debugbreak();
		}

		free(pStream);
		fclose(fp);
	}
	if (pRGB)
	{
		*ppOutBits = pRGB;
		*pdwOutWidth = dwImageWidth;
		*pdwOutHeight = dwImageHeight;
		*pdwOutColorKey = *(DWORD*)pRGB;
		bResult = TRUE;
	}
	return bResult;
}
void FreePngImage(BYTE* pBits)
{
	free(pBits);
}


BOOL LoadPngImageAsPalettedImage(BYTE** ppOutBits, DWORD* pdwOutWidth, DWORD* pdwOutHeight, DWORD* pdwOutColorKey, const char* szFileName, CDisplayPanel* pDisplayPanel)
{
	BOOL	bResult = FALSE;

	DWORD	dwImageWidth = 0;
	DWORD	dwImageHeight = 0;
	DWORD*	pRGBABits = nullptr;
	BYTE*	pPalettedImage = nullptr;
	if (LoadPngImage((BYTE**)&pRGBABits, &dwImageWidth, &dwImageHeight, pdwOutColorKey, szFileName))
	{
		pPalettedImage = (BYTE*)malloc(dwImageWidth * dwImageHeight);
		pDisplayPanel->Convert32BitsImageTo8BitsPalettedImageRGBA(pPalettedImage, pRGBABits, dwImageWidth, dwImageHeight);
		free(pRGBABits);
		pRGBABits = nullptr;

		*ppOutBits = pPalettedImage;
		*pdwOutWidth = dwImageWidth;
		*pdwOutHeight = dwImageHeight;
		bResult = TRUE;
	}

	return bResult;
}
void FreePalettedImage(BYTE* pBits)
{
	free(pBits);
}

CImageData* CreateImageData(const char* szFileName, CDisplayPanel* pDisplayPanel, const WCHAR* wchPluginPath, BOOL bCompress)
{
	WCHAR	wchOldPath[_MAX_PATH] = {};
	GetCurrentDirectory(_MAX_PATH, wchOldPath);

	SetCurrentDirectory(wchPluginPath);

	CImageData*	pImgageData = nullptr;

	BYTE*	pRGBABits = nullptr;
	DWORD	dwImageWidth = 0;
	DWORD	dwImageHeight = 0;
	DWORD	dwColorKey = 0;
	BYTE	bColorKeyIndex = 255;
	BYTE* pPalettedImage = nullptr;
	if (LoadPngImage(&pRGBABits, &dwImageWidth, &dwImageHeight, &dwColorKey, szFileName))
	{
		pPalettedImage = (BYTE*)malloc(dwImageWidth * dwImageHeight);
		pDisplayPanel->Convert32BitsImageTo8BitsPalettedImageRGBA(pPalettedImage, (DWORD*)pRGBABits, dwImageWidth, dwImageHeight);
		bColorKeyIndex = pDisplayPanel->Convert32BitsColorToPaletteIndexRGBA(dwColorKey);

		free(pRGBABits);
		pRGBABits = nullptr;

		pImgageData = new CImageData;
		if (bCompress)
		{
			pImgageData->CreateFromPalettedImage(pPalettedImage, dwImageWidth, dwImageHeight, bColorKeyIndex);
		}
		else
		{
			pImgageData->SetPalettedImage(pPalettedImage, dwImageWidth, dwImageHeight, bColorKeyIndex);
		}
		
	}

	SetCurrentDirectory(wchOldPath);
	return pImgageData;
}

BYTE Convert32BitsColorToPaletteIndexRGBA_Normal(const DWORD* pdwColorTable, DWORD dwColorTableCount, DWORD dwSrcColor)
{
	// r = (dwSrcColor & 0x000000ff);
	// g = (dwSrcColor & 0x0000ff00) >> 8;
	// b = (dwSrcColor & 0x00ff0000) >> 16;

	DWORD	dwSelectedIndex = 0;
	float min_dist = (float)INT_MAX;
	for (DWORD i = 0; i < dwColorTableCount; i++)
	{
		DWORD	dwDestColor = pdwColorTable[i];
		
		float sb = (float)((dwSrcColor & 0x00ff0000) >> 16);
		float sg = (float)((dwSrcColor & 0x0000ff00) >> 8);
		float sr = (float)((dwSrcColor & 0x000000ff));
		
		float dr = (float)((dwDestColor & 0x00ff0000) >> 16);
		float dg = (float)((dwDestColor & 0x0000ff00) >> 8);
		float db = (float)((dwDestColor & 0x000000ff));

		float r_diff = sr - dr;
		float g_diff = sg - dg;
		float b_diff = sb - db;

		float dist = sqrtf(r_diff * r_diff + g_diff * g_diff + b_diff * b_diff);
		if (min_dist > dist)
		{
			min_dist = dist;
			dwSelectedIndex = i;
		}
	}
	return (BYTE)dwSelectedIndex;
}

BYTE Convert32BitsColorToPaletteIndexRGBA_SSE(const DWORD* pdwColorTable, DWORD dwColorTableCount, DWORD dwSrcColor)
{
	//
	//  float color table을 미리 만들어두자.
	//
	// r = (dwSrcColor & 0x000000ff);
	// g = (dwSrcColor & 0x0000ff00) >> 8;
	// b = (dwSrcColor & 0x00ff0000) >> 16;
	__m128i src_dword = _mm_setr_epi32((dwSrcColor & 0x000000ff), (dwSrcColor & 0x0000ff00) >> 8, (dwSrcColor & 0x00ff0000) >> 16, 0);	// x | b | g| r |
	__m128 src_float = _mm_cvtepi32_ps(src_dword);

	DWORD	dwSelectedIndex = 0;
	DWORD	dwSelectedIndex1 = 0;
	float min_dist = (float)INT_MAX;

	for (DWORD i = 0; i < dwColorTableCount; i++)
	{
		// r = (dwDestColor & 0x00ff0000) >> 16;
		// g = (dwDestColor & 0x0000ff00) >> 8;
		// b = (dwDestColor & 0x000000ff) >> 0;
		DWORD	dwDestColor = pdwColorTable[i];
		__m128i dest_dword = _mm_setr_epi32((dwDestColor & 0x00ff0000) >> 16, (dwDestColor & 0x0000ff00) >> 8, (dwDestColor & 0x000000ff), 0);	// x | b | g| r |
		__m128 dest_float = _mm_cvtepi32_ps(dest_dword);

		__m128 diff = _mm_sub_ps(src_float, dest_float);
		__m128 diffxdiff = _mm_mul_ps(diff, diff);
		__m128 diff_s = _mm_hadd_ps(diffxdiff, diffxdiff);
		diff_s = _mm_hadd_ps(diff_s, diff_s);
		__m128 dist = _mm_sqrt_ss(diff_s);

		if (min_dist > dist.m128_f32[0])
		{
			dwSelectedIndex = i;
			min_dist = dist.m128_f32[0];
		}
	}
	return (BYTE)dwSelectedIndex;
}

BYTE Convert32BitsColorToPaletteIndexBGRA_Normal(const DWORD* pdwColorTable, DWORD dwColorTableCount, DWORD dwSrcColor)
{
	// r = (dwSrcColor & 0x00ff0000) >> 16;
	// g = (dwSrcColor & 0x0000ff00) >> 8;
	// b = (dwSrcColor & 0x000000ff);

	DWORD	dwSelectedIndex = 0;
	float min_dist = (float)INT_MAX;
	for (DWORD i = 0; i < dwColorTableCount; i++)
	{
		DWORD	dwDestColor = pdwColorTable[i];
		
		float sr = (float)((dwSrcColor & 0x00ff0000) >> 16);
		float sg = (float)((dwSrcColor & 0x0000ff00) >> 8);
		float sb = (float)((dwSrcColor & 0x000000ff));
		
		float dr = (float)((dwDestColor & 0x00ff0000) >> 16);
		float dg = (float)((dwDestColor & 0x0000ff00) >> 8);
		float db = (float)((dwDestColor & 0x000000ff));

		float r_diff = sr - dr;
		float g_diff = sg - dg;
		float b_diff = sb - db;

		float dist = sqrtf(r_diff * r_diff + g_diff * g_diff + b_diff * b_diff);
		if (min_dist > dist)
		{
			min_dist = dist;
			dwSelectedIndex = i;
		}
	}
	return (BYTE)dwSelectedIndex;
}
BYTE Convert32BitsColorToPaletteIndexBGRA_SSE(const DWORD* pdwColorTable, DWORD dwColorTableCount, DWORD dwSrcColor)
{
	//
	//  float color table을 미리 만들어두자.
	//
	// r = (dwSrcColor & 0x00ff0000) >> 16;
	// g = (dwSrcColor & 0x0000ff00) >> 8;
	// b = (dwSrcColor & 0x000000ff);
	__m128i src_dword = _mm_setr_epi32((dwSrcColor & 0x00ff0000) >> 16, (dwSrcColor & 0x0000ff00) >> 8, (dwSrcColor & 0x000000ff), 0);	// x | b | g| r |
	__m128 src_float = _mm_cvtepi32_ps(src_dword);

	DWORD	dwSelectedIndex = 0;
	DWORD	dwSelectedIndex1 = 0;
	float min_dist = (float)INT_MAX;

	for (DWORD i = 0; i < dwColorTableCount; i++)
	{
		// r = (dwDestColor & 0x00ff0000) >> 16;
		// g = (dwDestColor & 0x0000ff00) >> 8;
		// b = (dwDestColor & 0x000000ff) >> 0;
		DWORD	dwDestColor = pdwColorTable[i];
		__m128i dest_dword = _mm_setr_epi32((dwDestColor & 0x00ff0000) >> 16, (dwDestColor & 0x0000ff00) >> 8, (dwDestColor & 0x000000ff), 0);	// x | b | g| r |
		__m128 dest_float = _mm_cvtepi32_ps(dest_dword);

		__m128 diff = _mm_sub_ps(src_float, dest_float);
		__m128 diffxdiff = _mm_mul_ps(diff, diff);
		__m128 diff_s = _mm_hadd_ps(diffxdiff, diffxdiff);
		diff_s = _mm_hadd_ps(diff_s, diff_s);
		__m128 dist = _mm_sqrt_ss(diff_s);

		if (min_dist > dist.m128_f32[0])
		{
			dwSelectedIndex = i;
			min_dist = dist.m128_f32[0];
		}
	}
	return (BYTE)dwSelectedIndex;
}


void DownSample_FPU(DWORD* pDest, DWORD* pSrc, unsigned int SrcWidth, unsigned SrcHeight)
{
	// 반드시 다음이 성립해야 함.
	// dest_width = src_width / 2;
	// dest_height = src_height / 2;
	
	unsigned int Width = SrcWidth >> 1;
	unsigned int Height = SrcHeight >> 1;

	DWORD	px[4];
	for (unsigned int y = 0; y < Height; y++)
	{
		for (unsigned int x = 0; x < Width; x++)
		{
			px[0] = pSrc[(y << 1) * SrcWidth + (x << 1) + 0];
			px[1] = pSrc[(y << 1) * SrcWidth + (x << 1) + 1];
			px[2] = pSrc[((y << 1) + 1) * SrcWidth + (x << 1) + 0];
			px[3] = pSrc[((y << 1) + 1) * SrcWidth + (x << 1) + 1];

			DWORD c3 = (((px[0] & 0xff000000) >> 24) + ((px[1] & 0xff000000) >> 24) + ((px[2] & 0xff000000) >> 24) + ((px[3] & 0xff000000) >> 24)) / 4;
			DWORD c2 = (((px[0] & 0x00ff0000) >> 16) + ((px[1] & 0x00ff0000) >> 16) + ((px[2] & 0x00ff0000) >> 16) + ((px[3] & 0x00ff0000) >> 16)) / 4;
			DWORD c1 = (((px[0] & 0x0000ff00) >> 8) + ((px[1] & 0x0000ff00) >> 8) + ((px[2] & 0x0000ff00) >> 8) + ((px[3] & 0x0000ff00) >> 8)) / 4;
			DWORD c0 = (((px[0] & 0x000000ff) >> 0) + ((px[1] & 0x000000ff) >> 0) + ((px[2] & 0x000000ff) >> 0) + ((px[3] & 0x000000ff) >> 0)) / 4;
			pDest[y * Width + x] = (c3 << 24) | (c2 << 16) | (c1 << 8) | c0;;
		}
	}
}

int static CompareFunc(const void* first, const void* second)
{
	MIDI_MESSAGE* pFirstMessage = (MIDI_MESSAGE*)first;
	MIDI_MESSAGE* pSecondMessage = (MIDI_MESSAGE*)second;

	if (pFirstMessage->GetTickFromBegin() > pSecondMessage->GetTickFromBegin())
		return 1;
	else if (pFirstMessage->GetTickFromBegin() < pSecondMessage->GetTickFromBegin())
		return -1;
	else
		return 0;
}

void SortMidiMessageList(MIDI_MESSAGE* pArray, DWORD dwNum)
{
	qsort(pArray, dwNum, sizeof(MIDI_MESSAGE), CompareFunc);
	int a = 0;
}