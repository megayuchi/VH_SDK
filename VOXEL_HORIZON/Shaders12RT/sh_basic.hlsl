//#include "sh_typedef.hlsl"
#ifndef SH_BASIC_HLSL
#define SH_BASIC_HLSL

#include "sh_constant_buffer_default.hlsl"
#include "sh_constant_buffer_material.hlsl"

struct PS_INPUT_COLOR
{
	float4 Pos : SV_POSITION;
};

struct PS_INPUT_DEPTH
{
	float4 Pos : SV_POSITION;
	float Depth : ZDEPTH;
};

PS_INPUT_COLOR vsXYZ(float4 Pos : POSITION)
{
	PS_INPUT_COLOR output = (PS_INPUT_COLOR)0;

	output.Pos = mul(Pos, g_Camera.matWorldViewProjCommon);

	return output;
}
float4 psColor(PS_INPUT_COLOR input) : SV_Target
{
	float4 outColor = MtlDiffuse;

	return outColor;
}

PS_INPUT_DEPTH vsDepthDist(float4 Pos : POSITION)
{
	PS_INPUT_DEPTH output = (PS_INPUT_DEPTH)0;

	output.Pos = mul(Pos, g_Camera.matWorldViewProjCommon);
	//output.Depth = output.Pos.z / output.Pos.w;
	//output.Depth = saturate(output.Pos.w * (1.0f / 10000.0f));
	output.Depth = output.Pos.w * ProjConstant.fFarRcp;


	return output;
}

float4 psDepthDist(PS_INPUT_DEPTH input) : SV_Target
{
	float4 outColor = float4(input.Depth, input.Depth, input.Depth, 1);
	//float4	outColor = float4(input.Depth,1,1,1);

	return outColor;
}

#endif