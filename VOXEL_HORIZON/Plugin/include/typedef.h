#pragma once

#ifdef VH_PLUGIN	// VH_PLUGIN

#include <windows.h>
#include <stdio.h>
#include <Ole2.h>
#include "math.inl"
#include "emul_x86_simd.inl"
#include "emul_x86_generic.inl"

enum SCENE_WORLD_SIZE
{
	SCENE_WORLD_SIZE_DEFAULT = 0,	// 102400 x 102400 
	SCENE_WORLD_SIZE_HALF = 1,	// 51200 x 51200
	SCENE_WORLD_SIZE_QUARTER = 2		// 2500 x 25600
};
#define		DEFAULT_SCENE_MIN_X			-51200.0f
#define		DEFAULT_SCENE_MAX_X			51200.0f
#define		DEFAULT_SCENE_MIN_Z			-51200.0f
#define		DEFAULT_SCENE_MAX_Z			51200.0f

// 복셀 베이스 맵일때 , // 삼각형 베이스 맵일때때도 -2000 아래로 내려가진 않는다.
#define		DEFAULT_SCENE_MIN_Y	-2400.0f
#define		DEFAULT_SCENE_MAX_Y	28000.0f

enum AXIS_TYPE
{

	AXIS_TYPE_NONE = 0,
	AXIS_TYPE_X = 1,
	AXIS_TYPE_Y = 2,
	AXIS_TYPE_Z = 3
};

enum PLANE_AXIS_TYPE
{
	PLANE_AXIS_TYPE_XZ,
	PLANE_AXIS_TYPE_XY,
	PLANE_AXIS_TYPE_YZ,
	PLANE_AXIS_TYPE_COUNT,

};

enum CHAR_CODE_TYPE
{
	CHAR_CODE_TYPE_ASCII = 1,
	CHAR_CODE_TYPE_UNICODE = 2
};

enum RENDER_MODE
{
	RENDER_MODE_SOLID = 0x00000000,
	RENDER_MODE_POINT = 0x00000001,
	RENDER_MODE_WIREFRAME = 0x00000002
};

enum DEBUG_DRAW_FLAG
{
	DEBUG_DRAW_MODEL_COL_MESH = 0x00000001,
	DEBUG_DRAW_BONE_COL_MESH = 0x00000002,
	DEBUG_DRAW_ROOM_MESH = 0x00000004,
	DEBUG_DRAW_HFIELD_COL_MESH = 0x00000008,
	DEBUG_DRAW_CHARACTER_COL_BOX = 0x00000010,
	DEBUG_DRAW_LIGHT_PROBE = 0x00000020
};

enum GET_COLLISION_TRI_TYPE
{
	GET_COLLISION_TRI_TYPE_STRUCT = 0x00000001,
	GET_COLLISION_TRI_TYPE_HFIELD = 0x00000002,
	GET_COLLISION_TRI_TYPE_OBJECT = 0x00000004
};

struct DWORD_RECT
{
	DWORD		left;
	DWORD		top;
	DWORD		right;
	DWORD		bottom;
};
struct FLOAT_RECT
{
	float	fLeft;
	float	fTop;
	float	fRight;
	float	fBottom;
};

union COLORVALUE
{
	struct
	{
		float	b;
		float	g;
		float	r;
		float	a;
	};
	float		value[4];
};
union COLOR3
{
	struct
	{
		float	r;
		float	g;
		float	b;

	};
	float		value[3];
	void	Set(float rr, float gg, float bb) { r = rr; g = gg; b = bb; }
};

struct INDEX_POS
{
	DWORD		dwX;
	DWORD		dwY;
};

// 필드용
struct WORD_POS
{
	WORD		wX;
	WORD		wZ;
};

struct BYTE_POS
{
	BYTE	x;
	BYTE	y;
	BYTE	z;
	BYTE	reserved;
};
struct BYTE2
{
	BYTE	x;
	BYTE	y;
};

struct AABB
{
	VECTOR3	Min;
	VECTOR3	Max;
};
struct INT_AABB
{
	INT_VECTOR3 Min;
	INT_VECTOR3 Max;
};
struct PLANE
{
	VECTOR3		v3Up;
	float		D;
};


struct CAMERA_DESC_COMMON
{
	VECTOR3			v3From;
	VECTOR3			v3Up;			// 카메라의 up.
	VECTOR3			v3EyeDir;
	float			fNear;
	float			fFar;

};
struct CAMERA_DESC : CAMERA_DESC_COMMON
{
	VECTOR3			v3To;
	float			fXRot;
	float			fYRot;
	float			fZRot;
	float			fFovX;
	float			fFovY;
	float			fAspect;
	float			fZoomScale;
	BOOL			bOrtho;

};



struct IVERTEX
{
	float			x;
	float			y;
	float			z;


	float			nx;
	float			ny;
	float			nz;

	float			u0;
	float			v0;

	float			u1;
	float			v1;


	DWORD			dwMeshObjectIndex;
	DWORD			dwFaceGroupIndex;
	DWORD			dwFaceIndex;
	DWORD			dwMtlIndex;
	void*			pDataExt;
};
union INDEXED_EDGE
{
	DWORD			dwIndex[2];
	struct
	{
		DWORD		dwStart;
		DWORD		dwEnd;
	};
};
struct IVERTEX_QUAD
{
	IVERTEX		pivList[4];
};

struct COLLISION_TRI_MESH
{
	DWORD			dwTriNum;
	VECTOR3*		pv3TriList;
};

