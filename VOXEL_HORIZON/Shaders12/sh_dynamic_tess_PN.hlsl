#include "sh_dynamic_common.hlsl"



struct VS_OUTPUT_HS_INPUT
{
	float3	PosWorld		: POSITION;
	float3	Normal			: NORMAL;
	float2	TexCoord		: TEXCOORD0;

};

struct DS_POSITION_NORMAL_TEXCOORD
{
	float4	PosWorld	: POSITION;
	float3	Normal		: NORMAL;
	float2	TexCoord	: TEXCOORD0;

};

struct HS_ConstantOutput
{
	// Tess factor for the FF HW block
	float fTessFactor[3]    : SV_TessFactor;
	float fInsideTessFactor : SV_InsideTessFactor;

	// Geometry cubic generated control points
	float3 f3B210    : POSITION3;
	float3 f3B120    : POSITION4;
	float3 f3B021    : POSITION5;
	float3 f3B012    : POSITION6;
	float3 f3B102    : POSITION7;
	float3 f3B201    : POSITION8;
	float3 f3B111    : CENTER;

	// Normal quadratic generated control points
	float3 f3N110    : NORMAL3;
	float3 f3N011    : NORMAL4;
	float3 f3N101    : NORMAL5;
};

struct HS_ControlPointOutput
{
	float3 f3Position    : POSITION;
	float3 f3Normal      : NORMAL;
	float2 f2TexCoord    : TEXCOORD;
};

struct GS_INPUT
{
	float4	Pos				: SV_POSITION;
	float4	Diffuse			: COLOR0;
	float4	NormalColor		: COLOR1;
	float2	TexCoordDiffuse	: TEXCOORD0;
	float4	PosWorld		: TEXCOORD2;
	float	Dist : TEXCOORD3;
	float	NdotL[8]		: TEXCOORD5;

};
VS_OUTPUT_HS_INPUT vsDynamicTess(VS_INPUT_VL input)
{
	VS_OUTPUT_HS_INPUT output = (VS_OUTPUT_HS_INPUT)0;

	// 출력버텍스
	output.PosWorld = (float3)mul(input.Pos, g_TrCommon.matWorld);

	// 노멀을 월드좌표계로 변환
	output.Normal = mul(input.Normal, (float3x3)g_TrCommon.matWorld);


	output.TexCoord = input.TexCoord;



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



	return output;
}



//--------------------------------------------------------------------------------------
// This hull shader passes the tessellation factors through to the HW tessellator, 
// and the 10 (geometry), 6 (normal) control points of the PN-triangular patch to the domain shader
//--------------------------------------------------------------------------------------
HS_ConstantOutput HS_PNTrianglesConstant(InputPatch<VS_OUTPUT_HS_INPUT, 3> I)
{
	HS_ConstantOutput output = (HS_ConstantOutput)0;

	float fEdgeDot[3];

	// Use the tessellation factors as defined in constant space 

	//output.fTessFactor[0] = output.fTessFactor[1] = output.fTessFactor[2] = 2.5f;
	output.fTessFactor[0] = output.fTessFactor[1] = output.fTessFactor[2] = 3.0f;


	// Assign Positions
	float3 f3B003 = I[0].PosWorld.xyz;
	float3 f3B030 = I[1].PosWorld.xyz;
	float3 f3B300 = I[2].PosWorld.xyz;
	// And Normals
	float3 f3N002 = I[0].Normal;
	float3 f3N020 = I[1].Normal;
	float3 f3N200 = I[2].Normal;

	// Compute the cubic geometry control points
	// Edge control points
	output.f3B210 = ((2.0f * f3B003) + f3B030 - (dot((f3B030 - f3B003), f3N002) * f3N002)) / 3.0f;
	output.f3B120 = ((2.0f * f3B030) + f3B003 - (dot((f3B003 - f3B030), f3N020) * f3N020)) / 3.0f;
	output.f3B021 = ((2.0f * f3B030) + f3B300 - (dot((f3B300 - f3B030), f3N020) * f3N020)) / 3.0f;
	output.f3B012 = ((2.0f * f3B300) + f3B030 - (dot((f3B030 - f3B300), f3N200) * f3N200)) / 3.0f;
	output.f3B102 = ((2.0f * f3B300) + f3B003 - (dot((f3B003 - f3B300), f3N200) * f3N200)) / 3.0f;
	output.f3B201 = ((2.0f * f3B003) + f3B300 - (dot((f3B300 - f3B003), f3N002) * f3N002)) / 3.0f;
	// Center control point
	float3 f3E = (output.f3B210 + output.f3B120 + output.f3B021 + output.f3B012 + output.f3B102 + output.f3B201) / 6.0f;
	float3 f3V = (f3B003 + f3B030 + f3B300) / 3.0f;
	output.f3B111 = f3E + ((f3E - f3V) / 2.0f);

	// Compute the quadratic normal control points, and rotate into world space
	float fV12 = 2.0f * dot(f3B030 - f3B003, f3N002 + f3N020) / dot(f3B030 - f3B003, f3B030 - f3B003);
	output.f3N110 = normalize(f3N002 + f3N020 - fV12 * (f3B030 - f3B003));
	float fV23 = 2.0f * dot(f3B300 - f3B030, f3N020 + f3N200) / dot(f3B300 - f3B030, f3B300 - f3B030);
	output.f3N011 = normalize(f3N020 + f3N200 - fV23 * (f3B300 - f3B030));
	float fV31 = 2.0f * dot(f3B003 - f3B300, f3N200 + f3N002) / dot(f3B003 - f3B300, f3B003 - f3B300);
	output.f3N101 = normalize(f3N200 + f3N002 - fV31 * (f3B003 - f3B300));


	// Inside tess factor is just the average of the edge factors
	output.fInsideTessFactor = (output.fTessFactor[0] + output.fTessFactor[1] + output.fTessFactor[2]) / 3.0f;

	return output;
}

