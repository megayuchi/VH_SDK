#ifndef SH_Z_CULL_HLSL
#define SH_Z_CULL_HLSL

#include "sh_util.hlsl"

#define MAX_CULL_THREAD_NUM	64

cbuffer CONSTANT_BUFFER_Z_CULL : register(b0)
{
	float4		EyePos;
	float4		Up;
	matrix		matViewProj;
	float4		FrustumPlanes[6];    // view-frustum planes in world space (normals face out)
	float2		ViewportSize;        // Viewport Width and Height in pixels
	float		FarRcp;
	uint		OccludeeNum;
};


struct Z_CULL_RESULT
{
	float3	CornerPoint[4];
	int		MipLevel;
	float3	ClosestPoint;
	float	Width;

	float	sphere_depth;	// dist /far
	float	map_depth;
	int		Test;
	int		ThreadIndex;
};

// Bounding sphere center (XYZ) and radius (W), world space
Texture2D<float>		 HiZMap			: register(t0);
StructuredBuffer<float4> BufferInput    : register(t1);

// Is Visible 1 (Visible) 0 (Culled)
RWStructuredBuffer<Z_CULL_RESULT> BufferOut : register(u0);

SamplerState HiZMapSampler : register(s0);

[numthreads(MAX_CULL_THREAD_NUM, 1, 1)]
void csCull(uint3 GroupId          : SV_GroupID,
	uint3 DispatchThreadId : SV_DispatchThreadID,
	uint GroupIndex : SV_GroupIndex)
{
	// Calculate the actual index this thread in this group will be reading from.
	//int index = GroupIndex + (GroupId.x * NUM_THREADS_X);

	Z_CULL_RESULT	Result = (Z_CULL_RESULT)0;

	if (DispatchThreadId.x >= OccludeeNum)
		return;

	Result.ThreadIndex = DispatchThreadId.x;
	// Bounding sphere center (XYZ) and radius (W), world space
	float4 Bounds = BufferInput[DispatchThreadId.x];
	//BufferOut[index] = Bounds.x + Bounds.y + Bounds.z + Bounds.w;
//	BufferOut[index] = Reserved0.x + Reserved0.y;


	// Perform view-frustum test
	uint	visible = CullSphere(FrustumPlanes, Bounds.xyz, Bounds.w);

	if (visible)
	{



		float3	SphereEyeDir = EyePos.xyz - Bounds.xyz;
		float	SphereEyeDist = length(SphereEyeDir);

		float3	SphereEyeDirN = SphereEyeDir / SphereEyeDist;
		float3	viewRight = cross(SphereEyeDirN, Up.xyz);

		float fRadius = Bounds.w;

		// log2(1)	 = 0;
		// log2(2)	 = 1;
		// log2(4)	 = 2;
		// log2(8)	 = 3;
		// log2(16)	 = 4;
		// log2(32)	 = 5;
		// log2(64)	 = 6;
		// log2(128) = 7;
		// log2(256) = 8;
		// log2(512) = 9;


		// Compute the offsets for the points around the sphere
		float3 vUpRadius = Up.xyz * fRadius;
		float3 vRightRadius = viewRight * fRadius;

		// Generate the 4 corners of the sphere in world space.
		//float3	Center = *(float3*)&Bounds;
		float4 vCornerWS[4];
		float4 vCornerCS[4];

		vCornerWS[0] = float4(Bounds.xyz + vUpRadius - vRightRadius, 1); // Top-Left
		vCornerWS[1] = float4(Bounds.xyz + vUpRadius + vRightRadius, 1); // Top-Right
		vCornerWS[2] = float4(Bounds.xyz - vUpRadius - vRightRadius, 1); // Bottom-Left
		vCornerWS[3] = float4(Bounds.xyz - vUpRadius + vRightRadius, 1); // Bottom-Right

		// Transformfloat4_VPTR2(vCornerCS,vCornerWS,&matViewProj,4);
		uint i;
		[unroll]
		for (i = 0; i < 4; i++)
		{
			vCornerCS[i] = mul(vCornerWS[i], matViewProj);
		}

		float2 vCornerNDC[4];
		// 스크린 스페이스로 변환
		[unroll]
		for (i = 0; i < 4; i++)
		{
			vCornerCS[i] = vCornerCS[i] / vCornerCS[i].w;

			// 0에서 1사이로 정규화
			vCornerNDC[i] = vCornerCS[i].xy * float2(0.5f, -0.5f) + float2(0.5f, 0.5f);

			Result.CornerPoint[i] = vCornerCS[i].xyz;
		}


		// compute nearest point to camera on sphere, and project it
		float4	Pv = float4(Bounds.xyz + (SphereEyeDirN * Bounds.w), 1);
		float4	ClosestSpherePoint = mul(Pv, matViewProj);
		float	sphere_depth = ClosestSpherePoint.w * FarRcp;

		Result.ClosestPoint = ClosestSpherePoint.xyz / ClosestSpherePoint.w;
		Result.sphere_depth = sphere_depth;

		// 왼쪽 오른쪽 꼭지점의 거리.
		float fSphereWidthNDC = distance(vCornerNDC[0], vCornerNDC[1]);



		// Choose a MIP level in the HiZ map.
		// The orginal assumed viewport width > height, however I've changed it
		// to determine the greater of the two.
		//
		// This will result in a mip level where the object takes up at most
		// 2x2 textels such that the 4 sampled points have depths to compare
		// against.
		float Width = fSphereWidthNDC * max(ViewportSize.x, ViewportSize.y);
		float fLOD = ceil(log2(Width));
		Result.MipLevel = (uint)fLOD;
		Result.Width = Width;


		// fetch depth samples at the corners of the square to compare against
		float4 vSamples;
		vSamples.x = HiZMap.SampleLevel(HiZMapSampler, vCornerNDC[0], fLOD);
		vSamples.y = HiZMap.SampleLevel(HiZMapSampler, vCornerNDC[1], fLOD);
		vSamples.z = HiZMap.SampleLevel(HiZMapSampler, vCornerNDC[2], fLOD);
		vSamples.w = HiZMap.SampleLevel(HiZMapSampler, vCornerNDC[3], fLOD);

		float fMaxSampledDepth = max(max(vSamples.x, vSamples.y), max(vSamples.z, vSamples.w));
		Result.map_depth = fMaxSampledDepth;


		// cull sphere if the depth is greater than the largest of our ZMap values
		// or if the sphere's depth is less than 0, indicating that the object is behind us.

		//Result.Test = ((z_value > fMaxSampledDepth) || (z_value < 0)) ? 0 : 1;

		// 뎁스버퍼의 값보다 작으면 그린다.
		Result.Test = sphere_depth < fMaxSampledDepth;
		BufferOut[DispatchThreadId.x] = Result;
	}

}

#endif