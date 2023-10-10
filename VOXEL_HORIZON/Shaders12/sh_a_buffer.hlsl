#ifndef SH_A_BUFFER
#define SH_A_BUFFER

#include "sh_define.hlsl"
#include "shader_cpp_common.h"

#define MAX_SORT_NUM 10
#define INVALID_A_BUFFRE_OFFSET_VALUE 0x7fffffff // 01111111 11111111 11111111 11111111
#define A_BUFFRE_OFFSET_MASK 0x7fffffff // 01111111 11111111 11111111 11111111

cbuffer CONSTANT_BUFFER_A_BUFFER : register(b6)
{
	uint		ScreenWidth;
	uint		ScreenHeight;
	uint		ClearValue;
	uint		MaxFLNum;
}

// 4bytes align이면 작동하지만 성능상 패널티가 있으므로 16bytes align권장
struct FRAGMENT
{
	uint	uPixelColor;	// Packed pixel color
	uint	uNormal_ElementID;	// Normal 565(2bytes) | Property(1byte) |ElementID(1byte)
	float	fDepth;			// Pixel depth
};

struct FRAGMENT_EX : FRAGMENT
{
	float	AddValue;
};
struct FRAGMENT_LINK : FRAGMENT
{
	uint	uNext;		// Address of next link
	uint GetNext()
	{	
		return (uNext & A_BUFFRE_OFFSET_MASK);
	}
	void SetNext(uint offset)
	{
		uNext = (offset & A_BUFFRE_OFFSET_MASK);
	}
	void SetAlphaMode(uint mode)	// transp mode == 0, add mode == 1
	{
        uNext &= (~uint(0x80000000));
		uNext |= ((mode & 0x00000001) << 31);
	}
	float GetAddAlphaValue()
	{
		float value = (float)((uNext & 0x80000000) != 0);
		return value;
	}
};


RWByteAddressBuffer StartOffsetBuffer : register(u4);	// W
RWStructuredBuffer <FRAGMENT_LINK> FLBuffer : register(u5);	// RW
RWByteAddressBuffer PropertyBuffer : register(u6);	// RW
RWByteAddressBuffer FailCountBuffer : register(u7);	// RW

[numthreads(1024, 1, 1)]
void csClearABuffer(uint3 groupID : SV_GroupID, uint3 dispatchThreadId : SV_DispatchThreadID)
{	
	uint2	CurPixel = uint2(dispatchThreadId.x % ScreenWidth, dispatchThreadId.x / ScreenWidth);	// 현재 픽셀의 좌표
	uint	ArrayIndex = groupID.y;

	// Skip out of bound pixels
	if (CurPixel.y < ScreenHeight)
	{
		uint address = ((CurPixel.x + CurPixel.y*ScreenWidth) + (ScreenWidth*ScreenHeight*ArrayIndex)) * 4;
		StartOffsetBuffer.Store(address, ClearValue);

		PropertyBuffer.Store(address, 0);
	}
}
void SortFragList(inout FRAGMENT_EX FragList[MAX_SORT_NUM], uint FragCount)
{
	for (uint i = 0; i < FragCount; i++)
	{
		for (uint j = 0; j < FragCount; j++)
		{
			if (FragList[i].fDepth > FragList[j].fDepth)
			{
				FRAGMENT_EX t = FragList[i];
				FragList[i] = FragList[j];
				FragList[j] = t;
			}
		}
	}
}
/*
float4 ABufferResolvePS(FullScreenTriangleVSOut input) : SV_Target
{
    float3 blendColor = 0;
    float  totalTransmittance = 1;
    int2   screenAddress = int2(input.positionViewport.xy);   
    uint   firstNodeOffset = FL_GetFirstNodeOffset(screenAddress);   

    // Get offset to the first node
    uint outerNodeOffset = firstNodeOffset;
    
    // Fetch and sort nodes
    [loop] while (outerNodeOffset != FL_NODE_LIST_NULL)
    {
        // Get node..
        FragmentListNode outerNode = FL_GetNode(outerNodeOffset);

        float outerDepth;
        uint  outerCoverageMask;
        FL_UnpackDepthAndCoverage(outerNode.depth, outerDepth, outerCoverageMask);
	
        float visibility = 1;
            
        uint innerNodeOffset = firstNodeOffset;
        [loop] while (innerNodeOffset != FL_NODE_LIST_NULL) 
		{
            float innerDepth;
            uint  innerCoverageMask;

            FragmentListNode innerNode = FL_GetNode(innerNodeOffset);
            FL_UnpackDepthAndCoverage(innerNode.depth, innerDepth, innerCoverageMask);

            float4 innerNodeColor = FL_UnpackColor(innerNode.color);
            visibility *= outerDepth <= innerDepth ? 1 : 1 - innerNodeColor.w;

            innerNodeOffset = innerNode.next;  
        }
        // Composite this fragment
        float4 nodeColor = FL_UnpackColor(outerNode.color);
        blendColor += nodeColor.xyz * nodeColor.www * visibility.xxx;

        // Update total transmittance
        totalTransmittance *= 1 - nodeColor.w;

        // Move to next node
        outerNodeOffset = outerNode.next;                    
    }

    return float4(blendColor, totalTransmittance);
}
*/
/*
// 렌더링할때 z테스트는 on, z쓰기는 off
[earlydepthstencil]
float4 PS_StoreFragments(PS_INPUT input, float4 pos : SV_Position) : SV_Target
{
	float SCREEN_WIDTH = ScreenWidth;
	float SCREEN_HEIGHT = ScreenHeight;

	// Calculate fragment data (color, depth, etc.)
	//FragmentData_STRUCT FragmentData = ComputeFragment();

	// Retrieve current pixel count and increase counter
	uint uPixelCount = FLBuffer.IncrementCounter();

	if (uPixelCount >= MaxFLNum)
	{
		return float4(0, 0, 0, 0);
	}

	// Exchange offsets in StartOffsetBuffer
	uint2 vPos = uint2(pos.xy);
	uint uStartOffsetAddress = 4 * ((SCREEN_WIDTH*vPos.y) + vPos.x);
	uint uOldStartOffset;
	StartOffsetBuffer.InterlockedExchange(uStartOffsetAddress, uPixelCount, uOldStartOffset);

	
	// Add new fragment entry in Fragment & Link Buffer
	FRAGMENT_LINK Element;
	FLBuffer[uPixelCount].uPixelColor = 0;
	FLBuffer[uPixelCount].fDepth = 0.0;
	FLBuffer[uPixelCount].uNext = uOldStartOffset;

	return float4(1, 1, 1, 1);
}
*/



