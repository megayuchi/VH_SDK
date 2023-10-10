#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_post_effect_common.hlsl"


#ifdef STEREO_RENDER
Texture2DArray  texPrimary  : register(t0);
Texture2DArray  texOutLine  : register(t1);
#else
Texture2D		texPrimary  : register(t0);
Texture2D		texOutLine  : register(t1);
#endif

struct VS_OUTPUT_BLUR
{
	float4  Position    : SV_Position;
	float2  TexCoord[7] : TEXCOORD0;
	uint    ArrayIndex  : BLENDINDICES;
#if (1 == VS_RTV_ARRAY)
	uint    RTVIndex    : SV_RenderTargetArrayIndex;
#endif
};

struct GS_OUTPUT_BLUR : VS_OUTPUT_BLUR
{
#if (1 != VS_RTV_ARRAY)
	uint RTVIndex : SV_RenderTargetArrayIndex;
#endif
};
struct PS_INPUT_BLUR : VS_OUTPUT_BLUR
{


};

VS_OUTPUT_BLUR vsBlurX(uint VertexID : SV_VertexID, uint instId : SV_InstanceID)
{
	VS_OUTPUT_BLUR output = (VS_OUTPUT_BLUR)0;

	uint ArrayIndex = instId % 2;
	output.Position = float4(arrBasePos[VertexID].xy, 0.0, 1.0);

	// tex coord
	output.TexCoord[0] = arrBasePos[VertexID].zw + texCoordOffset7Sample[0].xy;
	output.TexCoord[1] = arrBasePos[VertexID].zw + texCoordOffset7Sample[1].xy;
	output.TexCoord[2] = arrBasePos[VertexID].zw + texCoordOffset7Sample[2].xy;
	output.TexCoord[3] = arrBasePos[VertexID].zw + texCoordOffset7Sample[3].xy;
	output.TexCoord[4] = arrBasePos[VertexID].zw + texCoordOffset7Sample[4].xy;
	output.TexCoord[5] = arrBasePos[VertexID].zw + texCoordOffset7Sample[5].xy;
	output.TexCoord[6] = arrBasePos[VertexID].zw;

	output.ArrayIndex = ArrayIndex;
#if (1 == VS_RTV_ARRAY)
	output.RTVIndex = ArrayIndex;
#endif
	return output;
}

VS_OUTPUT_BLUR vsBlurY(uint VertexID : SV_VertexID, uint instId : SV_InstanceID)
{
	VS_OUTPUT_BLUR output = (VS_OUTPUT_BLUR)0;

	uint ArrayIndex = instId % 2;
	output.Position = float4(arrBasePos[VertexID].xy, 0.0, 1.0);

	// tex coord
	output.TexCoord[0] = arrBasePos[VertexID].zw + texCoordOffset7Sample[0].zw;
	output.TexCoord[1] = arrBasePos[VertexID].zw + texCoordOffset7Sample[1].zw;
	output.TexCoord[2] = arrBasePos[VertexID].zw + texCoordOffset7Sample[2].zw;
	output.TexCoord[3] = arrBasePos[VertexID].zw + texCoordOffset7Sample[3].zw;
	output.TexCoord[4] = arrBasePos[VertexID].zw + texCoordOffset7Sample[4].zw;
	output.TexCoord[5] = arrBasePos[VertexID].zw + texCoordOffset7Sample[5].zw;
	output.TexCoord[6] = arrBasePos[VertexID].zw;

	output.ArrayIndex = ArrayIndex;
#if (1 == VS_RTV_ARRAY)
	output.RTVIndex = ArrayIndex;
#endif
	return output;
}


[maxvertexcount(3)]
void gsBlurXY(triangle VS_OUTPUT_BLUR input[3], inout TriangleStream<GS_OUTPUT_BLUR> TriStream)
{
	GS_OUTPUT_BLUR output[3];

	for (uint i = 0; i < 3; i++)
	{
		output[i].Position = input[i].Position;
		for (uint j = 0; j < 7; j++)
		{
			output[i].TexCoord[j] = input[i].TexCoord[j];
		}
		output[i].ArrayIndex = input[i].ArrayIndex;
		output[i].RTVIndex = input[i].ArrayIndex;
		TriStream.Append(output[i]);
	}
}

float4 ps7SampleBlur(PS_INPUT_BLUR input) : SV_Target
{

	float4	ColorSum = 0;

	for (int i = 0; i < 7; i++)
	{
#ifdef STEREO_RENDER
		float3 TexCoord = float3(input.TexCoord[i].xy, input.ArrayIndex);
#else
		float2 TexCoord = float2(input.TexCoord[i].xy);
#endif
		ColorSum += texPrimary.Sample(samplerClampLinear, TexCoord);
	}
	float4	OutColor = ColorSum * (1.0f / 7.0f);

	return OutColor;

}
