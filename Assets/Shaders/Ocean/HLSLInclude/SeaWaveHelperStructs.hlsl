#ifndef SEAWAVES_HELPER_STRUCTS_HLSL
#define SEAWAVES_HELPER_STRUCTS_HLSL

struct TerrainParams
{
	sampler2D terrainMap;
	float4 terrainMap_TexelSize;
	float3 axisU;
	float3 axisV;
	float3 axisOrigin;
	float mapSizeU;
	float mapSizeV;
	bool inverseSDFRange;
	bool2 inverseGradient;
};

struct FoamMapParams
{
	sampler2D foamMap;
	float foamMapUVScale;
	float foamMapScale;
};

struct FoamMapData
{
	float3 normalDisplacement;
	float3 positionDisplacement;
	float foamAlpha;
};

struct FluxLightingParams
{
	sampler2D reflectionTex;
	float4 reflectionTex_TexelSize;
	float4 waterTransmissionColor;
	float4 waterSurfaceColor;
	float depthScale;
	float indexOfRefraction;
	float screenUVDistortionIntensity;
	float3 scatteringDetail;
	float scatteringPower;
	float scatteringScale;
};


struct DetailWaveParams
{
	sampler2D detailWaveMap;
	float2 uvScale;
	float positionDisplacementScale;
	float normalDisplacementScale;
	float speed;
	float2 direction;
	float foamThreshold;
	float foamIntensity;

};

struct DetailWaveData
{
	float3 normalDisplacement;
	float3 positionDisplacement;
	float foamMask;
};

struct DistantWaveParams
{
	Texture2DArray distantWaveMap;
	SamplerState mapSampler;
	float uvScale;
	float uvRotate;
	float displacementScale;
	float frameCount;
	float fps;
	float time;
	float2 direction;
};


struct NearshoreWaveParams
{
	sampler2D waveMap;
	float4 waveMap_TexelSize;
	float waveSpeed;
	float waveCount;
	float waveForwardScale;
	float waveUpwardScale;
	float time;
	float foamIntensity;
	bool2 inverseUV;
};

struct NearshoreWaveResult
{
	float3 positionDisplacement;
	float2 velocity;
	float foamMask;
};


struct DistantWaveResult
{
	float3 positionDisplacement;
	float2 velocity;
};
#endif