struct BOUNDING_BOX
{
	VECTOR3			v3Oct[8];
	void SetWithAABB(const VECTOR3* pv3Min, const VECTOR3* pv3Max)
	{
		float	min_x = pv3Min->x;
		float	min_y = pv3Min->y;
		float	min_z = pv3Min->z;

		float	max_x = pv3Max->x;
		float	max_y = pv3Max->y;
		float	max_z = pv3Max->z;

		v3Oct[0].x = min_x;
		v3Oct[0].y = max_y;
		v3Oct[0].z = max_z;

		v3Oct[1].x = min_x;
		v3Oct[1].y = min_y;
		v3Oct[1].z = max_z;

		v3Oct[2].x = max_x;
		v3Oct[2].y = min_y;
		v3Oct[2].z = max_z;

		v3Oct[3].x = max_x;
		v3Oct[3].y = max_y;
		v3Oct[3].z = max_z;

		v3Oct[4].x = min_x;
		v3Oct[4].y = max_y;
		v3Oct[4].z = min_z;

		v3Oct[5].x = min_x;
		v3Oct[5].y = min_y;
		v3Oct[5].z = min_z;

		v3Oct[6].x = max_x;
		v3Oct[6].y = min_y;
		v3Oct[6].z = min_z;

		v3Oct[7].x = max_x;
		v3Oct[7].y = max_y;
		v3Oct[7].z = min_z;
	}
};

struct BOUNDING_SPHERE
{
	VECTOR3			v3Point;
	float			fRs;
};

struct BOUNDING_CAPSULE
{
	VECTOR3			v3From;
	VECTOR3			v3To;
	float			fRadius;
};

struct TRIANGLE
{
	VECTOR3		v3Point[3];
};

struct QUADRANGLE
{
	VECTOR3	v3Point[4];
};


struct UINT2
{
	UINT x;
	UINT y;
};

struct UINT4
{
	UINT x;
	UINT y;
	UINT z;
	UINT w;
};
union COLOR_VALUE
{
	struct
	{
		float r;
		float g;
		float b;
		float a;
	};
	float	rgba[4];
	void Set(float rr, float gg, float bb, float aa) { r = rr; g = gg; b = bb; a = aa; }
	void Set(DWORD dwColor)
	{
		r = (float)((dwColor & 0x00ff0000) >> 16) / 255.0f;		// R
		g = (float)((dwColor & 0x0000ff00) >> 8) / 255.0f;		// G
		b = (float)((dwColor & 0x000000ff)) / 255.0f;			// B;
		a = (float)((dwColor & 0xff000000) >> 24) / 255.0f;		// A
	}
};




#pragma pack(push,1)

union BGR_PIXEL
{
	struct
	{
		BYTE	b;
		BYTE	g;
		BYTE	r;

	};
	BYTE		bColorFactor[3];
};
union ABGR_PIXEL
{
	struct
	{
		BYTE	b;
		BYTE	g;
		BYTE	r;
		BYTE	a;

	};
	BYTE		bColorFactor[4];
};


union ARGB
{
	struct
	{

		BYTE	b;
		BYTE	g;
		BYTE	r;
		BYTE	a;
	};
	BYTE		bColorFactor[4];
};

union RGBA
{
	struct
	{
		BYTE	r;
		BYTE	g;
		BYTE	b;
		BYTE	a;
	};
	BYTE		bColorFactor[4];
};
#pragma pack(pop)

struct MOUSE_STATUS
{
	int		iMoveX;
	int		iMoveY;
	int		iMoveZ;
	BYTE	bButtonPress[8];
};

struct	KEYBOARD_STATUS
{
	BYTE	bKeyPress[256];
};


const DWORD MAX_VOXELS_PER_AXIS = 8;
const float MIN_VOXEL_SIZE = 50.0f;
const float MIN_VOXEL_SIZE_HALF = MIN_VOXEL_SIZE * 0.5f;
const float VOXEL_OBJECT_SIZE = (float)MAX_VOXELS_PER_AXIS * MIN_VOXEL_SIZE;
const float VOXEL_OBJECT_SIZE_HALF = VOXEL_OBJECT_SIZE * 0.5f;
const float VOXEL_OBJECT_SIZE_HALF_HALF = VOXEL_OBJECT_SIZE_HALF * 0.5f;
const DWORD TEX_WIDTH_DEPTH_HEIGHT_PER_VOXEL_OBJECT = MAX_VOXELS_PER_AXIS * 2;
const float VOXEL_PATCH_SIZE = MIN_VOXEL_SIZE / 2.0f;
const float VOXEL_PATCH_SIZE_HALF = VOXEL_PATCH_SIZE * 0.5f;	// 패치의 중심점이 필요하기 때문에 이걸로 나눠서 좌표를 계산한다.
const DWORD VOXEL_LIGHT_TEXTURE_WIDTH = 64;
const DWORD	VOXEL_LIGHT_TEXTURE_HEIGHT = 512;
const DWORD MAX_COMPRESSED_VOXELS_PATTERN_TABLE_COUNT = 16;	// 복셀데이터 압축시 2x2x2블럭의 패턴 종류 최대개수
const DWORD VXO_TREE_MAX_DEPTH = 20;
const DWORD	MAX_QUAD_COUNT_FOR_CREATE_COL_TRI_MESH = MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS * 6 * 2;
const DWORD MAX_POINT_LIGHT_NUM_IN_VOXEL_WORLD = 256;
const DWORD MAX_POINT_LIGHT_NUM_PER_VOXEL_OBJ = 7;
const DWORD MAX_VOXEL_PALETEED_COLOR_NUM = 256;	// 이 수치가 바뀔 경우 rednerer의 shader도 수정해야한다.
const DWORD MAX_VOXEL_OBJ_NUM_FOR_RAY_TRACING_BUFFER = 65536 * 4;	// CUDA RayTracing Culling을 사용할 경우 최대 복셀 오브젝트 개수

