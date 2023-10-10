
//#define SHADER_PARAMETER_ATT_LIGHT	1
//#define SHADER_PARAMETER_PHYSIQUE		1
//#define SHADER_PARAMETER_LIGHT_PRB	1
//#define SHADER_PARAMETER_USE_OIT		1
//#define SHADER_PARAMETER_USE_TILED_RESOURCES 1
//#define LIGHTING_TYPE	0	//(vlmesh에서 LIGHTING_TYPE이 0인 경우는 없다.)

#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_dynamic_common.hlsl"
#include "sh_constant_buffer_default.hlsl"
#include "sh_constant_buffer_instance.hlsl"
#include "sh_att_light.hlsl"
#include "sh_a_buffer.hlsl"

//RWByteAddressBuffer FailCountBuffer : register(u6);	// RW

#if (1 == SHADER_PARAMETER_PHYSIQUE)
#define VS_INPUT	VS_INPUT_VL_PHYSIQUE
#else
#define VS_INPUT	VS_INPUT_VL
#endif

#ifdef USE_INSTANCING
#undef STEREO_RENDER
#endif

VS_OUTPUT vsDynamicVL(VS_INPUT input)
{
    VS_OUTPUT output = (VS_OUTPUT)0;
    uint ArrayIndex = 0;
	
#ifdef USE_INSTANCING
    uint InstanceObjID = input.instId;
#endif

#ifdef STEREO_RENDER
	ArrayIndex = input.instId % 2;
#else
	
#endif
	
    float3 PosLocal;
    float3 NormalLocal;
    float3 TangentLocal;
#if (1 == SHADER_PARAMETER_PHYSIQUE)
	PosLocal = vsCalcBlendPos(input.Pos, input.BlendIndex, input.BlendWeight);	// 블랜딩된 로컬포지션을 계산
	NormalLocal = vsCalcBlendNormal(input.Normal, input.BlendIndex, input.BlendWeight);// 블랜딩된 로컬노멀을 계산.
	TangentLocal = vsCalcBlendNormal(input.Tangent.xyz, input.BlendIndex, input.BlendWeight);// 블랜딩된 로컬탄젠트를 계산.
#else
    PosLocal = (float3)input.Pos;
    NormalLocal = input.Normal;
	TangentLocal = input.Tangent.xyz;
#endif
    float4 PosWorld = mul(float4(PosLocal, 1), g_TrCommon.matWorld); // 월드공간에서의 버텍스 좌표
    float3 NormalWorld = mul(NormalLocal, (float3x3)g_TrCommon.matWorld); // 월드공간에서 노말
	float3 TangentWorld = mul(TangentLocal, (float3x3)g_TrCommon.matWorld); // 월드공간에서 노말
#ifdef USE_INSTANCING
    if (g_TrCommon.MeshShaderInstanceCount > 0)
    {
        PosWorld = mul(PosWorld, g_InstanceMatWorldList[InstanceObjID]); // 월드공간에서의 버텍스 좌표
        NormalWorld = mul(NormalWorld, (float3x3)g_InstanceMatWorldList[InstanceObjID]); // 월드공간에서 노말
		TangentWorld = mul(TangentWorld, (float3x3)g_InstanceMatWorldList[InstanceObjID]); // 월드공간에서 탄젠트
    }
#endif	
    NormalWorld = normalize(NormalWorld); // 다시 노멀라이즈(스케일이 들어있을 경우를 대비해서)
    //output.Pos = mul(float4(PosLocal, 1), matWorldViewProjArray[ArrayIndex]);	// 프로젝션된 좌표.
    output.Pos = mul(PosWorld, g_Camera.matViewProjArray[ArrayIndex]); // 프로젝션된 좌표.
    output.PosWorld = PosWorld; // 월드 좌표
    output.Clip = dot(PosWorld, ClipPlane); // 클립플레인처리

	// 노멀을 0에서 1사이로 포화
    output.NormalColor = float4((NormalWorld * 0.5f) + 0.5f, 0);
	//output.TangentColor = float4((TangentWorld * 0.5f) + 0.5f, 0);
    output.TexCoordDiffuse = input.TexCoord;

#if (0 == LIGHTING_TYPE)
	// MtlDiffuse + MtlAmbient
	//output.Diffuse = float4(MtlDiffuse.rgb + MtlAmbient.rgb,MtlDiffuse.a);
	output.Diffuse = float4(1, 1, 1, 1);
#else
    float cosang = saturate(dot(NormalWorld, (float3)(-LightDir)));
    cosang = max(MinNdotL.a, cosang);
    output.Diffuse = float4(cosang, cosang, cosang, 1);
#endif

    uint Property = asuint(input.Tangent.w);
	//float ElementColor = (float)((Property & 0x000000ff)) / 255.0;
	//Diffuse = float4(ElementColor, ElementColor, ElementColor, 1);
    output.Property = Property;


#if (1 == SHADER_PARAMETER_ATT_LIGHT)
	// 다이나믹 라이트가 있는 경우
	for (int i = 0; i < iAttLightNum; i++)
	{
		float3		LightVec = normalize((AttLight[i].Pos.xyz - PosWorld.xyz));
		output.NdotL[i] = dot(NormalWorld, LightVec);
	}
#endif
    output.Dist = output.Pos.w;
    output.ArrayIndex = ArrayIndex;
#if (1 == VS_RTV_ARRAY)
	output.RTVIndex = ArrayIndex;
#endif
    return output;
}