//////////////////////////////////////////////
// Defines
//////////////////////////////////////////////

#ifndef AOIT_NODE_COUNT 
#define AOIT_NODE_COUNT			(4)
#endif

#define AOIT_FIRT_NODE_TRANS	(1)
#define AOIT_RT_COUNT			(AOIT_NODE_COUNT / 4)
#define AIOT_EMPTY_NODE_DEPTH	(1E30)

// Forces compression to only work on the second half of the nodes (cheaper and better IQ in most cases)
#define AOIT_DONT_COMPRESS_FIRST_HALF 

//////////////////////////////////////////////
// Structs
//////////////////////////////////////////////

struct AOITData 
{
    float4 depth[AOIT_RT_COUNT];
    float4 trans[AOIT_RT_COUNT];
};

struct AOITFragment
{
    int   index;
    float depthA;
    float transA;
};


//////////////////////////////////////////////////
// Two-level search for AT visibility functions
//////////////////////////////////////////////////
 
AOITFragment AOITFindFragment(in AOITData data, in float fragmentDepth)
{
    int    index;
    float4 depth, trans;
    float  leftDepth;
    float  leftTrans;
    
    AOITFragment Output;      

#if AOIT_RT_COUNT > 7    
    if (fragmentDepth > data.depth[6][3])
    {
        depth        = data.depth[7];
        trans        = data.trans[7];
        leftDepth    = data.depth[6][3];
        leftTrans    = data.trans[6][3];
        Output.index = 28;        
    }
    else
#endif  
#if AOIT_RT_COUNT > 6    
    if (fragmentDepth > data.depth[5][3])
    {
        depth        = data.depth[6];
        trans        = data.trans[6];
        leftDepth    = data.depth[5][3];
        leftTrans    = data.trans[5][3];
        Output.index = 24;        
    }
    else
#endif  
#if AOIT_RT_COUNT > 5    
    if (fragmentDepth > data.depth[4][3])
    {
        depth        = data.depth[5];
        trans        = data.trans[5];
        leftDepth    = data.depth[4][3];
        leftTrans    = data.trans[4][3];
        Output.index = 20;        
    }
    else
#endif  
#if AOIT_RT_COUNT > 4    
    if (fragmentDepth > data.depth[3][3])
    {
        depth        = data.depth[4];
        trans        = data.trans[4];
        leftDepth    = data.depth[3][3];
        leftTrans    = data.trans[3][3];    
        Output.index = 16;        
    }
    else
#endif    
#if AOIT_RT_COUNT > 3    
    if (fragmentDepth > data.depth[2][3])
    {
        depth        = data.depth[3];
        trans        = data.trans[3];
        leftDepth    = data.depth[2][3];
        leftTrans    = data.trans[2][3];    
        Output.index = 12;        
    }
    else
#endif    
#if AOIT_RT_COUNT > 2    
    if (fragmentDepth > data.depth[1][3])
    {
        depth        = data.depth[2];
        trans        = data.trans[2];
        leftDepth    = data.depth[1][3];
        leftTrans    = data.trans[1][3];          
        Output.index = 8;        
    }
    else
#endif    
#if AOIT_RT_COUNT > 1    
    if (fragmentDepth > data.depth[0][3])
    {
        depth        = data.depth[1];
        trans        = data.trans[1];
        leftDepth    = data.depth[0][3];
        leftTrans    = data.trans[0][3];       
        Output.index = 4;        
    }
    else
#endif
    {    
        depth        = data.depth[0];
        trans        = data.trans[0];
        leftDepth    = data.depth[0][0];
        leftTrans    = data.trans[0][0];      
        Output.index = 0;        
    } 
      
    if (fragmentDepth <= depth[0]) {
        Output.depthA = leftDepth;
        Output.transA = leftTrans;
    } else if (fragmentDepth <= depth[1]) {
        Output.index += 1;
        Output.depthA = depth[0]; 
        Output.transA = trans[0];            
    } else if (fragmentDepth <= depth[2]) {
        Output.index += 2;
        Output.depthA = depth[1];
        Output.transA = trans[1];            
    } else if (fragmentDepth <= depth[3]) {
        Output.index += 3;    
        Output.depthA = depth[2];
        Output.transA = trans[2];            
    } else {
        Output.index += 4;       
        Output.depthA = depth[3];
        Output.transA = trans[3];         
    }
    
    return Output;
}	

