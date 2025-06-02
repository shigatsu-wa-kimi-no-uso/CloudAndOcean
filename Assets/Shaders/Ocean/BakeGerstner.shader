Shader "Custom/Scripts/GerstnerWaveBaking/BakeGerstner" {
    Properties {
        _MainTex ("Texture", 2D) = "white" {}
    }
    
    HLSLINCLUDE
     	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
     	#include "HLSLInclude/GerstnerWaveHelper.hlsl"

    float _Wavelength[10];
     	float _Steepness[10];
		float3 _Direction[10];
     	float _LoopCount[10];
     	float _FrameIndex;
     	float _FrameCount;
     	int _WaveCount;
     	
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

     	struct GerstnerWaveData
		{
			float3 position;
			float3 normal;
     		float amplitude;
		};

		GerstnerWaveData GetGerstnerWave(float3 positionWS, float3 direction, float steepness,float Wavelength, float loop)
		{
			GerstnerWaveData wave;
			GerstnerWaveInput input;
    		input.position = positionWS;
    		input.direction	= direction;
			input.steepness = steepness;
    		input.speed = 1;
    		input.wavelength = Wavelength;
    		input.time = Wavelength * loop;
			wave.position = GetGerstnerWavePosition(input);
			wave.normal = GetGerstnerWaveNormal(input);
			wave.amplitude = GetAmplitude(input.wavelength,input.steepness);
			return wave;
		}
     	

     	Varyings vert_Blit(Attributes a2v)
        {
            Varyings v2f;
            v2f.position = TransformObjectToHClip(a2v.vertex);
            v2f.uv = a2v.uv;
            return v2f;
        }

    

     	
     	float4 frag_GerstnerWave(Varyings v2f) : SV_Target
        {
            float3 positionWS = float3(v2f.uv.x, 0, v2f.uv.y);
        	float rectifiedSteepness[10];
        	float steepnessSum = 0.0001; // avoid dividing by zero
        	for (int i = 0; i < _WaveCount; i++){
        		 steepnessSum += _Steepness[i];
        	}
        	
        	for (int i = 0; i < _WaveCount; i++){
        		rectifiedSteepness[i] = _Steepness[i]*_Steepness[i] / steepnessSum;
        	}
        	
        	GerstnerWaveData g[10];
        	float3 positionDisplacement = float3(0,0,0);
			float amplitude = 0.0001;
        	for (int i = 0; i < _WaveCount; i++){
        		g[i] = GetGerstnerWave(positionWS, normalize(_Direction[i]), rectifiedSteepness[i],
        			_Wavelength[i],(_FrameIndex/_FrameCount)*_LoopCount[i]);
        		positionDisplacement += g[i].position;
        		amplitude += g[i].amplitude;
        	}
        	positionDisplacement /= amplitude;
        	return float4(positionDisplacement*0.5+0.5,amplitude);
        }

     	
   ENDHLSL

   SubShader {
        Tags {
			 "RenderPipeline"="UniversalPipeline"
		}
        
        Pass{
            Name "BakeGerstner"
            
            HLSLPROGRAM
                #pragma vertex vert_Blit
                #pragma fragment frag_GerstnerWave
                #pragma target 3.0
            ENDHLSL
        }
    }
}