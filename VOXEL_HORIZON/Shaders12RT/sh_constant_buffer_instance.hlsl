#ifndef CONSTANT_BUFFER_INSTANCE_HLSL
#define CONSTANT_BUFFER_INSTANCE_HLSL

#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_typedef.hlsl"

// Vertex Shader Constant ///////////////////////////

cbuffer CONSTANT_BUFFER_INSTANCE_MATRIX_ARRAY : register(b7)
{
    matrix g_InstanceMatWorldList[MAX_INSTANCE_COUNT];
}

#endif