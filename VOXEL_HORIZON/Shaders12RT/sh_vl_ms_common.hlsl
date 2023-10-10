#ifndef SH_VL_MS_COMMON_HLSL
#define SH_VL_MS_COMMON_HLSL

//#define SHADER_PARAMETER_ATT_LIGHT	1
//#define SHADER_PARAMETER_PHYSIQUE		1
//#define SHADER_PARAMETER_LIGHT_PRB	1
//#define SHADER_PARAMETER_USE_OIT		1
//#define SHADER_PARAMETER_USE_TILED_RESOURCES 1
//#define LIGHTING_TYPE	0	//(vlmesh에서 LIGHTING_TYPE이 0인 경우는 없다.)
#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_ms_common.hlsl"
#include "sh_typedef.hlsl"

#if (1 == SHADER_PARAMETER_PHYSIQUE)
#define VS_INPUT	VS_INPUT_VL_PHYSIQUE
#else
#define VS_INPUT	VS_INPUT_VL
#endif

#if (1 == SHADER_PARAMETER_PHYSIQUE)
StructuredBuffer <D3DVLVERTEX_PHYSIQUE> g_Vertices : register(t3);
#else
StructuredBuffer<D3DVLVERTEX> g_Vertices : register(t3);
#endif

#define MS_THREAD_NUM_PER_GROUP_VL 64
#define MAX_INDEXED_VERTEX_NUM_PER_MESHLET_SHADOW_CASTER_VL (MAX_INDEXED_VERTEX_NUM_PER_MESHLET_VL * MAX_CASCADE_NUM)
#define MAX_INDEXED_TRI_NUM_PER_MESHLET_SHADOW_CASTER_VL (MAX_INDEXED_TRI_NUM_PER_MESHLET_VL * MAX_CASCADE_NUM)

#endif