Shader "Custom/VolumetricCloud/VolumetricCloud"
{
    Properties{
        [HideInInspector]
        _MainTex("MainTex" , 2D) = "white"{}  // must be declared in properties scope
        _Color ("Color", Color) = (1,1,1,1)
        
        [Header(Cloud Volume Settings)]
        _CloudVolumeBounds_Min("Bounds Min", Vector) = (-1,-1,-1)
        _CloudVolumeBounds_Max("Bounds Max", Vector) = (1,1,1)
        _DensityScale("Density Scale", Range(0,2)) = 1
       

         [NoScaleOffset]
        _CloudVolumeTex("Texture", 3D)  = "" {}
    //    [KeywordEnum(R,G,B,A)] 
     //   _CLOUD_VOLUME_DENSITY_COMPONENT("Density Component",Float) = 0
        _CloudVolumeTex_ValueScale("Value Scale", Vector) = (1,1,1,1)
        _CloudVolumeTex_ValueOffset("Value Offset", Vector) = (0,0,0,0)
        _CloudVolumeTex_CoordsScale("Coords Scale", Vector) = (1,1,1)
        _CloudVolumeTex_CoordsOffsetSpeed("Coords Offset Speed", Vector) = (0,0,0)
        
        [Header(Cloud Volume Detail Settings)]
        [NoScaleOffset]
        _CloudVolumeDetailTex("Texture", 3D)  = "" {}
       // [KeywordEnum(R,G,B,A)] 
      //  _CLOUD_VOLUME_DETAIL_DENSITY_COMPONENT("Density Component",Float) = 0
        _CloudVolumeDetailTex_ValueScale("Detail Value Scale", Vector) = (1,1,1,1)
        _CloudVolumeDetailTex_ValueOffset("Detail Value Offset", Vector) = (0,0,0,0)
        _CloudVolumeDetailTex_CoordsScale("Detail Coords Scale", Vector) = (1,1,1)
        _CloudVolumeDetailTex_CoordsOffsetSpeed("Detail Coords Offset Speed", Vector) = (0,0,0)

        [KeywordEnum(ErosionVolume,WeatherMap)] 
        _CLOUD_MODIFY_WITH("Cloud Modification Mode",Float) = 0


        [Header(Weather Map Settings)]
        [NoScaleOffset]
        _WeatherMap("Texture", 2D) = "" {}
        _WeatherMap_ValueScale("Value Scale", Vector) = (1,1,1,1)
        _WeatherMap_ValueOffset("Value Offset", Vector) = (0,0,0,0)
        _WeatherMap_CoordsScale("Coords Scale", Vector) = (1,1,1)
        _WeatherMap_CoordsOffsetSpeed("Coords Offset Speed", Vector) = (0,0,0)

        [Header(Erosion Volume Settings)]
        [NoScaleOffset]
        _ErosionVolumeTex("Texture", 3D) = "" {}
        _ErosionVolumeTex_ValueScale("Value Scale", Vector) = (1,1,1,1)
        _ErosionVolumeTex_ValueOffset("Value Offset", Vector) = (0,0,0,0)
        _ErosionVolumeTex_CoordsScale("Coords Scale", Vector) = (1,1,1)
        _ErosionVolumeTex_CoordsOffsetSpeed("Coords Offset Speed", Vector) = (0,0,0)

         [Header(Cloud Lighting Settings)]
         _AbsorptionScatter("Absorption of Scatter", Vector) = (0.1,0.1,0.1,1)
         _AbsorptionLight("Absorption of Light", Vector) = (0.1,0.1,0.1,1)
        // _Albedo("Albedo", Color) = (1,1,1,1)
         _HgPhaseG1Factor("HgPhaseG1Factor", Range(-1.0,1.0)) = 0.8
         _HgPhaseG2Factor("HgPhaseG2Factor", Range(-1.0,1.0)) = -0.2
        _DarknessThreshold("Darkness Threshold", Range(0,1)) = 0.1
        [Toggle(_CLOUD_SCATTERING_BEER_POWDER)]
        _CLOUD_SCATTERING_BEER_POWDER("Beer Powder Attenuation",  Float) = 1
        _BeerPowderFactor("Beer Powder Factor", Float) = 6
        [Toggle(_CLOUD_SCATTERING_MULTIPLE)]
        _CLOUD_SCATTERING_MULTIPLE("Multiple Scattering",  Float) = 1
        
         [Header(Ray Marching Settings)]
         _RayMarching_Iteration("Iteration", Int) = 128
         _RayMarching_ScatterIteration("Scatter Iteration", Int) = 16

         [Toggle]
         _RAYMARCH_JITTER("Jitter", Float) = 0
         _RayMarching_RelativeJitterRange("Relative Jitter Range", Range(0.0,0.5)) = 0.1
         _RandomSeed("Random Seed", Float) = 0
        
         [Toggle]
         _RAYMARCH_TEMPORAL_FILTER("Temporal Filter", Float) = 0
         _BlendFactor("Temporal Filter Blend Factor", Range(0.0,1.0)) = 0.8
        
        
        [Toggle]
        _BILATERAL_FILTER("Bilateral Filter", Float) = 0
        _BilateralFilter_SpatialKernelSize("Spatial Kernel Size", Int) = 7
        _BilateralFilter_ColorSigma("Color Sigma", Vector) = (0.1,0.1,0.1,0.1)
    }

    HLSLINCLUDE
        // includes, global pragmas and public functions
        #pragma enable_d3d11_debug_symbols

     
        #pragma multi_compile __ _CHECKERBOARD_SAMPLING_ON
        #pragma multi_compile _RAYMARCH_SCREEN_SPACE _RAYMARCH_HEMI_OCTAHEDRON_SPACE
        #pragma multi_compile __ _RAYMARCH_JITTER_ON
        #pragma multi_compile __ _CLOUD_SCATTERING_BEER_POWDER
        #pragma multi_compile __ _CLOUD_SCATTERING_MULTIPLE
            
        #pragma shader_feature _CLOUD_MODIFY_WITH_EROSIONVOLUME _CLOUD_MODIFY_WITH_WEATHERMAP
        #pragma shader_feature _CLOUD_VOLUME_DENSITY_COMPONENT_A _CLOUD_VOLUME_DENSITY_COMPONENT_R _CLOUD_VOLUME_DENSITY_COMPONENT_G _CLOUD_VOLUME_DENSITY_COMPONENT_B
        #pragma shader_feature _CLOUD_VOLUME_DETAIL_DENSITY_COMPONENT_A _CLOUD_VOLUME_DETAIL_DENSITY_COMPONENT_R _CLOUD_VOLUME_DETAIL_DENSITY_COMPONENT_G _CLOUD_VOLUME_DETAIL_DENSITY_COMPONENT_B
        
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        #include "HLSLInclude/GaussianFilter.hlsl"
        #include "HLSLInclude/RayMarchingCloudShader.hlsl"
        #include "HLSLInclude/TemporalFilter.hlsl"
        #include "HLSLInclude/CheckerboardUitls.hlsl"


    //Global variables
        
        sampler2D _MainTex; // _MainTex is automatically set by blit function source texture, and must be declared in Properties scope.

        float2 _CheckerboardSampling_OriginalRTResolution;
        float _CheckerboardSampling_EvenOdd;
      //  SamplerState sampler_MainTex; // following naming rule: sampler + "TextureName" to let Unity match the state with the texture. (DX11 style)
        
        sampler3D _CloudVolumeTex;
        float4 _CloudVolumeTex_ValueScale;
        float4 _CloudVolumeTex_ValueOffset;
        float3 _CloudVolumeTex_CoordsScale;
        float3 _CloudVolumeTex_CoordsOffsetSpeed;

        sampler3D _CloudVolumeDetailTex;
        float4 _CloudVolumeDetailTex_ValueScale;
        float4 _CloudVolumeDetailTex_ValueOffset;
        float3 _CloudVolumeDetailTex_CoordsScale;
        float3 _CloudVolumeDetailTex_CoordsOffsetSpeed;
      
        float3 _CloudVolumeBounds_Min;
        float3 _CloudVolumeBounds_Max;
        float _DensityScale;


        sampler2D _WeatherMap;
        float4 _WeatherMap_ValueScale;
        float4 _WeatherMap_ValueOffset;
        float3 _WeatherMap_CoordsScale;
        float3 _WeatherMap_CoordsOffsetSpeed;

        sampler3D _ErosionVolumeTex;
        float4 _ErosionVolumeTex_ValueScale;
        float4 _ErosionVolumeTex_ValueOffset;
        float3 _ErosionVolumeTex_CoordsScale;
        float3 _ErosionVolumeTex_CoordsOffsetSpeed;

        //parameter definitions for settings of lighting
        float3 _AbsorptionScatter;
        float3 _AbsorptionLight;
        float3 _Albedo;
        float _HgPhaseG1Factor;
        float _HgPhaseG2Factor;
        float _DarknessThreshold;
        float _BeerPowderFactor;

            //parameter definitions for ray marching settings
        int _RayMarching_Iteration;  
        int _RayMarching_ScatterIteration;

        float _RayMarching_RelativeJitterRange; //Relative jitter range (in pencentage, resulting as '[samplePoint - stride*jitterRange,samplePoint + stride*jitterRange]')
        float _RandomSeed;
        
        int _BilateralFilter_SpatialKernelSize;
        float4 _BilateralFilter_ColorSigma;
      
        struct Attributes {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
        };

        struct Varyings {
            float4 position : SV_POSITION;
            float2 uv : TEXCOORD0;
        };


        float GetSceneDepth(float3 positionSS)
        {
            float2 uv = positionSS.xy / _ScaledScreenParams.xy;
            #if UNITY_REVERSED_Z
            float depth = SampleSceneDepth(uv);
            #else
            float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(uv));
            #endif
            return depth;
        }

         float GetSceneDepth(float2 screenUV)
        {
            #if UNITY_REVERSED_Z
            float depth = SampleSceneDepth(screenUV);
            #else
            float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(uv));
            #endif
            return depth;
        }
        
        
        float3 GetWorldPosition(float2 screenUV){
            /* get world space position from clip position */
            #if UNITY_REVERSED_Z
            real depth = SampleSceneDepth(screenUV);
            #else
            real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(uv));
            #endif
            return ComputeWorldSpacePosition(screenUV, depth, UNITY_MATRIX_I_VP);
        }

        
        
        float3 HemiOctahedronUVToYUpVector(float2 uv)
	    {
		    float2 uv2 = uv * 2.0 - 1.0;
            uv2 = float2(uv2.x + uv2.y, uv2.x - uv2.y)*0.5;
		    float3 n = float3(uv2,1-dot(1.0,abs(uv2)));
		    return normalize(n).xzy;
	    }
        
	    float2 YUpVectorToHemiOctahedronUV(float3 n)
	    {
		    n.xz /= dot(1.0, abs(n));
		    return float2(n.x + n.z, n.x - n.z) * 0.5 + 0.5;
	    }


        bool IsRayDirectionInViewFrustum()
        {
            return true;
        }
        
        CloudDesc GetRenderCloudDesc()
        {
            CloudDesc cloudDesc;
           
            BoundingBox bounds;
            bounds.boundsMin = _CloudVolumeBounds_Min;
            bounds.boundsMax = _CloudVolumeBounds_Max; 
                
            TextureSampleConfig cloudTexSampleCfg;
            cloudTexSampleCfg.valueScale = _CloudVolumeTex_ValueScale;
            cloudTexSampleCfg.valueOffset = _CloudVolumeTex_ValueOffset;
            cloudTexSampleCfg.coordsScale = _CloudVolumeTex_CoordsScale;
            cloudTexSampleCfg.coordsOffsetSpeed = _CloudVolumeTex_CoordsOffsetSpeed;
                
            TextureSampleConfig cloudDetailTexSampleCfg;
            cloudDetailTexSampleCfg.valueScale = _CloudVolumeDetailTex_ValueScale;
            cloudDetailTexSampleCfg.valueOffset = _CloudVolumeDetailTex_ValueOffset;
            cloudDetailTexSampleCfg.coordsScale = _CloudVolumeDetailTex_CoordsScale;
            cloudDetailTexSampleCfg.coordsOffsetSpeed = _CloudVolumeDetailTex_CoordsOffsetSpeed;
                
                
            TextureSampleConfig weatherMapSampleCfg;
            weatherMapSampleCfg.valueScale = _WeatherMap_ValueScale;
            weatherMapSampleCfg.valueOffset = _WeatherMap_ValueOffset;
            weatherMapSampleCfg.coordsScale = _WeatherMap_CoordsScale;
            weatherMapSampleCfg.coordsOffsetSpeed = _WeatherMap_CoordsOffsetSpeed;

            TextureSampleConfig erosionTexSampleCfg;
            erosionTexSampleCfg.valueScale = _ErosionVolumeTex_ValueScale;
            erosionTexSampleCfg.valueOffset = _ErosionVolumeTex_ValueOffset;
            erosionTexSampleCfg.coordsScale = _ErosionVolumeTex_CoordsScale;
            erosionTexSampleCfg.coordsOffsetSpeed = _ErosionVolumeTex_CoordsOffsetSpeed;
                
                
            cloudDesc.bounds = bounds;
            cloudDesc.cloudVolumeTexture = _CloudVolumeTex;
            cloudDesc.cloudVolumeDetailTexture = _CloudVolumeDetailTex;
            cloudDesc.weatherMap = _WeatherMap;
            cloudDesc.erosionVolumeTexture = _ErosionVolumeTex;

            cloudDesc.cloudTexSampleConfig = cloudTexSampleCfg;
            cloudDesc.cloudDetailTexSampleConfig = cloudDetailTexSampleCfg;
            cloudDesc.weatherMapSampleConfig = weatherMapSampleCfg;
            cloudDesc.erosionTexSampleConfig = erosionTexSampleCfg;

            cloudDesc.absorptionScatter = _AbsorptionScatter;
            cloudDesc.absorptionLight = _AbsorptionLight;
            cloudDesc.albedo = _Albedo;
            cloudDesc.hgPhaseG1Factor = _HgPhaseG1Factor;
            cloudDesc.hgPhaseG2Factor = _HgPhaseG2Factor;
            cloudDesc.timeInSeconds = _Time.y;
            cloudDesc.densityScale = _DensityScale;
            cloudDesc.darknessThreshold  = _DarknessThreshold;
            cloudDesc.beerPowderFactor = _BeerPowderFactor;
            return cloudDesc;
        }


        Ray GetWorldSpaceRay(float2 uv)
        {
            
            float3 rayOriginWS;
            float3 rayDirWS;
            float3 rayHitPoint;

            #if defined(_RAYMARCH_SCREEN_SPACE)
                float3 positionWS = GetWorldPosition(uv);
                rayHitPoint =  positionWS;
                rayOriginWS = _WorldSpaceCameraPos;
                rayDirWS = normalize(positionWS - rayOriginWS);
             //   return float4(smoothstep(0,100,positionWS),1);
            #elif defined(_RAYMARCH_HEMI_OCTAHEDRON_SPACE)
                rayOriginWS = float3(0,0,0);
                rayDirWS = HemiOctahedronUVToYUpVector(uv);
                rayHitPoint =  1000000*rayDirWS;
            #endif
                
            Ray ray;
            ray.origin = rayOriginWS;
            ray.direction = rayDirWS;
            ray.hitPoint = rayHitPoint;
            return ray;
        }

        float4 render_cloud(Varyings v2f)
        {
            CloudDesc cloudDesc = GetRenderCloudDesc();
            Ray ray = GetWorldSpaceRay(v2f.uv);
            
            // Light: predefined structure
            // GetMainLight(): predefined function to get the main light (must be directional light).
            
            Light light = GetMainLight();
            
            LightDesc lightDesc;
            lightDesc.direction = light.direction;
            lightDesc.color = light.color;
            
            RayMarchingDesc rayMarchDesc;

            rayMarchDesc.iteration = _RayMarching_Iteration;
            rayMarchDesc.scatterMarchIteration = _RayMarching_ScatterIteration;
            rayMarchDesc.ray = ray;
            rayMarchDesc.relativeJitterRange = _RayMarching_RelativeJitterRange;
            
            SetRandomSeed(_ScaledScreenParams.x * v2f.position.y + v2f.position.x + _RandomSeed + _Time.y);

            //float3 absorptionScatter = cloudDesc.absorptionLight*cloudDesc.albedo;
           // cloudDesc.absorptionScatter = absorptionScatter;
            float4 shadeResult = ShadeVolumetricCloud(cloudDesc, rayMarchDesc, lightDesc);
            float tr = BeerLambertsTransmittance( shadeResult.a * cloudDesc.absorptionLight);
            shadeResult.a = tr;
            #if defined(_RAYMARCH_BLEND_BACKGROUND)
                half4 backgroundColor = tex2D(_MainTex, v2f.uv);
                shadeResult = BlendWithBackground(backgroundColor, shadeResult.rgb,shadeResult.a);
            #endif
            //  shadeResult = BlendWithBackground(backgroundColor,shadeResult, shadeResult.a);
            // tr is within (0,1] which is just suitable for storing in a texture.
            // return float4(1,0,0,1);
            return shadeResult;
        }

        Varyings vert_screenspace_blit(Attributes a2v) {
            Varyings v2f;
            v2f.position = TransformObjectToHClip(a2v.vertex);
            v2f.uv = a2v.uv;
            return v2f;
        }
        
    ENDHLSL


    SubShader{
        Tags {
            "RenderPipeline" = "UniversalRenderPipeline"
        }

        Pass{
            Name "Ray Marching Pass"

            Cull Off
            ZTest Always
            ZWrite Off

            HLSLPROGRAM
            
            

            #pragma vertex vert_screenspace_blit
            #pragma fragment frag_cloud
            #pragma target 3.0
            #pragma multi_compile __ _RAYMARCH_BLEND_BACKGROUND


            float4 frag_cloud(Varyings v2f) : SV_TARGET {
                #if defined(_CHECKERBOARD_SAMPLING_ON)
                v2f.uv = GetCheckerboardSampledUV(v2f.position,_CheckerboardSampling_OriginalRTResolution,_CheckerboardSampling_EvenOdd);
                #endif
                
                return render_cloud(v2f);
            }

            ENDHLSL
        }


        Pass{
            Name "Blend Pass"
            Cull Off
            ZTest Always
            ZWrite Off
       
            HLSLPROGRAM


            float _BlendFactor;
            float4x4 _PrevFrameViewProjectMatrix;
            float4x4 _CurrFrameViewProjectMatrix;
            
            sampler2D _PrevFrameTex;    // texture of the previous frame
            float4 _PrevFrameTex_TexelSize; // automatically-set texture resolution info
            sampler2D _CurrFrameTex;    // texture of the current frame
            float4 _CurrFrameTex_TexelSize;
            
            #pragma multi_compile __ _RAYMARCH_TEMPORAL_FILTER_ON
    
            #pragma multi_compile __ _RAYMARCH_TEMPORAL_FILTER_NO_REPROJECTION
            #pragma multi_compile __ _CHECKERBOARD_FULL_RENDERING_WHEN_INVIEW
            #pragma multi_compile __ _CHECKERBOARD_OCTAHEDRON_SPACE
            #pragma multi_compile __ _RAYMARCH_TEMPORAL_FILTER_BLEND_BACKGROUND
            #pragma multi_compile __ _BILATERAL_FILTER_ON
            
            #pragma vertex vert_screenspace_blit
            #pragma fragment frag_blend
            #pragma target 3.0


            bool IsHemiOctahedronUVInView(float2 uv,float4x4 viewProjectMatrix)
            {
                float3 directionWS = HemiOctahedronUVToYUpVector(uv);
                float3 cameraPosWS = _CurrFrameViewProjectMatrix[3];
                float3 virtualRayHitPoint = float4(cameraPosWS + 100*directionWS,1);
                float4 pointCS = mul(viewProjectMatrix,virtualRayHitPoint);
                float4 pointNDC = pointCS / pointCS.w;
                return all(pointNDC.xy <= 1.0 && pointNDC.xy >= -1.0) && pointCS.w >= 0.0;
            }

            float4 ResolveCurrentFrameRawPixelColor(float3 pixelPos,float2 screenUV,float2 screenUVDelta,float frameParity,
                bool fullRenderingWhenInView,bool octahedronSpace){
                bool sampleFromCurr = GetCheckerboardPositionParity(pixelPos,frameParity);
                if (sampleFromCurr){
                    return tex2D(_CurrFrameTex,screenUV);
                }else{
                    if (octahedronSpace && fullRenderingWhenInView && IsHemiOctahedronUVInView(screenUV, _CurrFrameViewProjectMatrix)){
                         Varyings v2f;
                         v2f.position = float4(pixelPos,1);
                         v2f.uv = screenUV;
                         return render_cloud(v2f); 
                    }else{
                     //   return float4(1,0,0,0);
                         return GetColorAverage(_CurrFrameTex,screenUV,screenUVDelta,false);
                     }
                   
                }
            }

          
            
            half4 frag_blend(Varyings v2f) : SV_TARGET {
                
                float4 currFrameRawPixelColor;
                float4 result;
                bool usingReprojection;
                bool usingCheckerboardSampling;
                #if defined(_RAYMARCH_TEMPORAL_FILTER_NO_REPROJECTION)
                usingReprojection = false;
                #else
                usingReprojection = true;
                #endif
                
                bool octahedronSpace;
                #if defined(_CHECKERBOARD_OCTAHEDRON_SPACE)
                octahedronSpace = true;
                #else
                octahedronSpace = false;
                #endif
                
                bool fullRenderingWhenInView;
                #if defined(_CHECKERBOARD_FULL_RENDERING_WHEN_INVIEW)
                fullRenderingWhenInView = true;
                #else
                fullRenderingWhenInView = false;
                #endif
                #if defined(_CHECKERBOARD_SAMPLING_ON)
                
                usingCheckerboardSampling = true;
                currFrameRawPixelColor = ResolveCurrentFrameRawPixelColor(v2f.position,v2f.uv,
                    _PrevFrameTex_TexelSize.xy,_CheckerboardSampling_EvenOdd,fullRenderingWhenInView,octahedronSpace);
                
                #else
                usingCheckerboardSampling = false;
             
                currFrameRawPixelColor = tex2D(_CurrFrameTex,v2f.uv);
                #endif
            //    return currFrameRawPixelColor;
                
              //  float2 renderTargetResolution = _RenderTargetResolution;
             
              
                TemporalFilterInput temporalFilterInput;
                temporalFilterInput.pixelPos = v2f.position.xy;
                temporalFilterInput.screenUV = v2f.uv;
                temporalFilterInput.depth = GetSceneDepth(v2f.uv);
                temporalFilterInput.blendFactor= float4(_BlendFactor,_BlendFactor,_BlendFactor,_BlendFactor);
                temporalFilterInput.prevModelMatrix = k_identity4x4;
                temporalFilterInput.currModelMatrixInv = k_identity4x4;
                temporalFilterInput.currViewProjectMatrixInv = UNITY_MATRIX_I_VP;
                temporalFilterInput.prevViewProjectMatrix = _PrevFrameViewProjectMatrix;
                temporalFilterInput.prevFrameTex = _PrevFrameTex;
                temporalFilterInput.prevFrameTexUVDelta = _PrevFrameTex_TexelSize.xy;
                temporalFilterInput.currFramePixelColor = currFrameRawPixelColor;
                temporalFilterInput.currRawFrameTex = _CurrFrameTex;
                temporalFilterInput.currRawFrameTexUVDelta = _CurrFrameTex_TexelSize.xy;
                temporalFilterInput.evenOdd = _CheckerboardSampling_EvenOdd;
                temporalFilterInput.usingReprojection = usingReprojection;
                temporalFilterInput.usingCheckerboardSampling = usingCheckerboardSampling;
                #if defined(_RAYMARCH_TEMPORAL_FILTER_ON)
                result = GetTemporalFilteredResult(temporalFilterInput);
                
                #else
                result = currFrameRawPixelColor;
 
                #endif
                
             //   return backgroundColor;
             //   return tex2D(_CurrFrameTex, v2f.uv);
                //return cloudResult;
                
                #if defined(_RAYMARCH_TEMPORAL_FILTER_BLEND_BACKGROUND)
                half4 backgroundColor = tex2D(_MainTex, v2f.uv);
                result = BlendWithBackground(backgroundColor, currFrameRawPixelColor.rgb,currFrameRawPixelColor.a);
                #endif

              
                GaussianFilterInput gaussianInput;
                gaussianInput.centerColor = result;
                gaussianInput.pixelPos = v2f.position.xy;
                gaussianInput.screenUV = v2f.uv;
                gaussianInput.screenUVDelta = _CurrFrameTex_TexelSize.xy;
                gaussianInput.prevFrameTex = _PrevFrameTex;
                gaussianInput.currRawFrameTex = _CurrFrameTex;
                gaussianInput.usingCheckerboardSampling = usingCheckerboardSampling;
                gaussianInput.spatialKernelSize = _BilateralFilter_SpatialKernelSize;
                gaussianInput.tonalSigma  = _BilateralFilter_ColorSigma;
                gaussianInput.evenOdd  = _CheckerboardSampling_EvenOdd;
                #if defined(_BILATERAL_FILTER_ON)
                result = GetBilateralFilteredResult(gaussianInput);
                #endif
                return result;
            }

            ENDHLSL
            
        }
    }

}
