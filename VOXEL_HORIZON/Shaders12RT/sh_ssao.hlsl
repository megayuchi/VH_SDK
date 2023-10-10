#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_typedef.hlsl"

//-----------------------------------------------------------------------------------------
// Depth downscale
//-----------------------------------------------------------------------------------------
#ifdef STEREO_RENDER
Texture2DArray DepthTex : register(t0);
Texture2DArray NormalTex : register(t1);
#else
Texture2D DepthTex : register(t0);
Texture2D NormalTex : register(t1);
#endif

RWStructuredBuffer<float4> MiniDepthRW : register(u0);

cbuffer CONSTANT_BUFFER_SSAO : register(b0)
{
	uint2	Res;
	float2	ResRcp;
	matrix	matViewArray[2];
	DECOMP_PROJ	DecompProj[2];
	float	OffsetRadius;
	float	fRadius;
	float	fMaxDepth;
	float	Reserved;
}
//float ConvertZToLinearDepth(float depth, uint ArrayIndex)
//{
//	float linearDepth = DecompProj[ArrayIndex].m43 / (depth - DecompProj[ArrayIndex].m33);
//	return linearDepth;
//}
float3 CalcViewPos(float2 csPos, float depth, uint ArrayIndex)
{
	// csPos - Clip Space Postion -1 ~ +1


	//xp,yp,zp 는 프로젝션 된 점 (-1 - 1)

	// 일반적인 경우 - m21,m31,m32가 0인 경우
	// z = m43 / (zp - m33)
	// y = z*yp / m22
	// x = z*xp / m11

	// m21,m31,m32가 유효할 경우
	// z = m43 / (zp - m33)
	// y = (z*yp - z*m32) / m22
	// x = (z*xp - y*m21 - z*m31) / m11

	float z = DecompProj[ArrayIndex].m43 / (depth - DecompProj[ArrayIndex].m33);
	float y = ((z * csPos.y) - (z * DecompProj[ArrayIndex].m32)) * DecompProj[ArrayIndex].rcp_m22;
	float x = ((z * csPos.x) - (y * DecompProj[ArrayIndex].m21) - (z * DecompProj[ArrayIndex].m31)) * DecompProj[ArrayIndex].rcp_m11;
	return float3(x, y, z);
}

[numthreads(1024, 1, 1)]
void DepthDownscale(uint3 groupID : SV_GroupID, uint3 dispatchThreadId : SV_DispatchThreadID)
{
	// SV_GroupThreadID = Group내에서의 ID
	// SV_GroupID = Group의 ID
	// SV_DispatchThreadID = 모든 스레드를 전개했을때 Thread ID
	// SV_GroupIndex = Group내에서의 인덱스

	uint2	CurPixel = uint2(dispatchThreadId.x % Res.x, dispatchThreadId.x / Res.x);	// 현재 픽셀의 좌표
	uint	ArrayIndex = groupID.y;

	uint	Dest = ArrayIndex * Res.x * Res.y + dispatchThreadId.x;
	
	// Skip out of bound pixels
	if (CurPixel.y < Res.y)
	{
		float minDepth = 1.0;
		float3 avgNormalWorld = float3(0.0, 0.0, 0.0);
		//int4	location = int4(input.Position.xy,input.ArrayIndex,0);

		// 4x4로 샘플링
#ifdef STEREO_RENDER
		uint4 FullResPixel = uint4(CurPixel * 2, ArrayIndex, 0);
#else
		uint3 FullResPixel = uint3(CurPixel * 2, 0);
#endif
		[unroll]
		for (int y = 0; y < 2; y++)
		{
			[unroll]
			for (int x = 0; x < 2; x++)
			{
				// Get the pixels depth and store the minimum depth
				float curDepth = DepthTex.Load(FullResPixel, int2(x, y));
				minDepth = min(curDepth, minDepth);

				// Sum the viewspace normals so we can average them
				float3 normalWorld = NormalTex.Load(FullResPixel, int2(x, y));
				avgNormalWorld += normalize(normalWorld * 2.0 - 1.0);
			}
		}

		MiniDepthRW[Dest].x = minDepth;
		float3 avgNormalView = mul(avgNormalWorld * 0.25, (float3x3)matViewArray[ArrayIndex]);
		MiniDepthRW[Dest].yzw = avgNormalView;
	}
}

//-----------------------------------------------------------------------------------------
// SSAO Compute
//-----------------------------------------------------------------------------------------

StructuredBuffer<float4> MiniDepth : register(t0);


#ifdef STEREO_RENDER
RWTexture2DArray<float> AO : register(u0);
#else
RWTexture2D<float> AO : register(u0);
#endif

// Possion disc sampling pattern
static const float NumSamplesRcp = 1.0 / 8.0;
static const uint NumSamples = 8;
static const float2 SampleOffsets[NumSamples] = {
	float2(0.2803166, 0.08997212),
	float2(-0.5130632, 0.6877457),
	float2(0.425495, 0.8665376),
	float2(0.8732584, 0.3858971),
	float2(0.0498111, -0.6287371),
	float2(-0.9674183, 0.1236534),
	float2(-0.3788098, -0.09177673),
	float2(0.6985874, -0.5610316),
};

