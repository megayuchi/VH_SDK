#pragma once

class CDisplayPanel;
class CImageData;

#define COLOR_VALUE_WHITE						0xFFFFFFFF
#define COLOR_VALUE_GRAY						0xFF808080
#define COLOR_VALUE_RED							0xFFFF0000
#define COLOR_VALUE_GREEN						0xFF00FF00
#define COLOR_VALUE_BLUE						0xFF0000FF
#define COLOR_VALUE_YELLOW						0xFFFFD52B
#define COLOR_VALUE_CYAN						0xFF00FFFF

#define COLOR_VALUE_GOLD						0xFFFFD700
#define COLOR_VALUE_ORANGE						0xFFFF8A00
#define COLOR_VALUE_DARK_ORANGE					0xFFFF8C00

#define COLOR_VALUE_PLUM						0xFFDDA0DD
#define COLOR_VALUE_VIOLET						0xFFEE82EE
#define COLOR_VALUE_ORCHID						0xFFDA70D6
#define COLOR_VALUE_FUCHSIA						0xFFFF00FF
#define COLOR_VALUE_MAGENTA						0xFFFF00FF
#define COLOR_VALUE_MEDIUM_ORCHID				0xFFBA55D3
#define COLOR_VALUE_MEDIUM_PURPLE				0xFF9370DB
#define COLOR_VALUE_DARK_VIOLET					0xFF9400D3
#define COLOR_VALUE_DARK_ORCHID					0xFF9932CC
#define COLOR_VALUE_DARK_MAGENTA				0xFF8B008B
#define COLOR_VALUE_PURPLE						0xFF800080
#define COLOR_vALUE_INDIGO						0xFF4B0082

size_t GetFileSize(FILE* fp);
BOOL CalcClipArea(INT_VECTOR2* pivOutSrcStart, INT_VECTOR2* pivOutDestStart, INT_VECTOR2* pivOutDestSize, const INT_VECTOR2* pivPos, const INT_VECTOR2* pivImageSize, const INT_VECTOR2* pivBufferSize);
BOOL IsCollisionRectVsRect(const INT_VECTOR2* pv3MinA, const INT_VECTOR2* pv3MaxA, const INT_VECTOR2* pv3MinB, const INT_VECTOR2* pv3MaxB);
BOOL LoadPngImage(BYTE** ppOutBits, DWORD* pdwOutWidth, DWORD* pdwOutHeight, DWORD* pdwOutColorKey, const char* szFileName);
void FreePngImage(BYTE* pBits);
BOOL LoadPngImageAsPalettedImage(BYTE** ppOutBits, DWORD* pdwOutWidth, DWORD* pdwOutHeight, DWORD* pdwOutColorKey, const char* szFileName, CDisplayPanel* pDisplayPanel);
void FreePalettedImage(BYTE* pBits);

CImageData* CreateImageData(const char* szFileName, CDisplayPanel* pDisplayPanel, const WCHAR* wchPluginPath, BOOL bCompress);

BYTE Convert32BitsColorToPaletteIndexRGBA_Normal(const DWORD* pdwColorTable, DWORD dwColorTableCount, DWORD dwSrcColor);
BYTE Convert32BitsColorToPaletteIndexRGBA_SSE(const DWORD* pdwColorTable, DWORD dwColorTableCount, DWORD dwSrcColor);
BYTE Convert32BitsColorToPaletteIndexBGRA_Normal(const DWORD* pdwColorTable, DWORD dwColorTableCount, DWORD dwSrcColor);
BYTE Convert32BitsColorToPaletteIndexBGRA_SSE(const DWORD* pdwColorTable, DWORD dwColorTableCount, DWORD dwSrcColor);