//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------

// 렌더링할때 z테스트는 on, z쓰기는 off
#if (1 == SHADER_PARAMETER_USE_OIT)
[earlydepthstencil]
#endif
PS_TARGET psDynamicVL(PS_INPUT input)
{
	// 방향설 라이트 XS
	// ATT라이트 X
	// 그림자 X
    PS_TARGET output = (PS_TARGET)0;

#if (1 == SHADER_PARAMETER_USE_TILED_RESOURCES)
    uint FeedbackVar = 0;
    float4 texColor = texDiffuse.Sample(samplerWrap, input.TexCoordDiffuse, int2(0, 0), 0.0f, FeedbackVar);	// offset = int2(0,0), clamp = 0
#else
    float4 texColor = texDiffuse.Sample(samplerWrap, input.TexCoordDiffuse);
#endif
#if (1 == SHADER_PARAMETER_USE_OIT)
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
#endif
    float4 outColor;
    float3 NormalWorld = (input.NormalColor.rgb * 2.0) - 1.0;
    float4 NearColor = float4(1, 1, 1, 1);
#if (1 == SHADER_PARAMETER_LIGHT_PRB)

	float3	light_axis[6] = {
			1,0,0,
			-1,0,0,
			0,1,0,
			0,-1,0,
			0,0,1,
			0,0,-1
	};


	float3	gi_lit = float3(0, 0, 0);

	for (int i = 0; i < 6; i++)
	{
		float	cosang_per_axis = dot(light_axis[i], NormalWorld);
		if (cosang_per_axis > 0.0001)
		{
			//float4	LightColor = ConvertDWORDTofloat(LightCube.ColorPerAxis[i]);
			//float4	LightColor = ConvertDWORDTofloat(LightCubeBuf.ColorPerAxis[i]);
			//gi_lit += (LightColor.rgb * cosang_per_axis);
			gi_lit += ((float3)LightCube.ColorPerAxis[i] * cosang_per_axis);
		}
	}
	NearColor = float4(saturate(gi_lit.rgb + MtlAmbient.rgb), 1);
	//gi_lit.rgb += MtlAmbient.rgb;
	//NearColor = saturate(float4(gi_lit,1));
#else
    NearColor = float4(saturate(input.Diffuse.rgb + MtlAmbient.rgb), 1);

#endif	


	// LIGHTING_TYPE = 0 <- 라이트처리 안할때
	// LIGHTING_TYPE = 1 <- per Vertex 라이트
	// LIGHTING_TYPE = 2 <- Toon Shading
	// LIGHTING_TYPE = 3 <- Per Pixel , NormalMap

	// outColor <- 최종 출력컬러
	// texColor <- 텍스쳐픽셀
	// NearColor <- 라이트컬러, 라이트프로브와 Ambient를 적용한 값

#if (0 == LIGHTING_TYPE)		// no light
	outColor = ((texColor * MtlDiffuse) * MtlToneColor) + MtlDiffuseAdd;
	// no action
#elif (1 == LIGHTING_TYPE)	// Vertex Light
	float4	lit_color = NearColor * MtlToneColor * MtlDiffuse;
	lit_color = saturate(float4(max(MinNdotL.rgb, lit_color.rgb), lit_color.a));
	outColor = (texColor * lit_color) + MtlDiffuseAdd;
	//outColor = (((texColor * NearColor) * MtlToneColor) * MtlDiffuse) + MtlDiffuseAdd;

	// no action
#elif (2 == LIGHTING_TYPE)	// toon

	float2	toonTexCoordR = float2(input.Diffuse.r, NearColor.r);
	float2	toonTexCoordG = float2(input.Diffuse.g, NearColor.g);
	float2	toonTexCoordB = float2(input.Diffuse.b, NearColor.b);

	float4	toonColorR = texToon.Sample(samplerClamp, toonTexCoordR);
	float4	toonColorG = texToon.Sample(samplerClamp, toonTexCoordG);
	float4	toonColorB = texToon.Sample(samplerClamp, toonTexCoordB);

	float4	toonColor = float4(toonColorR.r, toonColorG.g, toonColorB.b, input.Diffuse.a);
	toonColor = toonColor * MtlDiffuse + MtlDiffuseAdd;
	//outColor = (texColor * toonColor) + MtlDiffuseAdd;
	//outColor = ((texColor + MtlDiffuseAdd) * (toonColor*MtlToneColor));
	outColor = texColor * toonColor * MtlToneColor;

	// no action
#elif (3 == LIGHTING_TYPE)	// per pixel
	outColor = ((texColor * input.Diffuse * NearColor) + MtlDiffuseAdd);
	// no action
#endif

//	outColor *= NearColor;

#if (1 == SHADER_PARAMETER_ATT_LIGHT)
	// 다이나믹 라이트 적용
	outColor.xyz += CalcAttLightColorWithNdotL(input.PosWorld.xyz, input.NdotL, iAttLightNum);
#endif

    float4 TexShadowWeight = texMask.Sample(samplerWrap, input.TexCoordDiffuse);
    uint ElementID = (input.Property & 0x000000ff); //VertexBuffer로부터 입력
    uint Prop = SetShadowWeight(Property, TexShadowWeight.r); // texShadowMask에서 샘플링한 shadow mask와 다른 프로퍼티.머리카락에 얼굴에 그림자 지는걸 방지한다든가...CB로부터 입력
    float4 NormalColor = float4(input.NormalColor.xyz, (float)Prop / 255.0);
    float4 ElementColor = float4((float)ElementID / 255.0, 0, 0, 0);
    
	// Tiled Resource Status
    uint TiledResourceStatus = 0;
#if (1 == SHADER_PARAMETER_USE_TILED_RESOURCES)
    uint2 TiledResourcSize = uint2((TiledResourceProp.FullWidthHeight & 0x0000ffff), (TiledResourceProp.FullWidthHeight & 0xffff0000)>> 16);
    uint2 SizePerTile = uint2((TiledResourceProp.WidthHeightPerTile & 0x0000ffff), (TiledResourceProp.WidthHeightPerTile & 0xffff0000)>> 16);
    uint TexID = TiledResourceProp.TexID & 0x0000000f;
    if (TexID)
    {
        TiledResourceStatus = CreateTiledResourcStatus(TexID, TiledResourcSize, SizePerTile, TiledResourceProp.LayoutType, texDiffuse, samplerWrap, input.TexCoordDiffuse, FeedbackVar);
    }
#endif
    output.Color0 = outColor;
    output.Color1 = NormalColor;
    output.Color2 = ElementColor;
    output.Color3 = TiledResourceStatus;

	//float	ReflectColor = CalcReflectionColor(LightDir.xyz, NormalWorld, GlobalEyePos, input.PosWorld);
	//float4	ks = float4(2.0*0.486, 2.0*0.433, 2.0*0.185, 1.0f);
	//output.Color0 = output.Color0 + ks * ReflectColor;	// 반영 반사광

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
	FLBuffer[uPixelCount].uNormal_ElementID = Pack_Normal_Property_ElementID_To_UINT(NormalColor.rgb, Prop, ElementID);

	FLBuffer[uPixelCount].fDepth = input.Pos.z;
	FLBuffer[uPixelCount].SetNext(uOldStartOffset);
	FLBuffer[uPixelCount].SetAlphaMode(MtlAlphaMode);
	PropertyBuffer.InterlockedOr(uStartOffsetAddress, MtlAlphaMode);
#endif
    return output;
}

