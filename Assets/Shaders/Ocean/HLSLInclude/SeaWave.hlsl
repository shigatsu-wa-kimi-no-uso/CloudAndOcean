#ifndef SEAWAVE_HLSL_H
#define SEAWAVE_HLSL_H

#include "SeaWaveHelperStructs.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

void DistortUV(float3 normal,float4 screenPos,float distortionIntensity,inout float2 uv)
{
    // dividing by w is needed.
    //https://catlikecoding.com/unity/tutorials/flow/looking-through-water/
    uv+= normal.xz*distortionIntensity/screenPos.w;//*screenPos.z/screenPos.w;
    //	HoleUV = (ScreenPosOrg.xy +  FlowRiverRefrac.xy / 10 * RiverRefractionLevel * 2) / ScreenPosOrg.w;
    //	HoleUV.x = ScreenPosOrg.x / ScreenPosOrg.w;
}


DistantWaveResult DistantWaveMorphing(DistantWaveParams waveParams,float2 uv,float2 direction){
    DistantWaveResult result;
    uv *= waveParams.uvScale;
    float index = fmod(waveParams.fps*waveParams.time,waveParams.frameCount);
	float thisIndex = floor(index);
	float nextIndex = ceil(index);
	float t = frac(index);
    float sr = sin(DegToRad(waveParams.uvRotate));
    float cr = cos(DegToRad(waveParams.uvRotate));
	float sd = direction.y;
    float cd = direction.x;
    float s = sd*cr - cd*sr;
    float c = cd*cr + sd*sr;
    float2 uvRotated = float2(dot(uv,float2(c,s)),dot(uv,float2(-s,c)));
    float4 waveVertexDisplacement1 = waveParams.distantWaveMap.SampleLevel(waveParams.mapSampler,float3(uvRotated,thisIndex),0)*2.0f - 1.0f;
	float4 waveVertexDisplacement2 = waveParams.distantWaveMap.SampleLevel(waveParams.mapSampler,float3(uvRotated,nextIndex),0)*2.0f - 1.0f;
	float4 waveVertexDisplacement = lerp(waveVertexDisplacement1,waveVertexDisplacement2,t);
    waveVertexDisplacement = waveVertexDisplacement*waveParams.displacementScale;
    result.positionDisplacement = waveVertexDisplacement.xyz;
    result.velocity = waveVertexDisplacement.xz*0.025f;
    return result;
}


NearshoreWaveResult NearshoreWaveMorphing(NearshoreWaveParams waveParams,float4 terrainData)
{
    NearshoreWaveResult result;
    float2 gradient = terrainData.gb*2.0f - 1.0f;
    float distToShore = terrainData.r * waveParams.waveCount;
    float u = frac(distToShore + waveParams.time * waveParams.waveSpeed);	//vertex displacement
    float v = (distToShore - u)/waveParams.waveCount;		//frame
    if (waveParams.inverseUV.x){
        u = 1 - u;
    }
    if (waveParams.inverseUV.y){
        v = 1 - v;
    }
    
    float4 wave = tex2Dlod(waveParams.waveMap,float4(u,v,0,0))*2.0f - 1.0f;
    float3 waveForward = float3(gradient.x,0,gradient.y)*waveParams.waveForwardScale;
    float3 waveUpward = float3(0,1,0)*waveParams.waveUpwardScale;
    float3 offsetForward = wave.x*waveForward;
    float3 offsetUpward = wave.y*waveUpward;
    result.positionDisplacement = (offsetForward + offsetUpward) * (terrainData.r);
    result.velocity = (offsetForward.xz - gradient)*saturate(distToShore*0.005f);
    result.foamMask = wave.b*0.5f + 0.5f; // foam mask
    return result;
}	
	

float2 GetNearDistMask(float2 terrainUV, float3 terrainData){
    float2 uvBound0 = step(float2(0.0,0.0),terrainUV);
    float2 uvBound1 = step(terrainUV,float2(1,1));
    float2 nearDistMask;
    nearDistMask.x = 1;
    nearDistMask.x *= uvBound0.x*uvBound1.x*uvBound0.y*uvBound1.y;
    nearDistMask.x = 1 - step(0.9,terrainData.r);	// dist:1 near:0
    nearDistMask.y = smoothstep(0.85,1,terrainData.r); //near to dist smoothstep 0->1
    return nearDistMask;
}

	
DetailWaveData SampleDetailWaveMap(DetailWaveParams detailWaveParams,float2 uv,float time)
{
	float2 detailMapUV = uv*detailWaveParams.uvScale;
	sampler2D detailMap = detailWaveParams.detailWaveMap;
	float detailSpeed = detailWaveParams.speed;
	float2 detailDir1 = normalize(detailWaveParams.direction);
	float2 detailDir2 = normalize(detailWaveParams.direction + float2(1,1));
	float2 detailDir3 = normalize(detailWaveParams.direction + float2(-1,1));
	float2 detailDir4 = normalize(detailWaveParams.direction + float2(1,-1));
		
	float4 detail1 = FlowSample(detailMap,detailMapUV,detailDir1*detailSpeed,time)*2 - 1;
	float4 detail2 = FlowSample(detailMap,detailMapUV,detailDir2*detailSpeed,time)*2 - 1;
	float4 detail3 = FlowSample(detailMap,detailMapUV, detailDir3*detailSpeed,time)*2 - 1;
	float4 detail4 = FlowSample(detailMap,detailMapUV,detailDir4*detailSpeed,time)*2 - 1;
	float4 detail  = (detail1+detail2+detail3+detail4)/4.0f;
	DetailWaveData result;
	result.normalDisplacement.xz = detail.rg*detailWaveParams.normalDisplacementScale;
	result.normalDisplacement.y = 0;
	result.positionDisplacement.y = detail.b*detailWaveParams.positionDisplacementScale;
	result.positionDisplacement.xz = float2(0,0);
	result.foamMask = detail.a*0.5 + 0.5;
	result.foamMask = clamp(result.foamMask - detailWaveParams.foamThreshold,0,1)*detailWaveParams.foamIntensity;
	return result;
}



FoamMapData SampleFoamMap(FoamMapParams foamMapParams,float2 uv,float2 velocity,float time){
	float2 foamUV = uv*foamMapParams.foamMapUVScale;
	float4 foam = MixedSample(foamMapParams.foamMap,foamUV,velocity,time)*2.0f - 1.0f;
	FoamMapData result;
	result.normalDisplacement.xz = foam.rg*foamMapParams.foamMapScale;
	result.normalDisplacement.y = 0;
	result.positionDisplacement.y = foam.b*foamMapParams.foamMapScale;
	result.positionDisplacement.xz = float2(0,0);
	result.foamAlpha = foam.a*0.5 + 0.5;
	return result;
}
	
	





#endif