const int	MAX_VOXEL_OBJ_MOVE_OFFSET = 32;	// m단위
const int	VOXEL_OBJ_MOVE_OFFSET_UNIT = 4;	// m단위

#define COMPRESS_COLOR_TABLE_WITH_2x2x2
#define COMPRESS_COLOR_TABLE_WITH_RLE
#ifdef COMPRESS_COLOR_TABLE_WITH_2x2x2
#undef COMPRESS_COLOR_TABLE_WITH_RLE
#endif


#pragma pack(push,1)
union COMPRESSED_COLOR_TABLE_2x2x2
{
	struct
	{
		BYTE	ResPerBlock;			// 범위는 0 - 8, 범위 표편에 4bits, 2x2x2일때 1x1x1개의 해상도 목록이 나오므로 ,4x1x1x1 = 4 bits	범위는 0 - 8 , 4 bits 데이터타입은 없으니 8 bits로 처리
		BYTE	bMinColorList;			// 2x2x2블럭당 최소 컬러값 -> 2x2x2개
		unsigned long pDistTable[2];	// 복셀당 2x2x2블럭 안에서의 컬러 거리 최대 8bits. 8x2x2x2 = 64 bits = 8 bytes
	};
	struct
	{
		BYTE	bOneColor;	// ResPerBlock과 같은 메모리를 공유한다. ResPerBlock의 하위 4 bits는 0-8사이이므로 bAllSameColor를 0b1111로 써넣으면 정상적인 ResPerBlock과 구분할 수 있다.
		BYTE	bColor;
	};
	static DWORD GetHeaderSize()
	{
		return (DWORD)(sizeof(COMPRESSED_COLOR_TABLE_2x2x2) - sizeof(pDistTable));
	}
	BOOL IsOneColor()
	{
		// 모든 복셀이 같은 컬러인지 체크
		BOOL bResult = (bOneColor & 0b1111) == 0b1111;
		return bResult;
	}
};
union COMPRESSED_COLOR_TABLE_4x4x4
{
	struct
	{
		unsigned long pResListPerBlock[1];	// 범위는 0 - 8, 범위 표편에 4bits, 4x4x4일때 2x2x2개의 해상도 목록이 나오므로 , 4x2x2x2 = 32 bits
		BYTE	bMinColorsSize;
		union
		{
			struct
			{
				char	pBuffer[8 + 64];
			};
			struct
			{
				// 최대 사이즈
				BYTE	MinColorList[8];		// 2x2x2블럭당 최소 컬러값 -> 2x2x2개
				unsigned long pDistTable[16];	// 복셀당 2x2x2블럭 안에서의 컬러 거리 최대 8bits. 8x4x4x4 = 512 bits = 64 bytes

			};
		};
	};
	struct
	{
		BYTE	bOneColor;	// pResListPerBlock[0]과 같은 메모리를 공유한다. pResListPerBlock[0]의 하위 4 bits는 0-8사이이므로 bOneColor를 0xff로 써넣으면 정상적인 pResListPerBlock[0]과 구분할 수 있다.
		BYTE	bColor;
	};
	BOOL IsOneColor()
	{
		// 모든 복셀이 같은 컬러인지 체크
		BOOL bResult = (bOneColor & 0b1111) == 0b1111;
		return bResult;
	}
	BYTE* GetUncompressedMinColorsPtr()
	{
		return (BYTE*)pBuffer;
	}
	COMPRESSED_COLOR_TABLE_2x2x2* GetCompressedMinColorsPtr()
	{
		return (COMPRESSED_COLOR_TABLE_2x2x2*)pBuffer;
	}
	unsigned long* GetDistTablePtr()
	{
		unsigned long* pDistTable;
		if (!bMinColorsSize)
		{
			// min 컬러테이블이 압축 안된 경우
			pDistTable = (unsigned long*)((DWORD_PTR)pBuffer + 8);
		}
		else
		{
			// min 컬러테이블이 압축된 경우
			pDistTable = (unsigned long*)((DWORD_PTR)pBuffer + (DWORD_PTR)bMinColorsSize);
		}
		return pDistTable;
	}
	static DWORD GetHeaderSize()
	{
		return (DWORD)(sizeof(COMPRESSED_COLOR_TABLE_4x4x4) - sizeof(pBuffer));
	}
};
union COMPRESSED_COLOR_TABLE_8x8x8
{
	struct
	{
		unsigned long pResListPerBlock[8];	//  범위는 0 - 8, 범위 표편에 4bits, 8x8x8일때 4x4x4개의 해상도 목록이 나오므로, 4x4x4x4 = 256 bits
		BYTE	bMinColorsSize;

