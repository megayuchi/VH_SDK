
//#define LIGHTING_TYPE	0	//(vlmesh���� LIGHTING_TYPE�� 0�� ���� ����.)
#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_dynamic_common.hlsl"
#include "sh_constant_buffer_default.hlsl"
#include "sh_att_light.hlsl"
#include "sh_block_common.hlsl"

// for NvExt ///////////////////////////////////////////////////////////////////////////////
#define NV_SHADER_EXTN_SLOT u6

// On DirectX12 and Shader Model 5.1, you can also define the register space for that UAV.
//#define NV_SHADER_EXTN_REGISTER_SPACE space0

// Include the header - note that the UAV slot has to be declared before including it.
#include "nvHLSLExtns.h"
////////////////////////////////////////////////////////////////////////////////////////////

//RWTexture3D<unorm float4> BlockedBuffer : register(u7); // W
RWTexture3D<uint> BlockedBuffer : register(u7); // W


#if (1 == SHADER_PARAMETER_PHYSIQUE)
#define VS_INPUT	VS_INPUT_VL_PHYSIQUE
#else
#define VS_INPUT	VS_INPUT_VL
#endif


VS_OUTPUT vsWriteToBlockBuffer(VS_INPUT input)
{
    VS_OUTPUT output = (VS_OUTPUT)0;

    float3 PosLocal;
    float3 NormalLocal;
    float3 TangentLocal;

#if (1 == SHADER_PARAMETER_PHYSIQUE)
	PosLocal = vsCalcBlendPos(input.Pos, input.BlendIndex, input.BlendWeight);	// ������ ������������ ���
	NormalLocal = vsCalcBlendNormal(input.Normal, input.BlendIndex, input.BlendWeight);// ������ ���ó���� ���.
	TangentLocal = vsCalcBlendNormal(input.Tangent.xyz, input.BlendIndex, input.BlendWeight);// ������ ź��Ʈ�� ���.
#else
    PosLocal = (float3)input.Pos;
    NormalLocal = input.Normal;
    TangentLocal = input.Tangent.xyz;
#endif
    float4 PosWorld = mul(float4(PosLocal, 1), g_TrCommon.matWorld); // ������������� ���ؽ� ��ǥ
    output.Normal = normalize(mul(NormalLocal, (float3x3)g_TrCommon.matWorld)); // ����������� �븻
    output.Tangent = normalize(mul(TangentLocal, (float3x3)g_TrCommon.matWorld)); // ����������� ź��Ʈ
	
	//output.Pos = mul(PosWorld, matOrtho[0]);	// �������ǵ� ��ǥ.
    output.PosWorld = PosWorld; // ���� ��ǥ
    output.Clip = dot(PosWorld, ClipPlane); // Ŭ���÷���ó��
    output.TexCoordDiffuse = input.TexCoord;
    output.Diffuse = float4(1, 1, 1, 1);

    uint Property = asuint(input.Tangent.w);
	//float ElementColor = (float)((Property & 0x000000ff)) / 255.0;
	//Diffuse = float4(ElementColor, ElementColor, ElementColor, 1);
    output.Property = Property;


#if (1 == SHADER_PARAMETER_ATT_LIGHT)
	// ���̳��� ����Ʈ�� �ִ� ���
	for (int i = 0; i < iAttLightNum; i++)
	{
		float3		LightVec = normalize((AttLight[i].Pos.xyz - PosWorld.xyz));
		output.NdotL[i] = dot(NormalWorld, LightVec);
	}
#endif
    output.Dist = output.Pos.w;
    output.ArrayIndex = input.instId;

    return output;
}
[maxvertexcount(9)]
void gsWriteToBlockBuffer(triangle VS_OUTPUT input[3], inout TriangleStream<GS_OUTPUT_VP> TriStream)
{
    GS_OUTPUT_VP output = (GS_OUTPUT_VP)0;

    for (uint f = 0; f < 3; f++)
    {
        for (uint i = 0; i < 3; i++)
        {
            output.Pos = mul(input[i].PosWorld, matOrtho[f]);
            output.Diffuse = input[i].Diffuse;
            output.Normal = input[i].Normal;
            output.Tangent = input[i].Tangent;
            output.TexCoordDiffuse = input[i].TexCoordDiffuse;
            output.PosWorld = input[i].PosWorld;
            output.Dist = input[i].Dist;
            output.Clip = dot(input[i].PosWorld, ClipPlane); // Ŭ���÷���ó��
            output.ArrayIndex = f;
            output.VPIndex = f;
            output.Property = input[i].Property;

            TriStream.Append(output);
        }
        TriStream.RestartStrip();
    }
}