[domain("tri")]
[partitioning("fractional_odd")]
[outputtopology("triangle_cw")]
[patchconstantfunc("HS_PNTrianglesConstant")]
[outputcontrolpoints(3)]
[maxtessfactor(9)]
HS_ControlPointOutput hsDynamicTessPN(InputPatch<VS_OUTPUT_HS_INPUT, 3> I, uint uCPID : SV_OutputControlPointID)
{
	HS_ControlPointOutput output = (HS_ControlPointOutput)0;

	// Just pass through inputs = fast pass through mode triggered
	output.f3Position = I[uCPID].PosWorld;
	output.f3Normal = I[uCPID].Normal;
	output.f2TexCoord = I[uCPID].TexCoord;

	return output;
}


DS_POSITION_NORMAL_TEXCOORD CalcPositionNormalTexPN(HS_ConstantOutput HSConstantData, const HS_ControlPointOutput controlPoint[3], float3 f3BarycentricCoords)
{
	DS_POSITION_NORMAL_TEXCOORD output = (DS_POSITION_NORMAL_TEXCOORD)0;
	// The barycentric coordinates
	float fU = f3BarycentricCoords.x;
	float fV = f3BarycentricCoords.y;
	float fW = f3BarycentricCoords.z;

	// Precompute squares and squares * 3 
	float fUU = fU * fU;
	float fVV = fV * fV;
	float fWW = fW * fW;
	float fUU3 = fUU * 3.0f;
	float fVV3 = fVV * 3.0f;
	float fWW3 = fWW * 3.0f;

	// Compute position from cubic control points and barycentric coords
	float3 PosWorld = controlPoint[0].f3Position * fWW * fW +
		controlPoint[1].f3Position * fUU * fU +
		controlPoint[2].f3Position * fVV * fV +
		HSConstantData.f3B210 * fWW3 * fU +
		HSConstantData.f3B120 * fW * fUU3 +
		HSConstantData.f3B201 * fWW3 * fV +
		HSConstantData.f3B021 * fUU3 * fV +
		HSConstantData.f3B102 * fW * fVV3 +
		HSConstantData.f3B012 * fU * fVV3 +
		HSConstantData.f3B111 * 6.0f * fW * fU * fV;

	output.PosWorld = float4(PosWorld, 1.0f);

	// Compute normal from quadratic control points and barycentric coords
	float3 Normal = controlPoint[0].f3Normal * fWW +
		controlPoint[1].f3Normal * fUU +
		controlPoint[2].f3Normal * fVV +
		HSConstantData.f3N110 * fW * fU +
		HSConstantData.f3N011 * fU * fV +
		HSConstantData.f3N101 * fW * fV;


	// Normalize the interpolated normal    
	output.Normal = normalize(Normal);

	// Linearly interpolate the texture coords
	output.TexCoord = controlPoint[0].f2TexCoord * fW + controlPoint[1].f2TexCoord * fU + controlPoint[2].f2TexCoord * fV;





	return output;
}