#if (1 == SHADER_PARAMETER_USE_OIT)
[earlydepthstencil]
#endif
float4 psDynamicVertexLightWaterBottom(PS_INPUT input) : SV_Target
{
	// float4 출력으로 바꾼다. BEGIN_BUILD_MIRROR에선 RTV 1개만 사용한다.

    float4 texColor = texDiffuse.Sample(samplerWrap, input.TexCoordDiffuse);
#if (1 == SHADER_PARAMETER_USE_OIT)
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
#endif

    float4 outColor = texColor * input.Diffuse;

	// VLMeshObject에 대해선 fade alpha를 사용하지 않기로 한다. 2018/10/15 yuchi
	//float	Alpha = saturate((Height - input.PosWorld.y) * RcpFadeDistance);
	//outColor.a *= Alpha;

    uint Prop = SetShadowWeight(Property, 0);
    float4 NormalColor = float4(input.NormalColor.xyz, (float)Prop / 255.0);
	
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
	FLBuffer[uPixelCount].uNormal_ElementID = Pack_Normal_Property_ElementID_To_UINT(NormalColor.rgb, Prop, 0);

	FLBuffer[uPixelCount].fDepth = input.Pos.z;
	FLBuffer[uPixelCount].SetNext(uOldStartOffset);
	FLBuffer[uPixelCount].SetAlphaMode(MtlAlphaMode);
	PropertyBuffer.InterlockedOr(uStartOffsetAddress, MtlAlphaMode);
#endif
    return outColor;
}