PS_TARGET psWriteToBlockBuffer(PS_INPUT input)
{
    PS_TARGET output = (PS_TARGET)0;

    float4 outColor = 0;

	// for blocked mesh /////////////////////////////
    float3 SpaceSize = float3((float)BlockWidth * BlockSize, (float)BlockHeight * BlockSize, (float)BlockDepth * BlockSize);
    float3 local_pos = (input.PosWorld.xyz - PosForBlock.xyz - MinPosForBlock.xyz);
    float3 rel_coord = local_pos / SpaceSize.xyz;

    int3 coord = 0;
    switch (input.ArrayIndex)
    {
        case 0: // XY
            coord = int3(input.Pos.x, BlockHeight - input.Pos.y, input.Pos.z * (float)BlockDepth);
            break;
        case 1: // ZY
            coord = int3(input.Pos.z * (float)BlockWidth, input.Pos.y, input.Pos.x);
            break;
        case 2: // XZ
            coord = uint3(input.Pos.x, input.Pos.z * (float)BlockHeight, input.Pos.y);
			//coord = int3(pos.x, BlockHeight - pos.y, 0);
            break;
    }

    if (coord.x < 0 || coord.x >= BlockWidth)
        discard;

    if (coord.y < 0 || coord.y >= BlockHeight)
        discard;

    if (coord.z < 0 || coord.z >= BlockDepth)
        discard;

    coord += BlockTexStartPos;

    float4 texColor = texDiffuse.Sample(samplerWrap, input.TexCoordDiffuse);
	
    float3 NormalWorld = input.Normal;
    float4 NearColor = float4(1, 1, 1, 1);
#if (1 == SHADER_PARAMETER_LIGHT_PRB)

	float3	light_axis[6] = {
			1,0,0,
			-1,0,0,
			0,1,0,
			0,-1,0,
			0,0,1,
			0,0,-1
	};


	float3	gi_lit = float3(0, 0, 0);

	for (int i = 0; i < 6; i++)
	{
		float	cosang_per_axis = dot(light_axis[i], NormalWorld);
		if (cosang_per_axis > 0.0001)
		{
			//float4	LightColor = ConvertDWORDTofloat(LightCube.ColorPerAxis[i]);
			//float4	LightColor = ConvertDWORDTofloat(LightCubeBuf.ColorPerAxis[i]);
			//gi_lit += (LightColor.rgb * cosang_per_axis);
			gi_lit += ((float3)LightCube.ColorPerAxis[i] * cosang_per_axis);
		}
	}
	NearColor = float4(saturate(gi_lit.rgb + MtlAmbient.rgb), 1);
	//gi_lit.rgb += MtlAmbient.rgb;
	//NearColor = saturate(float4(gi_lit,1));
#else
    NearColor = float4(saturate(input.Diffuse.rgb + MtlAmbient.rgb), 1);
#endif	

    float4 lit_color = NearColor * MtlDiffuse * MtlToneColor;
    lit_color = saturate(float4(max(MinNdotL.rgb, lit_color.rgb), lit_color.a));
    outColor = (texColor * lit_color) + MtlDiffuseAdd;

#if (1 == SHADER_PARAMETER_ATT_LIGHT)
	// ���̳��� ����Ʈ ����
	outColor.rgb += CalcAttLightColorWithNdotL(input.PosWorld.xyz, input.NdotL, iAttLightNum);
#endif
	// ���� ���� �ȼ��� �����ϱ� ���� �ֻ��� 8��Ʈ�� ��Ⱚ�� ��ġ�Ѵ�. �ΰ��� green�� �� ������ ��ġ�Ѵ�.
    float bw = outColor.r * 0.3 + outColor.g * 0.59 + outColor.b * 0.11;
    uint a = (uint)(saturate(bw) * 255.0);
    uint r = (uint)(saturate(outColor.r) * 255.0);
    uint g = (uint)(saturate(outColor.g) * 255.0);
    uint b = (uint)(saturate(outColor.b) * 255.0);

    uint packedColor = (a << 24) | (g << 16) | (r << 8) | b;
    uint oldColor;
    InterlockedMax(BlockedBuffer[coord], packedColor, oldColor);
	//BlockedBuffer[coord] = packedColor;
	
    discard;

    return output;
}


