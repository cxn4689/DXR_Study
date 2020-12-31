#include "Common.hlsl"

struct STriVertex {
  float3 vertex;
  float4 color;
};

struct STriAttrib {
	float4 attrib;
	float4 norm;
};

StructuredBuffer<STriVertex> BTriVertex : register(t0,space303);
RaytracingAccelerationStructure SceneBVH : register(t1,space303);
StructuredBuffer<STriAttrib> BTriAttrib : register(t2, space303);

[shader("closesthit")] void ClosestHit2(inout HitInfo payload,
                                       Attributes attrib) {
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

	float DIST = RayTCurrent();

	//diffuse surface

	if (payload.hit_info.y == 0.0f)//primary ray
	{
		//trace shadow ray
		//https://docs.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-sqrt
		//float3 hitLocation = ObjectRayOrigin() + ObjectRayDirection() * (RayTCurrent());//this is BLAS space (without transform matrix)
		float3 hitLocation = WorldRayOrigin() + WorldRayDirection() * RayTCurrent();
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

		payloadx.random.x = payload.random.x;// +1280 * 720;

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
		float3 final_color = direct_lit * hitColor + indirect_lit * hitColor  * cos_indrct_n;
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
}
