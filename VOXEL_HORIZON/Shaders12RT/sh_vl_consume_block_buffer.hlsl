
//#define LIGHTING_TYPE	0	//(vlmesh에서 LIGHTING_TYPE이 0인 경우는 없다.)
#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_dynamic_common.hlsl"
#include "sh_constant_buffer_default.hlsl"
#include "sh_att_light.hlsl"
#include "sh_block_common.hlsl"

Texture3D<uint> texBlocks : register(t0);


struct PS_INPUT_BLOCK
{
    float4 Pos : SV_POSITION;
    float2 TexCoord : TEXCOORD0;
    float4 PosWorld : TEXCOORD1;
    float Clip : SV_ClipDistance;
    float Dist : TEXCOORD2;
    float4 Diffuse : COLOR0;
    float4 NormalColor : COLOR1;
};
/*
matrix		matOrtho[3];	//0 == xy, 1 == zy , 2 == xz
	int			BlockWidth;
	int			BlockHeight;
	int			BlockDepth;
	float		BlockSize;
	float4		PosForBlock;
	float4		MinPosForBlock;
	int3		BlockTexStartPos;
	
	*/
GS_INPUT_BLOCK vsDefault(VS_INPUT_VL input)
{
    GS_INPUT_BLOCK output = (GS_INPUT_BLOCK)0;
	// 출력버텍스
    float half_block_size = BlockSize * 0.5;

	//v4MinPosForBlock
	//output.Pos = input.Pos;
    output.Pos.x = MinPosForBlock.x + (float)input.Pos.x * BlockSize + half_block_size;
    output.Pos.y = MinPosForBlock.y + (float)input.Pos.y * BlockSize + half_block_size;
    output.Pos.z = MinPosForBlock.z + (float)input.Pos.z * BlockSize + half_block_size;

    output.Normal = input.Normal;

    return output;
}


