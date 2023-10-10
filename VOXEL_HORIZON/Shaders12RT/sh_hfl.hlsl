//#define SHADER_PARAMETER_ATT_LIGHT	1
//#define SHADER_PARAMETER_RECV_SHADOW	1
#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_constant_buffer_default.hlsl"
#include "sh_constant_buffer_material.hlsl"
#include "sh_att_light.hlsl"

cbuffer ConstantBufferTexCoord : register(b1)
{
	float4		fTileTexCoord0;
	float4		fTileTexCoord1;
	float4		fTileTexCoord2;
	float4		fTileTexCoord3;

	float4		fAlphaTexCoord0;
	float4		fAlphaTexCoord1;
	float4		fAlphaTexCoord2;
	float4		fAlphaTexCoord3;


}

Texture2D		texDiffuse		: register(t0);
Texture2D		texAlphaMap		: register(t1);


//Texture2D		texScreenTex	: register( t4 );

SamplerState	samplerWrap		: register(s0);
SamplerState	samplerClamp	: register(s1);
SamplerState	samplerBorder	: register(s2);

//--------------------------------------------------------------------------------------
struct VS_INPUT_HFL
{
	float4		Pos				: POSITION;
	float3		Normal			: NORMAL;
	uint        instId          : SV_InstanceID;
};
struct VS_OUTPUT_HFL
{
	float4 Pos              : SV_POSITION;
	float3 Normal			: NORMAL;
	float2 TexCoordTile     : TEXCOORD0;
	float2 TexCoordAlphaMap : TEXCOORD1;
	float4 PosShadowSpace   : TEXCOORD2; // x/w = (0-1), y/w = (0-1), z/w = (0-1)
	float4 PosWorld         : TEXCOORD3;
	float Dist : TEXCOORD4;
	float Clip : SV_ClipDistance;
	uint ArrayIndex         : BLENDINDICES;
#if (1 == VS_RTV_ARRAY)
	uint RTVIndex : SV_RenderTargetArrayIndex;
#endif
};
struct GS_OUTPUT_HFL : VS_OUTPUT_HFL
{
#if (1 != VS_RTV_ARRAY)
	uint RTVIndex : SV_RenderTargetArrayIndex;
#endif
};
struct PS_INPUT_HFL : VS_OUTPUT_HFL
{
};



//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------
PS_INPUT_HFL vsDefault(VS_INPUT_HFL input)
{
	PS_INPUT_HFL output = (PS_INPUT_HFL)0;

	uint ArrayIndex = input.instId % 2;
	output.Pos = mul(input.Pos, g_Camera.matWorldViewProjArray[ArrayIndex]);

	// 월드공간에서의 버텍스 좌표
	output.PosWorld = input.Pos;
	output.Dist = output.Pos.w;

	// 클립플레인처리
	output.Clip = dot(input.Pos, ClipPlane);

	output.Normal = input.Normal;
	output.TexCoordTile.x = dot(input.Pos, fTileTexCoord0);
	output.TexCoordTile.y = dot(input.Pos, fTileTexCoord1);
	output.TexCoordAlphaMap.x = dot(input.Pos, fAlphaTexCoord0);
	output.TexCoordAlphaMap.y = dot(input.Pos, fAlphaTexCoord1);
	output.ArrayIndex = ArrayIndex;
#if (1 == VS_RTV_ARRAY)
	output.RTVIndex = ArrayIndex;
#endif
	return output;
}


[maxvertexcount(3)]
void gsStaticHFL(triangle VS_OUTPUT_HFL input[3], inout TriangleStream<GS_OUTPUT_HFL> TriStream)
{
	GS_OUTPUT_HFL output[3];
	/*
	float4 Pos              : SV_POSITION;
	float4 NormalColor      : COLOR0;
	float2 TexCoordTile     : TEXCOORD0;
	float2 TexCoordAlphaMap : TEXCOORD1;
	float4 PosShadowSpace   : TEXCOORD2; // x/w = (0-1), y/w = (0-1), z/w = (0-1)
	float4 PosWorld         : TEXCOORD3;
	float Dist              : TEXCOORD4;
	float Clip              : SV_ClipDistance;
	uint ArrayIndex         : BLENDINDICES;
*/
	for (uint i = 0; i < 3; i++)
	{
		output[i].Pos = input[i].Pos;
		output[i].Normal = input[i].Normal;
		output[i].TexCoordTile = input[i].TexCoordTile;
		output[i].TexCoordAlphaMap = input[i].TexCoordAlphaMap;
		output[i].PosShadowSpace = input[i].PosShadowSpace;
		output[i].PosWorld = input[i].PosWorld;
		output[i].Dist = input[i].Dist;
		output[i].Clip = input[i].Clip;
		output[i].ArrayIndex = input[i].ArrayIndex;
		output[i].RTVIndex = input[i].ArrayIndex;
		TriStream.Append(output[i]);
	}
}



//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
PS_TARGET psDefault(PS_INPUT_HFL input)
{
	PS_TARGET output = (PS_TARGET)0;

	float4	texColorAlphaMap = texAlphaMap.Sample(samplerClamp, input.TexCoordAlphaMap);
	clip(texColorAlphaMap.a - 0.003f);

	float4	texColorDiffuse = texDiffuse.Sample(samplerWrap, input.TexCoordTile);
	output.Color0 = float4(texColorDiffuse.rgb, texColorAlphaMap.a);
	output.Color1 = float4(input.Normal * 0.5f + 0.5f, (float)Property / 255.0f);
	output.Color2 = float4(0, (float)MtlPreset / 255.0, (float)g_TrCommon.ShadingType / 255.0, 0);
	
	return output;
}

PS_TARGET psInnerSphere(PS_INPUT_HFL input)
{
	// 툴에서 사용하기 위해 스피어 영역만큼만 렌더링
	// 스피어영역은 AttLight[0]을 사용

	PS_TARGET output = (PS_TARGET)0;


	float3	SpherePos = float3(PublicConst[0].x, PublicConst[0].y, PublicConst[0].z);
	float	Rs = PublicConst[0].w;

	float dist = distance(SpherePos, input.PosWorld.xyz);
	clip(Rs - dist);


	output.Color0 = MtlDiffuse;
	output.Color1 = float4(input.Normal * 0.5f + 0.5f, (float)Property / 255.0f);
	output.Color2 = float4(0, (float)MtlPreset / 255.0, (float)g_TrCommon.ShadingType / 255.0, 0);

	return output;
}


float4 vsHFLDepthSimple(VS_INPUT_HFL input) : SV_POSITION
{
	//PosView.z += 5.0f;
	float4	outPos = mul(input.Pos, g_Camera.matWorldViewProjCommon);

	return outPos;
}


float4 psHFLDepthSimple(float4 input : SV_POSITION) : SV_Target
{
	float	depth = input.z / input.w;
//return float4(0,0,0,1);
return float4(depth,depth,depth,1);
}


VS_OUTPUT_HFL vsXYZ(VS_INPUT_HFL input)
{
	VS_OUTPUT_HFL output = (VS_OUTPUT_HFL)0;

	uint	ArrayIndex = input.instId % 2;

	// 출력버텍스
	output.Pos = mul(input.Pos, g_Camera.matWorldViewProjArray[ArrayIndex]);

	return output;
}
float4 psColor(PS_INPUT_HFL input) : SV_Target
{
	float4 outColor = MtlDiffuse;

	return outColor;
}