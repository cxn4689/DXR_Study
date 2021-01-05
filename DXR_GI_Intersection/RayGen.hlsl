#include "Common.hlsl"

// Raytracing output texture, accessed as a UAV
RWTexture2D<float4> gOutput : register(u0, space100);
RWTexture2D<float4> gOutput2 : register(u1, space100);
RWTexture2D<float4> gOutput3 : register(u2, space100);

// Raytracing acceleration structure, accessed as a SRV
RaytracingAccelerationStructure SceneBVH : register(t0, space100);

[shader("raygeneration")] void RayGen() {
  // Initialize the ray payload
  HitInfo payload;
  payload.colorAndDistance = float4(0, 0, 0, 0);

  // Get the location within the dispatched 2D grid of work items
  // (often maps to pixels, so this could represent a pixel coordinate).
  uint2 launchIndex = DispatchRaysIndex().xy;
  float2 dims = float2(DispatchRaysDimensions().xy);
  //float2 d = (((launchIndex.xy + 0.5f) / dims.xy) * 2.f - 1.f);
  float2 d = (launchIndex.xy / dims.xy * 2.f - 1.f) * 2.f;//-1 : +1
  // Define a ray, consisting of origin, direction, and the min-max distance
  // values
  RayDesc ray;
  //ray.Origin = float3(d.x, -d.y, 1);
  //cxn4689
  ray.Origin = float3(0.0f, 0.0f, 15.0f);
  //ray.Direction = float3(0, 0, -1);
  //cxn4689
  //ray.Direction = float3(0.0, -0.3, -1);
  //origin = 0,0,2
  //Y range: 0.8 : -0.8
  //X range: 1.5 : -1.5
  //focal plane z=1.0
  //image plane z = 2.0
  //cam         z = 9.0
  //calculate Y:
  float3 ip = float3(1.5*0.5*d.x, -0.8*0.5*d.y, 2.0);
  float3 cp = float3(0.0, 0.0, 15.0);
  ray.Direction = normalize(ip - cp);
  
  ray.TMin = 0;
  ray.TMax = 100000;

  payload.hit_info.rgba = float4(-1.0f, 0.0f, 0.0f, 0.0f); //primary ray
  //payload.random.x = gOutput[launchIndex].w;// +launchIndex.x * launchIndex.y;

  float4 all_3 = gOutput3[launchIndex];

  float count = all_3.w;

  uint s_num = 0;
  float seed = launchIndex.y * dims.x + launchIndex.x;//like linear random function access in smallpt
  float3 accume_rgb = gOutput2[launchIndex].xyz;
  if (count == 0 || count < 0)
  {
	  //gOutput3[launchIndex].x = seed;
	  if (count < 0) count = 0;
  }
  else
  {
	  seed = all_3.x;
  }
  //
  count = count + 1;
  //gOutput2[launchIndex] = float4(accume_rgb, count);
  //
  //for (s_num = 0; s_num < SAMPLE_NUM; s_num++)
  if(1)
  {
	  payload.random.x = seed;// +(float)(s_num * dims.x * dims.y);// gOutput[launchIndex].w;
	  // Trace the ray
	  TraceRay(
		  // Parameter name: AccelerationStructure
		  // Acceleration structure
		  SceneBVH,

		  // Parameter name: RayFlags
		  // Flags can be used to specify the behavior upon hitting a surface
		  RAY_FLAG_NONE,

		  // Parameter name: InstanceInclusionMask
		  // Instance inclusion mask, which can be used to mask out some geometry to
		  // this ray by and-ing the mask with a geometry mask. The 0xFF flag then
		  // indicates no geometry will be masked
		  0xFF,

		  // Parameter name: RayContributionToHitGroupIndex
		  // Depending on the type of ray, a given object can have several hit
		  // groups attached (ie. what to do when hitting to compute regular
		  // shading, and what to do when hitting to compute shadows). Those hit
		  // groups are specified sequentially in the SBT, so the value below
		  // indicates which offset (on 4 bits) to apply to the hit groups for this
		  // ray. In this sample we only have one hit group per object, hence an
		  // offset of 0.
		  0,

		  // Parameter name: MultiplierForGeometryContributionToHitGroupIndex
		  // The offsets in the SBT can be computed from the object ID, its instance
		  // ID, but also simply by the order the objects have been pushed in the
		  // acceleration structure. This allows the application to group shaders in
		  // the SBT in the same order as they are added in the AS, in which case
		  // the value below represents the stride (4 bits representing the number
		  // of hit groups) between two consecutive objects.
		  0,

		  // Parameter name: MissShaderIndex
		  // Index of the miss shader to use in case several consecutive miss
		  // shaders are present in the SBT. This allows to change the behavior of
		  // the program when no geometry have been hit, for example one to return a
		  // sky color for regular rendering, and another returning a full
		  // visibility value for shadow rays. This sample has only one miss shader,
		  // hence an index 0
		  0,

		  // Parameter name: Ray
		  // Ray information to trace
		  ray,

		  // Parameter name: Payload
		  // Payload associated to the ray, which will be used to communicate
		  // between the hit/miss shaders and the raygen
		  payload);

	  seed = payload.random.x;

	  float3 primary_color = payload.colorAndDistance.rgb;
	  
	  if (count >= (float)(SAMPLE_NUM-1))//ACCUME_STEP)
	  {
		  float3 tmp = accume_rgb;
		  //inline int toInt(double x){ return int(pow(clamp(x),1/2.2)*255+.5); }
		  tmp.x = (tmp.x > 1.0) ? 1.0 : (tmp.x < 0.0) ? 0.0 : tmp.x;
		  tmp.y = (tmp.y > 1.0) ? 1.0 : (tmp.y < 0.0) ? 0.0 : tmp.y;
		  tmp.z = (tmp.z > 1.0) ? 1.0 : (tmp.z < 0.0) ? 0.0 : tmp.z;
		  tmp.x = pow(tmp.x, 1.0 / 2.2);
		  tmp.y = pow(tmp.y, 1.0 / 2.2);
		  tmp.z = pow(tmp.z, 1.0 / 2.2);
		  gOutput[launchIndex].xyz = tmp;
		  //
		  accume_rgb = float3(0, 0, 0);
		  accume_rgb = accume_rgb + primary_color * (1.0 / (float)SAMPLE_NUM);// ACCUME_STEP);
		  count = 1;
	  }
	  else
	  {
		  accume_rgb = accume_rgb + primary_color *(1.0 / (float)SAMPLE_NUM);// ACCUME_STEP);
		  //gOutput[launchIndex].w = payload.random.x;
		  //gOutput[launchIndex].rgb = float3(payload.random.x, 0, 0);
	  }
	  gOutput2[launchIndex] = float4(accume_rgb, count);
	  gOutput3[launchIndex] = float4(seed,0,0,count);
	  //gOutput[launchIndex] = float4(primary_color, 1.f);
  }
}
