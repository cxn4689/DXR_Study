// Hit information, aka ray payload
// This sample only carries a shading color and hit distance.
// Note that the payload should be kept as small as possible,
// and that its size must be declared in the corresponding
// D3D12_RAYTRACING_SHADER_CONFIG pipeline subobjet.
struct HitInfo {
	float4 colorAndDistance;
	float4 hit_info;//[0] instance id, [1] Need shadow ray [2] need reflect ray [3] RSVL
	float4 shadow_ray_dir;
	float4 shadow_ray_org;
	float4 reflect_ray_dir;
	float4 reflect_ray_org;
};

// Attributes output by the raytracing when hitting a surface,
// here the barycentric coordinates
struct Attributes {
  float2 bary;
};
