Shader "OceanWave"
{
    Properties
    {
		_GlobalMap("GlobalMap", 2D) = "white" {}
    	_WaveMap("WaveMap", 2D) = "white" {}
    	_FoamMap("FoamMap", 2D) = "white" {}
    	_TestMap("TestMap", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
		Cull Back ZWrite On 

        HLSLINCLUDE
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Packing.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"


			CBUFFER_START(UnityPerMaterial)

			CBUFFER_END
		
			#ifdef UNITY_DOTS_INSTANCING_ENABLED
			UNITY_DOTS_INSTANCING_START(MaterialPropertyMetadata)

			UNITY_DOTS_INSTANCING_END(MaterialPropertyMetadata)
		
			#endif
	
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
		ENDHLSL
        
        Pass
        {
            HLSLPROGRAM

            // GPU Instancing
			#pragma multi_compile_instancing
			#pragma multi_compile _ DOTS_INSTANCING_ON
            
            #pragma vertex vert
            #pragma fragment frag
            
            TEXTURE2D(_GlobalMap);
			SAMPLER(sampler_GlobalMap);
            
            TEXTURE2D(_WaveMap);
			SAMPLER(sampler_WaveMap);
            
			TEXTURE2D(_FoamMap);
			SAMPLER(sampler_FoamMap);
            
            TEXTURE2D(_TestMap);
			SAMPLER(sampler_TestMap);
            
            float _Loop;

            
            struct appdata
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            	UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
            	float2 Velocity : TEXCOORD1;
            	float FoamMask : TEXCOORD3;
            	float3 positionWS : TEXCOORD2;
                float4 positionCS : SV_POSITION;
            	UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
            };

   
            v2f vert(appdata input)
            {
                v2f output;

            	UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
            	
				VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

				output.uv = (vertexInput.positionWS.xz / 20) * 0.5f + 0.5f;
            	float4 GlobalMap = _GlobalMap.SampleLevel(sampler_GlobalMap, output.uv, 0);
     
        		float WaveDistance = 5.0f;
            	float WaveSpeed = 0.2f;
            	float WaveCount = 0.6f;
            	float WaveTime = 0.2f;
            	
				float2 Gradient = (GlobalMap.gb * 2.0f - 1.0f) * float2(-1,1);
            	float DistanceField = -(GlobalMap.r * 2.0f - 1.0f) * WaveDistance;
        
            	float u = frac(DistanceField + _Time.y * WaveSpeed);
            	float v = (DistanceField - WaveTime - u) * WaveCount;

            	float4 Wave = _WaveMap.SampleLevel(sampler_WaveMap,  float2(1-u,v), 0) * 2.0f - 1.0f;

            	float3 OffsetForward = Wave.x * float3(Gradient.x, 0, Gradient.y) * 0.2f;
            	float3 OffsetUp = Wave.y * float3(0, 1, 0) * 0.1f;
            	vertexInput.positionWS += (OffsetForward + OffsetUp) * (1 - GlobalMap.r);
            	
				output.Velocity = (OffsetForward.xz + Gradient) * saturate(DistanceField * 0.005f);
				output.FoamMask = Wave.b * 0.5 + 0.5;
            	
            	output.positionWS = vertexInput.positionWS;
				output.positionCS = TransformWorldToHClip(vertexInput.positionWS);
			
                return output;
            }

            
            float4 frag(v2f input) : SV_Target
            {
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
            	
            	float time = _Time.y * 4.0f;
            	float Loop1 = cos(time) * 0.5f + 0.5f;
            	float Loop2 = cos(time + 1.0f/3.0f * TWO_PI) * 0.5f + 0.5f;
            	float Loop3 = cos(time + 2.0f/3.0f* TWO_PI) * 0.5f + 0.5f;
				float4 Foam1 = _FoamMap.SampleLevel(sampler_FoamMap, input.uv * 100 - input.Velocity * Loop1, 0);
				float4 Foam2 = _FoamMap.SampleLevel(sampler_FoamMap, input.uv * 100 - input.Velocity * Loop2 + float2(0.1,0.1), 0);
            	float4 Foam3 = _FoamMap.SampleLevel(sampler_FoamMap, input.uv * 100 - input.Velocity * Loop3 + float2(-0.1,-0.1), 0);

            	float weight = 1.0f / 3.0f;
				float4 FinalFoam = Foam1 * Loop1 * weight + Foam2 * Loop2 * weight + Foam3 * Loop3 * weight;

            	float4 GlobalMap = _GlobalMap.SampleLevel(sampler_GlobalMap, input.uv, 0);
            	float coastline = saturate((GlobalMap.r - 0.5) * 5);
            	input.FoamMask = max(input.FoamMask, coastline);

            	float4 TestMap = _TestMap.SampleLevel(sampler_TestMap, input.uv * 500, 0) * 0.4f;
            	float4 foam = lerp(float4(0.1,0.3,0.4,1) * (1 + TestMap), float4(1,1,1,1), FinalFoam.a * input.FoamMask);
            	
				return foam;
            	
			}
            
            ENDHLSL
        }
        
        
      
        
    }
}