		union
		{
			struct
			{
				char	pBuffer[64 + 512];
			};
			struct
			{
				// 최대 사이즈
				BYTE	MinColorList[64];
				unsigned long pDistTable[128];	// 복셀당 2x2x2블럭 안에서의 컬러 거리 최대 8bits. 8x8x8x8 = 4096 bits = 512 bytes
			};
		};
	};
	struct
	{
		BYTE	bOneColor;	// pResListPerBlock[0]과 같은 메모리를 공유한다. pResListPerBlock[0]의 하위 4 bits는 0-8사이이므로 bOneColor를 0xff로 써넣으면 정상적인 pResListPerBlock[0]과 구분할 수 있다.
		BYTE	bColor;
	};
	BOOL IsOneColor()
	{
		// 모든 복셀이 같은 컬러인지 체크
		BOOL bResult = (bOneColor & 0b1111) == 0b1111;
		return bResult;
	}
	BYTE* GetUncompressedMinColorsPtr()
	{
		return (BYTE*)pBuffer;
	}
	COMPRESSED_COLOR_TABLE_4x4x4* GetCompressedMinColorsPtr()
	{
		return (COMPRESSED_COLOR_TABLE_4x4x4*)pBuffer;
	}
	unsigned long* GetDistTablePtr()
	{
		unsigned long* pDistTable;
		if (!bMinColorsSize)
		{
			// min 컬러테이블이 압축 안된 경우
			pDistTable = (unsigned long*)((DWORD_PTR)pBuffer + 64);
		}
		else
		{
			// min 컬러테이블이 압축된 경우
			pDistTable = (unsigned long*)((DWORD_PTR)pBuffer + (DWORD_PTR)bMinColorsSize);
		}
		return pDistTable;
	}
	static DWORD GetHeaderSize()
	{
		return (DWORD)(sizeof(COMPRESSED_COLOR_TABLE_8x8x8) - sizeof(pBuffer));
	}
};
inline constexpr DWORD GetMax2x2x2ColorTableCompressedSize()
{
	return (DWORD)sizeof(COMPRESSED_COLOR_TABLE_8x8x8);
}
union COMPRESSED_MEM_BUFFER
{
	COMPRESSED_COLOR_TABLE_8x8x8	CompressedMem8x8x8;
	COMPRESSED_COLOR_TABLE_4x4x4	CompressedMem4x4x4;
	COMPRESSED_COLOR_TABLE_2x2x2	CompressedMem2x2x2;
	BYTE	pRawColorTable[MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS];
};
#pragma pack(pop)


interface IVoxelObjectLite;
typedef void (__stdcall *ON_DELETE_VOXEL_OBJ_LITE_FUNC)(IVoxelObjectLite* pVoxelObj);

interface IVoxelObjectLite;
struct VOXEL_DESC_LITE
{
	IVoxelObjectLite*	pVoxelObj;
	int	x;
	int	y;
	int	z;
	BYTE	ColorIndex;
	void	Clear()
	{
		pVoxelObj = nullptr;
		x = 0;
		y = 0;
		z = 0;
		ColorIndex = 0;
	}
	BOOL	IsSameVoxel(VOXEL_DESC_LITE* pTarget)
	{
		BOOL	bResult = (pVoxelObj == pTarget->pVoxelObj) && (x == pTarget->x) && (y == pTarget->y) && (z == pTarget->z);
		return bResult;
	}
};

enum VOXEL_OBJECT_PROPERTY
{
	VOXEL_OBJECT_PROPERTY_DESTROYABLE = 0x00000001,
	VOXEL_OBJECT_PROPERTY_EDITABLE = 0x00000002,
	VOXEL_OBJECT_PROPERTY_AUTO_RECOVERY = 0x00000004
};

struct VOXEL_OBJ_PROPERTY
{
	UINT	WidthDepthHeight;
	float	VoxelSize;
};

inline constexpr DWORD GetMaxColorTableSize()
{
	DWORD	MaxCompressedSize = GetMax2x2x2ColorTableCompressedSize();
	DWORD	ColorStreamSize = MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS * sizeof(BYTE);

	DWORD	MaxColorTableSize = max(MaxCompressedSize, ColorStreamSize);
	return MaxColorTableSize;
}


#pragma pack(push,1)
struct COMPRESSED_VOXEL_GEOEMTRY_HEADER
{
	BYTE bPatternNum;
	BYTE pPatternTable[1];
	const unsigned long* GetBodyPtrForRead() const
	{
		const unsigned long* ptr = (const unsigned long*)(pPatternTable + ((DWORD)sizeof(BYTE) * (DWORD)bPatternNum));
		return ptr;
	}
	unsigned long* GetBodyPtrForWrite()
	{
		unsigned long* ptr = (unsigned long*)(pPatternTable + ((DWORD)sizeof(BYTE) * (DWORD)bPatternNum));
		return ptr;
	}
};
#pragma pack(pop)

inline constexpr DWORD GetCompressedVoxelDataBodySize(DWORD dwPatternCount, UINT WidthDepthHeight)
{
	DWORD	mul_value = 0;
	switch (WidthDepthHeight)
	{
		case 4:
			mul_value = 1;
			break;
		case 8:
			mul_value = 8;
			break;
		default:
			{
				int a = 0;
			}
	}
	DWORD	val = 1;
	DWORD	pow = 0;
	while (1)
	{
		if (val >= dwPatternCount)
			break;

		pow++;
		val = val << 1;
	}
	DWORD dwSize = pow * mul_value;
	return dwSize;
}

inline constexpr DWORD GetPureVoxelDataSizeWithVoxelCount(DWORD VoxelCount)
{
	DWORD dwSize = VoxelCount / 8 + (VoxelCount % 8 != 0);
	return dwSize;
}
inline constexpr DWORD GetPureVoxelDataSize(UINT WidthDepthHeight)
{
	DWORD dwSize = GetPureVoxelDataSizeWithVoxelCount(WidthDepthHeight * WidthDepthHeight * WidthDepthHeight);
	return dwSize;
}
inline constexpr DWORD GetCompressedVoxelDataSize(DWORD dwPatternCount, UINT WidthDepthHeight)
{
	DWORD	dwBodySize = GetCompressedVoxelDataBodySize(dwPatternCount, WidthDepthHeight);
	DWORD	dwHeaderSize = (DWORD)sizeof(COMPRESSED_VOXEL_GEOEMTRY_HEADER) - (DWORD)sizeof(BYTE) + (DWORD)sizeof(BYTE) * dwPatternCount;
	DWORD	dwSize = dwHeaderSize + dwBodySize;
	return dwSize;
}

