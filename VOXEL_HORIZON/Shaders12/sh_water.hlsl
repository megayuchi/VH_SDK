#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_constant_buffer_default.hlsl"
#include "sh_constant_buffer_material.hlsl"
#include "sh_util.hlsl"

// vertexshader constant, pixelshader constant
cbuffer ConstantBufferWater : register(b1)
{
    float4 TexCoordAdj;
    float4 EyePos;
    matrix matReflectTexCoord;
    matrix matRefractTexCoord;
}

Texture2D texDiffuse : register(t0);
Texture2D texNormal : register(t1); // 잔물결
Texture2D texReflect : register(t2); // 수면 반사
Texture2D texRefract : register(t3); // 물 밑 매쉬(굴절)

SamplerState samplerWrap : register(s0);
SamplerState samplerClamp : register(s1);
SamplerState samplerMirror : register(s2);


//--------------------------------------------------------------------------------------
// Vertex Shader
//--------------------------------------------------------------------------------------


struct VS_INPUT_WATER
{
    float4 Pos : POSITION;
    float2 TexCoord : TEXCOORD0;
    uint instId : SV_InstanceID;
};

struct VS_OUTPUT_WATER
{
    float4 Pos : SV_POSITION;
    float4 NormalColor : COLOR0;
    float2 TexCoordDiffuse : TEXCOORD0;
    float4 TexCoordReflect : TEXCOORD1;
    float4 TexCoordRefract : TEXCOORD2;
    float4 PosWorld : TEXCOORD3; // 월드공간에서의 위치
    float3 Normal : TEXCOORD4;
    float Distance : TEXCOORD5; // 거리(w값)
    uint ArrayIndex : BLENDINDICES;
#if (1 == VS_RTV_ARRAY)
	uint    RTVIndex        : SV_RenderTargetArrayIndex;
#endif
};

struct GS_OUTPUT_WATER : VS_OUTPUT_WATER
{
#if (1 != VS_RTV_ARRAY)
    uint RTVIndex : SV_RenderTargetArrayIndex;
#endif
};

struct PS_INPUT_WATER : VS_OUTPUT_WATER
{
};


VS_OUTPUT_WATER vsDefault(VS_INPUT_WATER input)
{
    VS_OUTPUT_WATER output = (VS_OUTPUT_WATER)0;

    uint ArrayIndex = input.instId % 2;

    output.Pos = mul(input.Pos, g_Camera.matWorldViewProjArray[ArrayIndex]);
    output.PosWorld = mul(input.Pos, g_TrCommon.matWorld);

	// 노멀을 0에서 1사이로 포화
    output.Normal = float3(0, 1, 0);
    output.NormalColor.rgb = float3(0.0, 1.0, 0.0);
    output.NormalColor.a = 1;

    output.Distance = output.Pos.w * 0.000025f;
    output.TexCoordDiffuse = input.TexCoord;
    output.TexCoordReflect = mul(input.Pos, matReflectTexCoord);
    output.TexCoordRefract = mul(input.Pos, matRefractTexCoord);
    output.ArrayIndex = ArrayIndex;
#if (1 == VS_RTV_ARRAY)
	output.RTVIndex = ArrayIndex;
#endif
    return output;
}

