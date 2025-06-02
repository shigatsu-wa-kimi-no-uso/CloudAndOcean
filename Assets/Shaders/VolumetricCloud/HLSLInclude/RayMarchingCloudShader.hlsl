#ifndef RAY_MARCHING_CLOUD_SHADER_HLSL
#define RAY_MARCHING_CLOUD_SHADER_HLSL
#include "RayMarchingUtils.hlsl"
#include "CloudTextureSampler.hlsl"
#include "CloudLightingUtils.hlsl"


struct BoundingBox {
    float3 boundsMax;
    float3 boundsMin;
};

struct Ray {
    float3 origin;
    float3 direction;
    float3 hitPoint;
};


struct TextureSampleConfig {
    float4 valueScale;
    float4 valueOffset;
    float3 coordsScale;
    float3 coordsOffsetSpeed;
};

struct CloudDesc {
    BoundingBox bounds;
    float3 absorptionScatter;
    float3 absorptionLight;
    float3 albedo;
    float hgPhaseG1Factor;
    float hgPhaseG2Factor;
    sampler3D cloudVolumeTexture;
    sampler3D cloudVolumeDetailTexture;
    sampler3D erosionVolumeTexture;
    sampler2D weatherMap;
    TextureSampleConfig cloudTexSampleConfig;
    TextureSampleConfig cloudDetailTexSampleConfig;
    TextureSampleConfig weatherMapSampleConfig;
    TextureSampleConfig erosionTexSampleConfig;
    float timeInSeconds;
    float densityScale;
    float darknessThreshold;
    float beerPowderFactor;
};



struct LightDesc {
    float3 direction;
    float3 color;
};

struct RayMarchingDesc {
    int iteration;
    int scatterMarchIteration;
    float relativeJitterRange;
    Ray ray;
};


float3 GetNextSamplePoint(float3 previousPoint, float jitterRange,float3 stepVector) {
#if defined(_RAYMARCH_JITTER_ON)
    return JitterSamplePoint(previousPoint, jitterRange, stepVector);   
#else
    return previousPoint + stepVector;
#endif
}

CloudVolumeDesc GetCloudVolumeDesc(in CloudDesc cloudDesc, in float3 samplePoint) {
    CloudVolumeDesc cloudVolumeDesc;
    cloudVolumeDesc.cloudVolumeTexture = cloudDesc.cloudVolumeTexture;
    cloudVolumeDesc.cloudVolumeDetailTexture = cloudDesc.cloudVolumeDetailTexture;
    cloudVolumeDesc.sampleDesc.valueAdd = cloudDesc.cloudTexSampleConfig.valueOffset;
    cloudVolumeDesc.sampleDesc.valueMulti = cloudDesc.cloudTexSampleConfig.valueScale;
    cloudVolumeDesc.detailSampleDesc.valueAdd = cloudDesc.cloudDetailTexSampleConfig.valueOffset;
    cloudVolumeDesc.detailSampleDesc.valueMulti = cloudDesc.cloudDetailTexSampleConfig.valueScale;
    cloudVolumeDesc.cloudLayerHeight = cloudDesc.bounds.boundsMax.y - cloudDesc.bounds.boundsMin.y;
    cloudVolumeDesc.sampleHeight = samplePoint.y - cloudDesc.bounds.boundsMin.y;
    cloudVolumeDesc.sampleDesc.uvw = GetTexCoords(samplePoint, cloudDesc.cloudTexSampleConfig.coordsScale, cloudDesc.cloudTexSampleConfig.coordsOffsetSpeed, cloudDesc.timeInSeconds);
    cloudVolumeDesc.detailSampleDesc.uvw = GetTexCoords(samplePoint, cloudDesc.cloudDetailTexSampleConfig.coordsScale, cloudDesc.cloudDetailTexSampleConfig.coordsOffsetSpeed, cloudDesc.timeInSeconds);
    return cloudVolumeDesc;
}

