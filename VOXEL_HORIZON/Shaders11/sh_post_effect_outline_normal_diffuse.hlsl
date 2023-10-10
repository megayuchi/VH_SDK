#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_post_effect_common.hlsl"

#ifdef STEREO_RENDER
Texture2DArray	texNormal		: register(t0);
Texture2DArray	texDiffuse		: register(t1);
#else
Texture2D		texNormal		: register(t0);
Texture2D		texDiffuse		: register(t1);

#endif
/*
#define		DEFAULT_ID		0.025f
#define		WATER_ID		0.025f
#define		DYNAMIC_ID		0.0275f
#define		HFIELD_ID		0.200f
#define		LMMESH_ID		0.225f
#define		SKY_ID			0.75f
*/

static const int2	Offset[8] =
{
	-1,-1,	// left-top
	0,-1,	// mid-top
	1,-1,	// right-top

	-1,0,	// left-mid
	1,0,		// right-mid

	-1,+1,	// left-bottom
	0,+1,	// mid-bottom
	+1,+1	// right-bottom
};
static const float3	bwConst = float3(0.3f, 0.59f, 0.11f);

float4 ps9SampleLaplacian(PS_INPUT input) : SV_Target
{

	float	ThickConst = 1.0f;

// 가운데 점(1픽셀)
#ifdef STEREO_RENDER
	int4	location = int4(input.Position.xy, input.ArrayIndex, 0);
#else
	int3	location = int3(input.Position.xy, 0);
#endif

	// Load normal.xyz | Dist
	float4	NormalCenter = texNormal.Load(location);	// normal.xyz
	float4	DiffuseCenter = texDiffuse.Load(location);	// Diffuse
	uint	Prop = (uint)(NormalCenter.a * 255.0 + ADJ_RCP_256);
	NormalCenter.a = 0.0;
	
	uint ChrTypeCount = (GetType(Prop) == MAP_OBJECT_TYPE_CHARACTER);

	uint EnabledOutLineCount = IsEnabledOutLine(Prop);
	float4	NormalSideSum = 0;
	float4	DiffuseSideSum = 0;

	// 주변 점(8픽셀)의 합
	for (int i = 0; i < 8; i++)
	{
#ifdef STEREO_RENDER
		int4	sideLocation = int4(location.xy + Offset[i].xy, input.ArrayIndex, 0);
#else
		int3	sideLocation = int3(location.xy + Offset[i].xy, 0);
#endif

		// load normal.xyz | Property
		float4	NormalSide = texNormal.Load(sideLocation);			// normal.xyz
		float4	DiffuseSide = texDiffuse.Load(sideLocation);
		uint	PropSide = (uint)(NormalSide.a * 255.0 + ADJ_RCP_256);
		NormalSide.a = 0.0;
		NormalSideSum += NormalSide;
		DiffuseSideSum += DiffuseSide;

		ChrTypeCount += (GetType(PropSide) == MAP_OBJECT_TYPE_CHARACTER);

		EnabledOutLineCount += IsEnabledOutLine(PropSide);
	}

	//if (ID_Sum > LMMESH_ID * 8 + HFIELD_ID)
	//{
	//	// 100% 지형으로만 구성된 경우 잔선이 보이지 않게 하기 위해서 다음과 같이 처리한다.
	//	NormalCenter.a = NormalCenter.a*50.0f;
	//	NormalSideSum.a = NormalSideSum.a*50.0f;
	//	weight = float4(0,0,0,1);
	//}
	float	OutLineColor = float4(1, 1, 1, 1);
	if (0 != EnabledOutLineCount)
	{
		if (0 != ChrTypeCount)
		{
			ThickConst = 0.40f;
		}

		// 라플라시안 필터 처리
		float3	DiffNormal = (NormalCenter.rgb*8.0f - NormalSideSum.rgb);
		DiffNormal *= DiffNormal;	// 제곱으로 부호를 +로

		// diffuse 컬러값 차이
		float3	DiffDiffuse = (DiffuseCenter.rgb*8.0f - DiffuseSideSum.rgb);
		//DiffDiffuse = abs(DiffDiffuse);
		DiffDiffuse *= DiffDiffuse;
		//DiffDiffuse *= DiffDiffuse;
		//DiffDiffuse *= 0.4;
		
		
		//DiffDiffuse = DiffDiffuse * DiffDiffuse * 0.35;// 제곱으로 부호를 +로, 상수 weight는 0.5
		
		//float3	LaplColor = max(DiffNormal.rgb, DiffDiffuse.rgb) * ThickConst;
		//float3	LaplColor = saturate(DiffNormal.rgb + DiffDiffuse.rgb) * ThickConst;
		//float3	LaplColor = DiffNormal.rgb * ThickConst;
		float3	LaplColor = lerp(DiffNormal.rgb, DiffDiffuse.rgb, 0.25) * ThickConst;

		// 컬러값을 반전시킨다.r0 = 0이면 아웃라인 처리 안함.
		float3	InvLaplColor = 1.0f - LaplColor;

		// 흑백으로 변환
		OutLineColor = dot(InvLaplColor, bwConst);
	}
	// 최종아웃라인컬러(흑백컬러, 깊이값,0,0)
	float4	outColor = float4(OutLineColor,0,0,0);

	return outColor;
}
