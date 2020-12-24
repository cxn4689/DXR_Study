#include "Common.hlsl"

struct STriVertex {
  float3 vertex;
  float4 color;
};

struct STriAttrib {
	float4 attrib;
	float4 norm;
};

StructuredBuffer<STriVertex> BTriVertex : register(t0, space305);
StructuredBuffer<STriAttrib> BTriAttrib : register(t2, space305);
RaytracingAccelerationStructure SceneBVH : register(t1, space305);

[shader("closesthit")] void ClosestHit3(inout HitInfo payload,
                                       Attributes attrib) {
  float3 barycentrics =
      float3(1.f - attrib.bary.x - attrib.bary.y, attrib.bary.x, attrib.bary.y);

  uint vertId = 3 * PrimitiveIndex();
  /*
  float3 hitColor = BTriVertex[vertId + 1].color * barycentrics.x +
					BTriVertex[vertId + 0].color * barycentrics.y +
					BTriVertex[vertId + 2].color * barycentrics.z;*/
  float3 hitColor = BTriAttrib[PrimitiveIndex()].attrib.rgb;//{ 0.0, 0.0, 1.0 };
  float3 norm = BTriAttrib[PrimitiveIndex()].norm.rgb;

  uint inst_index_TLAS = InstanceIndex();

  //
  float3 hitLocation = ObjectRayOrigin() + ObjectRayDirection() * (RayTCurrent());
  //center of light is: x=-1.35, y=0.7f, z=1.35
  float3 light_pos = float3(-1.35, 0.7, 1.35);
  float3 dir_shadow_ray = light_pos - hitLocation;
  dir_shadow_ray = normalize(dir_shadow_ray);

  uint go_reflect = PrimitiveIndex() == 0 || PrimitiveIndex() == 1;

  float3 I = ObjectRayDirection();
  I = normalize(I);
  float3 N = norm;

  //
  float cur_depth = payload.hit_info.z + 1;
  float shadow_factor = 0.0f;

  if (payload.hit_info.y == 0.0f)//primary ray
  {
	  HitInfo payloadx;
	  //trace shadow ray
	  //
	  //center of light is: x=-1.35, y=0.7f, z=1.35  
	  //
	  payloadx.hit_info.y = 1.0f;//shadow ray
	  payloadx.hit_info.z = cur_depth;
	  //
	  RayDesc ray;
	  //ray.Origin = float3(d.x, -d.y, 1);
	  //Me
	  ray.Origin = hitLocation.xyz;
	  ray.Direction = dir_shadow_ray;

	  ray.TMin = 0.1;
	  ray.TMax = 100000;
	  //
#if 1
	  TraceRay(
		  SceneBVH,
		  RAY_FLAG_NONE,
		  0xFFFF,
		  0,
		  0,
		  0,
		  ray,
		  payloadx);
	  if (payloadx.hit_info.x != 4.0f)//not light source
	  {
		  shadow_factor = 0.5f;
	  }
#else
	  hitColor = dir_shadow_ray;
#endif
	 //
	  float has_reflect = 0;
	  float3 reflect_color = float3(0.0,0.0,0.0);
#if 1
	  if(go_reflect)//only reflect Bottom
	  {
		  payloadx.hit_info.y = 2.0f;
		  //reflction dir = R = I - (2 * dot(I, N)) * N
		  float3 R = I - (2.0 * dot(I, N) * N);
		  ray.Direction = R;
		  ray.Origin = hitLocation;
		  TraceRay(
			  SceneBVH,
			  RAY_FLAG_NONE,
			  0xFF,
			  0,
			  0,
			  0,
			  ray,
			  payloadx);
		  reflect_color = payloadx.colorAndDistance.rgb;
		  has_reflect = 0.5;
	  }
#endif
	  float3 final_color = (1.0f - has_reflect) * hitColor + reflect_color * has_reflect;
	  final_color = (1.0f - shadow_factor) * final_color;
	  payload.hit_info.x = (float)inst_index_TLAS;
	  payload.colorAndDistance = float4(final_color, 1.0);//RayTCurrent()
  }
  else
  {
	  payload.hit_info.x = (float)inst_index_TLAS;
	  payload.colorAndDistance = float4(hitColor, 1.0);
  }
  {
	  payload.hit_info.z = cur_depth - 1;
  }
}