//    Geometry Compressed	|	ColorTable Compressed	|	 ColorTableSize    |   Property	  |  WidthDepthHeight 
//			1(1)			|		   1(1)				|	 11 1111 1111(10)  |	 11(2)	  |		11(2) n = {0,1,2,3} , WidthDepthHeight = 2^n
const DWORD WIDTH_DEPTH_HEIGHT_2BITS = 0b11;
const DWORD PROPERTY_2BITS = 0b1100;
const DWORD PROPERTY_DESTROYABLE_1BITS = 0b0100;
const DWORD PROPERTY_RESERVED_1BITS = 0b1000;
const DWORD COLOR_TABLE_SIZE_10BITS = 0b1111111111;
const DWORD COLOR_TABLE_SIZE_MASK = (COLOR_TABLE_SIZE_10BITS << 4);
const DWORD COLOR_TABLE_COMPRESSED_1BIT = 0b1;
const DWORD COLOR_TABLE_COMPRESSED_MASK = (COLOR_TABLE_COMPRESSED_1BIT << 14);
const DWORD GEOMETRY_COMPRESSED_MASK = (0b1 << 15);

inline DWORD CalcPowN(UINT WidthDepthHeight)
{
	DWORD	n = 0;
	while (WidthDepthHeight > 1)
	{
		WidthDepthHeight = WidthDepthHeight >> 1;
		n++;
	}
	return n;
}
inline UINT CalcWidthDepthHeight(DWORD n)
{
	UINT WidthDepthHeight = 1;
	for (DWORD i = 0; i < n; i++)
	{
		WidthDepthHeight = WidthDepthHeight << 1;
	}
	return WidthDepthHeight;
}

#pragma pack(push,1)
struct VOXEL_SHORT_POS
{
	short	x;
	short	y;
	short	z;
};
struct VOXEL_WORD_POS
{
	// INT 좌표계를 2바이트로 저장.0보다 작은 경우는 없으므로 WORD를 사용한다.
	WORD	x;
	WORD	y;
	WORD	z;
};
struct VOXEL_OBJECT_STREAM_COMMON_HEADER
{
	VOXEL_SHORT_POS	Pos;
	WORD	wProps;

	void	SetColorTableSize(DWORD ColorTableSize, BOOL bCompressed)
	{
		wProps &= (~(COLOR_TABLE_COMPRESSED_MASK | COLOR_TABLE_SIZE_MASK));
		wProps |= ((bCompressed & COLOR_TABLE_COMPRESSED_1BIT) << 14);
		wProps |= ((ColorTableSize & COLOR_TABLE_SIZE_10BITS) << 4);
	}
	DWORD	GetColorTableSize() const
	{
		DWORD	dwSize = (DWORD)((wProps & COLOR_TABLE_SIZE_MASK) >> 4);
		return dwSize;
	}
	BOOL	IsColorTableCompressed() const
	{
		BOOL	bCompressed = ((wProps & COLOR_TABLE_COMPRESSED_MASK) != 0);
		return bCompressed;
	}
	void	SetGeometryCompressed(BOOL bCompressed)
	{
		wProps = (wProps & 0x7FFF) | (bCompressed << 15);
	}
	BOOL	IsGeometryCompressed() const
	{
		BOOL	bCompressed = ((wProps & GEOMETRY_COMPRESSED_MASK) != 0);
		return bCompressed;
	}
	void	SetWidthDepthHeight(UINT WidthDepthHeight)
	{
		DWORD n = CalcPowN(WidthDepthHeight);
		wProps &= (~WIDTH_DEPTH_HEIGHT_2BITS);
		wProps |= (n & WIDTH_DEPTH_HEIGHT_2BITS);
	}
	UINT	GetWidthDepthHeight() const
	{
		DWORD	n = (UINT)(wProps & WIDTH_DEPTH_HEIGHT_2BITS);
		UINT	WidthDepthHeight = CalcWidthDepthHeight(n);
	#ifdef _DEBUG
		if (WidthDepthHeight > MAX_VOXELS_PER_AXIS)
			__debugbreak();
	#endif
		return WidthDepthHeight;
	}
	void	SetDestroyable(BOOL bSwitch)
	{
		wProps &= (~PROPERTY_DESTROYABLE_1BITS);
		wProps |= ((bSwitch << 2) & PROPERTY_DESTROYABLE_1BITS);
	}
	BOOL	IsDestroyable() const
	{
		BOOL bDestroyable = (wProps & PROPERTY_DESTROYABLE_1BITS) >> 2;
		return bDestroyable;
	}
};
struct VOXEL_OBJECT_PACKET_STREAM_HEADER : public VOXEL_OBJECT_STREAM_COMMON_HEADER
{
	BYTE	pData[1];

	const BYTE*	GetVoxelDataPtrForRead() const { return pData; }
	BYTE*	GetVoxelDataPtrForWrite() { return pData; }

