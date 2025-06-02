Shader "Custom/Scripts/TerrainBaking/BakeTerrain" {
    Properties {
        _MainTex ("Texture", 2D) = "white" {}
    }
    
    HLSLINCLUDE

     	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

     	
        float4x4 _MVP;
  
     	float _HeightMap_MinZ_Ortho01;
     	float _HeightMap_MaxZ_Ortho01;

     	int _RefineGradientMap_CompletionFilterSize;
     	int _RefineGradientMap_SmoothFilterSize;
     	
     	int _SDF_MaxPixelDist;
     	
     	Texture2D _MainTex;
     	SamplerState sampler_MainTex;
        float4 _MainTex_TexelSize;

     	Texture2D _GradientMap;
     	SamplerState sampler_GradientMap;
        float4 _GradientMap_TexelSize;

     	Texture2D _HeightMap;
     	SamplerState sampler_HeightMap;
        float4 _HeightMap_TexelSize;

     	Texture2D _SDFTex;
     	SamplerState sampler_SDFTex;
        float4 _SDFTex_TexelSize;

        struct Attributes
        {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
        };

        struct Varyings
        {
            float2 uv : TEXCOORD0;
            float4 position : SV_POSITION;
        };

        Varyings vert_BakeHeightMap(Attributes a2v)
        {
            Varyings v2f;
            v2f.position = mul(_MVP,a2v.vertex);//TransformObjectToHClip(a2v.vertex);
            v2f.uv = a2v.uv;
            return v2f;
        }

        float4 frag_BakeHeightMap(Varyings v2f) : SV_Target
        {
   
            float height = v2f.position.z;
            // orthogonal view range defined by near/far plane is larger than desired y range to prevent clipping of meshes.
            // clipping of meshes will cause wrong terrain height data.
        
            height = (height - _HeightMap_MinZ_Ortho01)/(_HeightMap_MaxZ_Ortho01 - _HeightMap_MinZ_Ortho01);
            height = 1 - height;
            height = clamp(height,0,1);
            float binarizedHeight = step(0.00001,height);
            
            return float4(height,binarizedHeight,0,1);
        }

     	Varyings vert_Blit(Attributes a2v)
        {
            Varyings v2f;
            v2f.position = TransformObjectToHClip(a2v.vertex);
            v2f.uv = a2v.uv;
            return v2f;
        }

     	float2 ZeroGradient()
        {
            return float2(0.0,0.0);
        }

     	/*bool IsZeroGradient(float4 color)
        {
            float2 t = color.rg - float2(0.5f,0.5f);
            return all(t < 0.01f) && all(t > -0.01f) && color.w > 0.999f;
        }*/

     	bool IsZeroGradient(float2 gradient)
        {
            float2 t = gradient - float2(0.5f,0.5f);
            return all(t < 0.01f) && all(t > -0.01f);
        }
     	
     	
     	bool IsClipped(float4 color)
        {
            return color.w < 0.001f;
        }

        float4 frag_BakeGradientMap(Varyings v2f) : SV_Target
        {
            float2 uv = v2f.uv;
            float2 deltaUV = _MainTex_TexelSize.xy;
            float4 heightMap = _MainTex.SampleLevel(sampler_MainTex, uv, 0);
            if (IsClipped(heightMap))
            {
                return float4(0,0,0,0);
            }
            // calculate gradient with four directional derivatives. (with sobel filter)
            float y1 = _MainTex.SampleLevel(sampler_MainTex, uv + float2(-1,1) * deltaUV, 0).r;
            float y2 = _MainTex.SampleLevel(sampler_MainTex, uv + float2(-1,0) * deltaUV, 0).r;
            float y3 = _MainTex.SampleLevel(sampler_MainTex, uv + float2(-1,-1) * deltaUV,0).r;
            float y4 = _MainTex.SampleLevel(sampler_MainTex, uv + float2(0,1) * deltaUV,0).r;
            float y5 = _MainTex.SampleLevel(sampler_MainTex, uv + float2(0,-1) * deltaUV,0).r;
            float y6 = _MainTex.SampleLevel(sampler_MainTex, uv + float2(1,1) * deltaUV,0).r;
            float y7 = _MainTex.SampleLevel(sampler_MainTex, uv + float2(1,0) * deltaUV,0).r;
            float y8 = _MainTex.SampleLevel(sampler_MainTex, uv + float2(1,-1) * deltaUV,0).r;
            float4 sobel1 = float4(y6,y8,y7,y4);
            float4 sobel2 = float4(y3,y1,y2,y5);
            float4 deltaY = sobel1 - sobel2;
            float gradientX = dot(deltaY,float4(1,1,2,0))*0.25;
            float gradientY = dot(deltaY,float4(1,-1,0,2))*0.25;
            // y component which representing 'height' has been inverted, so gradient should be inverted too.
            float2 gradient = normalize(-float2(gradientX,gradientY));
            if (AnyIsNaN(gradient))
            {
                gradient = ZeroGradient();
            }
            float2 packedGradient = gradient*0.5f + 0.5f;
            return float4(packedGradient,heightMap.g,1);
        }


     	float GetGaussianWeight(float2 pos,float sigma)
        {
            float weight = exp(-(pos.x*pos.x + pos.y*pos.y)/(2.0f*sigma*sigma));
            return weight;
        }
     	
 	    float4 GetAverageGradient(Texture2D tex,SamplerState sampler_tex,float2 uv,float2 deltaUV,int filterSize)
        {
            float4 averageGradient = float4(0,0,0,0);
            int halfFilterSize = filterSize/2;
            float sigma = ((float)filterSize - 1)/6.0f;
            float weightSum = 0.000001; // avoid dividing by zero
            // gaussian filter
            for (int i = -halfFilterSize; i <= halfFilterSize;i++)
            {
                for (int j = -halfFilterSize; j <= halfFilterSize; j++)
                {
                    float2 sampleUV = uv + float2(i,j) * deltaUV;
                    float4 sampleVal = tex.SampleLevel(sampler_tex, sampleUV,0);
                    if (IsZeroGradient(sampleVal.rg) == false && IsClipped(sampleVal) == false)
                    {
                        float weight = GetGaussianWeight(float2(i,j),sigma);
                        averageGradient += sampleVal*weight;
                        weightSum += weight;
                    }
                }
                
            }
            return averageGradient/weightSum;
        }

 	    float4 GetNearestGradient(Texture2D tex,SamplerState sampler_tex,float2 uv,float2 deltaUV,int maxPixelDist,out int nearestDist,out float2 averageGradient)
        {
            float2 signs[4] = {float2(1,1),float2(1,-1),float2(-1,1),float2(-1,-1)};
            float minDist = maxPixelDist;
            int maxIteration = maxPixelDist;
            float4 nearestGradient = float4(0,0,0,0);
            averageGradient  = float2(0,0);
            for (int i = 0;i <= maxIteration;i++)
            {
                for (int j = 0; j <= i; j++)
                {
                    float dist = length(float2(i,j));
                    if (dist >= minDist){
                        break; 
                    }
                    float4 color[2];
                    int foundCnt = 0;
                    int landFoundCnt = 0;
                    float4 avgColor = float4(0,0,0,0);
                    float2 avgUV = float2(0,0);
                    for (int k = 0; k < 4; k++){
                        float2 testUV1 = uv + float2(i,j) * signs[k] * deltaUV;
                        float2 testUV2 = uv + float2(j,i) * signs[k] * deltaUV;
                        if (all(testUV1 > 0.0f) && all(testUV1 < 1.0f) && all(testUV2 > 0.0f) && all(testUV2 < 1.0f))
                        {
                            color[0] = tex.SampleLevel(sampler_tex, testUV1,0);
                            color[1] = tex.SampleLevel(sampler_tex, testUV2,0);
                            if (IsZeroGradient(color[0].rg) == false && !IsClipped(color[0])){
                                foundCnt++;
                                avgColor += color[0];
                            }
                            if (IsZeroGradient(color[1].rg) == false && !IsClipped(color[1])){
                                foundCnt++;
                                avgColor += color[1];
                            }
                            // pixel is land
                            if (color[0].b < 0.01f)
                            {
                                landFoundCnt++;
                                avgUV += testUV1;
                            }
                            if (color[1].b < 0.01f)
                            {
                                landFoundCnt++;
                                avgUV += testUV2;
                            }
                        }
                    }
                    if (foundCnt){
                        if (dist < minDist){
                            minDist = dist;
                            nearestGradient = avgColor/float(foundCnt);
                            averageGradient = avgUV/float(landFoundCnt);
                        }
                        break;  
                    }
                }
            }
            nearestDist = minDist;
            averageGradient = normalize(averageGradient - uv)*0.5f + 0.5f;
            return nearestGradient;
        }
     	
     	float4 frag_RefineGradientMap(Varyings v2f) : SV_Target
        {
            float2 uv = v2f.uv;
            float2 deltaUV = _MainTex_TexelSize.xy;
            float4 gradient = _MainTex.SampleLevel(sampler_MainTex, uv, 0);
            if (IsClipped(gradient)){
              //  return float4(1,1,1,1);
            }
    
            if (IsZeroGradient(gradient.rg)||IsClipped(gradient)){
                float nearestGradientDist;
                float2 averageGradient;
                float4 nearestGradient = GetNearestGradient(_MainTex, sampler_MainTex, uv, deltaUV, 128,nearestGradientDist,averageGradient);
                int filterSize = (int)nearestGradientDist*2+ _RefineGradientMap_CompletionFilterSize;
                gradient.rg = GetAverageGradient(_MainTex, sampler_MainTex, uv, deltaUV, filterSize).rg;
                if (!IsZeroGradient(gradient.rg))
                {
                    gradient.a = 1;
                }
               // gradient.rg = averageGradient;
            }else{
                gradient.rg = GetAverageGradient(_MainTex, sampler_MainTex, uv, deltaUV, _RefineGradientMap_SmoothFilterSize).rg;
            }
            return gradient;
        }
     	
     	float GetNearestDistance(Texture2D tex,SamplerState sampler_tex,float2 uv,float2 deltaUV,int maxPixelDist)
        {
            float2 signs[4] = {float2(1,1),float2(1,-1),float2(-1,1),float2(-1,-1)};
            float minDist = maxPixelDist;
            int maxIteration = maxPixelDist;
            for (int i = 0;i <= maxIteration;i++)
            {
                for (int j = 0; j <= i; j++)
                {
                    float dist = length(float2(i,j));
                    if (dist >= minDist){
                        break; 
                    }
                    float4 color[2];
                    // calculate SDF from height map. g component for binarized height map.
                    bool found = false;
                    for (int k = 0; k < 4; k++){
                        float2 testUV1 = uv + float2(i,j) * signs[k] * deltaUV;
                        float2 testUV2 = uv + float2(j,i) * signs[k] * deltaUV;
                        if (all(testUV1 > 0.0f) && all(testUV1 < 1.0f) && all(testUV2 > 0.0f) && all(testUV2 < 1.0f))
                        {
                            color[0] = tex.SampleLevel(sampler_tex, testUV1,0);
                            color[1] = tex.SampleLevel(sampler_tex, testUV2,0);
                            if ((color[0].g<0.001 && color[0].a >0.999f ) || (color[1].g < 0.001 && color[1].a > 0.999f )){
                                found = true;
                                break;
                            }
                        }
                    }
                    if (found){
                        if (dist < minDist){
                            minDist = dist;
                        }
                        break;  
                    }
                }
            }
            return minDist/float(maxPixelDist);
        }
     	

     	
     	float4 frag_BakeSDF(Varyings v2f) : SV_Target
        {
            float2 uv = v2f.uv;
            float2 deltaUV = _MainTex_TexelSize.xy;
            float4 heightMap = _MainTex.SampleLevel(sampler_MainTex, uv, 0);
            /*if (heightMap.a < 0.001f)
            {
                return float4(heightMap.r,heightMap.g,0,0);
            }*/
            float dist = GetNearestDistance(_MainTex,sampler_MainTex,uv,deltaUV,_SDF_MaxPixelDist);
            return float4(heightMap.r,heightMap.g,dist,heightMap.a);
        }

     	
     	float4 frag_MixSDFAndGradient(Varyings v2f) : SV_Target
        {
            float2 uv = v2f.uv;
            float4 sdf = _SDFTex.SampleLevel(sampler_SDFTex, uv, 0);
            float4 gradient = _GradientMap.SampleLevel(sampler_GradientMap, uv, 0);
            return float4(sdf.b,gradient.rg,sdf.a);
        }

     	
   ENDHLSL

   SubShader {
        Tags {
			 "RenderPipeline"="UniversalPipeline"
		}
        
        Pass{
            Name "BakeHeightMap"
            
            HLSLPROGRAM
                #pragma vertex vert_BakeHeightMap
                #pragma fragment frag_BakeHeightMap
     
                #pragma target 3.0
                
            ENDHLSL
        }

         Pass{
             Name "BakeGradientMap"
                
             HLSLPROGRAM
               #pragma vertex vert_Blit
               #pragma fragment frag_BakeGradientMap
                    
               #pragma target 3.0
                    
             ENDHLSL
         }

        Pass{
             Name "RefineGradientMap"
                
             HLSLPROGRAM
               #pragma vertex vert_Blit
               #pragma fragment frag_RefineGradientMap
                    
               #pragma target 3.0
                    
             ENDHLSL
         }


        Pass{
             Name "BakeSDF"
                
             HLSLPROGRAM
               #pragma enable_d3d11_debug_symbols
               #pragma vertex vert_Blit
               #pragma fragment frag_BakeSDF
                    
               #pragma target 3.0
                    
             ENDHLSL
        }


        Pass{
             Name "MixSDFAndGradient"
                
             HLSLPROGRAM
               #pragma enable_d3d11_debug_symbols
               #pragma vertex vert_Blit
               #pragma fragment frag_MixSDFAndGradient
                    
               #pragma target 3.0
                    
             ENDHLSL
        }
    }
}