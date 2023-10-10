#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_constant_buffer_default.hlsl"


Texture2D		texHeightMap		: register(t0);	// for vs
Texture2D		texDiffuse			: register(t1);	// for ps
SamplerState	samplerLinearWrap	: register(s0);


cbuffer ConstantBufferParticle : register(b1)
{
	float	BoxHeight;		// ��ƼŬ �ڽ������� ����
	float	RcpBoxHeight;	// 1 / ��ƼŬ �ڽ��� ����
	float	ParticleSize;	// ��ƼŬ ������ cm
	float	VelAdjPerObj;

	float	CurSec;
	float	ParticleReserved0;
	float	ParticleReserved1;
	float	ParticleReserved2;

	float4x4	matProjExt;

}

struct VS_INPUT_XYZW
{
	float4	Pos	    : POSITION;
	uint    instId  : SV_InstanceID;
};

struct GS_INPUT_PARTICLE
{
	float4		Pos			: SV_POSITION;
	float		Size : TEXCOORD0;
	float		h_v : TEXCOORD1;	// Texel of HeightMap - Height of Vertex
	uint		ArrayIndex	: BLENDINDICES;
};

struct PS_INPUT_PARTICLE
{
	float4	Pos					: SV_POSITION;
	float2	TexCoordDiffuse		: TEXCOORD0;
};

struct GS_OUTPUT_PARTICLE : PS_INPUT_PARTICLE
{
	uint RTVIndex : SV_RenderTargetArrayIndex;
};

GS_INPUT_PARTICLE vsSnow(VS_INPUT_XYZW input)
{
	GS_INPUT_PARTICLE	output = (GS_INPUT_PARTICLE)0;

	uint	ArrayIndex = input.instId % 2;

	// ��¹��ؽ�
	float4	PosLocal = float4(input.Pos.xyz, 1);
	float	vel_per_obj = input.Pos.w;
	float	vel_adj = vel_per_obj + VelAdjPerObj;// ������Ʈ�� �ӵ� ������� ����
	float	mov_adj = vel_adj*CurSec;				// �ӵ��� ���� ����
	float	y_pos_rel = frac((input.Pos.y + mov_adj) * RcpBoxHeight);	// 0 - 1������ y�� �����ǥ
	PosLocal.y = y_pos_rel * BoxHeight;

	float4	PosWorld = mul(PosLocal, g_TrCommon.matWorld);

	// CRenderTexture���� Proj��Ʈ������ ���� ��� -1 - 1 ������ ���� 0 - 1 ���̷� ���ߵ��� ��Ʈ���� ������ �Ǿ������Ƿ� �ڵ忡�� ���� �ʿ䰡 ����.
	// ps�� �ƴ� vs���� w�� ������ tex coord�� ���� ���� ������ ������ ���ʿ� ���������� orthogonal�̾��� �����̴�.
	float4	PosHeightView = mul(PosWorld, matProjExt);
	float4	TexCoordHeightMap = PosHeightView.xyzw / PosHeightView.w;

	//float	height_map = texHeightMap.Gather(samplerLinearWrap,TexCoordHeightMap.xy);
	float4	height_map = texHeightMap.SampleLevel(samplerLinearWrap, TexCoordHeightMap.xy, 0);
	output.h_v = height_map.r - TexCoordHeightMap.z;

	output.Size = ParticleSize;
	output.Pos = PosWorld;
	output.ArrayIndex = ArrayIndex;

	return output;
}

[maxvertexcount(6)]
void gsParticle(point GS_INPUT_PARTICLE input[1], inout TriangleStream <GS_OUTPUT_PARTICLE> TriStream)
{
	GS_OUTPUT_PARTICLE	output = (GS_OUTPUT_PARTICLE)0;

	//float	size = 50.0f;

	if (input[0].h_v < 0.0f)
		return;

	float	size = input[0].Size;

	float4	ViewPos = mul(input[0].Pos, g_Camera.matViewArray[input[0].ArrayIndex]);

	float4	ViewRect[4];
	ViewRect[0] = ViewPos + float4(-size, size, 0, 0);
	ViewRect[1] = ViewPos + float4(size, size, 0, 0);
	ViewRect[2] = ViewPos + float4(size, -size, 0, 0);
	ViewRect[3] = ViewPos + float4(-size, -size, 0, 0);

	float4	ProjRect[4];
	for (uint i = 0; i < 4; i++)
	{
		ProjRect[i] = mul(ViewRect[i], g_Camera.matProjArray[input[0].ArrayIndex]);
	}

	float2	texCoord[4] = { 0,1, 1,1, 1,0, 0,0 };


	//output.PosWorld = mul(ViewRect[0],matViewInv);	�̷��� �ϸ� ������ǥ�� ���� �� �ִ�. view����� �����ϱ� �����Ƽ� �ϴ� ���� ����
	// �ﰢ�� 0
	output.Pos = ProjRect[0];
	output.TexCoordDiffuse = texCoord[0];
	output.RTVIndex = input[0].ArrayIndex;

	TriStream.Append(output);

	output.Pos = ProjRect[1];
	output.TexCoordDiffuse = texCoord[1];
	output.RTVIndex = input[0].ArrayIndex;

	TriStream.Append(output);

	output.Pos = ProjRect[2];
	output.TexCoordDiffuse = texCoord[2];
	output.RTVIndex = input[0].ArrayIndex;

	TriStream.Append(output);

	TriStream.RestartStrip();

	// �ﰢ�� 1
	output.Pos = ProjRect[0];
	output.TexCoordDiffuse = texCoord[0];
	output.RTVIndex = input[0].ArrayIndex;

	TriStream.Append(output);

	output.Pos = ProjRect[2];
	output.TexCoordDiffuse = texCoord[2];
	output.RTVIndex = input[0].ArrayIndex;

	TriStream.Append(output);

	output.Pos = ProjRect[3];
	output.TexCoordDiffuse = texCoord[3];
	output.RTVIndex = input[0].ArrayIndex;
	TriStream.Append(output);

	TriStream.RestartStrip();

}
float4 psParticle(PS_INPUT_PARTICLE input) : SV_Target
{

	float4	texColor = texDiffuse.Sample(samplerLinearWrap, input.TexCoordDiffuse);
	//float4	height = texHeightMap.Sample( samplerLinearWrap, input.TexCoordHeightMap.xy);
	//float4	height = texHeightMap.Gather(samplerLinearWrap,input.TexCoordHeightMap.xy);



	//clip(height.r - input.TexCoordHeightMap.z);

	return texColor;
}
