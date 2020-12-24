#include "Common.hlsl"

struct STriVertex {
  float3 vertex;
  float4 color;
};

StructuredBuffer<STriVertex> BTriVertex : register(t0,space302);
RaytracingAccelerationStructure SceneBVH : register(t1,space302);

[shader("closesthit")] void ClosestHit1(inout HitInfo payload,
                                       Attributes attrib) {
#if 1
  float3 barycentrics =
      float3(1.f - attrib.bary.x - attrib.bary.y, attrib.bary.x, attrib.bary.y);

  uint vertId = 3 * PrimitiveIndex();
  /*
  float3 hitColor = BTriVertex[vertId + 1].color * barycentrics.x +
                    BTriVertex[vertId + 0].color * barycentrics.y +
                    BTriVertex[vertId + 2].color * barycentrics.z;*/
  float3 hitColor = { 1.0, 0.0, 0.0 };

  uint inst_index_TLAS = InstanceIndex();

  HitInfo payloadx;
  //
  float cur_depth = payload.hit_info.z + 1;

  if (payload.hit_info.y == 0.0f)//primary ray
  {
	  //trace shadow ray
	  //
	  float3 hitLocation = ObjectRayOrigin() + ObjectRayDirection() * (RayTCurrent() * 0.99);
	  //center of light is: x=-1.35, y=0.7f, z=1.35
	  float3 light_pos = float3(-1.35, 0.7, 1.35);
	  float3 dir_shadow_ray = light_pos - hitLocation;
	  dir_shadow_ray = normalize(dir_shadow_ray);
	  //
	  payloadx.hit_info.y = 1.0f;//shadow ray
	  payloadx.hit_info.z = cur_depth;
	  //
	  RayDesc ray;
	  //ray.Origin = float3(d.x, -d.y, 1);
	  //Me
	  ray.Origin = hitLocation;
	  ray.Direction = dir_shadow_ray;

	  ray.TMin = 0;
	  ray.TMax = 100000;
	  //
	  TraceRay(
		  SceneBVH,
		  RAY_FLAG_NONE,
		  0xFF,
     	  0,
		  0,
		  0,
		  ray,
		  payloadx);
	  float shadow_factor = 0.0f;
	  if (payloadx.hit_info.x != 4.0f)//not light source
	  {
		  shadow_factor = 0.5f;
	  }
	  payload.hit_info.x = (float)inst_index_TLAS;
	  payload.colorAndDistance = float4(hitColor * (1.0f - shadow_factor), RayTCurrent());
  }
  else
  {
	  payload.hit_info.x = (float)inst_index_TLAS;
	  payload.colorAndDistance = float4(hitColor, RayTCurrent());
  }
  {
	  payload.hit_info.z = cur_depth - 1;
  }
#else
	payload.hit_info.x = 0.0f;
	payload.colorAndDistance = float4(float3(0.0, 0.0, 1.0), RayTCurrent());
#endif
}
