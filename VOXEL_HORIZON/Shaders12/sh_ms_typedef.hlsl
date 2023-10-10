#ifndef MESH_SHADER_TYPEDEF_HLSL
#define MESH_SHADER_TYPEDEF_HLSL


struct TVERTEX
{
	float2 uv;
};
struct D3DVLVERTEX
{
	float3		Pos;
	float3		Normal;
	float3		Tangent;
	uint		Property;
};

StructuredBuffer<D3DVLVERTEX> g_MeshVertices : register(t6);
ByteAddressBuffer g_MeshIndices : register(t7);

#endif