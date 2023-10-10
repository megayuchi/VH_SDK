#include "sh_define.hlsl"
#include "shader_cpp_common.h"
#include "sh_gbuffer_shader_common.hlsl"
#include "sh_a_buffer.hlsl"

// for OIT
ByteAddressBuffer StartOffsetBufferSRV : register(t0);
StructuredBuffer<FRAGMENT_LINK> FLBufferSRV : register(t1);
ByteAddressBuffer PropertyBufferSRV : register(t2);

struct PS_OUT_MERGE
{
	float4 Color0 : SV_Target0; // pixel color
	float4 Color1 : SV_Target1; // normal 
	float4 Color2 : SV_Target2; // r:ElementID | g:Alpha | b:N/A | a:N/A
	float	Depth : SV_Depth; // depth 
};

VS_OUTPUT vsMergeTransparency(uint VertexID : SV_VertexID, uint instId : SV_InstanceID)
{
	VS_OUTPUT output;

	//output.Position = float4( arrBasePos[VertexID].xy, 0.0, 1.0);
	//output.cpPos = output.Position.xy;
	uint ArrayIndex = instId % 2;
	output.Position = float4(arrBasePos[VertexID].xy, 0.0, 1.0);
	output.cpPos = arrBasePos[VertexID];
	output.ArrayIndex = ArrayIndex;
#if (1 == VS_RTV_ARRAY)
	output.RTVIndex = ArrayIndex;
#endif
	return output;
}

