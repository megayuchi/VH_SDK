#ifndef SH_CONSTANT_BUFFER_MATERIAL_HLSL
#define SH_CONSTANT_BUFFER_MATERIAL_HLSL

#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_typedef.hlsl"

// Vertex Shader Constant ///////////////////////////

cbuffer CONSTANT_BUFFER_MATERIAL : register(b2)
{
	float4		MtlDiffuse;
	float4		MtlAmbient;
	float4		MtlDiffuseAdd;		// �Ӹ�ī�� ������ Ư���� ��� �������ֱ� ���� �ȼ� ���̴��� �Ѿ ���� ���
	float4		MtlToneColor;		// ���������� ������� ������ ���, ��Ⱑ ��οﶧ �ַ� ���
	float4		MinNdotL;			// min (r,g,b,a = VertexLighting�� N dot L�� ������)
	uint		MtlAlphaMode;
    uint MeshletNumPerFaceGroup;
	uint MtlPreset;
	uint MtlReserved2;
    TILED_RESOURCE_PROPERTY TiledResourceProp;
}

#endif