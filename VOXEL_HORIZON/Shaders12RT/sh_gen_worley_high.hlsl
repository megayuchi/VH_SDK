#include "sh_const_buffer_gen_tex3d.hlsl"
#include "sh_gen_noise_util.hlsl"

RWTexture3D<float4> TexBuffer : register(u0);

#define THREAD_NUM_PER_GROUP_X 8
#define THREAD_NUM_PER_GROUP_Y 8
#define THREAD_NUM_PER_GROUP_Z 8

float4 Stackable3D_WorleyNoise3D(int3 pixel)
{
	float3 coord = float3(float(pixel.x) / (float)Res.x, float(pixel.y) / (float)Res.y, float(pixel.z) / (float)Res.z);

	// 3 octaves
	float cellCount = 2.0;
	float worleyNoise0 = (1.0f - worleyNoise3D(coord, cellCount * 1.0));
	float worleyNoise1 = (1.0f - worleyNoise3D(coord, cellCount * 2.0));
	float worleyNoise2 = (1.0f - worleyNoise3D(coord, cellCount * 4.0));
	float worleyNoise3 = (1.0f - worleyNoise3D(coord, cellCount * 8.0));
	float worleyFBM0 = worleyNoise0*0.625f + worleyNoise1*0.25f + worleyNoise2*0.125;
	float worleyFBM1 = worleyNoise1*0.625f + worleyNoise2*0.25f + worleyNoise3*0.125;
	float worleyFBM2 = worleyNoise2*0.75f + worleyNoise3*0.25; 
	// cellCount=4 -> worleyNoise4 is just noise due to sampling frequency=texel freque. So only take into account 2 frequencies for FBM

	return float4(worleyFBM0, worleyFBM1, worleyFBM2, 1.0);
}
//
[numthreads(THREAD_NUM_PER_GROUP_X, THREAD_NUM_PER_GROUP_Y, THREAD_NUM_PER_GROUP_Z)]
void GenerateWorleyNoise_High(uint3 groupID : SV_GroupID, uint3 threadID : SV_GroupThreadID)
{
	// SV_GroupThreadID = Group내에서의 ID
	// SV_GroupID = Group의 ID
	// SV_DispatchThreadID = 모든 스레드를 전개했을때 Thread ID
	// SV_GroupIndex = Group내에서의 인덱스
	uint3	CurPixel;
	CurPixel.x = groupID.x * THREAD_NUM_PER_GROUP_X + threadID.x;
	CurPixel.y = groupID.y * THREAD_NUM_PER_GROUP_Y + threadID.y;
	CurPixel.z = groupID.z * THREAD_NUM_PER_GROUP_Z + threadID.z;

	if (CurPixel.x >= Res.x || CurPixel.y >= Res.y || CurPixel.z >= Res.z)
	{
		return;
	}
	TexBuffer[CurPixel] = Stackable3D_WorleyNoise3D(CurPixel);
}
