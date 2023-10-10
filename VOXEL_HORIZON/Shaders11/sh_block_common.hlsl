
#ifndef SH_VL_BLOCK_COMMON
#define SH_VL_BLOCK_COMMON


cbuffer ConstantBufferBlockBuffer : register(b3)
{
	// dynamic mesh object as blocks 
	matrix		matOrtho[3];	//0 == xy, 1 == zy , 2 == xz
	int			BlockWidth;
	int			BlockHeight;
	int			BlockDepth;
	float		BlockSize;
	float4		PosForBlock;
	float4		MinPosForBlock;
	int3		BlockTexStartPos;
	float		BlockAlpha;
}
struct GS_INPUT_BLOCK
{
	float4		Pos : SV_POSITION;
	float3		Normal : NORMAL;
};

#endif