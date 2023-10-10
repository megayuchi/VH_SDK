
//#define SHADER_PARAMETER_PHYSIQUE		1
//#define SHADER_PARAMETER_USE_NORMALMAP 1
//#define SHADER_PARAMETER_USE_OIT		1
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
	PosLocal = vsCalcBlendPos(input.Pos, input.BlendIndex, input.BlendWeight);	// ������ ������������ ���
	NormalLocal = vsCalcBlendNormal(input.Normal, input.BlendIndex, input.BlendWeight);// ������ ���ó���� ���.
	TangentLocal = vsCalcBlendNormal(input.Tangent.xyz, input.BlendIndex, input.BlendWeight);// ������ ����ź��Ʈ�� ���.
#else
    PosLocal = (float3)input.Pos;
    NormalLocal = input.Normal;
    TangentLocal = input.Tangent.xyz;
#endif
    float4 PosWorld = mul(float4(PosLocal, 1), g_TrCommon.matWorld); // ������������� ���ؽ� ��ǥ
    float3 NormalWorld = mul(NormalLocal, (float3x3)g_TrCommon.matWorld); // ����������� �븻
    float3 TangentWorld = mul(TangentLocal, (float3x3)g_TrCommon.matWorld); // ����������� ź��Ʈ
#ifdef USE_INSTANCING
    if (g_TrCommon.MeshShaderInstanceCount > 0)
    {
        PosWorld = mul(PosWorld, g_InstanceMatWorldList[InstanceObjID]); // ������������� ���ؽ� ��ǥ
        NormalWorld = mul(NormalWorld, (float3x3)g_InstanceMatWorldList[InstanceObjID]); // ����������� �븻
        TangentWorld = mul(TangentWorld, (float3x3)g_InstanceMatWorldList[InstanceObjID]); // ����������� ź��Ʈ
    }
#endif	
    output.Normal = normalize(NormalWorld); // �ٽ� ��ֶ�����(�������� ������� ��츦 ����ؼ�)
    output.Tangent = normalize(TangentWorld); // �ٽ� ��ֶ�����(�������� ������� ��츦 ����ؼ�)
    
    output.Pos = mul(PosWorld, g_Camera.matViewProjArray[ArrayIndex]); // �������ǵ� ��ǥ.
    output.PosWorld = PosWorld; // ���� ��ǥ
    output.Clip = dot(PosWorld, ClipPlane); // Ŭ���÷���ó��
    output.TexCoordDiffuse = input.TexCoord;
    output.Diffuse = float4(1, 1, 1, 1);

    uint Property = asuint(input.Tangent.w);
	//float ElementColor = (float)((Property & 0x000000ff)) / 255.0;
	//Diffuse = float4(ElementColor, ElementColor, ElementColor, 1);
    output.Property = Property;

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

