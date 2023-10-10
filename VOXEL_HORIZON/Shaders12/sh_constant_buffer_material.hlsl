#ifndef SH_CONSTANT_BUFFER_MATERIAL_HLSL
#define SH_CONSTANT_BUFFER_MATERIAL_HLSL

#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_typedef.hlsl"

// Vertex Shader Constant ///////////////////////////

cbuffer CONSTANT_BUFFER_MATERIAL : register(b2)
{
	float4		MtlDiffuse;
	float4		MtlAmbient;
	float4		MtlDiffuseAdd;		// 머리카락 도색등 특수한 경우 강조해주기 위해 픽셀 쉐이더로 넘어간 이후 사용
	float4		MtlToneColor;		// 최종렌더링 결과물에 곱해줄 상수, 밝기가 어두울때 주로 사용
	float4		MinNdotL;			// min (r,g,b,a = VertexLighting시 N dot L의 최저값)
	uint		MtlAlphaMode;
    uint MeshletNumPerFaceGroup;
	uint MtlPreset;
	uint MtlReserved2;
    TILED_RESOURCE_PROPERTY TiledResourceProp;
}

#endif