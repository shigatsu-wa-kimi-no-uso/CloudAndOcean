#ifndef RAY_MARCHING_UTILS_HLSL
#define RAY_MARCHING_UTILS_HLSL
#include "RandomNumberUtils.hlsl"

struct RayMarchingConfig {
    float validDistance;
    float3 entryPoint;
    float3 stepVector;
    float stepSize;
};


struct BoundingBoxHitResult {
    float distToBox;
    float distInsideBox;
};


BoundingBoxHitResult CalcBoundingBoxRayHit(in float3 boundsMin,in float3 boundsMax,in float3 rayOrigin,in float3 rayDirection) {
    // 1. separate ray movement and box volume to x,y,z
    // 2. calculate ray arrival of box separately: (bmin.x/d.x,bmin.y/d.y,bmin.z/d.z),(bmax.x/d.x,bmax.y/d.y,bmax.z/d.z)
    // 3. put results in proper order: for each axis's value, the larger value is the 'ray out', the smaller value is the 'ray in'
    // 4. find out when the ray hits and enters the box: max value of the 'ray in' timepoint which separates into x,y,z, and min value of 'ray out'
    // 5. because the ray direction vector is a unit vector, time of ray enter is just the distance between ray origin and the hitpoint on the box.

    float3 t0 = (boundsMin - rayOrigin) / rayDirection;
    float3 t1 = (boundsMax - rayOrigin) / rayDirection;
    float3 tmin = min(t0, t1);
    float3 tmax = max(t0, t1);

    float distA = max(max(tmin.x, tmin.y), tmin.z);
    float distB = min(tmax.x, min(tmax.y, tmax.z));
    BoundingBoxHitResult result;
                    // also works for case that ray origin being originally inside the bounding box.
    result.distToBox = max(0, distA);
    result.distInsideBox = max(0, distB - result.distToBox);
    return result;
}



RayMarchingConfig GetRayMarchingConfig(in float3 boundsMin, in float3 boundsMax, in float3 rayOrigin, in float3 rayDirection,in float3 rayHitPoint,in int maxIteration) {
    BoundingBoxHitResult rayHitResult = CalcBoundingBoxRayHit(boundsMin, boundsMax, rayOrigin, rayDirection);
    RayMarchingConfig config;
    
    float distToOpaqueHitPnt = length(rayHitPoint - rayOrigin);
    config.validDistance = min(rayHitResult.distInsideBox, distToOpaqueHitPnt - rayHitResult.distToBox);
    config.entryPoint = rayOrigin + rayDirection * rayHitResult.distToBox;
    config.stepSize = config.validDistance / maxIteration;
    config.stepVector = rayDirection * config.stepSize;
    
    return config;
}


float3 JitterStepVector(float jitterRange,float3 stepVector)
{
    float r = Get01RandomWithTimeSeed(stepVector.x,stepVector.z);
    r = (r*2 - 1)*min(jitterRange,0.3);
    return stepVector + stepVector * r;
}

// get a value within [samplePoint - jitterRange,samplePoint + jitterRange]
float3 JitterSamplePoint(float3 previousPoint,float jitterRange,float3 stepVector) {
   // float r = GetRandom(jitterRange);
    float3 jitteredStepVector = JitterStepVector(jitterRange,stepVector);
    return previousPoint + jitteredStepVector;
}





#endif // RAY_MARCHING_UTILS_HLSL