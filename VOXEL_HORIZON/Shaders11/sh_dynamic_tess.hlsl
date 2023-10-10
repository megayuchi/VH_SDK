#include "sh_dynamic_common.hlsl"



struct PS_INPUT_TESS
{
	float4 Pos				: SV_POSITION;
	float4 Diffuse			: COLOR0;
	float4 MtlDiffuseAdd		: COLOR1;
	float2 TexCoordDiffuse	: TEXCOORD0;
};


struct VS_OUTPUT_HS_INPUT
{
	float3 PosWorld		: POSITION;
	float3 Normal		: NORMAL;
	float2 TexCoord		: TEXCOORD0;
	float  VertexDistanceFactor : VERTEXDISTANCEFACTOR;
};

struct HS_CONSTANT_DATA_OUTPUT
{
	float    Edges[3]         : SV_TessFactor;
	float    Inside : SV_InsideTessFactor;

	float    VertexDensity[3] : VERTEX_DENSITY;

};


struct HS_CONTROL_POINT_OUTPUT
{
	float3 PosWorld : POSITION;
	float3 Normal   : NORMAL;
	float2 TexCoord : TEXCOORD0;

};
VS_OUTPUT_HS_INPUT vsDynamicTess(VS_INPUT_VL input)
{
	VS_OUTPUT_HS_INPUT output = (VS_OUTPUT_HS_INPUT)0;

	// 출력버텍스
	output.PosWorld = (float3)mul(input.Pos, g_TrCommon.matWorld);

	// 노멀을 월드좌표계로 변환
	output.Normal = mul(input.Normal, (float3x3)g_TrCommon.matWorld);


	output.TexCoord = input.TexCoord;
	output.VertexDistanceFactor = 1.0f;

	return output;
}


VS_OUTPUT_HS_INPUT vsDynamicPhysiqueTess(VS_INPUT_VL_PHYSIQUE input)
{
	VS_OUTPUT_HS_INPUT output = (VS_OUTPUT_HS_INPUT)0;

	// 블랜딩된 로컬포지션을 계산
	float3	posLocal = vsCalcBlendPos(input.Pos, input.BlendIndex, input.BlendWeight);

	// 블랜딩된 로컬노멀을 계산.
	float3	normalLocal = vsCalcBlendNormal(input.Normal, input.BlendIndex, input.BlendWeight);

	// 출력 버텍스
	output.PosWorld = (float3)mul(float4(posLocal, 1), g_TrCommon.matWorld);

	// 노멀을 월드좌표계로 변환
	output.Normal = mul(normalLocal, (float3x3)g_TrCommon.matWorld);
	output.TexCoord = input.TexCoord;
	output.VertexDistanceFactor = 2.0f;

	return output;
}





//--------------------------------------------------------------------------------------
// Hull shader
//--------------------------------------------------------------------------------------
HS_CONSTANT_DATA_OUTPUT hsDynamicTessConstant(InputPatch<VS_OUTPUT_HS_INPUT, 3> p, uint PatchID : SV_PrimitiveID)
{
	HS_CONSTANT_DATA_OUTPUT output = (HS_CONSTANT_DATA_OUTPUT)0;
	//float4 vEdgeTessellationFactors = g_vTessellationFactor.xxxy;
	float4	vTessellationFactor = float4(7.0f, 7.0f, 7.0f, 0.1f);

	float4 vEdgeTessellationFactors = vTessellationFactor.xxxy;


	// Calculate edge scale factor from vertex scale factor: simply compute 
	// average tess factor between the two vertices making up an edge
	vEdgeTessellationFactors.x = 0.5 * (p[1].VertexDistanceFactor + p[2].VertexDistanceFactor);
	vEdgeTessellationFactors.y = 0.5 * (p[2].VertexDistanceFactor + p[0].VertexDistanceFactor);
	vEdgeTessellationFactors.z = 0.5 * (p[0].VertexDistanceFactor + p[1].VertexDistanceFactor);
	vEdgeTessellationFactors.w = vEdgeTessellationFactors.x;

	// Multiply them by global tessellation factor
	vEdgeTessellationFactors *= vTessellationFactor.xxxy;


	// Retrieve edge density from edge density buffer (swizzle required to match vertex ordering)
	//vEdgeTessellationFactors *= 0.25f;
	vEdgeTessellationFactors = 4.0f;



	// Assign tessellation levels
	output.Edges[0] = vEdgeTessellationFactors.x;
	output.Edges[1] = vEdgeTessellationFactors.y;
	output.Edges[2] = vEdgeTessellationFactors.z;
	output.Inside = vEdgeTessellationFactors.w;

	output.Edges[0] = 2;
	output.Edges[1] = 2;
	output.Edges[2] = 2;
	output.Inside = 5;


	return output;
}

[domain("tri")]
[partitioning("fractional_odd")]
[outputtopology("triangle_cw")]
[outputcontrolpoints(3)]
[patchconstantfunc("hsDynamicTessConstant")]
[maxtessfactor(15.0)]
HS_CONTROL_POINT_OUTPUT hsDynamicTess(InputPatch<VS_OUTPUT_HS_INPUT, 3> inputPatch, uint uCPID : SV_OutputControlPointID)
{
	HS_CONTROL_POINT_OUTPUT    output = (HS_CONTROL_POINT_OUTPUT)0;

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
PS_INPUT_TESS dsDynamicTess(HS_CONSTANT_DATA_OUTPUT input, float3 BarycentricCoordinates : SV_DomainLocation, const OutputPatch<HS_CONTROL_POINT_OUTPUT, 3> TrianglePatch)
{
	PS_INPUT_TESS output = (PS_INPUT_TESS)0;

	// Interpolate world space position with barycentric coordinates
	float3 PosWorld = (BarycentricCoordinates.x * TrianglePatch[0].PosWorld) + (BarycentricCoordinates.y * TrianglePatch[1].PosWorld) + (BarycentricCoordinates.z * TrianglePatch[2].PosWorld);

	// Interpolate world space normal and renormalize it
	float3 Normal = (BarycentricCoordinates.x * TrianglePatch[0].Normal) + (BarycentricCoordinates.y * TrianglePatch[1].Normal) + (BarycentricCoordinates.z * TrianglePatch[2].Normal);

	Normal = normalize(Normal);

	// Interpolate other inputs with barycentric coordinates
	output.TexCoordDiffuse = (BarycentricCoordinates.x * TrianglePatch[0].TexCoord) + (BarycentricCoordinates.y * TrianglePatch[1].TexCoord) + (BarycentricCoordinates.z * TrianglePatch[2].TexCoord);


	// N*L계산
	float	cosang = saturate(dot(Normal, (float3)(-LightDir)));

	// (N*L) * Diffuse + Ambient
	output.Diffuse = (cosang * MtlDiffuse) + MtlAmbient;
	output.Diffuse.a = MtlDiffuse.a;
	output.MtlDiffuseAdd = MtlDiffuseAdd;

	// world는 identity matrix일것
	output.Pos = mul(float4(PosWorld.xyz, 1.0), g_Camera.matWorldViewProjCommon);

	return output;
}


//--------------------------------------------------------------------------------------
// Pixel Shader
//--------------------------------------------------------------------------------------
float4 psDynamicTess(PS_INPUT_TESS input) : SV_Target
{
	float4	texColor = texDiffuse.Sample(samplerWrap, input.TexCoordDiffuse);

	float4	outColor = texColor * input.Diffuse + input.MtlDiffuseAdd;

	return outColor;
}