//--------------------------------------------------------------------------------------
// This domain shader applies contol point weighting to the barycentric coords produced by the FF tessellator 
//--------------------------------------------------------------------------------------
[domain("tri")]
GS_INPUT dsDynamicTessPN(HS_ConstantOutput HSConstantData, const OutputPatch<HS_ControlPointOutput, 3> I, float3 f3BarycentricCoords : SV_DomainLocation)
{
	GS_INPUT output = (GS_INPUT)0;

	//DS_POSITION_NORMAL_TEXCOORD CalcPositionNormalTexPN(HS_ConstantOutput HSConstantData, const HS_ControlPointOutput controlPoint[3], float3 f3BarycentricCoords)
    HS_ControlPointOutput P[3] = { I[0], I[1], I[2] };
	DS_POSITION_NORMAL_TEXCOORD PosNormalTex = CalcPositionNormalTexPN(HSConstantData, P, f3BarycentricCoords);
	output.PosWorld = PosNormalTex.PosWorld;
	// world는 identity matrix일것
	//output.Pos = mul( float4( output.PosWorld.xyz, 1.0 ), matViewProj );
	output.Pos = mul(float4(output.PosWorld.xyz, 1.0), g_Camera.matWorldViewProjCommon);
	output.Dist = output.Pos.w;
	output.TexCoordDiffuse = PosNormalTex.TexCoord;

	// 노멀을 0에서 1사이로 포화
	output.NormalColor.rgb = (PosNormalTex.Normal * 0.5f) + 0.5f;
	output.NormalColor.a = 1;

	// N*L계산
	float	cosang = saturate(dot(PosNormalTex.Normal, (float3)(-LightDir)));





	// (N*L) * Diffuse + Ambient
	output.Diffuse = (cosang * MtlDiffuse) + MtlAmbient;
	output.Diffuse.a = MtlDiffuse.a;

	// 다이나믹 라이트가 있는 경우
	for (int i = 0; i < iAttLightNum; i++)
	{
		float3		LightVec = normalize((AttLight[i].Pos.xyz - output.PosWorld.xyz));
		output.NdotL[i] = dot(PosNormalTex.Normal, LightVec);
	}

	return output;
}

[domain("tri")]
GS_INPUT dsDynamicTessToonPN(HS_ConstantOutput HSConstantData, const OutputPatch<HS_ControlPointOutput, 3> I, float3 f3BarycentricCoords : SV_DomainLocation)
{
	GS_INPUT output = (GS_INPUT)0;

	//DS_POSITION_NORMAL_TEXCOORD PosNormalTex = CalcPositionNormalTexPN(HSConstantData, I, f3BarycentricCoords);
    HS_ControlPointOutput P[3] = { I[0], I[1], I[2] };
	DS_POSITION_NORMAL_TEXCOORD PosNormalTex = CalcPositionNormalTexPN(HSConstantData, P, f3BarycentricCoords);

	// Transform model position with view-projection matrix
	// world는 identity matrix일것
	//output.Pos = mul( float4( PosNormalTex.PosWorld.xyz, 1.0 ), matViewProj );
	output.Pos = mul(float4(PosNormalTex.PosWorld.xyz, 1.0), g_Camera.matWorldViewProjCommon);
	output.Dist = output.Pos.w;
	output.PosWorld = PosNormalTex.PosWorld;
	output.TexCoordDiffuse = PosNormalTex.TexCoord;

	// 노멀을 0에서 1사이로 포화
	output.NormalColor.rgb = (PosNormalTex.Normal * 0.5f) + 0.5f;
	output.NormalColor.a = 1;

	output.Diffuse = saturate(MtlDiffuse + MtlAmbient);
	output.Diffuse.a = MtlDiffuse.a;

	// 다이나믹 라이트가 있는 경우
	for (int i = 0; i < iAttLightNum; i++)
	{
		float3		LightVec = normalize((AttLight[i].Pos.xyz - output.PosWorld.xyz));
		output.NdotL[i] = dot(PosNormalTex.Normal, LightVec);
	}


	return output;
}
[domain("tri")]
float4 dsDynamicTessPN_Depth(HS_ConstantOutput HSConstantData, const OutputPatch<HS_ControlPointOutput, 3> I, float3 f3BarycentricCoords : SV_DomainLocation) : SV_POSITION
{
	//DS_POSITION_NORMAL_TEXCOORD PosNormalTex = CalcPositionNormalTexPN(HSConstantData,I,f3BarycentricCoords);
	HS_ControlPointOutput P[3] = { I[0], I[1], I[2] };
    DS_POSITION_NORMAL_TEXCOORD PosNormalTex = CalcPositionNormalTexPN(HSConstantData, P, f3BarycentricCoords);

    float4 PosView = mul(PosNormalTex.PosWorld, g_Camera.matViewArray[0]);
	PosView.z += 2.5f;
    float4 outPos = mul(PosView, g_Camera.matProjArray[0]);

	return outPos;
}


//--------------------------------------------------------------------------------------
// Geometry Shader
//--------------------------------------------------------------------------------------
[maxvertexcount(3)]
void gsDefault(triangle GS_INPUT input[3], inout TriangleStream<PS_INPUT> TriStream)
{
	PS_INPUT	output = (PS_INPUT)0;

	for (uint i = 0; i < 3; i++)
	{
		output.Pos = input[i].Pos;
		output.Diffuse = input[i].Diffuse;
		output.NormalColor = input[i].NormalColor;
		output.TexCoordDiffuse = input[i].TexCoordDiffuse;
		output.PosWorld = input[i].PosWorld;
		output.Dist = input[i].Dist;
	


		// 다이나믹라이트에 대한 N DOT L
		for (uint j = 0; j < 8; j++)
		{
			output.NdotL[j] = input[i].NdotL[j];
		}
		// 클립플레인처리
		output.Clip = dot(input[i].PosWorld, ClipPlane);
		TriStream.Append(output);
	}
	TriStream.RestartStrip();
}

