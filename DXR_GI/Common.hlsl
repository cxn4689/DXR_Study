// Hit information, aka ray payload
// This sample only carries a shading color and hit distance.
// Note that the payload should be kept as small as possible,
// and that its size must be declared in the corresponding
// D3D12_RAYTRACING_SHADER_CONFIG pipeline subobjet.

struct HitInfo {
	float4 colorAndDistance;
	float4 hit_info;//[0] instance id, [1] Ray type: 0 primary ray 1: shadow ray  2: reflection ray [2] recursive depth
	float4 random;//[0] seed [1-3] RSVL
};

// Attributes output by the raytracing when hitting a surface,
// here the barycentric coordinates
struct Attributes {
  float2 bary;
};

#define MI_PI 3.1415926
#define LIGHT_E float3(100, 100,100)
#define LIGHT_POS float3(-1.35, 0.7, 0.05)

struct LCGRand {
	uint32_t state;
};

uint32_t lcg_random(inout LCGRand rng)
{
	const uint32_t m = 1664525;
	const uint32_t n = 1013904223;
	rng.state = rng.state * m + n;
	return rng.state;
}

float lcg_randomf(inout LCGRand rng)
{
	return ldexp((float)lcg_random(rng), -32) * 1.0f;
}

#define ACCUME_STEP 1024.0
#define SAMPLE_NUM 4096

#define TMP_X 1

#define USE_INDRCT 1

#define USE_GLASS 1
#define USE_MIRROR 1

//#define DEBUG_RANDOM_NUM 1

#if 0
struct test_t
{
	float4 col;
};
float4 test2(inout test_t a)
{
	a.col = float4(0, 0, 0, 0);
	return float4(1, 0, 0, 0);;
}

float4 test1(inout test_t a)
{
	return test2(a);
}
#endif