#include "sh_dynamic_common.hlsl"
#include "sh_util.hlsl"

cbuffer ConstantBufferCubemap : register(b4)
{
	matrix		matCubeViewList[6];
	matrix		matCubeProjList[6];
	matrix		matCubeViewProjList[6];
	float4		CamEyePos;		// x,y,z = eypos , w = 1/far
};

//Texture2D		texDiffuse		: register( t0 );
//SamplerState	samplerDiffuse	: register( s0 );

/*
struct VS_INPUT_VL
{
	float4		Pos		 : POSITION;
	float3		Normal	 : NORMAL;
	float3		Tangent	 : TANGENT;
	float2		TexCoord : TEXCOORD0;

};
*/

struct GS_INPUT
{
	float4		Pos : SV_POSITION;
	float3		Normal : NORMAL;
	float2		TexCoord : TEXCOORD0;
	float4		Diffuse : COLOR0;

};


struct PS_INPUT_IMM
{
	float4	Pos : SV_POSITION;
	float2	TexCoord : TEXCOORD0;
	float4	PosWorld : TEXCOORD1;
	float	Dist : TEXCOORD2;
	float4	Diffuse : COLOR0;
	float4	NormalColor : COLOR1;
};

struct PS_INPUT_DEPTH
{
	float4 Pos : SV_POSITION;
	float Depth : ZDEPTH;
};

struct PS_CUBEMAP_INPUT
{
	float4	Pos : SV_POSITION;     // Projection coord
	float4	Diffuse : COLOR0;
	uint	RTIndex : SV_RenderTargetArrayIndex;
};

PS_INPUT_IMM vsDefault(VS_INPUT_VL input)
{
	PS_INPUT_IMM	output = (PS_INPUT_IMM)0;
	// 출력버텍스

	output.Pos = mul(input.Pos, g_Camera.matWorldViewProjArray[0]);
	float3	NormalWorld = mul(input.Normal, (float3x3)g_TrCommon.matWorld);	// 월드공간에서 노말
	NormalWorld = normalize(NormalWorld);							// 다시 노멀라이즈(스케일이 들어있을 경우를 대비해서)
	output.NormalColor.rgb = (NormalWorld * 0.5f) + 0.5f;
	output.NormalColor.a = 1;
	output.TexCoord = input.TexCoord;
	output.Diffuse = MtlDiffuse;

	return output;
}

// 색 지정된 삼각형 렌더링. Color.rgb = Tangent.xyz 로 맵핑
PS_INPUT_IMM vsColorTri(VS_INPUT_VL input)
{
	PS_INPUT_IMM	output = (PS_INPUT_IMM)0;
	// 출력버텍스

	output.Pos = mul(input.Pos, g_Camera.matWorldViewProjCommon);
	float3	NormalWorld = mul(input.Normal, (float3x3)g_TrCommon.matWorld);	// 월드공간에서 노말
	NormalWorld = normalize(NormalWorld);							// 다시 노멀라이즈(스케일이 들어있을 경우를 대비해서)
	output.NormalColor.rgb = (NormalWorld * 0.5f) + 0.5f;
	output.NormalColor.a = 1;
	output.TexCoord = input.TexCoord;
	output.Diffuse = float4(input.Tangent.xyz, 1);

	return output;
}
PS_TARGET psColorTri(PS_INPUT_IMM input) : SV_Target
{
	PS_TARGET OutColor = (PS_TARGET)0;

	OutColor.Color0 = input.Diffuse;
	OutColor.Color1 = float4(input.NormalColor.xyz, (float)Property / 255.0f);
	OutColor.Color2 = float4(0, (float)MtlPreset / 255.0, (float)g_TrCommon.ShadingType / 255.0, 0);

	return OutColor;
}

GS_INPUT vsFlat(VS_INPUT_VL input)
{
	GS_INPUT	output = (GS_INPUT)0;
	// 출력버텍스

	output.Pos = mul(input.Pos, g_TrCommon.matWorld);

	output.TexCoord = input.TexCoord;
	output.Normal = input.Normal;
	output.Diffuse = MtlDiffuse;


	return output;
}

PS_TARGET psDefault(PS_INPUT_IMM input)
{
	PS_TARGET OutColor = (PS_TARGET)0;

	float4	texColor = texDiffuse.Sample(samplerWrap, input.TexCoord);

	OutColor.Color0 = texColor * input.Diffuse;
	OutColor.Color1 = float4(input.NormalColor.xyz, (float)Property / 255.0f);
	OutColor.Color2 = float4(0, (float)MtlPreset / 255.0, (float)g_TrCommon.ShadingType / 255.0, 0);
	return OutColor;
}

