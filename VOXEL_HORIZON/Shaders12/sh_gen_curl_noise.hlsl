#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_typedef.hlsl"
#include "sh_gen_noise_util.hlsl"
#include "sh_const_buffer_gen_tex3d.hlsl"

#define GEN_CURL_NOISE_THREAD_NUM 1024

RWTexture2D<float4> TexBuffer : register(u0);

static float perlinAmplitude = 0.5;
static float perlinFrequency = 0.8;
static float perlinScale = 100.0;
static int perlinOctaves = 4;
static float3 seed = 0.0;

float noiseInterpolation(in float2 i_coord, in float i_size)
{
	float2 grid = i_coord * i_size;

	float2 randomInput = floor(grid);
	float2 weights = frac(grid);


	float p0 = random2D(seed, randomInput);
	float p1 = random2D(seed, randomInput + float2(1.0, 0.0));
	float p2 = random2D(seed, randomInput + float2(0.0, 1.0));
	float p3 = random2D(seed, randomInput + float2(1.0, 1.0));

	weights = smoothstep(float2(0.0, 0.0), float2(1.0, 1.0), weights);

	return p0 +
		(p1 - p0) * (weights.x) +
		(p2 - p0) * (weights.y) * (1.0 - weights.x) +
		(p3 - p1) * (weights.y * weights.x);
}

float perlinNoise(float2 uv, float sc, float f, float a, int o)
{
	float noiseValue = 0.0;

	float localAplitude = a;
	float localFrecuency = f;

	for (int index = 0; index < o; index++)
	{

		noiseValue += noiseInterpolation(uv, sc * localFrecuency) * localAplitude;

		localAplitude *= 0.25;
		localFrecuency *= 3.0;
	}

	return noiseValue * noiseValue;
}

[numthreads(GEN_CURL_NOISE_THREAD_NUM, 1, 1)]
void GenerateCurlNoise(uint3 groupID : SV_GroupID, uint3 dispatchThreadId : SV_DispatchThreadID)
{
	uint	ArrayIndex = groupID.y;
	uint2	CurPixel = uint2(dispatchThreadId.x % Res.x, dispatchThreadId.x / Res.x);	// ÇöÀç ÇÈ¼¿ÀÇ ÁÂÇ¥

	uint2	DestCoord = CurPixel;
	// Skip out of bound pixels
	if (CurPixel.y >= Res.y)
		return;

	float2 uv = float2((float)CurPixel.x + 2.0, (float)CurPixel.y) / (float2)Res.xy;
	float2 suv = float2(uv.x + 5.5, uv.y + 5.5);

	float cloudType = saturate(perlinNoise(suv, perlinScale*3.0, 0.3, 0.7,10));
	float coverage = perlinNoise(uv, perlinScale * 0.95, perlinFrequency, perlinAmplitude, 4);
	TexBuffer[DestCoord] = float4(saturate(coverage), cloudType, 0, 1);
}