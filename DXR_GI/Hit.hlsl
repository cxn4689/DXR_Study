#include "Common.hlsl"

struct STriVertex {
  float3 vertex;
  float4 color;
};

struct STriAttrib {
	float4 attrib;
	float4 norm;
};

StructuredBuffer<STriVertex> BTriVertex : register(t0, space301);
RaytracingAccelerationStructure SceneBVH : register(t1, space301);
StructuredBuffer<STriAttrib> BTriAttrib : register(t2, space301);

[shader("closesthit")] void ClosestHit(inout HitInfo payload,
                                       Attributes attrib) {
#if 0
  float3 barycentrics =
      float3(1.f - attrib.bary.x - attrib.bary.y, attrib.bary.x, attrib.bary.y);

  uint vertId = 3 * PrimitiveIndex();
  uint primId = PrimitiveIndex();
  float3 hitColor = BTriVertex[vertId + 1].color * barycentrics.x +
                    BTriVertex[vertId + 0].color * barycentrics.y +
                    BTriVertex[vertId + 2].color * barycentrics.z;

  //calculate sencondary ray info
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
  HitInfo payloadx;
  
  uint inst_index_TLAS = InstanceIndex();
  //
  float cur_depth = payload.hit_info.z + 1;

  if (payload.hit_info.y == 0.0f)//primary ray
  {
	  if (cur_depth < 5)
	  {
		  //trace shadow ray
		  //
		  //float3 hitLocation = ObjectRayOrigin() + ObjectRayDirection() * (RayTCurrent());//this is BLAS space (without transform matrix)
		  float3 hitLocation = WorldRayOrigin() + WorldRayDirection() * RayTCurrent();
		  //into or leave 
		  float3 ray_dir = ObjectRayDirection();
		  ray_dir = normalize(ray_dir);
		  float3 norm = BTriAttrib[primId].norm;
		  norm = normalize(norm);
		  float in_or_out = dot(norm, ray_dir);
		  //from smallpt
		  float3 nl = (in_or_out < 0) ? norm : (norm * -1);
		  uint into = (dot(norm, nl) > 0) ? 1 : 0;
		  float nt = 1.5, nc = 1.0;
		  float nnt = into ? (nc / nt) : (nt / nc);
		  float ddn = dot(ray_dir, nl);
		  float cos2t = 1.0 - nnt * nnt * (1 - ddn * ddn);
		  //
		  float3 I = WorldRayDirection();
		  I = normalize(I);
		  float3 N = norm;
		  float3 R = I - (2.0 * dot(I, N) * N);
		  float3 RFR = ray_dir * nnt - norm * ((into ? 1.0 : -1.0) * (ddn *nnt + sqrt(cos2t)));
		  RFR = normalize(RFR);
		  R = normalize(R);
		  //
		  float3 reflect_color = float3(0, 0, 0);

		  RayDesc ray;

		  if (into)
		  {
			  ray.Origin = hitLocation;// +offset_fix;
			  ray.Direction = R;

			  ray.TMin = 0.001;
			  ray.TMax = 100000;
			  payloadx.hit_info.x = 0.0;
			  payloadx.hit_info.y = 0.0;// (into && (cos2t >= 0.0)) ? 0.0f : 2.0f;//shadow ray
			  payloadx.hit_info.z = cur_depth + 1;
			  payloadx.random.x = payload.random.x;//seed

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

			  payload.random.x = payloadx.random.x;
		  }
		  //
		  //center of light is: x=-1.35, y=0.7f, z=1.35
		  //float3 light_pos = float3(-1.35, 0.7, 1.35);
		  //float3 dir_shadow_ray = light_pos - hitLocation;
		  //dir_shadow_ray = normalize(dir_shadow_ray);
		  //
		  payloadx.hit_info.x = 0.0;
		  payloadx.hit_info.y = 0.0;// (into && (cos2t >= 0.0)) ? 0.0f : 2.0f;//shadow ray
		  payloadx.hit_info.z = cur_depth + 1;
		  payloadx.random.x = payload.random.x;//seed
		  //
		  //ray.Origin = float3(d.x, -d.y, 1);
		  //cxn4689
		  //float3 offset_fix = (into && (cos2t >= 0.0)) ? (RFR * 0.001) : float3(0, 0, 0);
		  ray.Origin = hitLocation;// +offset_fix;
		  ray.Direction = (cos2t < 0.0) ? R : RFR;
		  //assume 20% reflection
		  //uint seed = (uint)payloadx.random.x;
		  //if (seed % 5 == 4)
		  //{
			//  ray.Direction = R;
		  //}

		  ray.TMin = 0.001;
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
		  payload.random.x = payloadx.random.x;
		  if (into && 0)
		  {
			  payload.colorAndDistance.rgb = reflect_color * 0.2 + payloadx.colorAndDistance.rgb * 0.8;
		  }
		  else
		  {
			  payload.colorAndDistance = payloadx.colorAndDistance;
		  }
		  //payload.colorAndDistance = (into == 0) ? float4(0.0, 1.0 , 0.0, 1.0) : float4(1.0,0.0,0.0,1.0);// payloadx.colorAndDistance;
		  payload.hit_info.x = (float)inst_index_TLAS;
		  payload.hit_info.z = cur_depth - 1;
	  }
	  else
	  {
		  payload.hit_info.x = (float)inst_index_TLAS;
		  payload.colorAndDistance = float4(float3(0, 0, 0), RayTCurrent());
		  payload.hit_info.z = cur_depth - 1;
	  }
  }
  else//shadow ray probe, don't do recursive
  {
	  payload.hit_info.x = (float)inst_index_TLAS;
	  payload.colorAndDistance = float4(hitColor, RayTCurrent());
  }
#else
float3 barycentrics =
float3(1.f - attrib.bary.x - attrib.bary.y, attrib.bary.x, attrib.bary.y);

uint vertId = 3 * PrimitiveIndex();
uint primId = PrimitiveIndex();

/*float3 hitColor = BTriAttrib[primId].attrib.xyz * barycentrics.x +
	BTriAttrib[primId].attrib.xyz * barycentrics.y +
	BTriAttrib[primId].attrib.xyz * barycentrics.z;*/
	/*float3 hitColor = { 1.0, 0.0, 0.0 };*/
float3 hitColor = float3(0.0, 0.6, 1.0) * barycentrics.x +
float3(0.6, 0.0, 0.6) * barycentrics.y +
float3(0.6, 0.6, 0.0) * barycentrics.z;

uint inst_index_TLAS = InstanceIndex();

float3 norm = BTriAttrib[primId].norm;
norm = normalize(norm);

HitInfo payloadx;
//
float cur_depth = payload.hit_info.z + 1;

//diffuse surface

float DIST = RayTCurrent();

if (payload.hit_info.y == 0.0f)//primary ray
{
	//trace shadow ray
	//https://docs.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-sqrt
	//float3 hitLocation = ObjectRayOrigin() + ObjectRayDirection() * (RayTCurrent());//this is BLAS space (without transform matrix)
	float3 hitLocation = WorldRayOrigin() + WorldRayDirection() * RayTCurrent();
	/*
		// update payload for surface
	// trace reflection
	float3 worldRayOrigin = WorldRayOrigin() + WorldRayDirection() *
		RayTCurrent();

	float3 worldNormal = mul(attr.normal, (float3x3)ObjectToWorld3x4());
	RayDesc reflectedRay = { worldRayOrigin, SceneConstants.Epsilon,
							  ReflectRay(WorldRayDirection(), worldNormal),
							  SceneConstants.TMax };
	*/
	float3 norm = BTriAttrib[primId].norm;
	norm = normalize(norm);
	float3 ray_dir = ObjectRayDirection();
	ray_dir = normalize(ray_dir);
	//center of light is: x=-1.35, y=0.7f, z=1.35
	float3 light_pos = LIGHT_POS;
	float3 dir_shadow_ray = light_pos - hitLocation;
	float distant_to_light_square = dot(dir_shadow_ray, dir_shadow_ray);
	dir_shadow_ray = normalize(dir_shadow_ray);
	float cos_n = abs(dot(norm, dir_shadow_ray));
	//
	payloadx.hit_info.y = 1.0f;//shadow ray
	payloadx.hit_info.z = cur_depth + 1;
	//
	RayDesc ray;
	//ray.Origin = float3(d.x, -d.y, 1);
	//cxn4689
	ray.Origin = hitLocation;
	ray.Direction = dir_shadow_ray;

	payloadx.random.x = payload.random.x;

	ray.TMin = 0.001;
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
	payload.random.x = payloadx.random.x;
	uint cant_hit_light = 0;
	if (payloadx.hit_info.x != 4.0f)//not light source
	{
		cant_hit_light = 1.0;
	}
	//
	float3 direct_illumination = float3(0, 0, 0);
	//tracing secondary ray
	float3 indirect_lit = float3(0, 0, 0);
	float3 cos_indrct_n = float3(0, 0, 0);
	if (cur_depth < 5 && USE_INDRCT)
	{
		//create base
		/*
			double r1=2*M_PI*erand48(Xi), r2=erand48(Xi), r2s=sqrt(r2);
			Vec w=nl, u=((fabs(w.x)>.1?Vec(0,1):Vec(1))%w).norm(), v=w%u;
			Vec d = (u*cos(r1)*r2s + v*sin(r1)*r2s + w*sqrt(1-r2)).norm();
		*/
		float in_or_out = dot(norm, ray_dir);
		//from smallpt
		float3 nl = (in_or_out < 0) ? norm : (norm * -1);
		LCGRand randx;
		randx.state = asuint(payload.random.x);
		float r1 = lcg_randomf(randx) * 2.0 * MI_PI;
		float r2 = lcg_randomf(randx);
		payload.random.x = asfloat(randx.state);
		float3 w = nl;
		float3 u = (abs(w.x) > 0.1) ? float3(0.0, 1.0, 0.0) : float3(1.0, 0.0, 0.0);
		u = cross(u, w);
		u = normalize(u);
		float3 v = cross(w, u);
		float r2s = sqrt(r2);
		float3 dir_diffuse = u * (cos(r1) * r2s) + v * (sin(r1) * r2s) + w * (sqrt(1 - r2));
		dir_diffuse = normalize(dir_diffuse);
		cos_indrct_n = abs(dot(norm, dir_diffuse));
		//
		HitInfo payloady;
		payloady.hit_info.y = 0.0f;
		payloady.hit_info.z = cur_depth + 1;
		//
		RayDesc ray;
		//ray.Origin = float3(d.x, -d.y, 1);
		//cxn4689
		ray.Origin = hitLocation;
		ray.Direction = dir_diffuse;

		payloady.random.x = payload.random.x;// +dot(hitLocation, hitLocation);

		ray.TMin = 0.001;
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
			payloady);
		payload.random.x = payloady.random.x;
		indirect_lit = payloady.colorAndDistance.xyz;

		if (payloady.hit_info.x == 4)
		{
			indirect_lit = float3(0, 0, 0);
		}
#if DEBUG_RANDOM_NUM
		float a1 = lcg_randomf(randx);
		float a2 = lcg_randomf(randx);
		float a3 = lcg_randomf(randx);
		indirect_lit = float3(a1,a2,a3);
#endif
	}
	else
	{
		//no light
		//light size R = 0.1
	}
	//
	float3 direct_lit = float3(0, 0, 0);
	if (cant_hit_light == 0)//calculate direct light
	{
		/*
	double cos_a_max = sqrt(1-s.rad*s.rad/(x-s.p).dot(x-s.p));
	  double omega = 2*M_PI*(1-cos_a_max);
	  e = e + f.mult(s.e*l.dot(nl)*omega)*M_1_PI;  // 1/pi for brdf
		*/
		float cos_a_max = 1 - (0.1*0.1) / distant_to_light_square;
		cos_a_max = sqrt(cos_a_max);
		float omega = 2 * MI_PI * (1 - cos_a_max);
		direct_lit = LIGHT_E * (omega * (1 / MI_PI)) * cos_n;
	}
	//
	float3 final_color = direct_lit * hitColor + indirect_lit * hitColor *cos_indrct_n;
#ifdef DEBUG_RANDOM_NUM
	final_color = indirect_lit;
#endif
#if 0
	if (DIST > 1)
	{
		final_color = float3(1, 0, 0);
	}
#endif
	//
	payload.hit_info.x = (float)inst_index_TLAS;
	payload.colorAndDistance = float4(final_color, DIST);
	payload.hit_info.z = cur_depth - 1;
}
else
{
	payload.hit_info.x = (float)inst_index_TLAS;
	payload.colorAndDistance = float4(hitColor, DIST);
}
#endif
}