PS_OUT_MERGE psMergeTransparencySort(PS_INPUT input)
{
	PS_OUT_MERGE Output = (PS_OUT_MERGE)0;

#ifdef  STEREO_RENDER
	int4	location = int4(input.Position.xy, input.ArrayIndex, 0);
	float3	texCoord = float3(input.cpPos.zw, input.ArrayIndex);
#else
	int3	location = int3(input.Position.xy, 0);
	float2	texCoord = float2(input.cpPos.zw);
#endif

	// OIT
#ifdef  STEREO_RENDER
	uint uStartOffsetAddress = (location.x + location.y*ScreenWidth + input.ArrayIndex*ScreenWidth*ScreenHeight) * 4;
#else
	uint uStartOffsetAddress = (location.x + location.y*ScreenWidth) * 4;
#endif

	float	min_depth = 999999.0;
	float3	NormalColor = 0;
	uint	Prop = 0;
	uint	ElementID = 0;

	FRAGMENT_EX	FragList[MAX_SORT_NUM];
	uint		uFragCount = 0;

	uint prop = PropertyBufferSRV.Load(uStartOffsetAddress);
	if (1 == prop)
		discard;

	uint uOffset = StartOffsetBufferSRV.Load(uStartOffsetAddress);
	if (uOffset == INVALID_A_BUFFRE_OFFSET_VALUE)
		discard;

	while (uOffset != INVALID_A_BUFFRE_OFFSET_VALUE)
	{
		// Retrieve pixel at current offset
		FRAGMENT_LINK Element = FLBufferSRV[uOffset];
		if (uFragCount < MAX_SORT_NUM)
		{
			FragList[uFragCount].uPixelColor = Element.uPixelColor;
			FragList[uFragCount].fDepth = Element.fDepth;
			uFragCount++;
		}
		if (min_depth >= Element.fDepth)
		{
			min_depth = Element.fDepth;
			NormalColor = Unpack_UINT_To_Normal_Property_ElementID(ElementID, Prop, Element.uNormal_ElementID);
		}
		uOffset = Element.GetNext();
	}

	SortFragList(FragList, uFragCount);

	float4 blendColor = float4(0, 0, 0, 1);
	for (uint i = 0; i < uFragCount; i++)
	{
		float4 nodeColor = UnpackRGBA(FragList[i].uPixelColor);
		blendColor.rgb = nodeColor.rgb * nodeColor.aaa + (float3(1, 1, 1) - nodeColor.aaa) * blendColor.rgb;
		blendColor.a = blendColor.a * (1.0f - nodeColor.a);
	}

	if (blendColor.a >= 1.0)
		discard;

	Output.Color0 = blendColor;
	Output.Color1 = float4(NormalColor.rgb, Prop * (1.0 / 255.0));
	Output.Color2 = float4(ElementID * (1.0 / 255.0), 0, 0, 0);
	Output.Depth = saturate(min_depth);
	return Output;
}
PS_OUT_MERGE psMergeTransparencyVF(PS_INPUT input)
{
	PS_OUT_MERGE Output = (PS_OUT_MERGE)0;

#ifdef  STEREO_RENDER
	int4	location = int4(input.Position.xy, input.ArrayIndex, 0);
	float3	texCoord = float3(input.cpPos.zw, input.ArrayIndex);
#else
	int3	location = int3(input.Position.xy, 0);
	float2	texCoord = float2(input.cpPos.zw);
#endif

	// OIT
#ifdef  STEREO_RENDER
	uint uStartOffsetAddress = (location.x + location.y*ScreenWidth + input.ArrayIndex*ScreenWidth*ScreenHeight) * 4;
#else
	uint uStartOffsetAddress = (location.x + location.y*ScreenWidth) * 4;
#endif
	float3	BlendColor = 0;
	float	TotalTransmittance = 1;
	float	min_depth = 999999.0;
	float3	NormalColor = 0;
	uint	Prop = 0;
	uint	ElementID = 0;

	uint prop = PropertyBufferSRV.Load(uStartOffsetAddress);
	if (1 == prop)
		discard;

	uint uOffsetOuter = StartOffsetBufferSRV.Load(uStartOffsetAddress);
	if (uOffsetOuter == INVALID_A_BUFFRE_OFFSET_VALUE)
		discard;

	while (uOffsetOuter != INVALID_A_BUFFRE_OFFSET_VALUE)
	{
		float visibility = 1;

		// Retrieve pixel at current offset
		FRAGMENT_LINK ElementOuter = FLBufferSRV[uOffsetOuter];

		uint uOffsetInner = StartOffsetBufferSRV.Load(uStartOffsetAddress);
		while (uOffsetInner != INVALID_A_BUFFRE_OFFSET_VALUE)
		{
			// Retrieve pixel at current offset
			FRAGMENT_LINK ElementInner = FLBufferSRV[uOffsetInner];

			float4 ColorInner = UnpackRGBA(ElementInner.uPixelColor);
			visibility *= ElementOuter.fDepth <= ElementInner.fDepth ? 1 : 1 - ColorInner.a;

			uOffsetInner = ElementInner.GetNext();
		}
		// Composite this fragment
		float4 NodeColor = UnpackRGBA(ElementOuter.uPixelColor);
		BlendColor += NodeColor.rgb * NodeColor.aaa * visibility;

		// Update total transmittance
		TotalTransmittance *= (1 - NodeColor.a);
		if (min_depth >= ElementOuter.fDepth)
		{
			min_depth = ElementOuter.fDepth;
			NormalColor = Unpack_UINT_To_Normal_Property_ElementID(ElementID, Prop, ElementOuter.uNormal_ElementID);
		}
		uOffsetOuter = ElementOuter.GetNext();
	}

	if (TotalTransmittance >= 1.0)
		discard;

	Output.Color0 = float4(BlendColor, TotalTransmittance);
	Output.Color1 = float4(NormalColor.rgb, Prop * (1.0 / 255.0));
	Output.Color2 = float4(ElementID * (1.0 / 255.0), 0, 0, 0);
	Output.Depth = saturate(min_depth);
	return Output;
}
PS_OUT_MERGE psMergeTransparencyVF_OPT(PS_INPUT input)
{
	PS_OUT_MERGE Output = (PS_OUT_MERGE)0;

#ifdef  STEREO_RENDER
	int4	location = int4(input.Position.xy, input.ArrayIndex, 0);
	float3	texCoord = float3(input.cpPos.zw, input.ArrayIndex);
#else
	int3	location = int3(input.Position.xy, 0);
	float2	texCoord = float2(input.cpPos.zw);
#endif

	// OIT
#ifdef  STEREO_RENDER
	uint uStartOffsetAddress = (location.x + location.y*ScreenWidth + input.ArrayIndex*ScreenWidth*ScreenHeight) * 4;
#else
	uint uStartOffsetAddress = (location.x + location.y*ScreenWidth) * 4;
#endif
	float4	BlendColor = 0;
	float	min_depth = 999999.0;
	float3	NormalColor = 0;
	uint	Prop = 0;
	uint	ElementID = 0;

	uint prop = PropertyBufferSRV.Load(uStartOffsetAddress);
	if (1 == prop)
		discard;

	uint FirstOffset = StartOffsetBufferSRV.Load(uStartOffsetAddress);
	if (FirstOffset == INVALID_A_BUFFRE_OFFSET_VALUE)
		discard;

	AOITData data;
	// Initialize AVSM data    
	[unroll]
	for (uint i = 0; i < AOIT_RT_COUNT; i++)
	{
		data.depth[i] = AIOT_EMPTY_NODE_DEPTH.xxxx;
		data.trans[i] = AOIT_FIRT_NODE_TRANS.xxxx;
	}

	uint uOffset = FirstOffset;
	while (uOffset != INVALID_A_BUFFRE_OFFSET_VALUE)
	{
		// Retrieve pixel at current offset
		FRAGMENT_LINK Element = FLBufferSRV[uOffset];
		float4 Color = UnpackRGBA(Element.uPixelColor);

		//void AOITInsertFragment(in float fragmentDepth,  in float fragmentTrans,    inout AOITData AOITData)
		AOITInsertFragment(Element.fDepth, saturate(1.0 - Color.a), data);

		uOffset = Element.GetNext();
	}

	uOffset = FirstOffset;
	while (uOffset != INVALID_A_BUFFRE_OFFSET_VALUE)
	{
		FRAGMENT_LINK Element = FLBufferSRV[uOffset];

		// Composite this fragment
		float4 NodeColor = UnpackRGBA(Element.uPixelColor);
		AOITFragment frag = AOITFindFragment(data, Element.fDepth);
		float visibility = frag.index == 0 ? 1.0f : frag.transA;
		BlendColor.rgb += NodeColor.rgb * NodeColor.aaa * visibility;

		if (min_depth >= Element.fDepth)
		{
			min_depth = Element.fDepth;
			NormalColor = Unpack_UINT_To_Normal_Property_ElementID(ElementID, Prop, Element.uNormal_ElementID);
		}
		uOffset = Element.GetNext();
	}
	BlendColor.a = data.trans[AOIT_RT_COUNT - 1][3];
	if (BlendColor.a >= 1.0)
		discard;

	Output.Color0 = BlendColor;
	Output.Color1 = float4(NormalColor.rgb, Prop * (1.0 / 255.0));
	Output.Color2 = float4(ElementID * (1.0 / 255.0), 0, 0, 0);
	Output.Depth = saturate(min_depth);
	return Output;
}

