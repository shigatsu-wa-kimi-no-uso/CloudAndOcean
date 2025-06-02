#ifndef COMMON_SHADER_UTILS_HLSL
#define COMMON_SHADER_UTILS_HLSL
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"


float GetSceneDepth(float2 screenUV)
{
    #if UNITY_REVERSED_Z
    float depth = SampleSceneDepth(screenUV);
    #else
    float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(screenUV));
    #endif
    return depth;
}
	
float GetLinearEyeDepthFromRawZ(float rawDepth)
{
    return LinearEyeDepth(rawDepth, _ZBufferParams);
}

float GetLinearEyeDepthFromScene(float2 screenUV)
{
    return LinearEyeDepth(GetSceneDepth(screenUV), _ZBufferParams);
}

float4 TransformWorldToScreenspace(float3 pointWS)
{
    float4 pointHCS = TransformWorldToHClip(pointWS);
    float3 pointNDC = pointHCS.xyz / pointHCS.w;
    float2 pointSS = pointNDC.xy*0.5+0.5;
    pointSS.y = 1 - pointSS.y;
		
    return float4(pointSS,pointNDC.z, pointHCS.w);
}

float3 TransformScreenspaceToWorld(float2 screenUV){
    #if UNITY_REVERSED_Z
    float depth = SampleSceneDepth(screenUV);
    #else
    float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(uv));
    #endif
    return ComputeWorldSpacePosition(screenUV, depth, UNITY_MATRIX_I_VP);
}

float3 GetOpaqueSceneGeometryNormal(float2 screenUV)
{
    float3 pointWS = TransformScreenspaceToWorld(screenUV);
    float3 dx = ddx(pointWS);
    float3 dy = ddy(pointWS);
    float3 normal = normalize(cross(dx, dy));
    return normal;
}


float3 GetOpaqueSceneGeometryNormal(float2 screenUV,float3 frontDir)
{
    float3 normal = GetOpaqueSceneGeometryNormal(screenUV);
    if (dot(normal, frontDir) < 0){
        normal = -normal;
    }
    return normal;
}


float3 GetOpaqueSceneGeometryNormal(float2 screenUV,float2 screenUVDelta)
{
    float3 normal = GetOpaqueSceneGeometryNormal(screenUV);
    float3 normal2 = GetOpaqueSceneGeometryNormal(screenUV + float2(1,0)*screenUVDelta);
    float3 normal3 = GetOpaqueSceneGeometryNormal(screenUV + float2(0,1)*screenUVDelta);
    float3 normal4 = GetOpaqueSceneGeometryNormal(screenUV + float2(-1,0)*screenUVDelta);
    float3 normal5 = GetOpaqueSceneGeometryNormal(screenUV + float2(0,-1)*screenUVDelta);
    float3 normal6 = GetOpaqueSceneGeometryNormal(screenUV + float2(1,1)*screenUVDelta);
    float3 normal7 = GetOpaqueSceneGeometryNormal(screenUV + float2(-1,-1)*screenUVDelta);
    float3 result = normalize((normal + normal2 + normal3 + normal4 + normal5 + normal6 + normal7)/8);
    return result;
}

float3 GetOpaqueSceneGeometryNormal(float2 screenUV,float2 screenUVDelta,float3 viewDir)
{
    float3 normal = GetOpaqueSceneGeometryNormal(screenUV, screenUVDelta);
    if (dot(normal, viewDir) < 0){
        normal = -normal;
    }
    float3 dnormalx = ddx(normal);
    float3 dnormaly = ddy(normal);
    normal = normalize((normal*3 + (dnormalx + dnormaly))/3);
    return normal;
}


float3 GetOpaqueSceneGeometryNormal2(float2 screenUV,float2 deltaUV,float3 frontDir)
{
    
    float3 pointWS = TransformScreenspaceToWorld(screenUV);
    float3 dx = TransformScreenspaceToWorld(screenUV + 10*float2(deltaUV.x,0)) - pointWS;
    float3 dy = TransformScreenspaceToWorld(screenUV + 10*float2(0,deltaUV.y)) - pointWS;
    float3 dx2 = pointWS - TransformScreenspaceToWorld(screenUV + 2*float2(-deltaUV.x,0));
    float3 dy2 = pointWS - TransformScreenspaceToWorld(screenUV + 2*float2(0,-deltaUV.y));
    if (abs(dx.z) > abs(dx2.z))
    {
   //     dx = dx2;
    }
    if (abs(dy.z) > abs(dy2.z))
    {
   //     dy = dy2;
    }
    float3 normal = normalize(cross(dx,dy));
    if (dot(normal, frontDir) < 0)
    {
        normal = -normal;
    }
    return normal;
}



#endif