[maxvertexcount(3)]
void gsDefault(triangle VS_OUTPUT_WATER input[3], inout TriangleStream<GS_OUTPUT_WATER> TriStream)
{
    GS_OUTPUT_WATER output[3];

    for (uint i = 0; i < 3; i++)
    {
        output[i].Pos = input[i].Pos;
        output[i].NormalColor = input[i].NormalColor;
        output[i].TexCoordDiffuse = input[i].TexCoordDiffuse;
        output[i].TexCoordReflect = input[i].TexCoordReflect;
        output[i].TexCoordRefract = input[i].TexCoordRefract;
        output[i].PosWorld = input[i].PosWorld;
        output[i].Distance = input[i].Distance;
        output[i].ArrayIndex = input[i].ArrayIndex;
        output[i].RTVIndex = input[i].ArrayIndex;
        TriStream.Append(output[i]);
    }
    TriStream.RestartStrip();
}
PS_TARGET psDefault(PS_INPUT_WATER input)
{
    PS_TARGET output = (PS_TARGET)0;

    float4 outColor = 0;

    input.TexCoordReflect /= input.TexCoordReflect.w;
    input.TexCoordRefract /= input.TexCoordRefract.w;

    float2 texCoordWave = input.TexCoordDiffuse.xy + TexCoordAdj.xy;

    float4 texColorNormal = texNormal.Sample(samplerWrap, texCoordWave);

	// y와 z를 바꾸고 0.05를 곱해서 스케일
    float4 texCoordAdj = (texColorNormal.xzyw - 0.5f) * 0.05f;
	//float2 texCoordAdj = texCoordWave * 0.01;

    float2 texCoordReflect = input.TexCoordReflect.xy + texCoordAdj.xy;
    float2 texCoordDiffuse = input.TexCoordDiffuse.xy + texCoordAdj.xy;
    float2 texCoordRefract = input.TexCoordRefract.xy + (texCoordAdj.xy * 0.25);

    float4 texColorDiffuse = texDiffuse.Sample(samplerWrap, texCoordDiffuse);
    float4 texColorReflect = texReflect.Sample(samplerClamp, texCoordReflect);
    float4 texColorRefract = texRefract.Sample(samplerClamp, texCoordRefract);

	//mov			r10.a,r2.a		; 물밑 장면 텍스쳐 알파 백업
    float Alpha = 1.0; // texColorRefract.a;

    float3 N = input.Normal;
    float3 Fo = float3(0.5, 0.5, 0.5);
    float3 V = normalize((float3)EyePos - (float3)input.PosWorld);
    float3 wi;
    float3 Fr = Sample_Fr(V, wi, N, Fo);
	//float3 Fr = Kr * BxDF::Specular::Reflection::Sample_Fr(V, wi, N, Fo);    // Calculates wi
    float4 texMapRate = { 0.65f, 0.65f, 0.35f, 1.0 }; // (반사 , 물밑 , 디퓨즈) 비율

    float3 ReflectdColor = texColorReflect.rgb;
    float3 RefractedColor = (texColorRefract.rgb + texColorDiffuse.rgb);
    outColor.rgb = lerp(RefractedColor, ReflectdColor, Fr);
	
    outColor.a = Alpha;

    float4 NormalColor = float4(input.NormalColor.xyz, (float)Property / 255.0);
    output.Color0 = outColor;
    output.Color1 = NormalColor;
	

    return output;
}
VS_OUTPUT_WATER vsXYZ(VS_INPUT_WATER input)
{
    VS_OUTPUT_WATER output = (VS_OUTPUT_WATER)0;

    uint ArrayIndex = input.instId % 2;

	// 출력버텍스
    output.Pos = mul(input.Pos, g_Camera.matWorldViewProjArray[ArrayIndex]);

    return output;
}
float4 psColor(PS_INPUT_WATER input) : SV_Target
{
    float4 outColor = MtlDiffuse;

    return outColor;
}



struct VS_OUTPUT_HS_INPUT
{
    float3 PosWorld : POSITION;
    float3 Normal : NORMAL;
    float2 TexCoord : TEXCOORD0;
    float VertexDistanceFactor : VERTEXDISTANCEFACTOR;
};

struct HS_CONSTANT_DATA_OUTPUT
{
    float Edges[3] : SV_TessFactor;
    float Inside : SV_InsideTessFactor;

    float VertexDensity[3] : VERTEX_DENSITY;

};


struct HS_CONTROL_POINT_OUTPUT
{
    float3 PosWorld : POSITION;
    float3 Normal : NORMAL;
    float2 TexCoord : TEXCOORD0;

};



VS_OUTPUT_HS_INPUT vsTess(VS_INPUT_WATER input)
{
    VS_OUTPUT_HS_INPUT output = (VS_OUTPUT_HS_INPUT)0;

	// 출력버텍스
    output.PosWorld = (float3)mul(input.Pos, g_TrCommon.matWorld);

    float3 DefaultNormal = float3(0, 1, 0);
	// 노멀을 월드좌표계로 변환
    output.Normal = float3(0, 1, 0); // mul(DefaultNormal, (float3x3)matWorld);
    output.TexCoord = input.TexCoord;
    output.VertexDistanceFactor = 1.0;

    return output;
}


