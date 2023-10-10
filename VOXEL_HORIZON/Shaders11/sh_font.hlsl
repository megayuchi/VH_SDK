#include "sh_define.hlsl"
#include "shader_cpp_common.h"

cbuffer ConstantBufferFont : register(b0)
{
	matrix			matTex;
	matrix			matPos;
	float4			adjConstant;
	float4			diffuseColor;
}

Texture2D		texDiffuse		: register(t0);
SamplerState	samplerDiffuse	: register(s0);

//--------------------------------------------------------------------------------------
struct VS_INPUT_FONT
{
	float4		Pos		 : POSITION;
	float2		TexCoord : TEXCOORD0;
	uint        instId  : SV_InstanceID;

};
struct VS_OUTPUT_FONT
{
	float4 Pos : SV_POSITION;
	float4 Color : COLOR;
	float2 TexCoord : TEXCOORD0;
	uint ArrayIndex : BLENDINDICES;
#if (1 == VS_RTV_ARRAY)
	uint RTVIndex : SV_RenderTargetArrayIndex;
#endif
};
struct GS_OUTPUT_FONT : VS_OUTPUT_FONT
{
#if (1 != VS_RTV_ARRAY)
	uint RTVIndex : SV_RenderTargetArrayIndex;
#endif
};
struct PS_INPUT_FONT : VS_OUTPUT_FONT
{
};

//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------

VS_OUTPUT_FONT vsDefault(VS_INPUT_FONT input)
{
	VS_OUTPUT_FONT output = (VS_OUTPUT_FONT)0;

	uint ArrayIndex = input.instId % 2;

	// position
	float4 posSrc;
	posSrc.xy = input.Pos.xy;
	posSrc.z = adjConstant.z;
	posSrc.w = adjConstant.y;


	// tex coord
	float4 texSrc;
	texSrc.xy = input.Pos.xy;
	texSrc.z = adjConstant.x;
	texSrc.w = adjConstant.y;

	output.Pos = mul(posSrc, matPos);
	output.TexCoord = (float2)mul(texSrc, matTex);
	output.Color = diffuseColor;
	output.ArrayIndex = ArrayIndex;
#if (1 == VS_RTV_ARRAY)
	output.RTVIndex = ArrayIndex;
#endif
	return output;
}
VS_OUTPUT_FONT vsRender3D(VS_INPUT_FONT input)
{
	VS_OUTPUT_FONT output = (VS_OUTPUT_FONT)0;

	uint ArrayIndex = input.instId % 2;

	// tex coord
	float4 texSrc;
	texSrc.xy = input.Pos.xy;
	texSrc.z = adjConstant.x;
	texSrc.w = adjConstant.y;

	output.Pos = mul(input.Pos, matPos);
	output.TexCoord = (float2)mul(texSrc, matTex);
	output.Color = diffuseColor;
	output.ArrayIndex = ArrayIndex;
#if (1 == VS_RTV_ARRAY)
	output.RTVIndex = ArrayIndex;
#endif
	return output;
}


[maxvertexcount(3)]
void gsDefault(triangle VS_OUTPUT_FONT input[3], inout TriangleStream<GS_OUTPUT_FONT> TriStream)
{
	GS_OUTPUT_FONT output[3];

	for (uint i = 0; i < 3; i++)
	{
		output[i].Pos = input[i].Pos;
		output[i].Color = input[i].Color;
		output[i].TexCoord = input[i].TexCoord;
		output[i].ArrayIndex = input[i].ArrayIndex;
		output[i].RTVIndex = input[i].ArrayIndex;
		TriStream.Append(output[i]);
	}
}

float4 psDefault(PS_INPUT_FONT input) : SV_Target
{

	float4	texColor = texDiffuse.Sample(samplerDiffuse, input.TexCoord);

	clip(texColor.r - 0.003f);

	float4	outColor;
	outColor.rgb = input.Color.rgb;
	outColor.a = texColor.r * input.Color.a;

	return outColor;
}
