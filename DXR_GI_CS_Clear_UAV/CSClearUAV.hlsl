//#include "Common.hlsl"


#if 1

// Raytracing output texture, accessed as a UAV
RWTexture2D<float4> gOutput : register(u0);// , space600);

RWTexture2D<float4> gOutput2 : register(u1);// , space600);
RWTexture2D<float4> gOutput3 : register(u2);// , space600);

// Raytracing acceleration structure, accessed as a SRV
//RaytracingAccelerationStructure SceneBVH : register(t0);// , space600);


[numthreads(8, 8, 1)]
void CSMain(uint3 groupThreadID : SV_GroupThreadID,
	uint3 dispatchThreadID : SV_DispatchThreadID, uint3 GTid : SV_GroupThreadID, uint GI : SV_GroupIndex)
{
	int x = dispatchThreadID.x;
	int y = dispatchThreadID.y;

	gOutput[int2(x, y)] = float4(0, 0, 0, 0);
#if 1
	gOutput2[int2(x,y)] = float4(0, 0, 0, 0);
	gOutput3[int2(x, y)] = float4(0, 0, 2021, 0);
#endif
}

#else
[numthreads(8, 8, 1)]
void CSMain(uint3 groupThreadID : SV_GroupThreadID,
	uint3 dispatchThreadID : SV_DispatchThreadID, uint3 GTid : SV_GroupThreadID, uint GI : SV_GroupIndex)
{

}
#endif