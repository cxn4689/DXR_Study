#include "Common.hlsl"

struct STriVertex {
  float3 vertex;
  float4 color;
};

StructuredBuffer<STriVertex> BTriVertex : register(t0, space320);

[shader("closesthit")] void ClosestHit2(inout HitInfo payload,
                                       Attributes attrib) {
  float3 barycentrics =
      float3(1.f - attrib.bary.x - attrib.bary.y, attrib.bary.x, attrib.bary.y);

  uint vertId = 3 * PrimitiveIndex();
  /*
  float3 hitColor = BTriVertex[vertId + 1].color * barycentrics.x +
					BTriVertex[vertId + 0].color * barycentrics.y +
					BTriVertex[vertId + 2].color * barycentrics.z;*/
  float3 hitColor = { 0.0, 1.0, 0.0 };

  uint inst_index_TLAS = InstanceIndex();
  payload.hit_info.x = (float)inst_index_TLAS;
  payload.colorAndDistance = float4(hitColor, RayTCurrent());

  //
  float3 hitLocation = ObjectRayOrigin() + ObjectRayDirection() * (RayTCurrent() * 0.99);
  //center of light is: x=-1.35, y=0.7f, z=1.35
  float3 light_pos = float3(-1.35, 0.7, 1.35);
  float3 dir_shadow_ray = light_pos - hitLocation;
  dir_shadow_ray = normalize(dir_shadow_ray);
  //
  {
	  payload.hit_info.y = 1.0f;
	  payload.shadow_ray_dir = float4(dir_shadow_ray, 1.0);
	  payload.shadow_ray_org = float4(hitLocation, 1.0);
  }
  //
  {
	  payload.hit_info.z = 0.0f;
  }
}