WeatherMapDesc GetWeatherMapDesc(CloudDesc cloudDesc, float3 samplePoint) {
    WeatherMapDesc weatherMapDesc;
    weatherMapDesc.weatherMap = cloudDesc.weatherMap;
    weatherMapDesc.sampleDesc.valueMulti = cloudDesc.weatherMapSampleConfig.valueScale;
    weatherMapDesc.sampleDesc.valueAdd = cloudDesc.weatherMapSampleConfig.valueOffset;
    weatherMapDesc.sampleDesc.uv = GetTexCoords(samplePoint, cloudDesc.weatherMapSampleConfig.coordsScale, cloudDesc.weatherMapSampleConfig.coordsOffsetSpeed, cloudDesc.timeInSeconds).xz;
    return weatherMapDesc;
}

ErosionVolumeDesc GetErosionVolumeDesc(CloudDesc cloudDesc, float3 samplePoint) {
    ErosionVolumeDesc erosionVolumeDesc;
    erosionVolumeDesc.erosionVolumeTexture = cloudDesc.erosionVolumeTexture;
    erosionVolumeDesc.sampleDesc.valueMulti = cloudDesc.erosionTexSampleConfig.valueScale;
    erosionVolumeDesc.sampleDesc.valueAdd = cloudDesc.erosionTexSampleConfig.valueOffset;
    erosionVolumeDesc.sampleDesc.uvw = GetTexCoords(samplePoint, cloudDesc.erosionTexSampleConfig.coordsScale, cloudDesc.erosionTexSampleConfig.coordsOffsetSpeed, cloudDesc.timeInSeconds);
    return erosionVolumeDesc;
}

float3 TransmittancePointToLight(CloudDesc cloudDesc, LightDesc lightDesc, float3 litPoint, int iteration) {
    BoundingBox bounds = cloudDesc.bounds;
    float3 rayOrigin = litPoint;
    float3 rayDir = lightDesc.direction;
    float3 virtualRayHitPoint = rayOrigin + rayDir * 10000;
    
    RayMarchingConfig config = GetRayMarchingConfig(bounds.boundsMin, bounds.boundsMax, rayOrigin, rayDir, virtualRayHitPoint, iteration);
    
    float maxDistance = config.validDistance;

    float3 stepVec = config.stepVector;
    float stepSize = config.stepSize;

    float accumulatedDensity = 0;
    float traveledDist = 0;
    
  
    float3 currSampleIntervalLB =  config.entryPoint;
    float3 absorptionLight =  cloudDesc.absorptionLight;
    float3 tr = float3(1,1,1);
    [loop]
    for (int i = 0; i < iteration; i++) {
        if (traveledDist >= maxDistance) {
            break;
        }
        
        float3 realSamplePoint = currSampleIntervalLB + stepVec*0.5;

        // jitter is never used here
        CloudVolumeDesc cloudVolumeDesc = GetCloudVolumeDesc(cloudDesc, realSamplePoint);
        WeatherMapDesc weatherMapDesc = GetWeatherMapDesc(cloudDesc, realSamplePoint);
        ErosionVolumeDesc erosionVolumeDesc = GetErosionVolumeDesc(cloudDesc, realSamplePoint);
        
        float sampledDensity = 0;
#if defined(_CLOUD_MODIFY_WITH_WEATHERMAP)
        sampledDensity = SampleCloudDensity(cloudVolumeDesc,weatherMapDesc,cloudDesc.densityScale);
#elif defined(_CLOUD_MODIFY_WITH_EROSIONVOLUME)
        sampledDensity = SampleCloudDensity(cloudVolumeDesc,erosionVolumeDesc,cloudDesc.densityScale);
#endif
        
      //  tr*=BeerPowderAttenuate(sampledDensity * absorptionLight * stepSize, cloudDesc.beerPowderFactor);
        accumulatedDensity += sampledDensity * stepSize;
        traveledDist += stepSize;
        currSampleIntervalLB += stepVec;
    }

    // extinction coefficient * albedo = scattering coefficient. See Real Time Rendering 4 for more info.

    
    // float3 tr1 = BeerLambertsTransmittance(accumulatedDensityToLight.rgb * sigma);
    // note: density * extinction coefficient is the de facto 'extinction coefficient'.
    // density is functioned as a scalar to the so-called scattering/absorption/extinction coefficient.
   
    tr = BeerLambertsTransmittance(accumulatedDensity * absorptionLight);
    #ifdef _CLOUD_SCATTERING_BEER_POWDER
    tr = BeerPowderAttenuate(accumulatedDensity * absorptionLight, cloudDesc.beerPowderFactor);
    #endif
    
 //   tr = BeerPowderAttenuate(accumulatedDensity * absorptionLight,cloudDesc.beerPowderFactor);
    return tr;
    float3 lightEnergy = tr * lightDesc.color;
    
    float3 absorptionLight_inv = 1.0 / absorptionLight;
    
    // simulate multi-scattering
    lightEnergy = lightEnergy * (1 - tr) * absorptionLight_inv;
    // float x = energy2.x;
    
    return lightEnergy;
}

