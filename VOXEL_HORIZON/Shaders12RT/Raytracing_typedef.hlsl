#ifndef RAYTRACING_CONST_BUFFERL_HLSL
#define RAYTRACING_CONST_BUFFERL_HLSL

#include "PreDefine_CPP_Shader.h"
#include "sh_define.hlsl"
#include "sh_typedef.hlsl"
#include "BxDF.hlsl"

enum SHADING_TYPE
{
	SHADING_TYPE_VERTEX_LIGHT = 0x00000000,
	SHADING_TYPE_PERPIXEL_NORMAL = 0x00000001,
	SHADING_TYPE_TOON = 0x00000002,
	SHADING_TYPE_SKY = 0x00000003,
	SHADING_TYPE_STRUCT = 0x00000004,		// 건물 전용
	SHADING_TYPE_HFIELD = 0x00000005,
	SHADING_TYPE_SHADOW_CASTER = 0x00000006,		// 그림자 생성 등등
	SHADING_TYPE_POSTEFFECT = 0x00000007,		// 그림자 생성 등등
	SHADING_TYPE_WATER = 0x00000008,
	SHADING_TYPE_WATER_BOTTOM = 0x00000009,
	SHADING_TYPE_COLOR = 0x0000000A,		// 단색 컬러 렌더링,
	SHADING_TYPE_FLAT = 0x0000000C,			// Flat Shading
	SHADING_TYPE_BLOCK = 0x0000000D,		// as Blocks
	SHADING_TYPE_UNKNOWN = -1
};
static const uint MAX_SHADING_TYPE_NUM = 13;


#define DWORD uint
#define UINT uint

// property type
static const uint BLAS_PROPERTY_TYPE_CHARACTER = 0;
static const uint BLAS_PROPERTY_TYPE_STRUCT = 1;
static const uint BLAS_PROPERTY_TYPE_EFFECT = 2;


// mesh type
static const uint BLAS_INSTANCE_TYPE_DYNAMIC = 0;
static const uint BLAS_INSTANCE_TYPE_STATIC = 1;

static const uint BLAS_PRIMITIVE_TYPE_TRIANGLE = 0;
static const uint BLAS_PRIMITIVE_TYPE_VOXEL_TRIANGLE = 1;

// DXR의 Instance ID는 24비트만 사용.
// 최상위 2비트를 PRIMITIVE_TYPE_MASK로, primitive type에서 2비트 아래는 PropertyType으로 사용한다
//0b00000000110000000000000000000000
//0b00000000001100000000000000000000
//const DWORD BLAS_PRIMITIVE_TYPE_MASK = (0b11 << 22);		// 최상위 2비트가 primitive type
//const DWORD BLAS_PROPERTY_TYPE_MASK = (0b11 << 20);		// primitive type에서 2비트 아래
static const uint BLAS_PRIMITIVE_TYPE_MASK = 0x00c00000;	// 최상위 2비트가 primitive type
static const uint BLAS_PROPERTY_TYPE_MASK = 0x00300000;		// primitive type에서 2비트 아래

static const uint BLAS_NON_INDEX_MASK = (BLAS_PRIMITIVE_TYPE_MASK | BLAS_PROPERTY_TYPE_MASK);

#define BLAS_PRIMITIVE_TYPE uint
#define BLAS_PROPERTY_TYPE uint

UINT CreateInstanceID(DWORD dwInstanceIndex, BLAS_PRIMITIVE_TYPE PrimType, BLAS_PROPERTY_TYPE PropType)
{
	UINT ID = (dwInstanceIndex & (~BLAS_NON_INDEX_MASK)) | (PrimType << 22) | (PropType << 20);
	return ID;
}
DWORD GetInstanceIndex(UINT InstanceID)
{
	DWORD dwInstanceIndex = InstanceID & (~BLAS_NON_INDEX_MASK);
	return dwInstanceIndex;
}
BLAS_PRIMITIVE_TYPE GetPrimitiveType(UINT InstanceID)
{
	BLAS_PRIMITIVE_TYPE	PrimType = (BLAS_PRIMITIVE_TYPE)((InstanceID & BLAS_PRIMITIVE_TYPE_MASK) >> 22);
	return PrimType;
}
BLAS_PROPERTY_TYPE GetPropertyType(UINT InstanceID)
{
	BLAS_PROPERTY_TYPE	PropType = (BLAS_PROPERTY_TYPE)((InstanceID & BLAS_PROPERTY_TYPE_MASK) >> 20);
	return PropType;
}


static const float INVALID_AO_DISTNACE = 0.0;
#define HitDistanceOnMiss 0

static const uint g_IndexSizeInBytes = 2;
static const uint g_IndicesPerTriangle = 3;
static const uint g_TriangleIndexStride = g_IndicesPerTriangle * g_IndexSizeInBytes;

