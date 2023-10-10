#define MAX_COUNT_PIXEL_THREAD_NUM_X	16
#define MAX_COUNT_PIXEL_THREAD_NUM_Y	16



cbuffer CONSTANT_BUFFER_PIXEL_COUNT : register(b0)
{
	uint		Width;
	uint		Height;
	uint		Reserved0;
	uint		Reserved1;
};
struct CUBEMAP_PIXEL_COUNT
{
	uint		RedPixels;
	uint		BluePixels;
	uint		Reserved0;
	uint		Reserved1;

};
Texture2DArray	 cubeMap			: register(t0);

// Is Visible 1 (Visible) 0 (Culled)
RWStructuredBuffer<CUBEMAP_PIXEL_COUNT> BufferOut : register(u0);

SamplerState PointSampler : register(s0);


groupshared uint g_RedPixelCount[6];
groupshared uint g_BluePixelCount[6];

[numthreads(MAX_COUNT_PIXEL_THREAD_NUM_X, MAX_COUNT_PIXEL_THREAD_NUM_Y, 1)]
void csCountPixel(uint3 GroupId			 : SV_GroupID,
	uint3 GroupThreadID : SV_GroupThreadID,
	uint3 DispatchThreadId : SV_DispatchThreadID,
	uint GroupIndex : SV_GroupIndex)
{
	// SV_GroupIndex - �׷� �ȿ����� ���� �ε���
	// SV_DispatchThreadID - �׷� �ȿ����� ������ �ε���(x,y,z)
	// SV_GroupThreadID - �׷� �ȿ����� ������ �ε���
	// SV_GroupID - �׷� x,y,z�ε���


	uint	sx = DispatchThreadId.x;
	uint	sy = DispatchThreadId.y;
	uint	f = GroupId.z;

	uint	oldValue;
	if (DispatchThreadId.x == 0 && DispatchThreadId.y == 0)
	{
		BufferOut[f].BluePixels = 0;
		BufferOut[f].RedPixels = 0;
	}


	if (GroupThreadID.x == 0 && GroupThreadID.y == 0)
	{
		g_RedPixelCount[f] = 0;
		g_BluePixelCount[f] = 0;
	}
	GroupMemoryBarrierWithGroupSync();
	DeviceMemoryBarrierWithGroupSync();

	//g_RedPixelCount[f]++;
	//g_BluePixelCount[f]++;

	uint	oldRedPixelCount, oldBluePixelCount;
	if (sx < Width && sy < Height)
	{
		// get integer pixel coordinates
		// u, v, array index, mip-level
		uint4	nCoords = uint4(sx, sy, f, 0);
		float4	color = cubeMap.Load(nCoords);

		uint	r = (color.r > 0.5);
		uint	b = (color.b > 0.5);

		InterlockedAdd(g_RedPixelCount[f], r, oldValue);
		InterlockedAdd(g_BluePixelCount[f], b, oldValue);
	}
	GroupMemoryBarrierWithGroupSync();



	if (GroupThreadID.x == 0 && GroupThreadID.y == 0)
	{

		InterlockedAdd(BufferOut[f].RedPixels, g_RedPixelCount[f], oldValue);
		InterlockedAdd(BufferOut[f].BluePixels, g_BluePixelCount[f], oldValue);


		//BufferOut[f].RedPixels = f;
		//BufferOut[f].BluePixels = f;
//		InterlockedAdd(BufferOut[GroupIndex].BluePixels,1,oldBluePixelCount);
//		InterlockedAdd(BufferOut[GroupIndex].RedPixels,1,oldRedPixelCount);

	}
}