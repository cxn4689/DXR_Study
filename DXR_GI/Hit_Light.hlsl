#include "Common.hlsl"

struct STriVertex {
  float3 vertex;
  float4 color;
};

StructuredBuffer<STriVertex> BTriVertex : register(t0, space304);
RaytracingAccelerationStructure SceneBVH : register(t1, space304);

[shader("closesthit")] void ClosestHitLight(inout HitInfo payload,
                                       Attributes attrib) {
  float3 barycentrics =
      float3(1.f - attrib.bary.x - attrib.bary.y, attrib.bary.x, attrib.bary.y);

  uint vertId = 3 * PrimitiveIndex();
  uint primId = PrimitiveIndex();
  /*
  float3 hitColor = BTriVertex[vertId + 1].color * barycentrics.x +
					BTriVertex[vertId + 0].color * barycentrics.y +
					BTriVertex[vertId + 2].color * barycentrics.z;*/
  float3 hitColor = float3(1.0, 1.0, 1.0);//BTriAttrib[PrimitiveIndex()].attrib;//{ 0.0, 0.0, 1.0 };

  uint inst_index_TLAS = InstanceIndex();
  payload.hit_info.x = (float)inst_index_TLAS;
  payload.hit_info.y = payload.hit_info.z = 0.0f;

  hitColor = LIGHT_E;
#if 0
  if (primId == 0 || primId == 1)
  {
	  hitColor = float3(1.0, 0.0, 0.0);
  }
  if (primId == 2 || primId == 3)
  {
	  hitColor = float3(0.0, 1.0, 0.0);
  }
  if (primId == 4 || primId == 5)
  {
	  hitColor = float3(0.0, 0.0, 1.0);
  }
  if (primId == 6 || primId == 7)
  {
	  hitColor = float3(1.0, 1.0, 0.0);
  }
  if (primId == 8 || primId == 9)
  {
	  hitColor = float3(1.0, 0.0, 1.0);
  }
  if (primId == 10 || primId == 11)
  {
	  hitColor = float3(0.0, 1.0, 1.0);
  }
#endif
  payload.colorAndDistance = float4(hitColor, RayTCurrent());
}