// return the cloud color and cloud volume density
float4 ShadeVolumetricCloud(in CloudDesc cloudDesc, in RayMarchingDesc rayMarchDesc, in LightDesc lightDesc) {
    BoundingBox bounds = cloudDesc.bounds;
    Ray ray = rayMarchDesc.ray;
    
    float3 rayDir = ray.direction;
    float3 rayOrigin = ray.origin;
    float3 rayHitPoint = ray.hitPoint;
    
    int iteration = rayMarchDesc.iteration;
    float jitterRange = rayMarchDesc.relativeJitterRange;
    RayMarchingConfig config = GetRayMarchingConfig(bounds.boundsMin, bounds.boundsMax, rayOrigin, rayDir, rayHitPoint, iteration);
    
    float maxDistance = config.validDistance;
 
    float3 stepVec = config.stepVector;
    float stepSize = config.stepSize;

    
    float3 lightDir = lightDesc.direction;
    float3 lightColor = lightDesc.color;
    
     // calculate phase function
     // be careful about the theta angle's definition!
     // theta angle: the angle between light shooting direction and the direction that pointing to the camera.
    
    float cosTheta = dot(lightDir, rayDir);
    
    const float phaseVal = lerp(HgPhaseFunction(cosTheta, cloudDesc.hgPhaseG1Factor), HgPhaseFunction(cosTheta, cloudDesc.hgPhaseG2Factor), 0.5);
    
   // currentPoint = GetSamplePoint(currentPoint, stepVec, jitterRange);
    #if defined(_RAYMARCH_JITTER_ON)

    /*
    stepVec = JitterStepVector(stepVec, jitterRange);
    stepSize = length(stepVec);
    iteration = config.validDistance / stepSize;
    */
    
    #endif
    
    float3 lightEnergy= float3(0, 0, 0);
    float accumulatedDensity = 0;
    
    float traveledDist = 0;
    
    float3 previousSampleIntervalUB =  config.entryPoint;
    float3 currSampleIntervalUB;
    float3 currStepVec = stepVec;
       
    float currStepSize = stepSize;


    // |----*----|----*----|----*----|----*----|----*----|----*----|
    // ^bound    ^bound         ^real sample point
    // |----|: interval
    // ray march from '|' to '|', and length(|----|) is the step size, but '*' is the real sample point.
    // when featuring jitter, we can jitter '*' in each interval only, or jitter the whole interval.
    float3 transmittanceToEye = float3(1,1,1);
    
    [loop]
    for (int i = 0; i < 100; i++) {
      
       // float3 realSampledPoint = currentPoint;

        //float3 currSamplePoint = previousPoint + stepVec;
       // float3 currStepVec = stepVec;
       // float currStepSize = stepSize;

        if (traveledDist + currStepSize - 0.01 >= maxDistance) {
            break;
        }
        
        currSampleIntervalUB = GetNextSamplePoint(previousSampleIntervalUB, jitterRange,stepVec);
        currStepVec = currSampleIntervalUB - previousSampleIntervalUB;
        currStepSize = length(currStepVec);
        float3 realSamplePoint = currSampleIntervalUB - currStepVec * 0.5;
        CloudVolumeDesc cloudVolumeDesc = GetCloudVolumeDesc(cloudDesc, realSamplePoint);
        WeatherMapDesc weatherMapDesc = GetWeatherMapDesc(cloudDesc, realSamplePoint);
        ErosionVolumeDesc erosionVolumeDesc = GetErosionVolumeDesc(cloudDesc, realSamplePoint);
      //  return tex3D(cloudDesc.cloudVolumeDetailTexture,cloudVolumeDesc.sampleDesc.uvw);
        float sampledDensity = 0;
#if defined(_CLOUD_MODIFY_WITH_WEATHERMAP)
        sampledDensity = SampleCloudDensity(cloudVolumeDesc,weatherMapDesc,cloudDesc.densityScale);
#elif defined(_CLOUD_MODIFY_WITH_EROSIONVOLUME)
        sampledDensity = SampleCloudDensity(cloudVolumeDesc,erosionVolumeDesc,cloudDesc.densityScale);
#endif
       // return sampledDensity;
        float3 transmittanceToLight = TransmittancePointToLight(cloudDesc,  lightDesc, realSamplePoint, rayMarchDesc.scatterMarchIteration);
     
       
        float3 deltaLightEnergy = lerp(transmittanceToLight * lightDesc.color,float3(1,1,1),cloudDesc.darknessThreshold) * currStepSize;
        float3 absorptionLight_inv = 1.0 / cloudDesc.absorptionLight;
        // simulate multi-scattering
        #ifdef _CLOUD_SCATTERING_MULTIPLE
        deltaLightEnergy = deltaLightEnergy * (1 - transmittanceToLight) * absorptionLight_inv;
        #endif
      //  float3 deltaLightEnergy = TransmittancePointToLight(cloudDesc,  lightDesc, realSamplePoint, rayMarchDesc.scatterMarchIteration) * currStepSize;
       
        transmittanceToEye *= BeerLambertsTransmittance(sampledDensity *  cloudDesc.absorptionLight * currStepSize);
   
       // tr *= BeerLambertsTransmittance(sampledDensity * cloudDesc.absorptionLight * currStepSize);
        deltaLightEnergy = deltaLightEnergy * transmittanceToEye * phaseVal * sampledDensity * cloudDesc.absorptionScatter;

     
        //deltaLightEnergy = sampledDensity.rgb * deltaLightEnergy * phaseVal;
        //since we're doing integration, don't forget to multiply values with 'stepSize'
        lightEnergy += deltaLightEnergy;
        accumulatedDensity += sampledDensity * currStepSize;
        traveledDist += currStepSize;
        previousSampleIntervalUB = currSampleIntervalUB;
    }
    
   // return float4(1,1,1,1);
    return float4(lightColor * lightEnergy, accumulatedDensity);
}

float4 BlendWithBackground(in float4 backgroundColor, in float3 cloudColor, in float transmittance)
{
    float3 bgColorIntensity = backgroundColor.rgb * transmittance;
    return float4(bgColorIntensity + cloudColor, backgroundColor.a);
}



float4 ShadeCloud(in CloudDesc cloudDesc, in RayMarchingDesc rayMarchDesc, in LightDesc lightDesc,in half4 backgroundColor) {
    // result.a is the accumulated density which can be used when blending with background
    // also useful for detecting whether there's cloud in doing temporal filter afterward.
    float4 result = ShadeVolumetricCloud(cloudDesc, rayMarchDesc, lightDesc);
    float tr = BeerLambertsTransmittance( result.a * cloudDesc.absorptionScatter.r);
  
    return BlendWithBackground(backgroundColor, result.rgb, tr);
}



#endif // RAY_MARCHING_CLOUD_SHADER_HLSL