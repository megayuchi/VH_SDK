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
	output.TexCoordLightMap = input.TexCoordLightMap;


	// 노멀을 월드좌표계로 변환
	float3 NormalWorld = mul(input.Normal, (float3x3)g_TrCommon.matWorld);

	NormalWorld = normalize(NormalWorld);

	// 노멀을 0에서 1사이로 포화
	output.NormalColor.rgb = (NormalWorld * 0.5f) + 0.5f;
	output.NormalColor.a = 1;

	// 클립플레인처리
	output.Clip = dot(float4(output.PosWorld.xyz, 1), ClipPlane);
    output.Diffuse = float4(1, 1, 1, 1);
	//	float3	normal = mul(input.Normal,(float3x3)matWorld);
	//	float	NdotL = dot(normal,(float3)(ShadowLightDir));

#if (1 == SHADER_PARAMETER_ATT_LIGHT)
	// 다이나믹 라이트 처리
	for (int i = 0; i < iAttLightNum; i++)
	{
		float3		LightVec = normalize((AttLight[i].Pos.xyz - output.PosWorld.xyz));
		output.NdotL[i] = dot(input.Normal, LightVec);
	}
#endif
	output.ArrayIndex = ArrayIndex;
#if (1 == VS_RTV_ARRAY)
	output.RTVIndex = ArrayIndex;
#endif	
	return output;
}

//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
#if (1 == SHADER_PARAMETER_USE_OIT)
[earlydepthstencil]
#endif
PS_TARGET psDefault(PS_INPUT_LM input)
{
	PS_TARGET output = (PS_TARGET)0;

	float4 outColor;

	float4 texColorDiffuse = texDiffuse.Sample(samplerWrap, input.TexCoordDiffuse);

#if (1 == SHADER_PARAMETER_USE_OIT)
	// Add 알파의 경우 알파테스트를 걸어줘야하지만, LMM Mesh에선 Add알파는 사용하지 않는다고 가정한다.
	//	if (MtlAlphaMode)
	//	{
	//		const float3	bwConst = float3(0.3f, 0.59f, 0.11f);
	//		float	bwColor = dot(texColorDiffuse.rgb, bwConst);
	//		if (bwColor < ALPHA_TEST_THRESHOLD_ADD)
	//			discard;
	//	}
	if (texColorDiffuse.a < ALPHA_TEST_THRESHOLD_TRANSP)
		discard;
#endif
	float4 texColorLightMap = texLightMap.Sample(samplerClamp, input.TexCoordLightMap);

	//float4	outColor = float4(1,1,1,1);
	//float4	outColor = texColorDiffuse;

	// 라이트맵 컬러값 보정
	//texColorLightMap.rgb += texColorLightMap.rgb;
	texColorLightMap.rgb *= LightMapConst.rgb;


	// 최종 컬러는 (라이트맵*2)*디퓨즈테텍스쳐
	outColor.rgb = texColorDiffuse.rgb * texColorLightMap.rgb * input.Diffuse.rgb;

	// ambient occlusion 상수적용
	outColor.rgb *= texColorLightMap.a;

	// 외부 지정 알파값
	outColor.a = texColorDiffuse.a * MtlDiffuse.a;

#if (1 == SHADER_PARAMETER_ATT_LIGHT)
	// 다이나믹 라이트 적용
	if (iAttLightNum > 0)
	{
		outColor.xyz += CalcAttLightColorWithNdotL(input.PosWorld.xyz, input.NdotL, iAttLightNum);
	}
#endif
	float4	NormalColor = float4(input.NormalColor.xyz, (float)Property / 255.0f);
	output.Color0 = outColor;
	output.Color1 = NormalColor;
	output.Color2 = float4(0, 0, 0, 0);

#if (1 == SHADER_PARAMETER_USE_OIT)
	uint2	vPos = uint2(input.Pos.xy);
	uint	ScreenIndex = vPos.x + vPos.y*ScreenWidth;

	// Retrieve current pixel count and increase counter
	uint uPixelCount = FLBuffer.IncrementCounter();
	if (uPixelCount >= MaxFLNum)
	{
		uint OldFailCount;
		FailCountBuffer.InterlockedAdd((ScreenIndex & 0x0f) * 4, 1, OldFailCount);
		return output;
	}

	// Exchange offsets in StartOffsetBuffer
	uint uStartOffsetAddress = (ScreenIndex + input.ArrayIndex*ScreenWidth*ScreenHeight) * 4;
	uint uOldStartOffset;
	StartOffsetBuffer.InterlockedExchange(uStartOffsetAddress, uPixelCount, uOldStartOffset);

	// Add new fragment entry in Fragment & Link Buffer
	FLBuffer[uPixelCount].uPixelColor = PackRGBA(outColor);
	FLBuffer[uPixelCount].uNormal_ElementID = Pack_Normal_Property_ElementID_To_UINT(NormalColor.rgb, 0, 0);

	FLBuffer[uPixelCount].fDepth = input.Pos.z;
	FLBuffer[uPixelCount].SetNext(uOldStartOffset);
	FLBuffer[uPixelCount].SetAlphaMode(MtlAlphaMode);
	PropertyBuffer.InterlockedOr(uStartOffsetAddress, MtlAlphaMode);
#endif
	return output;
}

