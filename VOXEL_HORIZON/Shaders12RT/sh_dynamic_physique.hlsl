#ifndef SH_DYNAMIC_PHYSIQUE_HLSL
#define SH_DYNAMIC_PHYSIQUE_HLSL

#define			MAX_BONE_NUM	256

cbuffer ConstantBufferBoneMatrix : register(b1)
{
	float4x3	BoneMatrix[MAX_BONE_NUM];

}

float3 vsCalcBlendPos(float4 inputPos, uint4 BlendIndex, float4 BlendWeight)
{
	float3	pos0 = mul(inputPos, BoneMatrix[BlendIndex.x]);
	float3	pos1 = mul(inputPos, BoneMatrix[BlendIndex.y]);
	float3	pos2 = mul(inputPos, BoneMatrix[BlendIndex.z]);
	float3	pos3 = mul(inputPos, BoneMatrix[BlendIndex.w]);

	float3	posLocal = (pos0 * BlendWeight.x);
	posLocal += (pos1 * BlendWeight.y);
	posLocal += (pos2 * BlendWeight.z);
	posLocal += (pos3 * BlendWeight.w);

	return posLocal;
}

float3 vsCalcBlendNormal(float3 inputNormal, uint4 BlendIndex, float4 BlendWeight)
{
	float3	n0 = mul(inputNormal, (float3x3)BoneMatrix[BlendIndex.x]);
	float3	n1 = mul(inputNormal, (float3x3)BoneMatrix[BlendIndex.y]);
	float3	n2 = mul(inputNormal, (float3x3)BoneMatrix[BlendIndex.z]);
	float3	n3 = mul(inputNormal, (float3x3)BoneMatrix[BlendIndex.w]);

	float3	normalLocal = (n0 * BlendWeight.x);
	normalLocal += (n1 * BlendWeight.y);
	normalLocal += (n2 * BlendWeight.z);
	normalLocal += (n3 * BlendWeight.w);

	return normalLocal;
}

#endif