[maxvertexcount(3)]
void gsDefault(triangle VS_OUTPUT input[3], inout TriangleStream<GS_OUTPUT> TriStream)
{
    GS_OUTPUT output = (GS_OUTPUT)0;

    float3 N = CalcNormalWithTri((float3)input[0].PosWorld, (float3)input[1].PosWorld, (float3)input[2].PosWorld);

	// N*L계산
    float cosang = saturate(dot(N, (float3)(-LightDir)));
    cosang = max(MinNdotL.a, cosang);

    for (uint i = 0; i < 3; i++)
    {
        float4 Diffuse = float4(cosang, cosang, cosang, 1);
        float4 PosWorld = input[i].PosWorld;
        mul(input[i].Pos, g_TrCommon.matWorld);

		//output[i].Diffuse.rgb = N*0.5 + 0.5;
        output.Pos = input[i].Pos;
        output.Diffuse = Diffuse;
        output.NormalColor = float4((N * 0.5f) + 0.5f, 0);
        output.TexCoordDiffuse = input[i].TexCoordDiffuse;
        output.PosWorld = input[i].PosWorld;
        output.Dist = input[i].Dist;
        for (int i = 0; i < iAttLightNum; i++)
        {
            output.NdotL[i] = input[i].NdotL[i];
        }
        output.Clip = dot(PosWorld, ClipPlane); // 클립플레인처리
        output.ArrayIndex = input[i].ArrayIndex;
        output.Property = input[i].Property;
#if (1 == VS_RTV_ARRAY)
        output.RTVIndex = input[i].ArrayIndex;
#endif
        TriStream.Append(output);
    }
}



/*

sub		r1.a,c3.x,t3.y			; 수면 높이 - 물속 매쉬의 높이
mul_sat	r0.a,r1.a,c3.y		; 높이 차 / 페이딩 거리 ( 1이상이면 알파값 1, 그 미만은 0 - 1사이의 알파값)
*/

/*
[maxvertexcount(36)]
void gsVertexToBoxDepth(point GS_INPUT input[1], inout TriangleStream<PS_INPUT_IMM> TriStream)
{
	PS_INPUT_IMM	output = (PS_INPUT_IMM)0;

	float	size = PublicConst[0].x;

	uint		Index[36] =
	{
		// +z
		3,0,1,
		3,1,2,

		// -z
		4,7,6,
		4,6,5,

		// -x
		0,4,5,
		0,5,1,

		// +x
		7,3,2,
		7,2,6,

		// +y
		0,3,7,
		0,7,4,

		// -y
		2,1,5,
		2,5,6
	};

	float3	WorldPos[8];
	WorldPos[0] = input[0].Pos.xyz + float3(-size, size, size);
	WorldPos[1] = input[0].Pos.xyz + float3(-size, -size, size);
	WorldPos[2] = input[0].Pos.xyz + float3(size, -size, size);
	WorldPos[3] = input[0].Pos.xyz + float3(size, size, size);
	WorldPos[4] = input[0].Pos.xyz + float3(-size, size, -size);
	WorldPos[5] = input[0].Pos.xyz + float3(-size, -size, -size);
	WorldPos[6] = input[0].Pos.xyz + float3(size, -size, -size);
	WorldPos[7] = input[0].Pos.xyz + float3(size, size, -size);

	uint	VertexIndex = 0;
	for (uint i = 0; i < 6; i++)
	{
		for (uint j = 0; j < 2; j++)
		{
			for (uint k = 0; k < 3; k++)
			{
				float4	PosWorld = float4(WorldPos[Index[VertexIndex]], 1);
				output.PosWorld = PosWorld;
				output.Pos = mul(PosWorld, matWorldViewProjCommon);// world는 identity matrix일것
				TriStream.Append(output);
				VertexIndex++;
			}
			TriStream.RestartStrip();
		}

	}
}
*/