PS_TARGET psDefaultShadow(PS_INPUT_IMM input)
{
	PS_TARGET OutColor = (PS_TARGET)0;

	float4	texColor = texDiffuse.Sample(samplerWrap, input.TexCoord);
	
	OutColor.Color0 = texColor * input.Diffuse;
	OutColor.Color1 = float4(input.NormalColor.xyz, (float)Property / 255.0f);
	OutColor.Color2 = float4(0, (float)MtlPreset / 255.0, (float)g_TrCommon.ShadingType / 255.0, 0);
	return OutColor;
}

float4 psLine(PS_INPUT_IMM input) : SV_Target
{
	return input.Diffuse;
}
PS_TARGET psBox(PS_INPUT_IMM input)
{
	PS_TARGET OutColor = (PS_TARGET)0;

	float4	texColor = texDiffuse.Sample(samplerMirror, input.TexCoord);
	
	OutColor.Color0 = texColor * input.Diffuse;
	OutColor.Color1 = float4(input.NormalColor.xyz, (float)Property / 255.0f);
	OutColor.Color2 = float4(0, (float)MtlPreset / 255.0, (float)g_TrCommon.ShadingType / 255.0, 0);
	return OutColor;
}


PS_INPUT_DEPTH vsDepthDist(VS_INPUT_VL input)
{
	PS_INPUT_DEPTH output = (PS_INPUT_DEPTH)0;

	output.Pos = mul(input.Pos, g_Camera.matWorldViewProjCommon);
	output.Depth = output.Pos.w * ProjConstant.fFarRcp;

	return output;
}

float4 psDepthDist(PS_INPUT_DEPTH input) : SV_Target
{
	float4 outColor = float4(input.Depth, input.Depth, input.Depth, 1);

	return outColor;
}


[maxvertexcount(3)]
void gsDefault(triangle GS_INPUT input[3], inout TriangleStream <PS_INPUT_IMM> TriStream)
{
	PS_INPUT_IMM	output = (PS_INPUT_IMM)0;

	float3	N = CalcNormalWithTri((float3)input[0].Pos, (float3)input[1].Pos, (float3)input[2].Pos);


	// N*L계산
	float cosang = dot(N, (float3)(-LightDir));
	float L = cosang * 0.5 + 0.5;

	for (uint i = 0; i < 3; i++)
	{
		float4	Diffuse = float4(L*input[i].Diffuse.rgb, input[i].Diffuse.a);
		float4	Pos = mul(input[i].Pos, g_Camera.matWorldViewProjCommon);// world는 identity matrix일것
		float4	PosWorld = mul(input[i].Pos, g_TrCommon.matWorld);

		//output[i].Diffuse.rgb = N*0.5 + 0.5;
		output.Diffuse = Diffuse;
		output.Pos = Pos;
		output.TexCoord = input[i].TexCoord;
		output.PosWorld = PosWorld;
		output.NormalColor.rgb = (N * 0.5f) + 0.5f;
		output.NormalColor.a = 1;

		TriStream.Append(output);
	}
}