//--------------------------------------------------------------------------------------
// Hull shader
//--------------------------------------------------------------------------------------
HS_CONSTANT_DATA_OUTPUT hsTessConstant(InputPatch<VS_OUTPUT_HS_INPUT, 3> p, uint PatchID : SV_PrimitiveID)
{
    HS_CONSTANT_DATA_OUTPUT output = (HS_CONSTANT_DATA_OUTPUT)0;

    float4 g_vTessellationFactor = float4(2, 2, 2, 2);
    float4 vEdgeTessellationFactors = float4(1, 1, 1, 1);


	// Calculate edge scale factor from vertex scale factor: simply compute 
	// average tess factor between the two vertices making up an edge
	//vEdgeTessellationFactors.x = 0.5 * (p[1].VertexDistanceFactor + p[2].VertexDistanceFactor);
	//vEdgeTessellationFactors.y = 0.5 * (p[2].VertexDistanceFactor + p[0].VertexDistanceFactor);
	//vEdgeTessellationFactors.z = 0.5 * (p[0].VertexDistanceFactor + p[1].VertexDistanceFactor);

	
    vEdgeTessellationFactors.x = 1; // distance(p[1].PosWorld.xyz, p[2].PosWorld.xyz) / 25.0;
    vEdgeTessellationFactors.y = 1; // distance(p[2].PosWorld.xyz, p[0].PosWorld.xyz) / 25.0;
    vEdgeTessellationFactors.z = 1; // distance(p[0].PosWorld.xyz, p[1].PosWorld.xyz) / 25.0;

    float insideFactor = max(vEdgeTessellationFactors.x, vEdgeTessellationFactors.y);
    insideFactor = 1; // max(insideFactor, vEdgeTessellationFactors.z);

	// Multiply them by global tessellation factor
    vEdgeTessellationFactors *= g_vTessellationFactor.xxxy;

    output.Edges[0] = vEdgeTessellationFactors.x;
    output.Edges[1] = vEdgeTessellationFactors.y;
    output.Edges[2] = vEdgeTessellationFactors.z;
    output.Inside = insideFactor; // vEdgeTessellationFactors.w;

    return output;
}

[domain("tri")]
[partitioning("integer")]
[outputtopology("triangle_cw")]
[outputcontrolpoints(3)]
[patchconstantfunc("hsTessConstant")]
[maxtessfactor(15)]
HS_CONTROL_POINT_OUTPUT hsTess(InputPatch<VS_OUTPUT_HS_INPUT, 3> inputPatch, uint uCPID : SV_OutputControlPointID)
{
    HS_CONTROL_POINT_OUTPUT output = (HS_CONTROL_POINT_OUTPUT)0;

	// Copy inputs to outputs
    output.PosWorld = inputPatch[uCPID].PosWorld;
    output.Normal = inputPatch[uCPID].Normal;
    output.TexCoord = inputPatch[uCPID].TexCoord;

    return output;
}