float GetDepth(int2 pos, uint ArrayIndex)
{
	uint	offset = ArrayIndex * Res.x * Res.y;

	// Clamp the input pixel position
	float x = clamp(pos.x, 0, Res.x - 1);
	float y = clamp(pos.y, 0, Res.y - 1);

	// find the mini-depth index position and retrive the detph value
	int miniDepthIdx = offset + x + y * Res.x;
	return MiniDepth[miniDepthIdx].x;
}

float3 GetNormal(int2 pos, uint ArrayIndex)
{
	uint	offset = ArrayIndex * Res.x * Res.y;

	// Clamp the input pixel position
	float x = clamp(pos.x, 0, Res.x - 1);
	float y = clamp(pos.y, 0, Res.y - 1);

	int miniDepthIdx = offset + x + y * Res.x; // find the mini-depth index position
	return MiniDepth[miniDepthIdx].yzw;
}

float ComputeAO(int2 cetnerPixelPos, float2 centerClipPos, uint ArrayIndex)
{
	// view_pos.y = csPos.y * 1.0f / pMatProj->_22 * linearDepth;
	// view_pos.y = csPos.y * linearDepth / pMatProj->_22;

	// zv = m43 / (zp - m33)
	// yv = zv*yp / m22
	// xv = zv*xp / m11

	// vPos.z = linear_depth

	// vPos.y = linear_depth * cpPos.y * (1 / m22);
	// yv = linear_depth * cpPos.y * (1 / m22);
	// xv = linear_depth * cpPos.x * (1 / m11);


	// Get the depths for the normal calculation
	float centerDepth = GetDepth(cetnerPixelPos.xy, ArrayIndex);	// linear depth

	float isNotSky = centerDepth < fMaxDepth;

	// Find the center pixel veiwspace position
	float3 centerPos = CalcViewPos(centerClipPos, centerDepth, ArrayIndex);

	// Get the view space normal for the center pixel
	float3 centerNormal = GetNormal(cetnerPixelPos.xy, ArrayIndex);
	centerNormal = normalize(centerNormal);
	
	//float bw = centerDepth / 40000.0f;
	//float3 normalColor = centerNormal * 0.5 + float3(0.5, 0.5, 0.5);
	//float3 bwConst = float3(0.3f, 0.59f, 0.11f);
	//float bw = dot((float3) normalColor, bwConst);
	//return bw;
	
	// Prepare for random sampling offset
	float rotationAngle = 0.0;
	//float rotationAngle = dot(float2(centerClipPos), float2(73.0, 197.0));
	float2 randSinCos;
	sincos(rotationAngle, randSinCos.x, randSinCos.y);
	float2x2 randRotMat = float2x2(randSinCos.y, -randSinCos.x, randSinCos.x, randSinCos.y);

	// Take the samples and calculate the ambient occlusion value for each
	float ao = 0.0;
	[unroll]
	for (uint i = 0; i < NumSamples; i++)
	{
		// Find the texture space position and depth
		float2 sampleOff = OffsetRadius.xx * mul(SampleOffsets[i], randRotMat);
		float curDepth = GetDepth(cetnerPixelPos + int2(sampleOff.x, -sampleOff.y), ArrayIndex);

		// Calculate the view space position

		float2	curClipPos = centerClipPos + 2.0 * sampleOff * ResRcp;
		float3	curPos = CalcViewPos(curClipPos, curDepth, ArrayIndex);

		//float3 curPos;
		//curPos.xy = (centerClipPos + 2.0 * sampleOff * ResRcp) * ProjParams.xy * curDepth;
		//curPos.z = curDepth;

		float3 centerToCurPos = curPos - centerPos;
		float lenCenterToCurPos = length(centerToCurPos);
		float angleFactor = 1.0 - dot(centerToCurPos / lenCenterToCurPos, centerNormal);
		float distFactor = lenCenterToCurPos / fRadius;

		ao += saturate(max(distFactor, angleFactor)) * isNotSky;
	}

	return ao * NumSamplesRcp;
}

[numthreads(1024, 1, 1)]
void SSAOCompute(uint3 groupID : SV_GroupID, uint3 dispatchThreadId : SV_DispatchThreadID)
{
	uint2	CurPixel = uint2(dispatchThreadId.x % Res.x, dispatchThreadId.x / Res.x);	// 현재 픽셀의 좌표
	uint	ArrayIndex = groupID.y;

#ifdef STEREO_RENDER
	uint3	DestCoord = uint3(CurPixel, ArrayIndex);
#else
	uint2	DestCoord = CurPixel;
#endif
	// Skip out of bound pixels
	if (CurPixel.y < Res.y)
	{
		// Find the XY clip space position for the current pixel
		// Y has to be inverted
		float2 centerClipPos = 2.0 * float2(CurPixel)* ResRcp;
		centerClipPos = float2(centerClipPos.x - 1.0, 1.0 - centerClipPos.y);

		AO[DestCoord] = ComputeAO(CurPixel, centerClipPos, ArrayIndex);
	}
}
