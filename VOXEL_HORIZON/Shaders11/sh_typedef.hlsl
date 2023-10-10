#ifndef SH_TYPEDEF_HLSL
#define SH_TYPEDEF_HLSL

#include "shader_cpp_common.h"

#define INT_MIN     (-2147483647 - 1)
#define INT_MAX       2147483647
#define EPSILON 1e-10

struct ATT_LIGHT
{
	// 16bytes align 64bytes
	float4		Pos;
	float		Rs;
	float		RcpRsRs;
	dword		ColorCenter;
	dword		ColorSide;
};
struct CASCADE_CONSTANT
{
	// 16 bytes align
	float		Dist;
	float		Reserved0;
	float		Reserved1;
	float		Reserved2;
};

struct LIGHT_CUBE_CONST
{
	float4			ColorPerAxis[8];
};

struct TILED_RESOURCE_PROPERTY
{
    uint TexID; // Tiled Resource로 사용할 텍스처 ID
    uint FullWidthHeight; // 텍스처의 완전한 크기, 최대 16384x1384 , Width = Low 16bits , Height = High 16bits
    uint WidthHeightPerTile; // 타일의 해상도 BC3포맷일 경우 256x256, Width = Low 16bits , Height = High 16bits
    uint LayoutType; // Tiled Texture의 layout 유형 0-7사이
};
struct PROJ_CONSTANT
{
	float		fNear;
	float		fFar;
	float		fFarRcp;
	float		Reserved1;
};

struct DECOMP_PROJ
{
	float	rcp_m11;
	float	rcp_m22;
	float	m21;
	float	m31;
	float	m32;
	float	m33;
	float	m43;
	float	Reserved0;
};
struct TRANSFORM_COMMON
{
	matrix matWorld;	
		
	// mesh shader
    uint MeshShaderInstanceCount;
	uint MeshletPerObj;
	uint MeshShader_Reserved2;
	uint MeshShader_Reserved3;	
};
struct CAMERA_MATRIX
{
    matrix matWorldViewProjCommon;
    matrix matViewProjCommon;
    matrix matViewArray[VIEW_PROJ_ARRAY_COUNT];
    matrix matViewInvArray[VIEW_PROJ_ARRAY_COUNT];
    matrix matProjArray[VIEW_PROJ_ARRAY_COUNT];
    matrix matWorldViewProjArray[VIEW_PROJ_ARRAY_COUNT];
    matrix matViewProjArray[VIEW_PROJ_ARRAY_COUNT];
};
struct SHADOW_CASTER_MATRIX
{
    matrix matWorldViewProjList[MAX_CASCADE_NUM];
    matrix matViewProjList[MAX_CASCADE_NUM];
};
struct VS_INPUT_VL
{
	float4  Pos		    : POSITION;
	float3	Normal	    : NORMAL;
	float4	Tangent	    : TANGENT;
	float2	TexCoord    : TEXCOORD0;
	uint    instId      : SV_InstanceID;
};


struct VS_INPUT_VL_PHYSIQUE
{
	float4		Pos         : POSITION;
	float3		Normal      : NORMAL;
	float4		Tangent     : TANGENT;

	uint4		BlendIndex  : BLENDINDICES;
	float4		BlendWeight : BLENDWEIGHTS;

	float2		TexCoord    : TEXCOORD0;
	uint        instId      : SV_InstanceID;
};


// for Mesh Shader, Compute Shader
struct D3DVLVERTEX_PHYSIQUE
{
    float3 Pos;
    float3 Normal;
    float3 Tangent;
    uint Property;
    uint BoneIndex; // 0:x, 1:y, 2:z, w:3
    float4 BoneWeight4; // 0:x, 1:y, 2:z, w:3
};
struct D3DVLVERTEX
{
    float3 Pos;
    float3 Normal;
    float3 Tangent;
    uint Property;
};

struct D3DPLLMVERTEX
{
    float3 Pos;
    float3 Normal;
    float3 Tangent;
    float2 TexCoordDiffuse;
    float2 TexCoordLightMap;
};
struct PS_TARGET
{
	float4 Color0 : SV_Target0; // pixel color
	float4 Color1 : SV_Target1; // normal 
	float4 Color2 : SV_Target2; // r:ElementID | g:N/A | b:N/A | a:N/A
    uint Color3 : SV_Target3; // Tiled Resource Status(32bits)
};

#define MAX_ATT_LIGHT_NUM		8
#define MAX_PUBLIC_CONST_NUM	4


#define	AXIS_BIT_POSITIVE_X 0
#define AXIS_BIT_NEGATIVE_X 1
#define AXIS_BIT_POSITIVE_Y 2
#define AXIS_BIT_NEGATIVE_Y 3
#define AXIS_BIT_POSITIVE_Z 4
#define AXIS_BIT_NEGATIVE_Z 5