[maxvertexcount(36)]
void gsDVertexToBlock(point GS_INPUT_BLOCK input[1], inout TriangleStream<PS_INPUT_BLOCK> TriStream)
{
    PS_INPUT_BLOCK output = (PS_INPUT_BLOCK)0;

	//
	// input[0].Pos <- 0 base,  local 좌표
	//
    float half_block_size = BlockSize * 0.5;
    float3 SpaceSize = float3((float)BlockWidth * BlockSize, (float)BlockHeight * BlockSize, (float)BlockDepth * BlockSize);
    float3 rel_coord = input[0].Normal;
    int4 block_tex_coord = int4((int)(rel_coord.x * (float)BlockWidth), (int)(rel_coord.y * (float)BlockHeight), (int)(rel_coord.z * (float)BlockDepth), 0);

    block_tex_coord.xyz += BlockTexStartPos;
    uint packedColor = texBlocks.Load(block_tex_coord).r;
	/*
	uint side_color[6];
	side_color[0] = texBlocks.Load(block_tex_coord+int4(1, 0, 0, 0)).r;
	side_color[1] = texBlocks.Load(block_tex_coord+int4(-1, 0, 0, 0)).r;
	side_color[2] = texBlocks.Load(block_tex_coord+int4(0, 1, 0, 0)).r;
	side_color[3] = texBlocks.Load(block_tex_coord+int4(0, -1, 0, 0)).r;
	side_color[4] = texBlocks.Load(block_tex_coord+int4(0, 0, 1, 0)).r;
	side_color[5] = texBlocks.Load(block_tex_coord+int4(0, 0, -1, 0)).r;

	uint side_count = 0;
	for (uint i = 0; i<6; i++)
	{
		if (((side_color[i] & 0xff000000) >> 24) > 0)
		{
			side_count++;
		}
	}
	if (side_count >= 6)
	{
		return;
	}
	*/
    float bw = (float)((packedColor & 0xff000000) >> 24) / 255.0;
    float g = (float)((packedColor & 0x00ff0000) >> 16) / 255.0;
    float r = (float)((packedColor & 0x0000ff00) >> 8) / 255.0;
    float b = (float)(packedColor & 0x000000ff) / 255.0;

    float4 BlockTexColor = float4(r, g, b, bw);
    if (BlockTexColor.a < 0.0001)
        return;

    float4 WorldVertexPos = float4(input[0].Pos.xyz + PosForBlock.xyz, 1);
	//float4	WorldVertexPos = float4(input[0].Pos.xyz + float3(0, 0, 0), 1);

    uint Index[36] =
    {
		// +z
        3, 0, 1,
		3, 1, 2,

		// -z
		4, 7, 6,
		4, 6, 5,

		// -x
		0, 4, 5,
		0, 5, 1,

		// +x
		7, 3, 2,
		7, 2, 6,

		// +y
		0, 3, 7,
		0, 7, 4,

		// -y
		2, 1, 5,
		2, 5, 6
    };
	
    float3 NormalList[6] =
    {
        0, 0, 1, // +z
		0, 0, -1, // -z
		-1, 0, 0, // -x
		1, 0, 0, // +x
		0, 1, 0, // +y
		0, -1, 0 // -y
    };
    float3 WorldPos[8];
    WorldPos[0] = WorldVertexPos.xyz + float3(-half_block_size, half_block_size, half_block_size);
    WorldPos[1] = WorldVertexPos.xyz + float3(-half_block_size, -half_block_size, half_block_size);
    WorldPos[2] = WorldVertexPos.xyz + float3(half_block_size, -half_block_size, half_block_size);
    WorldPos[3] = WorldVertexPos.xyz + float3(half_block_size, half_block_size, half_block_size);
    WorldPos[4] = WorldVertexPos.xyz + float3(-half_block_size, half_block_size, -half_block_size);
    WorldPos[5] = WorldVertexPos.xyz + float3(-half_block_size, -half_block_size, -half_block_size);
    WorldPos[6] = WorldVertexPos.xyz + float3(half_block_size, -half_block_size, -half_block_size);
    WorldPos[7] = WorldVertexPos.xyz + float3(half_block_size, half_block_size, -half_block_size);

    uint VertexIndex = 0;
    for (uint i = 0; i < 6; i++)
    {
        float3 N = NormalList[i];
		// N*L계산
        float cosang = dot(N, (float3)(-LightDir));
        float L = cosang * 0.5 + 0.5;
        float4 Diffuse = float4(L * BlockTexColor.rgb, BlockAlpha);

        float DotShadow = dot(N, (float3)ShadowLightDirInv);
        if (DotShadow <= 0)
        {
            DotShadow = 0;
        }
		
        for (uint j = 0; j < 2; j++)
        {
            for (uint k = 0; k < 3; k++)
            {
                float4 PosWorld = float4(WorldPos[Index[VertexIndex]], 1);
                output.PosWorld = PosWorld;
                output.Pos = mul(PosWorld, g_Camera.matViewProjCommon);
                output.Dist = output.Pos.w;
                output.Clip = dot(PosWorld, ClipPlane); // 클립플레인처리
                output.Diffuse = Diffuse;
                output.NormalColor.rgb = (N * 0.5f) + 0.5f;
                output.NormalColor.a = 1;
                TriStream.Append(output);
                VertexIndex++;
            }
            TriStream.RestartStrip();
        }
    }
}


PS_TARGET psDefault(PS_INPUT_BLOCK input)
{
    PS_TARGET OutColor = (PS_TARGET)0;

    uint ElementID = 255;
    uint Prop = SetShadowWeight(Property, 0); // texShadowMask에서 샘플링한 shadow mask와 다른 프로퍼티.머리카락에 얼굴에 그림자 지는걸 방지한다든가...CB로부터 입력
    float4 NormalColor = float4(input.NormalColor.xyz, (float)Prop / 255.0);
    float4 ElementColor = float4((float)ElementID / 255.0, 0, (float)g_TrCommon.ShadingType / 255.0, 0);

    OutColor.Color0 = input.Diffuse;
    OutColor.Color1 = NormalColor;
    OutColor.Color2 = ElementColor;
    return OutColor;
}

