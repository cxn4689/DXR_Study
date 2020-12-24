#include "Common.hlsl"

// Raytracing output texture, accessed as a UAV
RWTexture2D<float4> gOutput : register(u0, space100);

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
  //Me
  ray.Origin = float3(0.0f, 0.0f, 15.0f);
  //ray.Direction = float3(0, 0, -1);
  //Me
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
  ray.Direction = ip - cp;
  
  ray.TMin = 0;
  ray.TMax = 100000;

  payload.hit_info.z == 0.0f; //primary ray

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

  float3 primary_color = payload.colorAndDistance.rgb;

  /*
 struct HitInfo {
	float4 colorAndDistance;
	float4 hit_info;//[0] instance id, [1] Need shadow ray [2] need reflect ray [3] RSVL
	float4 shadow_ray_dir;
	float4 shadow_ray_org;
	float4 reflect_ray_dir;
	float4 reflect_ray_org;
};
  */
  float hit_shadow = 0.0;
  float has_shadow = payload.hit_info.y;
  float has_reflection = payload.hit_info.z;
  float3 reflect_org = payload.reflect_ray_org;
  float3 reflect_dir = payload.reflect_ray_dir;
  payload.hit_info.z = payload.hit_info.y = 0.0;
  if (has_shadow)
  {
	  //trace shadow ray
	  // Trace the ray
	  ray.Origin = payload.shadow_ray_org;
	  ray.Direction = payload.shadow_ray_dir;
	  TraceRay(
		  SceneBVH,
		  RAY_FLAG_NONE,
		  0xFF,
		  0,
		  0,
		  0,
		  ray,
		  payload);
	  float hit_instance_index = payload.hit_info.x;
	  if (hit_instance_index != 4.0f)//light source TLAS index
	  {
		  hit_shadow = 0.5;
	  }
  }
  float has_reflect = 0;
  float3 reflect_color;
  payload.hit_info.z = payload.hit_info.y = 0.0;
  if (has_reflection)
  {
	  has_reflect = 1.0f;
	  //trace reflection ray
	  // Trace the ray
	  ray.Origin = reflect_org;
	  ray.Direction = reflect_dir;
	  TraceRay(
		  SceneBVH,
		  RAY_FLAG_NONE,
		  0xFF,
		  0,
		  0,
		  0,
		  ray,
		  payload);
	  float hit_instance_index = payload.hit_info.x;
	  reflect_color = payload.colorAndDistance.rgb;
  }
  hit_shadow = 1.0 - hit_shadow;
  if (has_reflect)
  {
	  primary_color = primary_color * 0.5 + reflect_color * 0.5;
  }

  gOutput[launchIndex] = float4(primary_color * hit_shadow, 1.f);
}
