#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_post_effect_common.hlsl"

#ifdef STEREO_RENDER
Texture2DArray	texNormal		: register(t0);
Texture2DArray	texDepth		: register(t1);
#else
Texture2D		texNormal		: register(t0);
Texture2D		texDepth		: register(t1);

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
static const float4	weight = float4(0.2, 0.2, 0.2, 0.4);

float4 ps9SampleLaplacian(PS_INPUT input) : SV_Target
{

	float	ThickConst = 1.0f;

// ��� ��(1�ȼ�)
#ifdef STEREO_RENDER
	int4	location = int4(input.Position.xy, input.ArrayIndex, 0);
#else
	int3	location = int3(input.Position.xy, 0);
#endif

	// Load normal.xyz | Dist
	float4	NormalCenter = texNormal.Load(location);	// normal.xyz
	uint	Prop = (uint)(NormalCenter.a * 255.0 + ADJ_RCP_256);

	float	Depth = texDepth.Load(location).r;			// depth
	float	linearDepth = DecompProj[input.ArrayIndex].m43 / (Depth - DecompProj[input.ArrayIndex].m33);
	NormalCenter.a = linearDepth * ProjConst.fFarRcp;	// NormalCenter = normal.xyz | Dist(0-1)




	//if (ID_Center.g <= DYNAMIC_ID)
	//{
	//	ThickConst = 0.40f;
	//}

	uint ChrTypeCount = (GetType(Prop) == MAP_OBJECT_TYPE_CHARACTER);

	uint EnabledOutLineCount = IsEnabledOutLine(Prop);
	float4	NormalSideSum = 0;



	// �ֺ� ��(8�ȼ�)�� ��
	for (int i = 0; i < 8; i++)
	{
#ifdef STEREO_RENDER
		int4	sideLocation = int4(location.xy + Offset[i].xy, input.ArrayIndex, 0);
#else
		int3	sideLocation = int3(location.xy + Offset[i].xy, 0);
#endif

		// load normal.xyz | Property
		float4	NormalSide = texNormal.Load(sideLocation);			// normal.xyz
		uint	PropSide = (uint)(NormalSide.a * 255.0 + ADJ_RCP_256);

		float	DepthSide = texDepth.Load(sideLocation).r;			// depth 
		float	linearDepthSide = DecompProj[input.ArrayIndex].m43 / (DepthSide - DecompProj[input.ArrayIndex].m33);	// near - far
		NormalSide.a = linearDepthSide * ProjConst.fFarRcp;			// NormalSide = normal.xyz | Dist(0-1)

		NormalSideSum += NormalSide;


		ChrTypeCount += (GetType(PropSide) == MAP_OBJECT_TYPE_CHARACTER);

		EnabledOutLineCount += IsEnabledOutLine(PropSide);
	}

	//if (ID_Sum > LMMESH_ID * 8 + HFIELD_ID)
	//{
	//	// 100% �������θ� ������ ��� �ܼ��� ������ �ʰ� �ϱ� ���ؼ� ������ ���� ó���Ѵ�.
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

		// ���ö�þ� ���� ó��
		float4	LaplColor = (NormalCenter*8.0f - NormalSideSum);

		// ����
		LaplColor *= LaplColor;

		LaplColor.rgb *= ThickConst;
		// �÷����� ������Ų��.r0 = 0�̸� �ƿ����� ó�� ����.
		float4	InvLaplColor = 1.0f - LaplColor;

		// ������� ��ȯ
		OutLineColor = dot(InvLaplColor, weight);
	}
	// �����ƿ������÷�(����÷�, ���̰�,0,0)
	float4	outColor = float4(OutLineColor,0,0,0);

	return outColor;
}