[maxvertexcount(3)]
void gsStaticLM(triangle VS_OUTPUT_LM input[3], inout TriangleStream<GS_OUTPUT_LM> TriStream)
{
	GS_OUTPUT_LM output[3];

	for (uint i = 0; i < 3; i++)
	{
		output[i].Pos = input[i].Pos;
		output[i].NormalColor = input[i].NormalColor;
		output[i].TexCoordDiffuse = input[i].TexCoordDiffuse;
		output[i].TexCoordLightMap = input[i].TexCoordLightMap;
		output[i].PosWorld = input[i].PosWorld;
		output[i].Dist = input[i].Dist;
		[unroll]
		for (uint j = 0; j < 8; j++)
		{
			output[i].NdotL[j] = input[i].NdotL[j];
		}
		output[i].Clip = input[i].Clip;
		output[i].ArrayIndex = input[i].ArrayIndex;
		output[i].RTVIndex = input[i].ArrayIndex;
		TriStream.Append(output[i]);
	}
}
#if (1 == SHADER_PARAMETER_USE_OIT)
[earlydepthstencil]
#endif
float4 psDefaultWaterBottom(PS_INPUT_LM input) : SV_Target
{
	float4 outColor = 0;

	float4 texColorDiffuse = texDiffuse.Sample(samplerWrap, input.TexCoordDiffuse);
#if (1 == SHADER_PARAMETER_USE_OIT)
	// Add 알파의 경우 알파테스트를 걸어줘야하지만, LMM Mesh에선 Add알파는 사용하지 않는다고 가정한다.
	//	if (MtlAlphaMode)
	//	{
	//		const float3	bwConst = float3(0.3f, 0.59f, 0.11f);
	//		float	bwColor = dot(texColorDiffuse.rgb, bwConst);
	//		if (bwColor < ALPHA_TEST_THRESHOLD_ADD)
	//			discard;
	//	}
	if (texColorDiffuse.a < ALPHA_TEST_THRESHOLD_TRANSP)
			discard;
#endif
	float4 texColorLightMap = texLightMap.Sample(samplerClamp, input.TexCoordLightMap);

	// 라이트맵 컬러값 보정
	texColorLightMap.rgb *= LightMapConst.rgb;

	// 최종 컬러는 (라이트맵*2)*디퓨즈테텍스쳐
	outColor.rgb = texColorDiffuse.rgb * texColorLightMap.rgb;

	// ambient occlusion 상수적용
	outColor.rgb *= texColorLightMap.a;

	// 외부 지정 알파값
	outColor.a = texColorDiffuse.a * MtlDiffuse.a;

	float Alpha = saturate((Height - input.PosWorld.y) * RcpFadeDistance);
	outColor.a *= Alpha;

	float4	NormalColor = float4(input.NormalColor.xyz, (float)Property / 255.0f);

#if (1 == SHADER_PARAMETER_USE_OIT)
	uint2	vPos = uint2(input.Pos.xy);
	uint	ScreenIndex = vPos.x + vPos.y*ScreenWidth;

	// Retrieve current pixel count and increase counter
	uint uPixelCount = FLBuffer.IncrementCounter();
	if (uPixelCount >= MaxFLNum)
	{
		uint OldFailCount;
		FailCountBuffer.InterlockedAdd((ScreenIndex & 0x0f) * 4, 1, OldFailCount);
		return outColor;
	}

	// Exchange offsets in StartOffsetBuffer
	uint uStartOffsetAddress = (ScreenIndex + input.ArrayIndex*ScreenWidth*ScreenHeight) * 4;
	uint uOldStartOffset;
	StartOffsetBuffer.InterlockedExchange(uStartOffsetAddress, uPixelCount, uOldStartOffset);

	// Add new fragment entry in Fragment & Link Buffer
	FLBuffer[uPixelCount].uPixelColor = PackRGBA(outColor);
	FLBuffer[uPixelCount].uNormal_ElementID = Pack_Normal_Property_ElementID_To_UINT(NormalColor.rgb, 0, 0);

	FLBuffer[uPixelCount].fDepth = input.Pos.z;
	FLBuffer[uPixelCount].SetNext(uOldStartOffset);
	FLBuffer[uPixelCount].SetAlphaMode(MtlAlphaMode);
	PropertyBuffer.InterlockedOr(uStartOffsetAddress, MtlAlphaMode);
#endif
	return outColor;
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
	output.Color1 = float4(input.NormalColor.xyz, (float)Property / 255.0f);
	output.Color2 = float4(0, 0, 0, 0);

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
