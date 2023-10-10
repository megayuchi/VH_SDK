#ifndef SH_DYNAMIC_COMMON_HLSL
#define SH_DYNAMIC_COMMON_HLSL

#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_typedef.hlsl"
#include "sh_constant_buffer_default.hlsl"
#include "sh_constant_buffer_material.hlsl"
#include "sh_dynamic_physique.hlsl"

Texture2D		texDiffuse		: register(t0);
Texture2D		texMask			: register(t1);
Texture2D		texToon			: register(t2);
//Texture3D		texGI			: register( t4 );

SamplerState	samplerWrap			: register(s0);
SamplerState	samplerClamp		: register(s1);
SamplerState	samplerBorder		: register(s2);
SamplerState	samplerMirror		: register(s3);



cbuffer ConstantBufferLightCube : register(b5)
{
	LIGHT_CUBE_CONST	LightCube;
}

//--------------------------------------------------------------------------------------




struct VS_OUTPUT
{
	float4	Pos				: SV_POSITION;
	float4	Diffuse			: COLOR0;
	float4	NormalColor		: COLOR1;
	float2	TexCoordDiffuse	: TEXCOORD0;
	float4	PosWorld		: TEXCOORD1;
	float	Dist			: TEXCOORD2;
	float	NdotL[8]		: TEXCOORD3;
	float	Clip : SV_ClipDistance;
	uint    ArrayIndex      : BLENDINDICES0;
	uint	Property		: BLENDINDICES1;
#if (1 == VS_RTV_ARRAY)
	uint    RTVIndex        : SV_RenderTargetArrayIndex;
#endif	
};

struct GS_OUTPUT : VS_OUTPUT
{
#if (1 != VS_RTV_ARRAY)
	uint RTVIndex : SV_RenderTargetArrayIndex;
#endif
};
struct GS_OUTPUT_VP : VS_OUTPUT
{
	uint VPIndex : SV_ViewportArrayIndex;
};

struct PS_INPUT : VS_OUTPUT
{
};

VS_OUTPUT vsNonLight(VS_INPUT_VL input)
{
	VS_OUTPUT output = (VS_OUTPUT)0;

	uint	ArrayIndex = input.instId % 2;

	// 출력버텍스
	output.Pos = mul(input.Pos, g_Camera.matWorldViewProjArray[ArrayIndex]);
	output.PosWorld = mul(input.Pos, g_TrCommon.matWorld);
	output.Diffuse = MtlAmbient;
	output.Diffuse.a = MtlDiffuse.a;

	output.TexCoordDiffuse = input.TexCoord;


	// 노멀을 월드좌표계로 변환
	float3	Normal = mul(input.Normal, (float3x3)g_TrCommon.matWorld);

	// 다시 노멀라이즈
	Normal = normalize(Normal);
	// 노멀을 0에서 1사이로 포화
	output.NormalColor.rgb = (Normal * 0.5f) + 0.5f;
	output.NormalColor.a = 1;
	output.ArrayIndex = ArrayIndex;
#if (1 == VS_RTV_ARRAY)
	output.RTVIndex = ArrayIndex;
#endif
	return output;
}

VS_OUTPUT vsDynamicXYZPhysique(VS_INPUT_VL_PHYSIQUE input)
{
	VS_OUTPUT output = (VS_OUTPUT)0;

	uint	ArrayIndex = input.instId % 2;

	// 블랜딩된 로컬포지션을 계산
	float3	posLocal = vsCalcBlendPos(input.Pos, input.BlendIndex, input.BlendWeight);

	// 출력 버텍스
	output.Pos = mul(float4(posLocal, 1), g_Camera.matWorldViewProjArray[ArrayIndex]);
	output.ArrayIndex = ArrayIndex;
#if (1 == VS_RTV_ARRAY)
	output.RTVIndex = ArrayIndex;
#endif
	return output;
}
[maxvertexcount(3)]
void gsDynamicDefault(triangle VS_OUTPUT input[3], inout TriangleStream<GS_OUTPUT> TriStream)
{
	GS_OUTPUT output[3];

	[unroll]
	for (uint i = 0; i < 3; i++)
	{
		output[i].Pos = input[i].Pos;
		output[i].Diffuse = input[i].Diffuse;
		output[i].NormalColor = input[i].NormalColor;
		output[i].TexCoordDiffuse = input[i].TexCoordDiffuse;
		output[i].PosWorld = input[i].PosWorld;
		output[i].Dist = input[i].Dist;
	
		[unroll]
		for (uint j = 0; j < 8; j++)
		{
			output[i].NdotL[j] = input[i].NdotL[j];
		}
		output[i].Clip = input[i].Clip;
		output[i].RTVIndex = input[i].ArrayIndex;
		output[i].ArrayIndex = input[i].ArrayIndex;
		output[i].Property = input[i].Property;
		TriStream.Append(output[i]);
	}
}
PS_TARGET psDiffuseTex(PS_INPUT input)
{
	PS_TARGET output = (PS_TARGET)0;

	float4 texColor = texDiffuse.Sample(samplerWrap, input.TexCoordDiffuse);

	output.Color0 = texColor;
	output.Color1 = float4(input.NormalColor.xyz, (float)Property / 255.0f);
	output.Color2 = float4(0, 0, 0, 0);
	return output;
}

PS_TARGET psSky(PS_INPUT input) : SV_Target
{
	PS_TARGET output = (PS_TARGET)0;

	float4 texColor = texDiffuse.Sample(samplerWrap, input.TexCoordDiffuse);

	output.Color0 = texColor;
	output.Color1 = float4(input.NormalColor.xyz, (float)Property / 255.0f);
	output.Color2 = float4(0, 0, 0, 0);

	return output;
}

VS_OUTPUT vsXYZ(VS_INPUT_VL input)
{
	VS_OUTPUT output = (VS_OUTPUT)0;

	uint	ArrayIndex = input.instId % 2;

	// 출력버텍스
	output.Pos = mul(input.Pos, g_Camera.matWorldViewProjArray[ArrayIndex]);

	return output;
}
float4 psColor(PS_INPUT input) : SV_Target
{
	float4 outColor = MtlDiffuse;

	return outColor;
}
#endif