#define MAP_OBJECT_TYPE_CHARACTER 0
#define MAP_OBJECT_TYPE_STRUCT 1

static const float ADJ_RCP_32 = 0.5 / 31.0;
static const float ADJ_RCP_256 = 0.5f / 255.0f;

#define ALPHA_TEST_THRESHOLD_ADD (0.001)
#define ALPHA_TEST_THRESHOLD_TRANSP (0.025)

uint SetShadowWeight(uint PropOld, float ShadowWeight)
{
	uint weight = (uint)(ShadowWeight * 31.0 + ADJ_RCP_32);
	// Type(chr/map) |  OutLine   |    SSAO     |   ShadowWeight
	//      1        |     1      |      1      |     11111
	uint Prop = (PropOld & 0x000000E0) | weight;
	return Prop;
}
uint GetType(uint Prop)
{
	return ((Prop & 0x80) >> 7);
}

uint GetShadowWeight(uint Prop)
{
	uint weight = Prop & 0x0000001F;
	float ShadowWeight = (float)weight / 31.0;
	return ShadowWeight;
}
bool IsEnabledSSAO(uint Prop)
{
	return ((Prop & 0x00000020) >> 5);
}

bool IsEnabledOutLine(uint Prop)
{
	return ((Prop & 0x00000040) >> 6);
}

float4 UnpackRGBA(uint packedInput)
{
    float4 unpackedOutput;
	uint4 p = uint4((packedInput & 0xFFUL),
				    (packedInput >> 8UL) & 0xFFUL,
				    (packedInput >> 16UL) & 0xFFUL,
				    (packedInput >> 24UL));

	unpackedOutput = ((float4)p) / 255;
	return unpackedOutput;
}

uint PackRGBA(float4 unpackedInput)
{
	uint4 u = (uint4)(saturate(unpackedInput) * 255);
	uint  packedOutput = (u.w << 24UL) | (u.z << 16UL) | (u.y << 8UL) | u.x;
	return packedOutput;
}

uint Pack_Normal_Property_ElementID_To_UINT(float3 NormalColor, uint Prop, uint ElementID)
{
	// NormalColor = nx,ny,nz,ShadowWeight
	uint3 un = (uint3)(NormalColor * 255.0);
	uint p = (un.b >> 3 << 11) | (un.g >> 2 << 5) | (un.r >> 3);
	p |= ((Prop & 0x000000ff) << 16);
	p |= ((ElementID & 0x000000ff) << 24);

	return p;
}
float3 Unpack_UINT_To_Normal_Property_ElementID(out uint ElementID, out uint Prop, uint p)
{
	ElementID = ((p & 0xff000000) >> 24);

	uint3 un;
	un.r = (p & 0x0000001f) << 3;
	un.g = (p & 0x000007e0) >> 5 << 2;
	un.b = (p & 0x0000f800) >> 11 << 3;

	Prop = ((p & 0x00ff0000) >> 16);	// Property (texShadwoMask등...)
	
	float3 normal = (float3)un * (1.0 / 255.0);
	return normal;
}

static uint3 g_boxIndexList[12] =
{
    uint3(0, 1, 2),
	uint3(0, 2, 3),

	uint3(4, 6, 5),
	uint3(4, 7, 6),

	uint3(0, 4, 1),
	uint3(4, 5, 1),

	uint3(2, 7, 3),
	uint3(7, 2, 6),

	uint3(0, 3, 7),
	uint3(0, 7, 4),

	uint3(1, 6, 2),
	uint3(5, 6, 1)
};

static float3 g_boxVertexList[8] =
{
    float3(-1, 1, 1),
	float3(-1, -1, 1),
	float3(1, -1, 1),
	float3(1, 1, 1),
	float3(-1, 1, -1),
	float3(-1, -1, -1),
	float3(1, -1, -1),
	float3(1, 1, -1)
};

static int2 g_AABB_To_VertexList_Filter[8][3] =
{
    int2(1, 0), int2(0, 1), int2(0, 1),
    int2(1, 0), int2(1, 0), int2(0, 1),
    int2(0, 1), int2(1, 0), int2(0, 1),
    int2(0, 1), int2(0, 1), int2(0, 1),
    int2(1, 0), int2(0, 1), int2(1, 0),
    int2(1, 0), int2(1, 0), int2(1, 0),
    int2(0, 1), int2(1, 0), int2(1, 0),
    int2(0, 1), int2(0, 1), int2(1, 0)
};


struct INT_AABB
{
    int4 Min;
    int4 Max;
};
#endif