// �������Ҷ� z�׽�Ʈ�� on, z����� off
#if (1 == SHADER_PARAMETER_USE_OIT)
[earlydepthstencil]
#endif
PS_TARGET psDynamicVL(PS_INPUT input)
{
    PS_TARGET output = (PS_TARGET)0;

#if (1 == SHADER_PARAMETER_USE_TILED_RESOURCES)
    uint FeedbackVar = 0;
    float4 texColor = texDiffuse.Sample(samplerWrap, input.TexCoordDiffuse, int2(0, 0), 0.0f, FeedbackVar);	// offset = int2(0,0), clamp = 0
#else
    float4 texColor = texDiffuse.Sample(samplerWrap, input.TexCoordDiffuse);
#endif
    float4 texNormalColor = texNormal.Sample(samplerWrap, input.TexCoordDiffuse);
	// Tiled Resource Status
    uint TiledResourceStatus = 0;
#if (1 == SHADER_PARAMETER_USE_TILED_RESOURCES)
    uint2 TiledResourcSize = uint2((TiledResourceProp.FullWidthHeight & 0x0000ffff), (TiledResourceProp.FullWidthHeight & 0xffff0000) >> 16);
    uint2 SizePerTile = uint2((TiledResourceProp.WidthHeightPerTile & 0x0000ffff), (TiledResourceProp.WidthHeightPerTile & 0xffff0000) >> 16);
    uint TexID = TiledResourceProp.TexID & 0x0000000f;
    if (TexID)
    {
        TiledResourceStatus = CreateTiledResourcStatus(TexID, TiledResourcSize, SizePerTile, TiledResourceProp.LayoutType, texDiffuse, samplerWrap, input.TexCoordDiffuse, FeedbackVar);
    }
    else
    {
		// DXR�������� �ƴ� ��� OIT����϶��� �����׽�Ʈ ó���� �Ѵ�.
		// DXR���� �⺻������ ������ �̿��ؼ� ���� ó���� �ϱ� ������ OIT�� �ƴ� ��쵵 �����׽�Ʈ�� �����Ѵ�.
		// �� Tiled Resource�� �̿��ϴ� ���, �����׽�Ʈ�� �����Ѵ�.
//#if (1 == SHADER_PARAMETER_USE_OIT)	
        if (MtlAlphaMode)
        {
            const float3 bwConst = float3(0.3f, 0.59f, 0.11f);
            float bwColor = dot(texColor.rgb, bwConst);
            if (bwColor < ALPHA_TEST_THRESHOLD_ADD)
                discard;
        }
        else
        {
            if (texColor.a < ALPHA_TEST_THRESHOLD_TRANSP)
                discard;
        }
//#endif
    }
#endif
#if (1 == SHADER_PARAMETER_USE_NORMALMAP)
	float3	binormal = cross(input.Tangent, input.Normal);
	float3	tan_normal = texNormalColor * 2 - 1;
	float3	surfaceNormal = (tan_normal.xxx * input.Tangent) + (tan_normal.yyy * binormal) + (tan_normal.zzz * input.Normal);
#else
    float3 surfaceNormal = input.Normal.xyz;
#endif
    uint ElementID = (input.Property & 0x000000ff); //VertexBuffer�κ��� �Է�
    uint Prop = SetShadowWeight(Property, 0); // texShadowMask���� ���ø��� shadow mask�� �ٸ� ������Ƽ.�Ӹ�ī���� �󱼿� �׸��� ���°� �����Ѵٵ簡...CB�κ��� �Է�
	
    float4 NormalColor = float4(surfaceNormal.xyz * float3(0.5, 0.5, 0.5) + float3(0.5, 0.5, 0.5), (float)Prop / 255.0);
	//float4	NormalColor = float4(input.Normal.xyz * float3(0.5, 0.5, 0.5) + float3(0.5, 0.5, 0.5), (float)Prop / 255.0);
	//float4	NormalColor = float4(input.Tangent.xyz * float3(0.5, 0.5, 0.5) + float3(0.5, 0.5, 0.5), (float)Prop / 255.0);
	//float4	NormalColor = float4(binormal.xyz * float3(0.5, 0.5, 0.5) + float3(0.5, 0.5, 0.5), (float)Prop / 255.0);

    float4 ElementColor = float4((float)ElementID / 255.0, (float)MtlPreset / 255.0, (float)g_TrCommon.ShadingType / 255.0, 0);
	
	
    float4 outColor = ((texColor * MtlDiffuse) + MtlDiffuseAdd) * input.Diffuse;
    output.Color0 = outColor;
    output.Color1 = NormalColor;
    output.Color2 = ElementColor;
    output.Color3 = TiledResourceStatus;
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
PS_TARGET psWater(PS_INPUT input)
{
    PS_TARGET output = (PS_TARGET)0;

    float3 texNormalColor0 = (float3)texNormal.Sample(samplerMirror, input.PosWorld.xz * 0.001 + TimeValue);
    float3 texNormalColor1 = (float3)texNormal.Sample(samplerMirror, input.PosWorld.xz * 0.001 - TimeValue);
    float4 texDiffuse0 = texDiffuse.Sample(samplerWrap, input.PosWorld.xz * 0.001 + TimeValue);
    float4 texDiffuse1 = texDiffuse.Sample(samplerWrap, input.PosWorld.xz * 0.001 - TimeValue);
    float4 texColor = lerp(texDiffuse0, texDiffuse1, 0.5);

    if (MtlAlphaMode)
    {
        const float3 bwConst = float3(0.3f, 0.59f, 0.11f);
        float bwColor = dot(texColor.rgb, bwConst);
        if (bwColor < ALPHA_TEST_THRESHOLD_ADD)
            discard;
    }
    else
    {
        if (texColor.a < ALPHA_TEST_THRESHOLD_TRANSP)
            discard;
    }
    float3 binormal = cross(input.Tangent, input.Normal);
	//float3	tan_normal = texNormalColor * 2 - 1;
    float3 tan_normal = normalize((texNormalColor0 + texNormalColor1) * 2 - 1);
    float3 surfaceNormal = (tan_normal.xxx * input.Tangent) + (tan_normal.yyy * binormal) + (tan_normal.zzz * input.Normal);
	
    surfaceNormal = lerp(input.Normal, surfaceNormal, 0.125);

    uint ElementID = (input.Property & 0x000000ff); //VertexBuffer�κ��� �Է�
    uint Prop = SetShadowWeight(Property, 0); // texShadowMask���� ���ø��� shadow mask�� �ٸ� ������Ƽ.�Ӹ�ī���� �󱼿� �׸��� ���°� �����Ѵٵ簡...CB�κ��� �Է�
	
    float4 NormalColor = float4(surfaceNormal.xyz * float3(0.5, 0.5, 0.5) + float3(0.5, 0.5, 0.5), (float)Prop / 255.0);
	//float4	NormalColor = float4(input.Normal.xyz * float3(0.5, 0.5, 0.5) + float3(0.5, 0.5, 0.5), (float)Prop / 255.0);
	//float4	NormalColor = float4(input.Tangent.xyz * float3(0.5, 0.5, 0.5) + float3(0.5, 0.5, 0.5), (float)Prop / 255.0);
	//float4	NormalColor = float4(binormal.xyz * float3(0.5, 0.5, 0.5) + float3(0.5, 0.5, 0.5), (float)Prop / 255.0);

    float4 ElementColor = float4((float)ElementID / 255.0, (float)MtlPreset / 255.0, (float)g_TrCommon.ShadingType / 255.0, 0);

    output.Color0 = float4(texColor.rgb * MtlDiffuse.rgb + MtlDiffuseAdd.rgb, texColor.a);
    output.Color1 = NormalColor;
    output.Color2 = ElementColor;

    return output;
}
[maxvertexcount(3)]
void gsDefault(triangle VS_OUTPUT input[3], inout TriangleStream<GS_OUTPUT> TriStream)
{
    GS_OUTPUT output = (GS_OUTPUT)0;

    float3 N = CalcNormalWithTri((float3)input[0].PosWorld, (float3)input[1].PosWorld, (float3)input[2].PosWorld);

	// N*L���
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
        output.Normal = N;
        output.Tangent = input[i].Tangent; // flat���̵����� ������ tangent�ʿ�����ϱ�..
        output.TexCoordDiffuse = input[i].TexCoordDiffuse;
        output.PosWorld = input[i].PosWorld;
        output.Dist = input[i].Dist;
        output.Clip = dot(PosWorld, ClipPlane); // Ŭ���÷���ó��
        output.ArrayIndex = input[i].ArrayIndex;
        output.Property = input[i].Property;
#if (1 == VS_RTV_ARRAY)
        output.RTVIndex = input[i].ArrayIndex;
#endif
        TriStream.Append(output);
    }
}


