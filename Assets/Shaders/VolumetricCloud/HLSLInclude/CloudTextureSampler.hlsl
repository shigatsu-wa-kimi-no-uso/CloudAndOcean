#ifndef CLOUD_TEXTURE_SAMPLER_HLSL
#define CLOUD_TEXTURE_SAMPLER_HLSL


struct MapSampleDesc {
    float2 uv;
    float4 valueMulti;
    float4 valueAdd;
};

struct VolumeSampleDesc {
    float3 uvw;
    float4 valueMulti;
    float4 valueAdd;
};

struct CloudVolumeDesc {
    sampler3D cloudVolumeTexture;
    sampler3D cloudVolumeDetailTexture;
    VolumeSampleDesc sampleDesc;
    VolumeSampleDesc detailSampleDesc;
    float cloudLayerHeight;
    float sampleHeight;
};

struct WeatherMapDesc {
    sampler2D weatherMap;
    MapSampleDesc sampleDesc;
};

struct ErosionVolumeDesc {
    sampler3D erosionVolumeTexture;
    VolumeSampleDesc sampleDesc;
};

float3 GetTexCoords(float3 pos, float3 coordsScale,float3 coordsOffsetSpeed,float timeInSeconds) {
    const float baseScale = 0.00001f;
    float3 uvw = pos * baseScale * coordsScale + coordsOffsetSpeed * timeInSeconds;
    return uvw;
}

float SampleCloudVolumeTex(sampler3D volumeTex, float3 uvw) {
    float value = 0.0;
    return tex3D(volumeTex, uvw);
#if defined(_CLOUD_VOLUME_DENSITY_COMPONENT_R)
    value = tex3D(volumeTex, uvw).r;
#elif defined(_CLOUD_VOLUME_DENSITY_COMPONENT_G)
    value = tex3D(volumeTex, uvw).g;
#elif defined(_CLOUD_VOLUME_DENSITY_COMPONENT_B)
    value = tex3D(volumeTex, uvw).b;
#elif defined(_CLOUD_VOLUME_DENSITY_COMPONENT_A)
    value = tex3D(volumeTex, uvw).a;
#endif
    return value;
}

float SampleCloudVolumeDetailTex(sampler3D volumeTex, float3 uvw) {
    float value = 0.0;
    return tex3D(volumeTex, uvw);
#if defined(_CLOUD_VOLUME_DETAIL_DENSITY_COMPONENT_R)
    value = tex3D(volumeTex, uvw).r;
#elif defined(_CLOUD_VOLUME_DETAIL_DENSITY_COMPONENT_G)
    value = tex3D(volumeTex, uvw).g;
#elif defined(_CLOUD_VOLUME_DETAIL_DENSITY_COMPONENT_B)
    value = tex3D(volumeTex, uvw).b;
#elif defined(_CLOUD_VOLUME_DETAIL_DENSITY_COMPONENT_A)
    value = tex3D(volumeTex, uvw).a;
#endif
    return value;
}

float SampleCloudDensity(CloudVolumeDesc cloudDesc,WeatherMapDesc weatherDesc,float densityScale) {
    sampler3D cloudTex = cloudDesc.cloudVolumeTexture;
    sampler3D cloudDetailTex = cloudDesc.cloudVolumeDetailTexture;
    sampler2D weatherMap = weatherDesc.weatherMap;

    float3 cloudUVW = cloudDesc.sampleDesc.uvw;
    float4 cloudValueAdd = cloudDesc.sampleDesc.valueAdd;
    float4 cloudValueMulti = cloudDesc.sampleDesc.valueMulti;
        
    float3 cloudDetailUVW = cloudDesc.detailSampleDesc.uvw;
    float4 cloudDetailValueAdd = cloudDesc.detailSampleDesc.valueAdd;
    float4 cloudDetailValueMulti = cloudDesc.detailSampleDesc.valueMulti;
    
    float2 weatherUV = weatherDesc.sampleDesc.uv;
    float4 weatherValueMulti = weatherDesc.sampleDesc.valueMulti;
    float4 weatherValueAdd = weatherDesc.sampleDesc.valueAdd;
    float cloudLayerHeight = cloudDesc.cloudLayerHeight;
    float sampleHeight = cloudDesc.sampleHeight;

//    float shapeFBM = dot(shapeNoise, normalizedShapeWeights) * heightGradient;
    
    float4 general = SampleCloudVolumeTex(cloudTex, cloudUVW) * cloudValueMulti + cloudValueAdd;
    float4 detail = SampleCloudVolumeDetailTex(cloudDetailTex, cloudDetailUVW) * cloudDetailValueMulti + cloudDetailValueAdd;
 
   // detail = (detailVal.g*2.0 + detailVal.b)* cloudDetailValueMulti;
    float4 weather = tex2D(weatherMap, weatherUV) * weatherValueMulti + weatherValueAdd;
    float density = saturate(dot(general,float4(1,1,1,1)) - dot(detail,float4(1,1,1,1)) - dot(weather,float4(1,1,1,1)));
    density*=densityScale;
  //  density = clamp(density, 0, 1);
    
    //return density;
    float factor = 0.2;
    
    float shape = density * smoothstep(0, cloudLayerHeight * factor, sampleHeight);
    shape = shape * smoothstep(0, cloudLayerHeight * factor, cloudLayerHeight - sampleHeight);
    
    float result = pow(shape, 1.5);
    result = lerp(result,saturate(result),0.5);
    
    return result;
} 



float SampleCloudDensity(CloudVolumeDesc cloudDesc, ErosionVolumeDesc erosionDesc,float densityScale) {
    sampler3D cloudTex = cloudDesc.cloudVolumeTexture;
    sampler3D cloudDetailTex = cloudDesc.cloudVolumeDetailTexture;
    sampler3D erosionTex = erosionDesc.erosionVolumeTexture;

    float3 cloudUVW = cloudDesc.sampleDesc.uvw;
    float cloudValueAdd = cloudDesc.sampleDesc.valueAdd;
    float cloudValueMulti = cloudDesc.sampleDesc.valueMulti;
    
    float3 cloudDetailUVW = cloudDesc.detailSampleDesc.uvw;
    float4 cloudDetailValueAdd = cloudDesc.detailSampleDesc.valueAdd;
    float4 cloudDetailValueMulti = cloudDesc.detailSampleDesc.valueMulti;
    
    float3 erosionUVW = erosionDesc.sampleDesc.uvw;
    float4 erosionValueMulti = erosionDesc.sampleDesc.valueMulti;
    float cloudLayerHeight = cloudDesc.cloudLayerHeight;
    float sampleHeight = cloudDesc.sampleHeight;
 
    float general = SampleCloudVolumeTex(cloudTex, cloudUVW) * cloudValueMulti;
    float detail = SampleCloudVolumeDetailTex(cloudDetailTex, cloudDetailUVW) * cloudDetailValueMulti;
    float erosion = tex3D(erosionTex, erosionUVW).r * erosionValueMulti;
    float density = saturate(general - detail - erosion + cloudValueAdd);
  //  return density;
   // float shape = density;
    float shape = density * smoothstep(0, cloudLayerHeight * 0.1, sampleHeight);
    shape = shape * smoothstep(0, cloudLayerHeight * 0.1, cloudLayerHeight - sampleHeight);
  //  return shape;
    float result = pow(shape, 1.5);
    result = lerp(result, saturate(result), 0.5);
    return result;
}



#endif