/*
// FP16x4(8bytes)���� NvInterlockedMaxFp16x4�� �̿��� �ڵ� - �۵���
#if (1== USE_NVAPI)
	NvInterlockedMaxFp16x4(BlockedBuffer, coord, outColor);
#else
	BlockedBuffer[coord] = outColor;
#endif
*/

/*
// ���� �ȶ��� reduction �ڵ� - �۵���
float4 warpMax = outColor;
	
warpMax = max(warpMax, NvShflXor(warpMax, 16,32));
warpMax = max(warpMax, NvShflXor(warpMax, 8, 32));
warpMax = max(warpMax, NvShflXor(warpMax, 4, 32));
warpMax = max(warpMax, NvShflXor(warpMax, 2, 32));
warpMax = max(warpMax, NvShflXor(warpMax, 1, 32));
outColor = warpMax;
	
BlockedBuffer[coord] = outColor;
*/
/*
// �밡�� reduction�ڵ� - �۵���
float4 target = 0;
int LandID = NvGetLaneId();
if (LandID < 16)
{
	target.r = asfloat(NvShfl(asuint(outColor.r), LandID+16));
	target.g = asfloat(NvShfl(asuint(outColor.g), LandID+16));
	target.b = asfloat(NvShfl(asuint(outColor.b), LandID+16));
	target.a = asfloat(NvShfl(asuint(outColor.a), LandID+16));

	if (outColor.r < target.r)
		outColor.r = target.r;

	if (outColor.g < target.g)
		outColor.g = target.g;

	if (outColor.b < target.b)
		outColor.b = target.b;

	if (outColor.a < target.a)
		outColor.a = target.a;
}
if (LandID < 8)
{
	target.r = asfloat(NvShfl(asuint(outColor.r), LandID+8));
	target.g = asfloat(NvShfl(asuint(outColor.g), LandID+8));
	target.b = asfloat(NvShfl(asuint(outColor.b), LandID+8));
	target.a = asfloat(NvShfl(asuint(outColor.a), LandID+8));

	if (outColor.r < target.r)
		outColor.r = target.r;

	if (outColor.g < target.g)
		outColor.g = target.g;

	if (outColor.b < target.b)
		outColor.b = target.b;

	if (outColor.a < target.a)
		outColor.a = target.a;

}
if (LandID < 4)
{
	target.r = asfloat(NvShfl(asuint(outColor.r), LandID+4));
	target.g = asfloat(NvShfl(asuint(outColor.g), LandID+4));
	target.b = asfloat(NvShfl(asuint(outColor.b), LandID+4));
	target.a = asfloat(NvShfl(asuint(outColor.a), LandID+8));

	if (outColor.r < target.r)
		outColor.r = target.r;

	if (outColor.g < target.g)
		outColor.g = target.g;

	if (outColor.b < target.b)
		outColor.b = target.b;
	
	if (outColor.a < target.a)
		outColor.a = target.a;
}
if (LandID < 2)
{
	target.r = asfloat(NvShfl(asuint(outColor.r), LandID+2));
	target.g = asfloat(NvShfl(asuint(outColor.g), LandID+2));
	target.b = asfloat(NvShfl(asuint(outColor.b), LandID+2));
	target.a = asfloat(NvShfl(asuint(outColor.a), LandID+8));

	if (outColor.r < target.r)
		outColor.r = target.r;

	if (outColor.g < target.g)
		outColor.g = target.g;

	if (outColor.b < target.b)
		outColor.b = target.b;
		
	if (outColor.a < target.a)
		outColor.a = target.a;
}
if (LandID < 1)
{
	target.r = asfloat(NvShfl(asuint(outColor.r), LandID+1));
	target.g = asfloat(NvShfl(asuint(outColor.g), LandID+1));
	target.b = asfloat(NvShfl(asuint(outColor.b), LandID+1));
	target.a = asfloat(NvShfl(asuint(outColor.a), LandID+1));

	if (outColor.r < target.r)
		outColor.r = target.r;

	if (outColor.g < target.g)
		outColor.g = target.g;

	if (outColor.b < target.b)
		outColor.b = target.b;
		
	if (outColor.a < target.a)
		outColor.a = target.a;
}
	
//outColor.r = asfloat(NvShfl(asuint(outColor.r), 0));
//outColor.g = asfloat(NvShfl(asuint(outColor.g), 0));
//outColor.b = asfloat(NvShfl(asuint(outColor.b), 0));
outColor.a = 1;// asfloat(NvShfl(asuint(outColor.a), 0));
BlockedBuffer[coord] = outColor;
*/