	DWORD	GetVoxelDataSize() const
	{
		DWORD dwSize = 0;
		UINT WidthDepthHeight = GetWidthDepthHeight();
		if (IsGeometryCompressed())
		{
			COMPRESSED_VOXEL_GEOEMTRY_HEADER*	pHeader = (COMPRESSED_VOXEL_GEOEMTRY_HEADER*)pData;
			dwSize = GetCompressedVoxelDataSize((DWORD)pHeader->bPatternNum, WidthDepthHeight);
		}
		else
		{
			dwSize = GetPureVoxelDataSize(WidthDepthHeight);
		}
		return dwSize;
	}
	const BYTE*	GetColorTablePtrForRead() const { return ((const BYTE*)pData + GetVoxelDataSize()); }
	BYTE*	GetColorTablePtrForWrite() { return ((BYTE*)pData + GetVoxelDataSize()); }
	VOXEL_OBJECT_PACKET_STREAM_HEADER*	Next()
	{
		DWORD	ColorTableSize = GetColorTableSize();
		UINT	WidthDepthHeight = GetWidthDepthHeight();
		DWORD	TotalVoxels = WidthDepthHeight * WidthDepthHeight * WidthDepthHeight;
		DWORD	VoxelDataSize = GetVoxelDataSize();
		DWORD	MemSize = (DWORD)sizeof(VOXEL_OBJECT_PACKET_STREAM_HEADER) - (DWORD)sizeof(BYTE) + VoxelDataSize + ColorTableSize;

		VOXEL_OBJECT_PACKET_STREAM_HEADER*	pNext = (VOXEL_OBJECT_PACKET_STREAM_HEADER*)((char*)this + MemSize);
		return pNext;
	}
	DWORD	GetNextOffset()
	{
		DWORD	ColorTableSize = GetColorTableSize();
		UINT	WidthDepthHeight = GetWidthDepthHeight();
		DWORD	TotalVoxels = WidthDepthHeight * WidthDepthHeight * WidthDepthHeight;
		DWORD	VoxelDataSize = GetVoxelDataSize();
		DWORD	MemSize = (DWORD)sizeof(VOXEL_OBJECT_PACKET_STREAM_HEADER) - (DWORD)sizeof(BYTE) + VoxelDataSize + ColorTableSize;
		return MemSize;
	}
};

struct VOXEL_OBJECT_FILE_STREAM_HEADER : VOXEL_OBJECT_STREAM_COMMON_HEADER
{
	// 파일에서 사용할때는 voxel data 압축하지 않음.
	INT64	i64OwnerSerial;
	DWORD	pData[1];

	unsigned long*	GetBitTablePtr() { return (unsigned long*)pData; }

	DWORD	GetVoxelDataSize()
	{
		UINT WidthDepthHeight = GetWidthDepthHeight();
		DWORD dwSize = GetPureVoxelDataSize(WidthDepthHeight);
		return dwSize;
	}
	BYTE*	GetColorTablePtr() { return ((BYTE*)pData + GetVoxelDataSize()); }
	VOXEL_OBJECT_FILE_STREAM_HEADER*	Next()
	{
		DWORD	ColorTableSize = GetColorTableSize();
		UINT	WidthDepthHeight = GetWidthDepthHeight();
		DWORD	TotalVoxels = WidthDepthHeight * WidthDepthHeight * WidthDepthHeight;
		DWORD	VoxelDataSize = GetVoxelDataSize();
		DWORD	MemSize = (DWORD)sizeof(VOXEL_OBJECT_FILE_STREAM_HEADER) - (DWORD)sizeof(DWORD) + VoxelDataSize + ColorTableSize;

		VOXEL_OBJECT_FILE_STREAM_HEADER*	pNext = (VOXEL_OBJECT_FILE_STREAM_HEADER*)((char*)this + MemSize);
		return pNext;
	}
};

inline constexpr DWORD GetMaxVoxelObjectPacketStreamSize()
{
	DWORD	VoxelDataSize = GetPureVoxelDataSize(MAX_VOXELS_PER_AXIS);
	DWORD	MaxColorTableSize = GetMaxColorTableSize();
	DWORD	MemSize = sizeof(VOXEL_OBJECT_PACKET_STREAM_HEADER) - sizeof(BYTE) + VoxelDataSize + MaxColorTableSize;
	return MemSize;
}

inline constexpr DWORD GetMaxVoxelObjectFileStreamSize()
{
	DWORD	VoxelDataSize = GetPureVoxelDataSize(MAX_VOXELS_PER_AXIS);
	DWORD	MaxColorTableSize = GetMaxColorTableSize();
	DWORD	MemSize = (DWORD)sizeof(VOXEL_OBJECT_FILE_STREAM_HEADER) - (DWORD)sizeof(DWORD) + VoxelDataSize + MaxColorTableSize;
	return MemSize;
}
inline constexpr DWORD GetVoxelObjectPacketStreamSizeWithoutColorTable(UINT WidthDepthHeight)
{
	DWORD	VoxelDataSize = GetPureVoxelDataSize(WidthDepthHeight);
	DWORD	MemSize = (DWORD)sizeof(VOXEL_OBJECT_PACKET_STREAM_HEADER) - (DWORD)sizeof(BYTE) + VoxelDataSize;
	return MemSize;
}

inline constexpr DWORD GetCompressedVoxelObjectPacketStreamSizeWithoutColorTable(DWORD dwCompressedVoxelDeataSize)
{
	DWORD	MemSize = (DWORD)sizeof(VOXEL_OBJECT_PACKET_STREAM_HEADER) - (DWORD)sizeof(BYTE) + dwCompressedVoxelDeataSize;
	return MemSize;
}

inline constexpr DWORD GetVoxelObjectFileStreamSizeWithoutColorTable(UINT WidthDepthHeight)
{
	DWORD	VoxelDataSize = GetPureVoxelDataSize(WidthDepthHeight);
	DWORD	MemSize = (DWORD)sizeof(VOXEL_OBJECT_FILE_STREAM_HEADER) - (DWORD)sizeof(DWORD) + VoxelDataSize;
	return MemSize;
}


struct VOXEL_OBJECT_COLOR_TABLE_HEADER
{
	WORD	wPosX;
	WORD	wPosY;
	WORD	wPosZ;
	WORD	wProps;
	DWORD	pData[1];

	void	SetColorTableSize(DWORD ColorTableSize, BOOL bCompressed)
	{
		wProps &= (~COLOR_TABLE_COMPRESSED_MASK);
		wProps |= (bCompressed & COLOR_TABLE_COMPRESSED_1BIT) << 14;
	}
	void	SetWidthDepthHeight(UINT WidthDepthHeight)
	{
		DWORD n = CalcPowN(WidthDepthHeight);
		wProps &= (~WIDTH_DEPTH_HEIGHT_2BITS);
		wProps |= (n & WIDTH_DEPTH_HEIGHT_2BITS);
	}
	UINT	GetWidthDepthHeight()
	{
		DWORD	n = (UINT)(wProps & WIDTH_DEPTH_HEIGHT_2BITS);
		UINT	WidthDepthHeight = CalcWidthDepthHeight(n);
		return WidthDepthHeight;
	}

