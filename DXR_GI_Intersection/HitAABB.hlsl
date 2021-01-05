#include "Common.hlsl"

struct AABBBufferT {
  float3 vertex;
  float4 color;
};

struct AABBPropertyT {
	float4 pos;
	float4 color;
};

StructuredBuffer<AABBBufferT> BTriVertex : register(t0,space306);
RaytracingAccelerationStructure SceneBVH : register(t1,space306);
StructuredBuffer<AABBPropertyT> BTriAttrib : register(t2, space306);

struct STlightPos {
	float4 pos;//w = light num
};
StructuredBuffer<STlightPos> BLightPos : register(t3, space306);

//assume this is glass

[shader("intersection")] void IntersectionAABB() {
	Attributes attr;
	attr.bary.xy = float2(1.0, 0);
	float thit = 1.0;
	//Ray localRay = GetRayInAABBPrimitiveLocalSpace();
#if 0
	ReportHit(thit, /*hitKind*/ 1, attr);
	/*
	uint HitKind	A value used to identify the type of hit. 
	This is a user-specified value in the range of 0-127. 
	The value can be read by any hit or closest hit shaders with the HitKind() intrinsic.
	*/
#else
	float3 ray_origin = WorldRayOrigin();
	float3 ray_dir = WorldRayDirection();
	//sphere interction from smallpt
	float3 pos = BTriAttrib[0].pos.xyz;
	float  rad = BTriAttrib[0].pos.w;
	/*
  double intersect(const Ray &r) const { // returns distance, 0 if nohit
	Vec op = p-r.o; // Solve t^2*d.d + 2*t*(o-p).d + (o-p).(o-p)-R^2 = 0
	double t, eps=1e-4, b=op.dot(r.d), det=b*b-op.dot(op)+rad*rad;
	if (det<0) return 0; else det=sqrt(det);
	return (t=b-det)>eps ? t : ((t=b+det)>eps ? t : 0);
  }
	*/
	ray_dir = normalize(ray_dir);
	float3 op = pos - ray_origin;
	float eps = 0.0001;
	float b = dot(op, ray_dir);
	float det = b * b - dot(op, op) + rad * rad;
	float t = 1;
#if 0
	if (pos.x == 0 && pos.y == 0 && pos.z == 0.0 && rad == 0.1)
	{
		//if(b < 0)
		if(length(ray_origin) > 10)
			ReportHit(thit, /*hitKind*/ 1, attr);
	}
#else
	//ReportHit(thit, /*hitKind*/ 1, attr);
	if (det < 0)
	{
		//not hit
		//ReportHit(t, /*hitKind*/ 1, attr);
	}
	else
	{
		det = sqrt(det);
		t = b - det;
		if (t > eps && t > 0 && t < 10000)
		{
			ReportHit(t, /*hitKind*/ 1, attr);
		}
		else
		{
			t = b + det;
			if (t > eps && t > 0 && t < 10000)
			{
				ReportHit(t, /*hitKind*/ 1, attr);
			}
			else
			{
				//miss
				//ReportHit(t, /*hitKind*/ 1, attr);
			}
		}
	}
#endif
#endif
}

[shader("anyhit")] void AnyHitAABB(inout HitInfo payload,
	Attributes attrib) {
	//IgnoreHit();
#if 0
	payload.colorAndDistance.xyz = float3(1, 0, 0);//R is anyhit
#endif
#if 0//0 has extra cost but same effect as only closet hit
	AcceptHitAndEndSearch();
#endif
}