PS_OUT_MERGE psMergeTransparencySortAdd(PS_INPUT input)
{
	PS_OUT_MERGE Output = (PS_OUT_MERGE)0;

#ifdef  STEREO_RENDER
	int4	location = int4(input.Position.xy, input.ArrayIndex, 0);
	float3	texCoord = float3(input.cpPos.zw, input.ArrayIndex);
#else
	int3	location = int3(input.Position.xy, 0);
	float2	texCoord = float2(input.cpPos.zw);
#endif

	// OIT
#ifdef  STEREO_RENDER
	uint uStartOffsetAddress = (location.x + location.y*ScreenWidth + input.ArrayIndex*ScreenWidth*ScreenHeight) * 4;
#else
	uint uStartOffsetAddress = (location.x + location.y*ScreenWidth) * 4;
#endif

	float	min_depth = 999999.0;
	float3	NormalColor = 0;
	uint	Prop = 0;
	uint	ElementID = 0;

	FRAGMENT_EX	FragList[MAX_SORT_NUM];
	uint		uFragCount = 0;

	uint prop = PropertyBufferSRV.Load(uStartOffsetAddress);
	if (1 != prop)
		discard;

	uint uOffset = StartOffsetBufferSRV.Load(uStartOffsetAddress);
	if (uOffset == INVALID_A_BUFFRE_OFFSET_VALUE)
		discard;

	while (uOffset != INVALID_A_BUFFRE_OFFSET_VALUE)
	{
		// Retrieve pixel at current offset
		FRAGMENT_LINK Element = FLBufferSRV[uOffset];
		if (uFragCount < MAX_SORT_NUM)
		{
			FragList[uFragCount].uPixelColor = Element.uPixelColor;
			FragList[uFragCount].fDepth = Element.fDepth;
			FragList[uFragCount].AddValue = Element.GetAddAlphaValue();
			uFragCount++;
		}

		if (min_depth >= Element.fDepth)
		{
			min_depth = Element.fDepth;
			NormalColor = Unpack_UINT_To_Normal_Property_ElementID(ElementID, Prop, Element.uNormal_ElementID);
		}
		uOffset = Element.GetNext();
	}

	SortFragList(FragList, uFragCount);

	float4 blendColor = float4(0, 0, 0, 1);
	float3	ColorSum = float3(0, 0, 0);

	for (uint i = 0; i < uFragCount; i++)
	{
		float addValue = FragList[i].AddValue;
		float4 nodeColor = UnpackRGBA(FragList[i].uPixelColor);
		float3	nodeColorMulAlpha = nodeColor.rgb * nodeColor.aaa;
		blendColor.rgb = nodeColorMulAlpha + saturate((float3(1, 1, 1) - nodeColor.aaa + float3(addValue, addValue, addValue))) * blendColor.rgb;
		ColorSum += nodeColorMulAlpha;
		//if (addValue > 0.0)
		//{
		//	const float3	bwConst = float3(0.3f, 0.59f, 0.11f);
		//	float	bwColor = dot(blendColor.rgb, bwConst);
		//	nodeColor.a = bwColor;
		//}
		blendColor.a = blendColor.a * saturate((1.0f - nodeColor.a + addValue));
	}

	Output.Color0 = blendColor;
	Output.Color1 = float4(NormalColor.rgb, Prop * (1.0 / 255.0));
	Output.Color2 = float4(ElementID * (1.0 / 255.0), 0, 0, 0);
	Output.Depth = saturate(min_depth);
	return Output;
}