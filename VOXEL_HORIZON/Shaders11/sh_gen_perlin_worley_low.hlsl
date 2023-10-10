#include "sh_const_buffer_gen_tex3d.hlsl"
#include "sh_gen_noise_util.hlsl"

RWTexture3D<float4> TexBuffer : register(u0);

#define THREAD_NUM_PER_GROUP_X 8
#define THREAD_NUM_PER_GROUP_Y 8
#define THREAD_NUM_PER_GROUP_Z 8

float PerlinWorleyNoise3D(float3 pIn, float frequency, int octaveCount)
{
	float octaveFrenquencyFactor = 2.0;			// noise frequency factor between octave, forced to 2

	// Compute the sum for each octave
	float sum = 0.0;
	float weightSum = 0.0;
	float weight = 0.5;
	for (int oct = 0; oct < octaveCount; oct++)
	{
		// Perlin float3 is bugged in GLM on the Z axis :(, black stripes are visible
		// So instead we use 4d Perlin and only use xyz...
		//glm::float3 p(x * freq, y * freq, z * freq);
		//float val = glm::perlin(p, glm::float3(freq)) *0.5 + 0.5;

		float4 p = float4(pIn.x, pIn.y, pIn.z, 0.0) * float4(frequency, frequency, frequency, frequency);
		float val = glmPerlin4D(p, float4(frequency, frequency, frequency, frequency));

		sum += val * weight;
		weightSum += weight;

		weight *= weight;
		frequency *= octaveFrenquencyFactor;
	}

	float noise = (sum / weightSum);// *0.5 + 0.5;
	noise = min(noise, 1.0f);
	noise = max(noise, 0.0f);
	return noise;
}


float4 Stackable_PerlinWorleyNoise3D(int3 pixel)
{
	float frequenceMul[6] = { 2.0, 8.0, 14.0, 20.0, 26.0, 32.0 };

	float3 coord = (float3)pixel.xyz / (float3)Res.xyz;

	// Perlin FBM noise
	int octaveCount = 3;
	float frequency = 8.0;
	float perlinNoise = PerlinWorleyNoise3D(coord, frequency, octaveCount);


	// r,g 성분
	float cellCount = 4.0;
	float3 worleyNoise_0 = float3(
		1.0 - worleyNoise3D(coord, cellCount * frequenceMul[0]),
		1.0 - worleyNoise3D(coord, cellCount * frequenceMul[1]),
		1.0 - worleyNoise3D(coord, cellCount * frequenceMul[2])
		);

	// PerlinWorley noise as described p.101 of GPU Pro 7
	//float worleyFBM = rg_worleyNoise0 * 0.625f + rg_worleyNoise1 * 0.25f + rg_worleyNoise2 * 0.125;
	float worleyFBM_0 = dot(worleyNoise_0, float3(0.625, 0.25, 0.125));
	float PerlinWorleyNoise = remap(perlinNoise, 0.0, 1.0, worleyFBM_0, 1.0);

	/*

	float cellCount = 4.0;
	float worleyNoise1 = (1.0 - worleyNoise3D(coord, cellCount * 2.0));
	float worleyNoise2 = (1.0 - worleyNoise3D(coord, cellCount * 4.0));
	float worleyNoise3 = (1.0 - worleyNoise3D(coord, cellCount * 8.0));
	float worleyNoise4 = (1.0 - worleyNoise3D(coord, cellCount * 16.0));
	//float worleyNoise5 = (1.0f - Tileable3dNoise::WorleyNoise(coord, cellCount * 32));
	//cellCount=2 -> half the frequency of texel, we should not go further (with cellCount = 32 and texture size = 64)

	// Three frequency of Worley FBM noise
	float worleyFBM0 = worleyNoise1*0.625f + worleyNoise2*0.25f + worleyNoise3*0.125f;
	float worleyFBM1 = worleyNoise2*0.625f + worleyNoise3*0.25f + worleyNoise4*0.125f;
	//float worleyFBM2 = worleyNoise3*0.625f + worleyNoise4*0.25f + worleyNoise5*0.125f;
	float worleyFBM2 = worleyNoise3*0.75f + worleyNoise4*0.25f;
	*/
	// b,a 성분
	float4 worleyNoise_1 = float4(
		1.0 - worleyNoise3D(coord, cellCount * 2.0),
		1.0 - worleyNoise3D(coord, cellCount * 4.0),
		1.0 - worleyNoise3D(coord, cellCount * 8.0),
		1.0 - worleyNoise3D(coord, cellCount * 16.0));

	// Three frequency of Worley FBM noise
	//float worleyFBM0 = worleyNoise1 * 0.625f + worleyNoise2 * 0.25f + worleyNoise3 * 0.125;
	//float worleyFBM1 = worleyNoise2 * 0.625f + worleyNoise3 * 0.25f + worleyNoise4 * 0.125;
	//float worleyFBM2 = worleyNoise3*0.625f + worleyNoise4*0.25f + worleyNoise5*0.125;
	float3 worleyFBM_1 = float3(
		dot(worleyNoise_1.rgb, float3(0.625, 0.25, 0.125)),
		dot(worleyNoise_1.gba, float3(0.625, 0.25, 0.125)),
		dot(worleyNoise_1.ba, float2(0.75, 0.25))
		);



	//return float4(PerlinWorleyNoise * PerlinWorleyNoise, worleyFBM_1.r, worleyFBM_1.g, worleyFBM_1.b);
	return float4(PerlinWorleyNoise * PerlinWorleyNoise, worleyFBM_1.r, worleyFBM_1.g, worleyFBM_1.b);
	
}


[numthreads(THREAD_NUM_PER_GROUP_X, THREAD_NUM_PER_GROUP_Y, THREAD_NUM_PER_GROUP_Z)]
void GeneratePerlinWorleyNoise_LowFrequecy(uint3 groupID : SV_GroupID, uint3 threadID : SV_GroupThreadID)
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
	TexBuffer[CurPixel] = Stackable_PerlinWorleyNoise3D(CurPixel);
	//TexBuffer[CurPixel] = float4((float)(groupID.x * 8) / 255, (float)(groupID.y * 8) / 255, (float)(groupID.z * 8) / 255, 1);
}