[shader("closesthit")] void ClosestHitAABB(inout HitInfo payload,
                                       Attributes attrib) {

  float3 barycentrics =
      float3(1.f - attrib.bary.x - attrib.bary.y, attrib.bary.x, attrib.bary.y);

  uint primId = PrimitiveIndex();
 
  /*float3 hitColor = BTriAttrib[primId].attrib.xyz * barycentrics.x +
	  BTriAttrib[primId].attrib.xyz * barycentrics.y +
	  BTriAttrib[primId].attrib.xyz * barycentrics.z;*/
  /*float3 hitColor = { 1.0, 0.0, 0.0 };*/
  /*float3 hitColor = float3(0.0,0.6,1.0) * barycentrics.x +
	  float3(0.6, 0.0, 0.6) * barycentrics.y +
	  float3(0.6, 0.6, 0.0) * barycentrics.z;*/
#if 1 //0 use any hit color
  float3 hitColor = BTriAttrib[0].color.xyz;//G is closet hit
#else
  //nothing
  float3 hitColor = payload.colorAndDistance.xyz;
#endif
  uint inst_index_TLAS = InstanceIndex();

  float DIST = RayTCurrent();
  //
  float cur_depth = payload.hit_info.z + 1;

  //diffuse surface
  float3 pos = BTriAttrib[0].pos.xyz;
  float3 hitLocation = WorldRayOrigin() + WorldRayDirection() * (RayTCurrent());
  float3 norm = hitLocation - pos;
  norm = normalize(norm);
  //

  if (payload.hit_info.y == 0.0f && cur_depth < 5)//primary ray
  {
#ifndef _USE_PURE_SPHERE_REFLECTION_
	  if (cur_depth < 5)
	  {
		  //trace shadow ray
		  //
		  //float3 hitLocation = ObjectRayOrigin() + ObjectRayDirection() * (RayTCurrent());//this is BLAS space (without transform matrix)
		  float3 hitLocation = WorldRayOrigin() + WorldRayDirection() * RayTCurrent();
		  //into or leave 
		  float3 ray_dir = WorldRayDirection();
		  ray_dir = normalize(ray_dir);
		  //float3 norm = BTriAttrib[primId].norm;
		  //norm = normalize(norm);
		  float in_or_out = dot(norm, ray_dir);
		  //from smallpt
		  float3 nl = (in_or_out < 0) ? norm : (norm * -1);
		  uint into = (dot(norm, nl) > 0) ? 1 : 0;
		  float nt = 1.1, nc = 1.0;
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
		  //
		  /*
		  if ((cos2t=1-nnt*nnt*(1-ddn*ddn))<0)    // Total internal reflection
			Vec tdir = (r.d*nnt - n*((into?1:-1)*(ddn*nnt+sqrt(cos2t)))).norm();
			double a=nt-nc, b=nt+nc, R0=a*a/(b*b), c = 1-(into?-ddn:tdir.dot(n));
			double Re=R0+(1-R0)*c*c*c*c*c,Tr=1-Re,P=.25+.5*Re,RP=Re/P,TP=Tr/(1-P);
			return obj.e + f.mult(depth>2 ? (erand48(Xi)<P ?   // Russian roulette
			radiance(reflRay,depth,Xi)*RP:radiance(Ray(x,tdir),depth,Xi)*TP) :
			radiance(reflRay,depth,Xi)*Re+radiance(Ray(x,tdir),depth,Xi)*Tr);
		  */
		  float3 tdir = RFR;// ray_dir * nnt - norm * ((into ? 1.0 : -1.0)*(ddn*nnt + sqrt(cos2t)));
		  tdir = normalize(tdir);
		  float a = nt - nc, b = nt + nc, R0 = a * a / (b*b), c = 1 - (into ? -ddn : dot(tdir, norm));
		  float Re = R0 + (1 - R0)*c*c*c*c*c, Tr = 1 - Re, P = .25 + .5*Re, RP = Re / P, TP = Tr / (1 - P);

		  LCGRand randx;
		  randx.state = asuint(payload.random.x);
		  float r1 = lcg_randomf(randx);
		  payload.random.x = asfloat(randx.state);
		  uint use_reflect = (cur_depth <= 2) || (r1 < P);

		  RayDesc ray;

		  HitInfo payloadx;
#if 1
		  if (use_reflect)
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
#endif
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
		  ray.Direction = RFR;// (cos2t < 0.0) ? R : RFR;
		  //assume 20% reflection
		  //uint seed = (uint)payloadx.random.x;
		  //if (seed % 5 == 4)
		  //{
			//  ray.Direction = R;
		  //}

		  ray.TMin = 0.001;
		  ray.TMax = 100000;
		  //
		  if (cos2t >= 0)
		  {
			  TraceRay(
				  SceneBVH,
				  RAY_FLAG_NONE,
				  0xFF,
				  0,
				  0,
				  0,
				  ray,
				  payloadx);
		  }
		  payload.random.x = payloadx.random.x;
		  if (into && 0)
		  {
			  payload.colorAndDistance.rgb = reflect_color * 0.3 + payloadx.colorAndDistance.rgb * 0.7;
		  }
		  else
		  {
			  //payload.colorAndDistance = payloadx.colorAndDistance;
			  /*return obj.e + f.mult(depth > 2 ? (erand48(Xi) < P ?   // Russian roulette
				  radiance(reflRay, depth, Xi)*RP : radiance(Ray(x, tdir), depth, Xi)*TP) :
				  radiance(reflRay, depth, Xi)*Re + radiance(Ray(x, tdir), depth, Xi)*Tr);*/
			  if (cur_depth > 2)
			  {
				  if (r1 < P)
				  {
					  payload.colorAndDistance.rgb = reflect_color * RP;
				  }
				  else
				  {
					  payload.colorAndDistance.rgb = payloadx.colorAndDistance.rgb * TP;
				  }
			  }
			  else
			  {
				  payload.colorAndDistance.rgb = reflect_color * Re + payloadx.colorAndDistance.rgb * Tr;
			  }
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
#else
#if 1
	  HitInfo payloadx;
	  float3 I = WorldRayDirection();
	  I = normalize(I);
	  float3 N = norm;
	  float3 R = I - (2.0 * dot(I, N) * N);
	  //
	  payloadx.hit_info.y = 0.0f;
	  payloadx.hit_info.z = cur_depth + 1;
	  payloadx.random.x = payload.random.x;

	  RayDesc ray;
	  ray.Origin = hitLocation;
	  ray.Direction = R;

	  ray.TMin = 0.01;
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
	  payload.colorAndDistance = float4(payloadx.colorAndDistance.xyz, DIST);
	  payload.hit_info.x = (float)inst_index_TLAS;
#else
	  //trace shadow ray
	  //https://docs.microsoft.com/en-us/windows/win32/direct3dhlsl/dx-graphics-hlsl-sqrt
	  //float3 hitLocation = ObjectRayOrigin() + ObjectRayDirection() * (RayTCurrent());//this is BLAS space (without transform matrix)
	  //float3 hitLocation = WorldRayOrigin() + WorldRayDirection() * (RayTCurrent());
	  payload.hit_info.x = (float)inst_index_TLAS;
	  payload.colorAndDistance = float4(hitColor, DIST);
#endif
#endif
  }
  else
  {
	  payload.hit_info.x = (float)inst_index_TLAS;
	  payload.colorAndDistance = float4(hitColor, DIST);
  }
}