//--------------------------------------------------------------------------------------
// Domain Shader
//--------------------------------------------------------------------------------------
[domain("tri")]
GS_OUTPUT_WATER dsTess(HS_CONSTANT_DATA_OUTPUT input, float3 BarycentricCoordinates : SV_DomainLocation, const OutputPatch<HS_CONTROL_POINT_OUTPUT, 3> TrianglePatch)
{
    GS_OUTPUT_WATER output = (GS_OUTPUT_WATER)0;

	// Interpolate world space position with barycentric coordinates
    float3 PosWorld = (BarycentricCoordinates.x * TrianglePatch[0].PosWorld) + (BarycentricCoordinates.y * TrianglePatch[1].PosWorld) + (BarycentricCoordinates.z * TrianglePatch[2].PosWorld);

    float delta = TexCoordAdj.x * 200.0;
    PosWorld.y += (sin(PosWorld.x + delta) * sin(PosWorld.z + delta)) * 2.5;

	// Interpolate world space normal and renormalize it
    float3 Normal = (BarycentricCoordinates.x * TrianglePatch[0].Normal) + (BarycentricCoordinates.y * TrianglePatch[1].Normal) + (BarycentricCoordinates.z * TrianglePatch[2].Normal);

    Normal = normalize(Normal);

	// Interpolate other inputs with barycentric coordinates
    output.TexCoordDiffuse = (BarycentricCoordinates.x * TrianglePatch[0].TexCoord) + (BarycentricCoordinates.y * TrianglePatch[1].TexCoord) + (BarycentricCoordinates.z * TrianglePatch[2].TexCoord);

    uint ArrayIndex = 0; // input.instId % 2;
    output.PosWorld = float4(PosWorld, 1);
    output.Pos = mul(float4(output.PosWorld.xyz, 1.0), g_Camera.matViewProjArray[ArrayIndex]);
	//output.Dist = output.Pos.w;
    output.TexCoordReflect = mul(float4(PosWorld.xyz, 1), matReflectTexCoord);
    output.TexCoordRefract = mul(float4(PosWorld.xyz, 1), matRefractTexCoord);
    output.Distance = output.Pos.w * 0.000025f;

	

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
void gsTess(triangle VS_OUTPUT_WATER input[3], inout TriangleStream<GS_OUTPUT_WATER> TriStream)
{
    GS_OUTPUT_WATER output[3];

    float3 N = CalcNormalWithTri((float3)input[0].PosWorld, (float3)input[1].PosWorld, (float3)input[2].PosWorld);

    for (uint i = 0; i < 3; i++)
    {
        output[i].Pos = input[i].Pos;
        output[i].Normal = N;
        output[i].NormalColor = float4((N * 0.5f) + 0.5f, 0);
        output[i].TexCoordDiffuse = input[i].TexCoordDiffuse;
        output[i].TexCoordReflect = input[i].TexCoordReflect;
        output[i].TexCoordRefract = input[i].TexCoordRefract;
        output[i].PosWorld = input[i].PosWorld;
        output[i].Distance = input[i].Distance;
        output[i].ArrayIndex = input[i].ArrayIndex;
        output[i].RTVIndex = input[i].ArrayIndex;
        TriStream.Append(output[i]);
    }
    TriStream.RestartStrip();
}
PS_TARGET psTess(PS_INPUT_WATER input)
{
    PS_TARGET output = (PS_TARGET)0;

    float4 outColor = 0;

    input.TexCoordReflect /= input.TexCoordReflect.w;
    input.TexCoordRefract /= input.TexCoordRefract.w;

    float2 texCoordWave = input.TexCoordDiffuse.xy + TexCoordAdj.xx;

    float4 texColorNormal = texNormal.Sample(samplerMirror, texCoordWave);

	

	// y와 z를 바꾸고 0.05를 곱해서 스케일
    float4 texCoordAdj = (texColorNormal.xzyw - 0.5f) * 0.05f;

    float2 texCoordReflect = input.TexCoordReflect.xy + texCoordAdj.xy;
    float2 texCoordDiffuse = input.TexCoordDiffuse.xy + texCoordAdj.xy;
    float2 texCoordRefract = input.TexCoordRefract.xy + (texCoordAdj.xy * 0.25);

    float4 texColorDiffuse = texDiffuse.Sample(samplerWrap, texCoordDiffuse);
    float4 texColorReflect = texReflect.Sample(samplerClamp, texCoordReflect);
    float4 texColorRefract = texRefract.Sample(samplerClamp, texCoordRefract);

	//mov			r10.a,r2.a		; 물밑 장면 텍스쳐 알파 백업
    float Alpha = 1.0; // texColorRefract.a;

    float3 N = input.Normal;
    float3 Fo = float3(0.5, 0.5, 0.5);
    float3 V = normalize((float3)EyePos - (float3)input.PosWorld);
    float3 wi;
    float3 Fr = Sample_Fr(V, wi, N, Fo);
	//float3 Fr = Kr * BxDF::Specular::Reflection::Sample_Fr(V, wi, N, Fo);    // Calculates wi
    float4 texMapRate = { 0.65f, 0.65f, 0.35f, 1.0 }; // (반사 , 물밑 , 디퓨즈) 비율

    float3 ReflectdColor = texColorReflect.rgb;
    float3 RefractedColor = (texColorRefract.rgb + texColorDiffuse.rgb);
    outColor.rgb = lerp(RefractedColor, ReflectdColor, Fr);
	
    outColor.a = Alpha;

    float3 DetailNormal = (texColorNormal.xzy * 2 - 1);
    float3 AdjNormal = normalize(input.Normal + DetailNormal);
    float4 NormalColor = float4(AdjNormal.xyz * 0.5 + 0.5, (float)Property / 255.0);

    output.Color0 = outColor;
    output.Color1 = NormalColor;
	

    return output;
}
