//#define SHADER_PARAMETER_ATT_LIGHT	1
//#define SHADER_PARAMETER_USE_OIT 1

#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_constant_buffer_default.hlsl"
#include "sh_constant_buffer_material.hlsl"
#include "sh_lm_common.hlsl"
#include "sh_att_light.hlsl"
#include "sh_a_buffer.hlsl"



struct GS_OUTPUT_LM : VS_OUTPUT_LM
{
#if (1 != VS_RTV_ARRAY)
	uint RTVIndex : SV_RenderTargetArrayIndex;
#endif
};

struct PS_INPUT_LM : VS_OUTPUT_LM
{
};

//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------

VS_OUTPUT_LM vsDefault(VS_INPUT_LM input)
{
	VS_OUTPUT_LM output = (VS_OUTPUT_LM)0;

	uint ArrayIndex = input.instId % 2;

	output.Pos = mul(input.Pos, g_Camera.matWorldViewProjArray[ArrayIndex]);
	output.PosWorld = mul(input.Pos, g_TrCommon.matWorld);
	output.Dist = output.Pos.w;
	output.TexCoordDiffuse = input.TexCoordDiffuse;
	//output.TexCoordLightMap = input.TexCoordLightMap;


	// 노멀을 월드좌표계로 변환
	output.Normal = normalize(mul(input.Normal.xyz, (float3x3)g_TrCommon.matWorld));
	output.Tangent = normalize(mul(input.Tangent.xyz, (float3x3)g_TrCommon.matWorld));

	// 클립플레인처리
	output.Clip = dot(float4(output.PosWorld.xyz, 1), ClipPlane);
	output.Diffuse = float4(1, 1, 1, 1);
	//	float3	normal = mul(input.Normal,(float3x3)matWorld);
	//	float	NdotL = dot(normal,(float3)(ShadowLightDir));


	output.ArrayIndex = ArrayIndex;
#if (1 == VS_RTV_ARRAY)
	output.RTVIndex = ArrayIndex;
#endif	
	return output;
}

//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
PS_TARGET psDefault(PS_INPUT_LM input)
{
	PS_TARGET output = (PS_TARGET)0;

	float4 outColor;
	

	float4 texColorDiffuse = texDiffuse.Sample(samplerWrap, input.TexCoordDiffuse);
	float4 texNormalColor = texNormal.Sample(samplerWrap, input.TexCoordDiffuse);

	// 출력 diffuse
	outColor.rgb = texColorDiffuse.rgb * input.Diffuse.rgb;
	outColor.a = texColorDiffuse.a * MtlDiffuse.a;

	float3	binormal = cross(input.Tangent, input.Normal);
	float3	tan_normal = texNormalColor * 2 - 1;
	float3	surfaceNormal = (tan_normal.xxx * input.Tangent) + (tan_normal.yyy * binormal) + (tan_normal.zzz * input.Normal);
	
	float4	NormalColor = float4(surfaceNormal * float3(0.5, 0.5, 0.5) + float3(0.5, 0.5, 0.5), (float)Property / 255.0f);
	//float4	NormalColor = float4(input.Normal * float3(0.5, 0.5, 0.5) + float3(0.5, 0.5, 0.5), (float)Property / 255.0f);
	//float4	NormalColor = float4(input.Tangent * float3(0.5, 0.5, 0.5) + float3(0.5, 0.5, 0.5), (float)Property / 255.0f);
	//float4	NormalColor = float4(binormal * float3(0.5, 0.5, 0.5) + float3(0.5, 0.5, 0.5), (float)Property / 255.0f);
	output.Color0 = outColor;
	output.Color1 = NormalColor;
	output.Color2 = float4(0, (float)MtlPreset / 255.0, (float)g_TrCommon.ShadingType / 255.0, 0);

	return output;
}

[maxvertexcount(3)]
void gsStaticLM(triangle VS_OUTPUT_LM input[3], inout TriangleStream<GS_OUTPUT_LM> TriStream)
{
	GS_OUTPUT_LM output[3];

	for (uint i = 0; i < 3; i++)
	{
		output[i].Pos = input[i].Pos;
		output[i].Normal = input[i].Normal;
		output[i].Tangent = input[i].Tangent;
		output[i].TexCoordDiffuse = input[i].TexCoordDiffuse;
		//output[i].TexCoordLightMap = input[i].TexCoordLightMap;
		output[i].PosWorld = input[i].PosWorld;
		output[i].Dist = input[i].Dist;

		output[i].Clip = input[i].Clip;
		output[i].ArrayIndex = input[i].ArrayIndex;
		output[i].RTVIndex = input[i].ArrayIndex;
		TriStream.Append(output[i]);
	}
}

PS_TARGET psInnerSphere(PS_INPUT_LM input)
{
	// 툴에서 사용하기 위해 스피어 영역만큼만 렌더링
	// 스피어영역은 AttLight[0]을 사용

	PS_TARGET output = (PS_TARGET)0;


	float3 SpherePos = float3(PublicConst[0].x, PublicConst[0].y, PublicConst[0].z);
	float Rs = PublicConst[0].w;

	float dist = distance(SpherePos, input.PosWorld.xyz);
	clip(Rs - dist);

	
	output.Color0 = MtlDiffuse;
	output.Color1 = float4(input.Normal * float3(0.5, 0.5, 0.5) + float3(0.5, 0.5, 0.5), (float)Property / 255.0f);
	output.Color2 = float4(0, (float)MtlPreset / 255.0, (float)g_TrCommon.ShadingType / 255.0, 0);

	return output;
}

float4 vsLMDepthSimple(VS_INPUT_LM input) : SV_POSITION
{
	//PosView.z += 5.0f;
	float4 outPos = mul(input.Pos, g_Camera.matWorldViewProjCommon);

	return outPos;
}


float4 psLMDepthSimple(float4 input : SV_POSITION) : SV_Target
{
	float depth = input.z / input.w;
//return float4(0,0,0,1);
return float4(depth, depth, depth, 1);
}

VS_OUTPUT_LM vsXYZ(VS_INPUT_LM input)
{
	VS_OUTPUT_LM output = (VS_OUTPUT_LM)0;

	uint	ArrayIndex = input.instId % 2;

	// 출력버텍스
	output.Pos = mul(input.Pos, g_Camera.matWorldViewProjArray[ArrayIndex]);

	return output;
}
float4 psColor(PS_INPUT_LM input) : SV_Target
{
	float4 outColor = MtlDiffuse;

	return outColor;
}