[maxvertexcount(36)]
void gsVertexToBox(point GS_INPUT input[1], inout TriangleStream<PS_INPUT_IMM> TriStream)
{
	PS_INPUT_IMM	output = (PS_INPUT_IMM)0;

	float	size = PublicConst[0].x;

	float	start_u = PublicConst[1].x;
	float	start_v = PublicConst[1].y;
	float	tex_coord_offset = PublicConst[1].z;


	uint		Index[36] =
	{
		// +z
		3,0,1,
		3,1,2,

		// -z
		4,7,6,
		4,6,5,

		// -x
		0,4,5,
		0,5,1,

		// +x
		7,3,2,
		7,2,6,

		// +y
		0,3,7,
		0,7,4,

		// -y
		2,1,5,
		2,5,6
	};

	float3	NormalList[6] =
	{
		0,0,1,	// +z
		0,0,-1,	// -z
		-1,0,0,	// -x
		1,0,0,	// +x
		0,1,0,	// +y
		0,-1,0	// -y
	};
	float3	WorldPos[8];
	WorldPos[0] = input[0].Pos.xyz + float3(-size, size, size);
	WorldPos[1] = input[0].Pos.xyz + float3(-size, -size, size);
	WorldPos[2] = input[0].Pos.xyz + float3(size, -size, size);
	WorldPos[3] = input[0].Pos.xyz + float3(size, size, size);
	WorldPos[4] = input[0].Pos.xyz + float3(-size, size, -size);
	WorldPos[5] = input[0].Pos.xyz + float3(-size, -size, -size);
	WorldPos[6] = input[0].Pos.xyz + float3(size, -size, -size);
	WorldPos[7] = input[0].Pos.xyz + float3(size, size, -size);

	//float2	TexCoord[4] = 
	//{
	//	0,0,
	//	1,0,
	//	1,1,
	//	0,1
	//};
	float2	TexCoord[4] =
	{
		0,0,
		1,0,
		1,1,
		0,1
	};

	uint TexCoordIndex[36] =
	{
		// -z
		0,1,2,
		0,2,3,

		// +z
		0,1,2,
		0,2,3,

		// -x
		0,1,2,
		0,2,3,

		// +x
		0,1,2,
		0,2,3,

		// +y
		0,1,2,
		0,2,3,

		// -y
		0,1,2,
		0,2,3
	};

	/*
	for (DWORD i=0; i<8; i++)
	{
		WorldPos[i] = mul(WorldPos[i],matWorld);
	}
	*/
	uint	VertexIndex = 0;
	for (uint i = 0; i < 6; i++)
	{
		float3	N = NormalList[i];
		// N*L계산
		float cosang = dot(N, (float3)(-LightDir));
		float L = cosang * 0.5 + 0.5;
		float4	Diffuse = float4(L*input[0].Diffuse.rgb, input[0].Diffuse.a);
		//float4	Diffuse = float4(1,1,1,1);


		float	DotShadow = dot(N, (float3)ShadowLightDirInv);
		if (DotShadow <= 0)
		{
			DotShadow = 0;
		}
		
		for (uint j = 0; j < 2; j++)
		{
			for (uint k = 0; k < 3; k++)
			{
				float4	PosWorld = float4(WorldPos[Index[VertexIndex]], 1);
				output.PosWorld = PosWorld;
				output.Pos = mul(PosWorld, g_Camera.matWorldViewProjCommon);	// world는 identity matrix일것
				output.Dist = output.Pos.w;
				output.TexCoord = float2(TexCoord[TexCoordIndex[VertexIndex]]) * float2(tex_coord_offset, tex_coord_offset) + float2(start_u, start_v);
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
[maxvertexcount(36)]
void gsVertexToBoxDepth(point GS_INPUT input[1], inout TriangleStream<PS_INPUT_IMM> TriStream)
{
	PS_INPUT_IMM	output = (PS_INPUT_IMM)0;

	float	size = PublicConst[0].x;

	uint		Index[36] =
	{
		// +z
		3,0,1,
		3,1,2,

		// -z
		4,7,6,
		4,6,5,

		// -x
		0,4,5,
		0,5,1,

		// +x
		7,3,2,
		7,2,6,

		// +y
		0,3,7,
		0,7,4,

		// -y
		2,1,5,
		2,5,6
	};

	float3	WorldPos[8];
	WorldPos[0] = input[0].Pos.xyz + float3(-size, size, size);
	WorldPos[1] = input[0].Pos.xyz + float3(-size, -size, size);
	WorldPos[2] = input[0].Pos.xyz + float3(size, -size, size);
	WorldPos[3] = input[0].Pos.xyz + float3(size, size, size);
	WorldPos[4] = input[0].Pos.xyz + float3(-size, size, -size);
	WorldPos[5] = input[0].Pos.xyz + float3(-size, -size, -size);
	WorldPos[6] = input[0].Pos.xyz + float3(size, -size, -size);
	WorldPos[7] = input[0].Pos.xyz + float3(size, size, -size);

	uint	VertexIndex = 0;
	for (uint i = 0; i < 6; i++)
	{
		for (uint j = 0; j < 2; j++)
		{
			for (uint k = 0; k < 3; k++)
			{
				float4	PosWorld = float4(WorldPos[Index[VertexIndex]], 1);
				output.PosWorld = PosWorld;
				output.Pos = mul(PosWorld, g_Camera.matWorldViewProjCommon);// world는 identity matrix일것
				TriStream.Append(output);
				VertexIndex++;
			}
			TriStream.RestartStrip();
		}

	}
}

[maxvertexcount(6)]
void gsVertexToRect(point GS_INPUT input[1], inout TriangleStream <PS_INPUT_IMM> TriStream)
{
	PS_INPUT_IMM	output = (PS_INPUT_IMM)0;

	float	size = PublicConst[0].x;

	float4	ViewPos = mul(input[0].Pos, g_Camera.matViewArray[0]);

	float4	ViewRect[4];
	ViewRect[0] = ViewPos + float4(-size, size, 0, 0);
	ViewRect[1] = ViewPos + float4(size, size, 0, 0);
	ViewRect[2] = ViewPos + float4(size, -size, 0, 0);
	ViewRect[3] = ViewPos + float4(-size, -size, 0, 0);

	float4	ProjRect[4];
	for (uint i = 0; i < 4; i++)
	{
		ProjRect[i] = mul(ViewRect[i], g_Camera.matProjArray[0]);
	}

	float2	texCoord[4] = { 0,1, 1,1, 1,0, 0,0 };

	float3	N = float3(0, -1, 0);
	output.NormalColor.rgb = (N * 0.5f) + 0.5f;
	output.NormalColor.a = 1;
	output.Diffuse = input[0].Diffuse;



	//output.PosWorld = mul(ViewRect[0],matViewInv);	이렇게 하면 월드좌표는 구할 수 있다. view역행렬 전달하기 귀찮아서 일단 구현 안함

	// 삼각형 0
	output.Pos = ProjRect[0];
	output.TexCoord = texCoord[0];
	TriStream.Append(output);

	output.Pos = ProjRect[1];
	output.TexCoord = texCoord[1];
	TriStream.Append(output);

	output.Pos = ProjRect[2];
	output.TexCoord = texCoord[2];
	TriStream.Append(output);

	TriStream.RestartStrip();

	// 삼각형 1
	output.Pos = ProjRect[0];
	output.TexCoord = texCoord[0];
	TriStream.Append(output);

	output.Pos = ProjRect[2];
	output.TexCoord = texCoord[2];
	TriStream.Append(output);

	output.Pos = ProjRect[3];
	output.TexCoord = texCoord[3];
	TriStream.Append(output);

	TriStream.RestartStrip();

}





bool IsBackFace(float3 p0, float3 p1, float3 p2, float3 Eye)
{

	// this works out the vector from the camera to the face.
	float3	cameraToFace = p0 - Eye;

	float3	faceNormal = CalcNormalWithTri(p0, p1, p2);

	float cosang = dot(cameraToFace, faceNormal);

	bool	backface = cosang > 0.0f;
	return backface;
}

[maxvertexcount(18)]
void gsCubeMapFrontBack(triangle GS_INPUT input[3], inout TriangleStream<PS_CUBEMAP_INPUT> CubeMapStream)
{
	float	rcp_far = CamEyePos.w;

	float4	colorFront = float4(0, 0, 1, 1);
	float4	colorBack = float4(1, 0, 0, 1);


	for (int f = 0; f < 6; ++f)
	{
		uint3	index = float3(0, 1, 2);
		float4	diffuseColor = colorFront;



		bool	flip = IsBackFace((float3)input[0].Pos, (float3)input[1].Pos, (float3)input[2].Pos, (float3)CamEyePos);
		//bool	flip = false;
		//bool	flip = true;

		if (flip)
		{
			// 면방향이이 카메라 방향을 향하고 있지 않으면 뒤집는다.
			index = uint3(0, 2, 1);
			diffuseColor = colorBack;
		}

		PS_CUBEMAP_INPUT	output[3];
		for (uint i = 0; i < 3; i++)
		{

			float4	Pos = mul(input[i].Pos, matCubeViewProjList[f]);


			output[i].RTIndex = f;
			output[i].Diffuse = diffuseColor;
			output[i].Pos = Pos;
		}
		CubeMapStream.Append(output[index.x]);
		CubeMapStream.Append(output[index.y]);
		CubeMapStream.Append(output[index.z]);
		CubeMapStream.RestartStrip();

	}
}
[maxvertexcount(18)]
void gsCubeMapDefault(triangle GS_INPUT input[3], inout TriangleStream<PS_CUBEMAP_INPUT> CubeMapStream)
{
	float	rcp_far = CamEyePos.w;

	float4	colorFront = float4(0, 0, 1, 1);

	for (int f = 0; f < 6; ++f)
	{
		uint3	index = float3(0, 1, 2);
		float4	diffuseColor = colorFront;

		PS_CUBEMAP_INPUT	output[3];
		for (uint i = 0; i < 3; i++)
		{

			float4	Pos = mul(input[i].Pos, matCubeViewProjList[f]);


			output[i].RTIndex = f;
			output[i].Diffuse = diffuseColor;
			output[i].Pos = Pos;
		}
		CubeMapStream.Append(output[index.x]);
		CubeMapStream.Append(output[index.y]);
		CubeMapStream.Append(output[index.z]);
		CubeMapStream.RestartStrip();

	}
}

float4 psCubeMap(PS_CUBEMAP_INPUT input) : SV_Target
{
	float4	OutColor = input.Diffuse;
	return OutColor;
}
