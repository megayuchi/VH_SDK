#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_constant_buffer_default.hlsl"


Texture2D		texHeightMap		: register(t0);	// for vs
Texture2D		texDiffuse			: register(t1);	// for ps
SamplerState	samplerLinearWrap	: register(s0);


cbuffer ConstantBufferParticle : register(b1)
{
	float	BoxHeight;		// 파티클 박스에서의 높이
	float	RcpBoxHeight;	// 1 / 파티클 박스의 높이
	float	ParticleSize;	// 파티클 사이즈 cm
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

	// 출력버텍스
	float4	PosLocal = float4(input.Pos.xyz, 1);
	float	vel_per_obj = input.Pos.w;
	float	vel_adj = vel_per_obj + VelAdjPerObj;// 오브젝트당 속도 조절계수 적용
	float	mov_adj = vel_adj*CurSec;				// 속도로 인한 변량
	float	y_pos_rel = frac((input.Pos.y + mov_adj) * RcpBoxHeight);	// 0 - 1사이의 y축 상대좌표
	PosLocal.y = y_pos_rel * BoxHeight;

	float4	PosWorld = mul(PosLocal, g_TrCommon.matWorld);

	// CRenderTexture에서 Proj매트릭스를 얻을 경우 -1 - 1 사이의 값을 0 - 1 사이로 맞추도록 매트릭스 설정이 되어있으므로 코드에서 맞출 필요가 없다.
	// ps가 아닌 vs에서 w로 나눠서 tex coord로 쓰는 것이 가능한 이유는 애초에 프로젝션이 orthogonal이었기 때문이다.
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


	//output.PosWorld = mul(ViewRect[0],matViewInv);	이렇게 하면 월드좌표는 구할 수 있다. view역행렬 전달하기 귀찮아서 일단 구현 안함
	// 삼각형 0
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

	// 삼각형 1
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
