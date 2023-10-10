
#ifndef SH_COSNT_BUFFER_VOLUME_TEX
#define SH_COSNT_BUFFER_VOLUME_TEX

#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_typedef.hlsl"

cbuffer CONSTANT_BUFFER_FILL_VOLUME_TEXTURE : register(b0)
{
	uint3	Res;
	uint	Reserved0;
	uint3	GroupNum;
	uint	Reserved1;
}

#endif