	BOOL	IsColorTableCompressed()
	{
		BOOL	bCompressed = ((wProps & COLOR_TABLE_COMPRESSED_MASK) != 0);
		return bCompressed;
	}

	DWORD	GetColorTableSize()
	{
		DWORD	dwSize = (DWORD)((wProps & COLOR_TABLE_SIZE_MASK) >> 4);
		return dwSize;
	}
	BYTE*			GetColorTablePtr() { return ((BYTE*)pData); }


	VOXEL_OBJECT_COLOR_TABLE_HEADER*	Next()
	{
		DWORD	ColorTableSize = GetColorTableSize();
		DWORD	MemSize = (DWORD)sizeof(VOXEL_OBJECT_COLOR_TABLE_HEADER) - (DWORD)sizeof(DWORD) + ColorTableSize;

		VOXEL_OBJECT_COLOR_TABLE_HEADER*	pNext = (VOXEL_OBJECT_COLOR_TABLE_HEADER*)((char*)this + MemSize);
		return pNext;
	}
};
#pragma pack(pop)


enum CREATE_VOXEL_OBJECT_ERROR
{
	CREATE_VOXEL_OBJECT_ERROR_OK = 0,
	CREATE_VOXEL_OBJECT_ERROR_ALREADY_EXIST = 1,
	CREATE_VOXEL_OBJECT_ERROR_INVALID_POS = 2,
	CREATE_VOXEL_OBJECT_ERROR_FAIL_ALLOC_INDEX = 3
};
static const int	MAX_COMPRESSED_GEOMETRY_STREAM_BUFFER_SIZE = (int)GetMaxVoxelObjectPacketStreamSize();
static const int	MAX_FILE_GEOMETRY_STREAM_BUFFER_SIZE = (int)GetMaxVoxelObjectFileStreamSize();

struct VOXEL_OBJ_PERF
{
	BOOL		bNoCullingOnRaster;
	BOOL		bUseSWOccTest;
	float		fSWOccTestNodeLimitTime;
	float		fSWOccRasterLimitTime;
	float		fCamPosBiasDist;
	float		fCamRayBiasAngle;
	float		fAvgSWCulledNodeCount;
	float		fAvgSWCulledObjCount;
	DWORD		dwTotalObjCount;
	DWORD		dwTotalVoxelCount;
	DWORD		pdwVoxelCountList[4];
	DWORD		dwFoundObjCount;
	float		fAvgSWTestElapsedTicks;
	DWORD64		AvgSWTestElapsedClocks;
	float		fAvgSWRasterElapsedTicks;
	DWORD64		AvgSWRasterElapsedClocks;
	float		fAvgRasterTriCountPerFind;
	float		fAvgTestNodeCountPerFind;
	float		fAvgElapsedTickPerFind;
	DWORD		dwSWRasterThreadCount;
	DWORD		dwVoxelEditEventCount;	// 복셀이 변형되는 이벤트 발생 수
	DWORD		dwOptimizeSuccessCount;	// 복셀이 변형될때 최적화에 성공한 회수
	DWORD		dwLastUpdatingElapsedTick; // 마지막 업데이트(복셀 지오메트리 압축해제, 라이팅 등)에 걸린 시간.
	BOOL		bUseMultiThreadUpdateLightTexutre;	// 라이트 텍스처 업데이트에 멀티 스레드 사용 여부
	WCHAR		wchSWOccTesterInstType[32];
};

struct VOXEL_OBJ_MEM_PERF
{
	size_t	TotalMemSize;
	size_t	CompressedVoxelData;
	size_t	ColTriSize;
	size_t	PatchSize;
	size_t	ColotTableSize;

	void operator +=(VOXEL_OBJ_MEM_PERF& memObj)
	{
		TotalMemSize += memObj.TotalMemSize;
		CompressedVoxelData += memObj.CompressedVoxelData;
		ColTriSize += memObj.ColTriSize;
		PatchSize += memObj.PatchSize;
		ColotTableSize += memObj.ColotTableSize;
	}
	VOXEL_OBJ_MEM_PERF operator /(DWORD dwObjNum) const
	{
		VOXEL_OBJ_MEM_PERF	result = {};
		result.TotalMemSize = (size_t)((float)TotalMemSize / (float)dwObjNum);
		result.CompressedVoxelData = (size_t)((float)CompressedVoxelData / (float)dwObjNum);
		result.ColTriSize = (size_t)((float)ColTriSize / (float)dwObjNum);
		result.PatchSize = (size_t)((float)PatchSize / (float)dwObjNum);
		result.ColotTableSize = (size_t)((float)ColotTableSize / (float)dwObjNum);

		return result;
	}
};
struct VOXEL_MEM_PERF
{
	size_t	TotalMemSize;
	VOXEL_OBJ_MEM_PERF	objAvg;
	VOXEL_OBJ_MEM_PERF	objTotal;
	size_t	ObjSize;				// voxle objects
	size_t	TreeSize;				// m_pTree
	size_t	WorkingPtrBufferSize;
	size_t	OwnerTableSize;
	size_t	GeometryContextMemSize;
	size_t	ObjBitTableSize;
	size_t	CopyPatchMemSize;
	size_t	SortOccluderBufferMemSize;
	size_t	ObjTableMemSize;
	size_t	GlobalRefSrcSize;		// src ref bit table
	DWORD	ObjCount;
	DWORD	Reserved;
};