////////////////////////////////////////////////////
// Insert a new fragment in the visibility function
////////////////////////////////////////////////////

void AOITInsertFragment(in float fragmentDepth,
                        in float fragmentTrans,
                        inout AOITData AOITData)
{	
    int i, j;
  
    // Unpack AOIT data    
    float depth[AOIT_NODE_COUNT + 1];	
    float trans[AOIT_NODE_COUNT + 1];	                
     
	for (i = 0; i < AOIT_RT_COUNT; ++i) 
	{
	     
		for (j = 0; j < 4; ++j) 
		{
		    depth[4 * i + j] = AOITData.depth[i][j];
		    trans[4 * i + j] = AOITData.trans[i][j];			        
	    }
    }	

    // Find insertion index 
    AOITFragment tempFragment = AOITFindFragment(AOITData, fragmentDepth);
    const int   index = tempFragment.index;
    // If we are inserting in the first node then use 1.0 as previous transmittance value
    // (we don't store it, but it's implicitly set to 1. This allows us to store one more node)
    const float prevTrans = index != 0 ? tempFragment.transA : 1.0f;

    // Make space for the new fragment. Also composite new fragment with the current curve 
    // (except for the node that represents the new fragment)
    
	for (i = AOIT_NODE_COUNT - 1; i >= 0; --i) 
	{
        
		if (index <= i) 
		{
            depth[i + 1] = depth[i];
            trans[i + 1] = trans[i] * fragmentTrans;
        }
    }
    
    // Insert new fragment
    
	for (i = 0; i <= AOIT_NODE_COUNT; ++i) 
	{
        if (index == i) {
            depth[i] = fragmentDepth;
            trans[i] = fragmentTrans * prevTrans;
        }
    } 
    
    // pack representation if we have too many nodes
    
	if (depth[AOIT_NODE_COUNT] != AIOT_EMPTY_NODE_DEPTH) 
	{	                
        
        // That's total number of nodes that can be possibly removed
        const int removalCandidateCount = (AOIT_NODE_COUNT + 1) - 1;

#ifdef AOIT_DONT_COMPRESS_FIRST_HALF
        // Although to bias our compression scheme in order to favor..
        // .. the closest nodes to the eye we skip the first 50%
		const int startRemovalIdx = removalCandidateCount / 2;
#else
		const int startRemovalIdx = 1;
#endif

        float nodeUnderError[removalCandidateCount];

        
		for (i = startRemovalIdx; i < removalCandidateCount; ++i) 
		{
            nodeUnderError[i] = (depth[i] - depth[i - 1]) * (trans[i - 1] - trans[i]);
        }

        // Find the node the generates the smallest removal error
        int smallestErrorIdx;
        float smallestError;

        smallestErrorIdx = startRemovalIdx;
        smallestError    = nodeUnderError[smallestErrorIdx];
        i = startRemovalIdx + 1;

        
		for ( ; i < removalCandidateCount; ++i) 
		{
            if (nodeUnderError[i] < smallestError) 
			{
                smallestError = nodeUnderError[i];
                smallestErrorIdx = i;
            } 
        }

        // Remove that node..
        
		for (i = startRemovalIdx; i < AOIT_NODE_COUNT; ++i) 
		{
            if (smallestErrorIdx <= i) {
                depth[i] = depth[i + 1];
            }
        }
        
		for (i = startRemovalIdx - 1; i < AOIT_NODE_COUNT; ++i) 
		{
            if (smallestErrorIdx - 1 <= i) {
                trans[i] = trans[i + 1];
            }
        }
    }
    
    // Pack AOIT data
     
	for (i = 0; i < AOIT_RT_COUNT; ++i) 
	{
	     
		for (j = 0; j < 4; ++j) 
		{
		    AOITData.depth[i][j] = depth[4 * i + j];
		    AOITData.trans[i][j] = trans[4 * i + j];			        
	    }
    }	
}
#endif