#define	MAX_ZTEST_THREAD_NUM	256

cbuffer CONSTANT_BUFFER_AABB_Z_TEST : register(b0)
{
	matrix		matViewProjList[6];
	uint		Width;
	uint		Height;
	float		WidthAdj;
	float		HeightAdj;
	float		OffsetX;
	float		OffsetY;
	uint		AABBNum;
	uint		Reserved0;
};

struct AABB_FLOAT4
{
	float4	Min;
	float4	Max;
};

struct AABB_Z_TEST_RESULT
{
	float4	Min;
	float4	Max;
	int		Visible;
	float	buffer_depth;
	float	WidthAdj;
	float	HeightAdj;
	float4	v[8];
	int		sx;
	int		sy;
	int		Reerved0;
	int		Reerved1;
};

StructuredBuffer<AABB_FLOAT4>	AABBList    : register(t0);
Texture2DArray<float>			DepthMap	: register(t1);

RWStructuredBuffer<AABB_Z_TEST_RESULT>	ResultList	: register(u0);

SamplerState PointSampler : register(s0);


void MakeBoxWithAABB(out float4	v[8], float4 Min, float4 Max);

[numthreads(MAX_ZTEST_THREAD_NUM, 1, 1)]
void csAABB_Z_Test(uint3 GroupId		 : SV_GroupID,
	uint3 GroupThreadID : SV_GroupThreadID,
	uint3 DispatchThreadId : SV_DispatchThreadID,
	uint GroupIndex : SV_GroupIndex)
{

	uint	ThreadIndex = DispatchThreadId.x;

	float4	v[8];

	int		Visible = 0;
	float	buffer_depth = 0;
	int		sx;
	int		sy;

	if (ThreadIndex < AABBNum)
	{
		MakeBoxWithAABB(v, AABBList[ThreadIndex].Min, AABBList[ThreadIndex].Max);

		for (uint f = 0; f < 6; f++)
		{
			for (uint i = 0; i < 8; i++)
			{
				//TransformVector4_VPTR2(v_prj,v,pMatViewProjList+i,dwVertexNum);
				float4	v_prj = mul(v[i], matViewProjList[f]);
				if (v_prj.w == 0.0f)
				{
					v_prj.w = 0.000001f;
				}
				float	rhw = 1.0f / v_prj.w;
				if (v_prj.x < -1.0f)
					continue;

				if (v_prj.x > 1.0f)
					continue;

				if (v_prj.y < -1.0f)
					continue;

				if (v_prj.y > 1.0f)
					continue;

				if (v_prj.z < 0.0f)
					continue;


				float	x = 0.5f*v_prj.x + 0.5f;
				float	y = -0.5f*v_prj.y + 0.5f;

				x = x * WidthAdj + OffsetX;
				y = y * HeightAdj + OffsetY;

				sx = (int)((float)Width*x);
				sy = (int)((float)Height*y);

				sx = max(0, sx);
				sx = min(Width - 1, sx);

				sy = max(0, sy);
				sy = min(Height - 1, sy);

				uint4	nCoords = uint4(sx, sy, f, 0);
				float4	texel = DepthMap.Load(nCoords);
				buffer_depth = texel.r;

				if (v_prj.z < buffer_depth)
				{
					Visible = 1;
					f = 6;	// 루프 빠져나간다.
					break;
				}
			}
		}
		ResultList[ThreadIndex].Min = AABBList[ThreadIndex].Min;
		ResultList[ThreadIndex].Max = AABBList[ThreadIndex].Max;
		ResultList[ThreadIndex].Visible = Visible;
		ResultList[ThreadIndex].buffer_depth = buffer_depth;
		ResultList[ThreadIndex].WidthAdj = WidthAdj;
		ResultList[ThreadIndex].HeightAdj = HeightAdj;
		ResultList[ThreadIndex].sx = sx;
		ResultList[ThreadIndex].sy = sy;
		for (uint i = 0; i < 8; i++)
		{
			ResultList[ThreadIndex].v[i] = v[i];
		}

	}
}

void MakeBoxWithAABB(out float4	v[8], float4 Min, float4 Max)
{

	float	min_x = Min.x;
	float	min_y = Min.y;
	float	min_z = Min.z;

	float	max_x = Max.x;
	float	max_y = Max.y;
	float	max_z = Max.z;

	v[0].x = min_x;
	v[0].y = max_y;
	v[0].z = max_z;
	v[0].w = 1.0f;

	v[1].x = min_x;
	v[1].y = min_y;
	v[1].z = max_z;
	v[1].w = 1.0f;

	v[2].x = max_x;
	v[2].y = min_y;
	v[2].z = max_z;
	v[2].w = 1.0f;

	v[3].x = max_x;
	v[3].y = max_y;
	v[3].z = max_z;
	v[3].w = 1.0f;

	v[4].x = min_x;
	v[4].y = max_y;
	v[4].z = min_z;
	v[4].w = 1.0f;

	v[5].x = min_x;
	v[5].y = min_y;
	v[5].z = min_z;
	v[5].w = 1.0f;

	v[6].x = max_x;
	v[6].y = min_y;
	v[6].z = min_z;
	v[6].w = 1.0f;

	v[7].x = max_x;
	v[7].y = max_y;
	v[7].z = min_z;
	v[7].w = 1.0f;
}