inline void Vector3ToVoxelShortPos(VOXEL_SHORT_POS* pOutShortPos, const VECTOR3* pv3ObjPos)
{
	pOutShortPos->x = (short)(int)((pv3ObjPos->x - VOXEL_OBJECT_SIZE_HALF) / VOXEL_OBJECT_SIZE);
	pOutShortPos->y = (short)(int)((pv3ObjPos->y - VOXEL_OBJECT_SIZE_HALF) / VOXEL_OBJECT_SIZE);
	pOutShortPos->z = (short)(int)((pv3ObjPos->z - VOXEL_OBJECT_SIZE_HALF) / VOXEL_OBJECT_SIZE);
}
inline void VoxelShortPosToVector3(VECTOR3* pv3OutPos, const VOXEL_SHORT_POS* pShortPos)
{
	pv3OutPos->x = (float)pShortPos->x * VOXEL_OBJECT_SIZE + VOXEL_OBJECT_SIZE_HALF;
	pv3OutPos->y = (float)pShortPos->y * VOXEL_OBJECT_SIZE + VOXEL_OBJECT_SIZE_HALF;
	pv3OutPos->z = (float)pShortPos->z * VOXEL_OBJECT_SIZE + VOXEL_OBJECT_SIZE_HALF;
}
struct PICK_RESULT
{
	VECTOR3				v3IntersectPoint;		// 픽킹 요청일때 픽킹위치
	BOOL				bPickResult;			// 픽킹 요청일때 픽킹 성공 여부
	float				t;
	void*				pChrObj;
	IVoxelObjectLite*	pVoxelObj;	// 복셀에 충돌했을때
};

struct INTERSECT_RESULT
{
	VECTOR3				v3IntersectPoint;
	float				t;

};
struct TRI_MESH
{
	TRIANGLE*		pTriList;
	DWORD			dwTriNum;
};

struct MIDI_NOTE
{
private:
	// Control / note | On / Off(1) | velocity(7) | key(7)
	static const DWORD ON_OFF_MASK = 0b1;
	static const DWORD VELOCITY_MASK = 0b1111111;
	static const DWORD KEY_MASK = 0b1111111;
	DWORD	dwRelativeTick;
	DWORD	dwValue;
public:
	BOOL IsControl() const
	{
		BOOL bResult = (dwValue & (1 << 15)) != 0;
		return bResult;
	}
	DWORD GetRelativeTick() const
	{
		return dwRelativeTick;
	}
	void SetRelativeTick(DWORD dwTick)
	{
		dwRelativeTick = dwTick;
	}

	// as note
	void SetAsNote(BOOL bOnOff, DWORD dwTick, DWORD dwVelocity, DWORD dwKey)
	{
		dwRelativeTick = dwTick;
		dwValue = (0 << 15) | ((bOnOff & ON_OFF_MASK) << 14) | ((dwVelocity & VELOCITY_MASK) << 7) | (dwKey & KEY_MASK);
	}
	BOOL GetOnOff() const
	{
		return (BOOL)((dwValue >> 14) & ON_OFF_MASK);
	}
	DWORD GetVelocity() const
	{
		return ((dwValue >> 7) & VELOCITY_MASK);
	}
	DWORD GetKey() const
	{
		return (dwValue & KEY_MASK);
	}
	// as controller
	void SetAsControl(DWORD dwTick, DWORD dwControlValue, DWORD dwController)
	{
		dwRelativeTick = dwTick;
		dwValue = (1 << 15) | ((1 & ON_OFF_MASK) << 14) | ((dwControlValue & VELOCITY_MASK) << 7) | (dwController & KEY_MASK);
	}
	DWORD GetControlValue() const
	{
		return ((dwValue >> 7) & VELOCITY_MASK);
	}
	DWORD GetController() const
	{
		return (dwValue & KEY_MASK);
	}
};
struct MIDI_NOTE_L
{
private:
	// Control / note | On / Off(1) | velocity(7) | key(7)
	static const DWORD CONTROL_NOTE_MASK = 0b1;
	static const DWORD ON_OFF_MASK = 0b1;
	static const DWORD VELOCITY_MASK = 0b1111111;
	static const DWORD KEY_MASK = 0b1111111;
	DWORD	dwValue;
public:
	// as note
	void SetAsNote(BOOL bOnOff, DWORD dwVelocity, DWORD dwKey)
	{
		dwValue = (0 << 15) | ((bOnOff & ON_OFF_MASK) << 14) | ((dwVelocity & VELOCITY_MASK) << 7) | (dwKey & KEY_MASK);
	}
	BOOL IsControl() const
	{
		BOOL bResult = (dwValue & (1 << 15)) != 0;
		return bResult;
	}
	BOOL GetOnOff() const
	{
		return (BOOL)((dwValue >> 14) & ON_OFF_MASK);
	}
	DWORD GetVelocity() const
	{
		return ((dwValue >> 7) & VELOCITY_MASK);
	}
	DWORD GetKey() const
	{
		return (dwValue & KEY_MASK);
	}

	// as controller
	void SetAsControl(DWORD dwControlValue, DWORD dwController)
	{
		dwValue = (1 << 15) | ((1 & ON_OFF_MASK) << 14) | ((dwControlValue & VELOCITY_MASK) << 7) | (dwController & KEY_MASK);
	}
	DWORD GetControlValue() const
	{
		return ((dwValue >> 7) & VELOCITY_MASK);
	}
	DWORD GetController() const
	{
		return (dwValue & KEY_MASK);
	}

};
const DWORD MAX_NOTE_NUM_PER_BLOCK = 8;

#endif	// VH_PLUGIN