#define MIN_VOXEL_SIZE 50.0
#define MAX_VOXELS_PER_AXIS 8
#define VERTEX_COUNT_PER_PLANE		(3*2)	// triangle(3) * 2trinagls per plane(2)
#define VERTEX_COUNT_PER_VOXEL		(3*2*6)	// triangle(3) * 2trinagls per plane(2) * plane_count(6)

struct RAY_TRACING_VOXEL_COLOR_TABLE
{
	// instance(아마도 오브젝트)별 상수버퍼
	// 복셀오브젝트인 경우
	//uint	InstanceIndex;
	//uint	Reserved1;
	//uint	Reserved2;
	//uint	Reserved3;
	uint4	Palette[(MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS * MAX_VOXELS_PER_AXIS) / 16];	// 512 Palette 
};

struct RAY_TRACING_RENDER_OPTION
{
	float3	Diffuse;
	uint	ShadingType;
	float3	DiffuseAdd;
	uint	Flags;
};

// shadint Type에 따른 프로퍼티
struct PROPERTY_PER_SHADING_TYPE
{
	float	fMinAmbientIllumination;
	float	AORadius;
	float	AO_MaxTheoreticalAORayHitTime;
	uint	Reserved3;
};
static const uint RTLIGHT_TYPE_DIRECTIONAL = 0;
static const uint RTLIGHT_TYPE_POINT = 1;

struct RT_LIGHT
{
	float3 Pos;
	float Rs;
	float3 Color;
	uint Type;
	bool ShadowEnabled;
	uint Reserved0;
	uint Reserved1;
	uint Reserved2;
};
static const uint MAX_RTLIGHT_NUM = 32;
cbuffer CONSTANT_BUFFER_RAY_TRACING : register(b0)
{
	matrix	g_ViewProj[2];
	matrix	g_PrvViewProj[2];
	matrix	g_ViewInvArray[2];
	DECOMP_PROJ	g_DecompProj[2];
	float4 g_CaemraPosition;  // matViewInvArray로 대체할것

	float g_Near;
	float g_Far;
	bool g_RTAOEnabled;
	uint g_AO_RandomSeed;

	uint g_AO_SampleRayNum;
	uint g_FrameCount;
	float g_TimeValue;
	uint CBRT_Reserved0;

	float g_Kr_Mul_Const;	// 글로벌 반사곱셈계수
	float g_Ks_Mul_Const;	// 글로벌 스페큘러곱셈계수
	float CBRT_Reserved1;
	float CBRT_Reserved2;

	float4	g_ColorOverRecusionDepth;

	uint g_MaxRadianceRayRecursionDepth;
	uint g_MaxEffectRadianceRayRecursionDepth;
	uint g_MaxShadowRayRecursionDepth;
	uint g_RTLightNum;

	RT_LIGHT	g_RTLightList[MAX_RTLIGHT_NUM];
};

struct CONSTANT_BUFFER_RAY_GEOM
{
	float3 Pos;			// position of voxel object
	uint PackedProperty;	// Reserved | Bulb On/Off | VoxelsPerAxis | MaterialPreset | VoxelObjIndex 
	
	//uint MaterialPreset;
	//uint VoxelsPerAxis;	// width_depth_height ( ex 1,2,4, 8)
	//float VoxelSize;	// voxel size (50cm , 100cm , 200cm, 400cm)
	//uint VoxelObjIndex;	// voxel Obj일때 const buffer indxt
	//uint FaceGroupIndex;
};

static const uint ALPHA_TRANSP = 0;
static const uint ALPHA_ADD = 1;
static const float3	BW_CONST = float3(0.3, 0.59, 0.11);
static const float RT_ALPHA_TEST_THRESHOLD = 0.001;
//static const float RT_ALPHA_TEST_THRESHOLD = 0.025;

struct RAY_TRACING_MATERIAL
{
	float3 Kd;
	bool hasDiffuseTexture;
	float3 Ks;
	float roughness;
	float3 Kr;
	bool hasNormalTexture;
	float3 Kt;
	bool hasPerVertexTangents;
	float3 opacity;
	MaterialType::Type type;
	float3 eta;
	float AmbientIntensity;
	uint AlphaType;
	bool bUseRTAO;
	bool bIsWater;
	uint Reserved3;
};
struct AO_BUFFER
{
	float AO_CoEfficient;
	float AO_Distance;
	uint NormalDepth;	// normal.xyz | linear depth
	float LinearDepth;
	float2 MotionVector;
	uint ReprojectedNormalDepth;
	bool RTAOEnabled;
};

struct RadiancePayload
{
	float3 radiance;              // TODO encode
	float depth;
	uint rayRecursionDepth;
	uint NormalColor;
	uint ElementColor;
#if defined(RTAO_IN_TRACE_RAY)
	AO_BUFFER ao;
#endif
};

struct ShadowPayload
{
    float tHit;         // Hit time <0,..> on Hit. -1 on miss.
};
static const float NEAR_PLANE = 1.0;
static const float FAR_PLANE = 80000.0;

typedef BuiltInTriangleIntersectionAttributes MyAttributes;

#endif