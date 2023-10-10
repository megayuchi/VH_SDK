#pragma once


#pragma pack(push,4)
struct PIXEL_STREAM
{
	WORD	wPosX;
	WORD	wPixelNum;
	BYTE	bPixel;
	BYTE	bReserved0;
	BYTE	bReserved1;
	BYTE	bReserved2;
};
#pragma pack(pop)
struct COMPRESSED_LINE
{
	DWORD	dwStreamNum;
	DWORD	dwLineDataSize;
	union
	{
		struct
		{
			PIXEL_STREAM*	pPixelStream;
		};
		struct
		{
			DWORD	dwOffset;
		};
	};
};
class CImageData
{
	DWORD	m_dwWidth = 0;
	DWORD	m_dwHeight = 0;
	COMPRESSED_LINE*	m_pCompressedImage = nullptr;
	BYTE*	m_pUncompressedPalettedImage = nullptr;
	BYTE	m_bColorKeyIndex = 255;
	BOOL	m_bCompressed = FALSE;

	DWORD	CreatePerLineFromPalettedImage(const BYTE* pDest, int iMaxMemSize, const BYTE* pSrcBits, DWORD dwWidth, BYTE bColorKeyIndex);
public:
	const COMPRESSED_LINE*	GetCompressedImage(int y) const
	{
	#ifdef _DEBUG
		if (y < 0)
			__debugbreak();
		if (y >= (int)m_dwHeight)
			__debugbreak();
	#endif
		return m_pCompressedImage + y; 
	}
	const BYTE*	GetUncompressedImage() const { return m_pUncompressedPalettedImage; }
	BOOL	CreateFromPalettedImage(const BYTE* pSrcBits, DWORD dwWidth, DWORD dwHeight, BYTE bColorKeyIndex);
	DWORD	GetWidth() const { return m_dwWidth; }
	DWORD	GetHeight() const { return m_dwHeight; }
	void	SetPalettedImage(BYTE* pBits, DWORD dwWidth, DWORD dwHeight, BYTE bColorKeyIndex);
	CImageData();
	~CImageData();
};