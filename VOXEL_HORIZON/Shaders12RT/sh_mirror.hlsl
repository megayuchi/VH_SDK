#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_constant_buffer_default.hlsl"
#include "sh_constant_buffer_material.hlsl"

cbuffer ConstantBufferMirror : register(b1)
{
	matrix		matReflectTexCoord;
}

Texture2D		texDiffuse : register(t0);	// diffuse
Texture2D		texReflect		: register(t3);	// 반사

SamplerState	samplerWrap			: register(s0);
SamplerState	samplerClamp		: register(s1);



//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------

struct VS_OUTPUT_MIRROR
{
	float4	Pos				: SV_POSITION;
	float4	Diffuse			: COLOR0;
	float4	MtlDiffuseAdd	: COLOR1;
	float4	NormalColor		: COLOR2;
	float2	TexCoordDiffuse	: TEXCOORD0;
	float4	TexCoordReflect	: TEXCOORD1;
	float4	PosWorld		: TEXCOORD2;
	float	Clip : SV_ClipDistance;
	uint    ArrayIndex      : BLENDINDICES;
#if (1 == VS_RTV_ARRAY)
	uint    RTVIndex        : SV_RenderTargetArrayIndex;
#endif
};

struct GS_OUTPUT_MIRROR : VS_OUTPUT_MIRROR
{
#if (1 != VS_RTV_ARRAY)
	uint RTVIndex : SV_RenderTargetArrayIndex;
#endif
};

struct PS_INPUT_MIRROR : VS_OUTPUT_MIRROR
{
};

PS_INPUT_MIRROR vsDefault(VS_INPUT_VL input)
{
	PS_INPUT_MIRROR output = (PS_INPUT_MIRROR)0;

	uint ArrayIndex = input.instId % 2;

	// 출력버텍스
	output.Pos = mul(input.Pos, g_Camera.matWorldViewProjArray[ArrayIndex]);
	output.PosWorld = mul(input.Pos, g_TrCommon.matWorld);
	/*
	float4	Diffuse = float4(1,1,1,0.5);
	float4	MtlDiffuseAdd = float4(0,0,0,0);
	float4	Ambient = float4(0,0,0,0);
	*/

	output.Diffuse = MtlDiffuse;//saturate(Diffuse + Ambient);
	output.MtlDiffuseAdd = MtlDiffuseAdd;


	output.TexCoordDiffuse = input.TexCoord;
	output.TexCoordReflect = mul(input.Pos, matReflectTexCoord);

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


[maxvertexcount(3)]
void gsDefault(triangle VS_OUTPUT_MIRROR input[3], inout TriangleStream<GS_OUTPUT_MIRROR> TriStream)
{
	GS_OUTPUT_MIRROR output[3];

	for (uint i = 0; i < 3; i++)
	{
		output[i].Pos = input[i].Pos;
		output[i].Diffuse = input[i].Diffuse;
		output[i].MtlDiffuseAdd = input[i].MtlDiffuseAdd;
		output[i].NormalColor = input[i].NormalColor;
		output[i].TexCoordDiffuse = input[i].TexCoordDiffuse;
		output[i].TexCoordReflect = input[i].TexCoordReflect;
		output[i].PosWorld = input[i].PosWorld;
		output[i].Clip = input[i].Clip;
		output[i].ArrayIndex = input[i].ArrayIndex;
		output[i].RTVIndex = input[i].ArrayIndex;
		TriStream.Append(output[i]);
	}
}
PS_TARGET psDefault(PS_INPUT_MIRROR input)
{
	PS_TARGET output = (PS_TARGET)0;

	float4	DiffuseTexColor = texDiffuse.Sample(samplerWrap, input.TexCoordDiffuse);
	float4	DiffuseColor = DiffuseTexColor * input.Diffuse;

	float2	TexCoordReflect = input.TexCoordReflect.xy / input.TexCoordReflect.w;

	float4	ReflectColor = texReflect.Sample(samplerWrap, TexCoordReflect);
	float4	OutColor = lerp(DiffuseColor, float4(ReflectColor.xyz, 1), 0.5f);

	output.Color0 = float4(OutColor.rgb, DiffuseColor.a);
	output.Color1 = float4(input.NormalColor.xyz, (float)Property / 255.0f);
	output.Color2 = float4(0, (float)MtlPreset / 255.0, (float)g_TrCommon.ShadingType / 255.0, 0);
	return output;
}
