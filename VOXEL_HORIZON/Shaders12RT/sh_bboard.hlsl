#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_util.hlsl"
#include "sh_dynamic_common.hlsl"
#include "sh_a_buffer.hlsl"

//--------------------------------------------------------------------------------------



//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------



VS_OUTPUT vsDefault(VS_INPUT_VL input)
{
	VS_OUTPUT output = (VS_OUTPUT)0;

	uint	ArrayIndex = input.instId % 2;

	float3	PosLocal = (float3)input.Pos;
	float4	PosWorld = mul(float4(PosLocal, 1), g_TrCommon.matWorld);		// 월드공간에서의 버텍스 좌표
	float4	NormalView = float4(0, 0, -1, 0);
	float4	NormalWorld = mul(NormalView, g_Camera.matViewInvArray[ArrayIndex]);
	NormalWorld = normalize(NormalWorld);
												
	output.Pos = mul(float4(PosLocal, 1), g_Camera.matWorldViewProjArray[ArrayIndex]);	// 프로젝션된 좌표.
	output.PosWorld = PosWorld;										// 월드 좌표
	output.Clip = dot(PosWorld, ClipPlane);										// 클립플레인처리

	output.Normal = NormalWorld;
	output.Tangent = float3(1, 0, 0);
	output.TexCoordDiffuse = input.TexCoord;
	uint Property = asuint(input.Tangent.w);
	//float ElementColor = (float)((Property & 0x000000ff)) / 255.0;
	//Diffuse = float4(ElementColor, ElementColor, ElementColor, 1);
	output.Property = Property;

	output.Dist = output.Pos.w;
	output.ArrayIndex = ArrayIndex;
	output.Diffuse = float4(1, 1, 1, 1);
	output.ArrayIndex = ArrayIndex;
#if (1 == VS_RTV_ARRAY)
	output.RTVIndex = ArrayIndex;
#endif
	return output;
}
[maxvertexcount(3)]
void gsDefault(triangle VS_OUTPUT input[3], inout TriangleStream<GS_OUTPUT> TriStream)
{
    GS_OUTPUT output = (GS_OUTPUT) 0;

	float3	N = CalcNormalWithTri((float3)input[0].PosWorld, (float3)input[1].PosWorld, (float3)input[2].PosWorld);

	// N*L계산
    float cosang = saturate(dot(N, (float3) (-LightDir)));
    cosang = max(MinNdotL.a, cosang);

	for (uint i = 0; i < 3; i++)
	{        
        float4 Diffuse = float4(cosang, cosang, cosang, 1);
        float4 PosWorld = input[i].PosWorld;
        mul(input[i].Pos, g_TrCommon.matWorld);

		//output[i].Diffuse.rgb = N*0.5 + 0.5;
		output.Pos = input[i].Pos;
        output.Diffuse = Diffuse;
		output.Normal = input[i].Normal;
		output.Tangent = input[i].Tangent;
        output.TexCoordDiffuse = input[i].TexCoordDiffuse;
        output.PosWorld = input[i].PosWorld;
        output.Dist = input[i].Dist;
        output.Clip = dot(PosWorld, ClipPlane); // 클립플레인처리
        output.ArrayIndex = input[i].ArrayIndex;
        output.Property = input[i].Property;
#if (1 == VS_RTV_ARRAY)
        output.RTVIndex = input[i].ArrayIndex;
#endif
		TriStream.Append(output);
	}
}


#if (1 == SHADER_PARAMETER_USE_OIT)
[earlydepthstencil]
#endif
PS_TARGET psDefault(PS_INPUT input)
{
	PS_TARGET output = (PS_TARGET)0;

	float4 texColor = texDiffuse.Sample(samplerWrap, input.TexCoordDiffuse);
//#if (1 == SHADER_PARAMETER_USE_OIT)
	if (MtlAlphaMode)
	{
		const float3	bwConst = float3(0.3f, 0.59f, 0.11f);
		float	bwColor = dot(texColor.rgb, bwConst);
		if (bwColor < ALPHA_TEST_THRESHOLD_ADD)
			discard;
	}
	else
	{
		if (texColor.a < ALPHA_TEST_THRESHOLD_TRANSP)
			discard;
	}
//#endif

	float4 outColor = texColor * input.Diffuse;
	float3	NormalWorld = float3(0, 0, -1);

	uint	ElementID = (input.Property & 0x000000ff);	//VertexBuffer로부터 입력
	uint	Prop = SetShadowWeight(Property, 0);	// texShadowMask에서 샘플링한 shadow mask와 다른 프로퍼티.머리카락에 얼굴에 그림자 지는걸 방지한다든가...CB로부터 입력
	float4	NormalColor = float4(input.Normal.xyz * float3(0.5, 0.5, 0.5) + float3(0.5, 0.5, 0.5), (float)Prop / 255.0);
	float4	ElementColor = float4((float)ElementID / 255.0, (float)MtlPreset / 255.0, (float)g_TrCommon.ShadingType / 255.0, 0);

	output.Color0 = outColor;
	output.Color1 = NormalColor;
	output.Color2 = ElementColor;
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
	FLBuffer[uPixelCount].uNormal_ElementID = Pack_Normal_Property_ElementID_To_UINT(NormalColor.rgb, Property, 0);
	
	FLBuffer[uPixelCount].fDepth = input.Pos.z;
	FLBuffer[uPixelCount].SetNext(uOldStartOffset);
	FLBuffer[uPixelCount].SetAlphaMode(MtlAlphaMode);
	PropertyBuffer.InterlockedOr(uStartOffsetAddress, MtlAlphaMode);
#endif
	return output;
}