#if (1 == SHADER_PARAMETER_PHYSIQUE)
StructuredBuffer <D3DVLVERTEX_PHYSIQUE> g_Vertices : register(t3);
#else
StructuredBuffer<D3DVLVERTEX> g_Vertices : register(t3);
#endif
RWStructuredBuffer<D3DVLVERTEX> g_OutVertices : register(u8);

[numthreads(1024, 1, 1)]
void csDynamicVL(uint3 groupID : SV_GroupID, uint3 dispatchThreadId : SV_DispatchThreadID)
{
    VS_OUTPUT output = (VS_OUTPUT)0;

	VS_INPUT input;
	
    float3 PosLocal;
    float3 NormalLocal;
    float3 TangentLocal;

    uint CurVertexIndex = dispatchThreadId.x;
    if (CurVertexIndex > g_TrCommon.ObjVertexNum)
        return;

    input.Pos = float4(g_Vertices[CurVertexIndex].Pos, 1);
    input.Normal = float3(g_Vertices[CurVertexIndex].Normal);
    input.Tangent = float4(g_Vertices[CurVertexIndex].Tangent.xyz, 0);

#if (1 == SHADER_PARAMETER_PHYSIQUE)
	input.BlendIndex[0] = (g_Vertices[CurVertexIndex].BoneIndex & 0x000000ff);
	input.BlendIndex[1] = (g_Vertices[CurVertexIndex].BoneIndex & 0x0000ff00) >> 8;
	input.BlendIndex[2] = (g_Vertices[CurVertexIndex].BoneIndex & 0x00ff0000) >> 16;
	input.BlendIndex[3] = (g_Vertices[CurVertexIndex].BoneIndex & 0xff000000) >> 24;
	input.BlendWeight[0] = g_Vertices[CurVertexIndex].BoneWeight4.x;
	input.BlendWeight[1] = g_Vertices[CurVertexIndex].BoneWeight4.y;
	input.BlendWeight[2] = g_Vertices[CurVertexIndex].BoneWeight4.z;
	input.BlendWeight[3] = g_Vertices[CurVertexIndex].BoneWeight4.w;
#else
#endif

#if (1 == SHADER_PARAMETER_PHYSIQUE)
	PosLocal = vsCalcBlendPos(input.Pos, input.BlendIndex, input.BlendWeight);	// ������ ������������ ���
	NormalLocal = vsCalcBlendNormal(input.Normal, input.BlendIndex, input.BlendWeight);// ������ ���ó���� ���.
	TangentLocal = vsCalcBlendNormal(input.Tangent.xyz, input.BlendIndex, input.BlendWeight);// ������ ź��Ʈ�� ���.
#else
    PosLocal = (float3)input.Pos;
    NormalLocal = input.Normal;
    TangentLocal = input.Tangent.xyz;
#endif
	// ���� ��ȯ�� ���� �ʴ´�. TLAS���� Transform Matrix�� ������ ���̴�.
	//float4	PosWorld = mul(float4(PosLocal, 1), matWorld);		// ������������� ���ؽ� ��ǥ
	//float3	NormalWorld = mul(NormalLocal, (float3x3)matWorld);	// ����������� �븻
	//NormalWorld = normalize(NormalWorld);											// �ٽ� ��ֶ�����(�������� ������� ��츦 ����ؼ�)
    g_OutVertices[CurVertexIndex].Pos.xyz = PosLocal.xyz; // ���� ��ǥ
    g_OutVertices[CurVertexIndex].Normal.xyz = normalize(NormalLocal.xyz);
    g_OutVertices[CurVertexIndex].Tangent = normalize(TangentLocal.xyz);
    g_OutVertices[CurVertexIndex].Property = g_Vertices[CurVertexIndex].Property;
	//g_OutVertices[CurVertexIndex].xyz = float3(1, 1, 1);
	
	
    return;

}