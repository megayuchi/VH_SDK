
Texture2D		texMip		: register(t0);

void vsDownSample(in  float4 Position  : POSITION, out float4 PositionSS : SV_POSITION)
{
	PositionSS = Position;
}

float4 psDownSample(float4 PositionSS : SV_POSITION) : SV_TARGET
{
	uint lastMipWidth, lastMipHeight;
	texMip.GetDimensions(lastMipWidth, lastMipHeight);

	// get integer pixel coordinates
	uint3 nCoords = uint3(PositionSS.xy, 0);

	// fetch a 2x2 neighborhood and compute the max
	nCoords.xy *= 2;


	float4 vTexels;
	vTexels.x = texMip.Load(nCoords).r;
	vTexels.y = texMip.Load(nCoords, uint2(1,0)).r;
	vTexels.z = texMip.Load(nCoords, uint2(0,1)).r;
	vTexels.w = texMip.Load(nCoords, uint2(1,1)).r;


	// Determine the largest depth value and use it as the new down sampled
	// color.
	float fMaxDepth = max(max(vTexels.x, vTexels.y), max(vTexels.z, vTexels.w));



	return fMaxDepth;
}

/*

struct VS_INPUT
{
	float4		Pos		 : POSITION;
	float2		TexCoord : TEXCOORD0;

};

struct PS_INPUT
{
	float4	Pos			 : SV_POSITION;
	float2	TexPos		 : TEXCOORD0;
};

PS_INPUT vsDownSample( VS_INPUT input )
{
	PS_INPUT output = (PS_INPUT)0;

	// position
	output.Pos = input.Pos;
	output.Pos.w = 1.0f;

	float2	TexCoord;
	TexCoord.x = input.Pos.x * 0.5f + 1.0f;
	TexCoord.y = 1.0f - (input.Pos.y * 0.5f + 1.0f);

	output.TexPos.xy = TexCoord * GenericConst.xy;

	return output;
}



float4 psDownSample( PS_INPUT input) : SV_Target
{

	uint3	nCoords;
	nCoords = uint3((uint2)input.TexPos.xy,0);


	// fetch a 2x2 neighborhood and compute the max
	nCoords.xy *= 2;


	float4 vTexels;
	vTexels.x = texMip.Load( nCoords );
	vTexels.y = texMip.Load( nCoords, uint2(1,0) );
	vTexels.z = texMip.Load( nCoords, uint2(0,1) );
	vTexels.w = texMip.Load( nCoords, uint2(1,1) );


	// Determine the largest depth value and use it as the new down sampled
	// color.
	float fMaxDepth = max( max( vTexels.x, vTexels.y ), max( vTexels.z, vTexels.w ) );
	fMaxDepth = 0.0f;

	return fMaxDepth;
}
*/
/*

void VS( in  float4 Position   : POSITION,
		 out float4 PositionSS : SV_POSITION )
{
	PositionSS = Position;
}

float4 PS( float4 PositionSS : SV_POSITION ) : SV_TARGET
{
	uint lastMipWidth, lastMipHeight;
	LastMip.GetDimensions(lastMipWidth, lastMipHeight);

	// get integer pixel coordinates
	uint3 nCoords = uint3( PositionSS.xy, 0 );

	// fetch a 2x2 neighborhood and compute the max
	nCoords.xy *= 2;


	float4 vTexels;
	vTexels.x = LastMip.Load( nCoords );
	vTexels.y = LastMip.Load( nCoords, uint2(1,0) );
	vTexels.z = LastMip.Load( nCoords, uint2(0,1) );
	vTexels.w = LastMip.Load( nCoords, uint2(1,1) );


	// Determine the largest depth value and use it as the new down sampled
	// color.
	float fMaxDepth = max( max( vTexels.x, vTexels.y ), max( vTexels.z, vTexels.w ) );



	return fMaxDepth;
}
*/