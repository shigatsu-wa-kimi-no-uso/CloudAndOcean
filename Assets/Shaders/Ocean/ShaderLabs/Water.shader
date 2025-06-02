Shader "Custom/Water"
{
    Properties
    {
	    [Header(Water Lighting Config)]
    	_WaterTransmissionColor("Transmission Color", Color) = (0.92, 0.95, 0.95, 1)
    	_WaterSurfaceColor("Surface Color", Color) = (0.95, 0.95, 0.95, 0.95)
    	_IndexOfRefraction("Index Of Refraction", Range(1, 2)) = 1.33
    	_DepthScale("Transmission Depth Scale", Float) = 1
    	[Header(Wave Config 1)]
		_Wavelength_0("Wavelength", Float) = 1
    	_Speed_0("Speed", Float) = 1
		_Steepness_0("Steepness", Range(0, 1)) = 0.5
    	_Direction_0("Direction", Vector) = (1, 0, 0, 0)
	    [Header(Wave Config 2)]
	    _Wavelength_1("Wavelength", Float) = 1
    	_Speed_1("Speed", Float) = 1
		_Steepness_1("Steepness", Range(0, 1)) = 0.5
    	_Direction_1("Direction", Vector) = (1, 0, 0, 0)
	    [Header(Wave Config 3)]
	    _Wavelength_2("Wavelength", Float) = 1
    	_Speed_2("Speed", Float) = 1
		_Steepness_2("Steepness", Range(0, 1)) = 0.5
    	_Direction_2("Direction", Vector) = (1, 0, 0, 0)
     }

    
    HLSLINCLUDE
	
	#define ARRAY_GET(name, index) name##_##index
	#define ARRAY_DECL_2(name) name##_0,name##_1
	#define ARRAY_DECL_3(name) name##_0,name##_1,name##_2
	#define ARRAY_DECL_4(name) name##_0,name##_1,name##_2,name##_3


	sampler2D _ReflectionTex;
	sampler2D _ReflectionTex_TexelSize;
	float ARRAY_DECL_3(_Wavelength);
	float ARRAY_DECL_3(_Speed);
	float ARRAY_DECL_3(_Steepness);
	float3 ARRAY_DECL_3(_Direction);
	float4 _WaterTransmissionColor;
	float4 _WaterSurfaceColor;
	float _DepthScale;
	float _IndexOfRefraction;
	
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
	#include "../HLSLInclude/GerstnerWaveHelper.hlsl"
    #include "../HLSLInclude/CommonShaderUtils.hlsl"
    #include "../HLSLInclude/WaterLightingUtils.hlsl"
	
    struct Attributes
    {
	    float4 positionOS : POSITION;
    	float2 uv : TEXCOORD0;
    };

    
    struct Varyings
    {
        float4 position : SV_POSITION;
        float2 uv : TEXCOORD0;
    	float3 viewDirWS : TEXCOORD1;
    	float3 positionWS : TEXCOORD2;
    	float3 normalWS : TEXCOORD3;
    	float3 originalNormalWS : TEXCOORD4;
   
    };


	struct GerstnerWaveData
	{
		float3 position;
		float3 normal;
	};

	GerstnerWaveData GetGerstnerWave(float3 positionWS, float3 direction, float steepness, float phaseSpeed, float Wavelength, float time)
	{
		GerstnerWaveData wave;
		GerstnerWaveInput input;
    	input.position = positionWS;
    	input.direction	= direction;
		input.steepness = steepness;
    	input.speed = phaseSpeed;
    	input.wavelength = Wavelength;
    	input.time = time;
		wave.position = GetGerstnerWavePosition(input);
		wave.normal = GetGerstnerWaveNormal(input);
		return wave;
	}
	

	
    Varyings vert(Attributes a2v)
	{
	    Varyings v2f;
    
	    float3 positionWS = mul(GetObjectToWorldMatrix(),a2v.positionOS).xyz;
    	float time = _Time.y;

		float rectifiedSteepness[3];
		float sum = ARRAY_GET(_Steepness,0) + ARRAY_GET(_Steepness,1) + ARRAY_GET(_Steepness,2);
		sum += 0.0001; // avoid dividing by zero
		rectifiedSteepness[0] = ARRAY_GET(_Steepness,0)*ARRAY_GET(_Steepness,0) / sum;
		rectifiedSteepness[1] = ARRAY_GET(_Steepness,1)*ARRAY_GET(_Steepness,1) / sum;
		rectifiedSteepness[2] = ARRAY_GET(_Steepness,2)*ARRAY_GET(_Steepness,2) / sum;
		
		GerstnerWaveData g1 = GetGerstnerWave(positionWS, normalize(ARRAY_GET(_Direction,0)), rectifiedSteepness[0],
			ARRAY_GET(_Speed,0),ARRAY_GET(_Wavelength,0),time);
		GerstnerWaveData g2 = GetGerstnerWave(positionWS, normalize(ARRAY_GET(_Direction,1)), rectifiedSteepness[1],
			ARRAY_GET(_Speed,1),ARRAY_GET(_Wavelength,1),time);
		GerstnerWaveData g3 = GetGerstnerWave(positionWS, normalize(ARRAY_GET(_Direction,2)), rectifiedSteepness[2],ARRAY_GET(_Speed,2),
			ARRAY_GET(_Wavelength,2),time);
		
		v2f.positionWS = positionWS + g1.position + g2.position + g3.position;
		//see https://zhuanlan.zhihu.com/p/490275564
    	v2f.normalWS = normalize(float3(0,1,0) + g1.normal + g2.normal + g3.normal);
		v2f.originalNormalWS = float3(0,1,0);
	    v2f.viewDirWS = _WorldSpaceCameraPos  - v2f.positionWS;
		v2f.position = TransformWorldToHClip(v2f.positionWS);
		v2f.uv = a2v.uv;
    	//v2f.color = float3(v2f.position.xyz);
	    return v2f;
	}

	
	
	float4 frag(Varyings v2f) : SV_Target
	{
		
		float2 screenUV = v2f.position/_ScreenParams.xy;
		float3 opaqueNormal = GetOpaqueSceneGeometryNormal(screenUV,screenUV/_ScreenParams.xy,v2f.normalWS);
		float3 rayHitPointWS = TransformScreenspaceToWorld(screenUV);
		float deflectionAngle = GetDeflectionAngle(normalize(v2f.viewDirWS),v2f.normalWS,v2f.originalNormalWS,_IndexOfRefraction);
		
		float3 shiftedRayHitPointWS = GetApproximateDeflectedRefractionRayHitPoint(v2f.positionWS,rayHitPointWS,opaqueNormal,deflectionAngle);
		//float3 rayHitPointWS = GetRefractionRayHitPoint(v2f.positionWS,normalize(v2f.viewDirWS),normalize(v2f.normalWS),1.0/_IndexOfRefraction,500);
		float4 shiftedRayHitPointSS = TransformWorldToScreenspace(shiftedRayHitPointWS);
		float2 shiftedScreenUV = shiftedRayHitPointSS.xy;
		shiftedRayHitPointWS = TransformScreenspaceToWorld(shiftedScreenUV);
	//	float2 screenUV = rayHitPointSS.xy;
		//return float4(screenUV,0,1);
		//return float4(rayHitPointWS,1);
		//return float4(rayHitPointWS,1);
		
		float waterEyeDepth = GetLinearEyeDepthFromRawZ(v2f.position.z);
		float opaqueDepth = GetLinearEyeDepthFromScene(shiftedScreenUV);
		if (opaqueDepth < waterEyeDepth)
		{
			//opaqueDepth > waterEyeDepth will get opaque color above the water.
			//cancel this screen uv shift to get more realistic result.
			shiftedRayHitPointWS = rayHitPointWS;
			shiftedScreenUV = screenUV;
		}
		//float opaqueDepth = length(shiftedRayHitPointWS - v2f.positionWS);//GetLinearSceneEyeDepth(screenUV);
		//float depth = opaqueDepth - waterEyeDepth;//length(rayHitPointWS - v2f.positionWS);
		float depth = length(shiftedRayHitPointWS - v2f.positionWS);
		//float opaqueDepth = GetLinearSceneEyeDepth(screenUV);
	//	return float4(waterEyeDepth,waterEyeDepth,waterEyeDepth,1);
		float3 viewDirWS = normalize(v2f.viewDirWS);
		float3 f = SchlickFresnel(v2f.normalWS, viewDirWS,_IndexOfRefraction);
		float3 refraction = Refraction(shiftedScreenUV, depth ,_DepthScale, TransmissionColorToAbsorption(_WaterTransmissionColor.rgb,1.0));
	
		float reflectDeflectionAngle = GetReflectDeflectionAngle(viewDirWS,v2f.originalNormalWS,v2f.normalWS);
		float3 pos = GetApproximateDeflectedReflectionRayHitPoint(v2f.positionWS,-viewDirWS,v2f.originalNormalWS,reflectDeflectionAngle);
		float4 reflectionScreenUV = TransformWorldToScreenspace(pos);
		float3 reflection =  tex2D(_ReflectionTex,reflectionScreenUV.xy) * f;
		refraction *=(1-f)*_IndexOfRefraction*_IndexOfRefraction;
		float3 result = lerp(_WaterSurfaceColor.rgb,refraction,_WaterSurfaceColor.a) + reflection;
		return float4(result,1);
	}

	
	
	
    ENDHLSL
    
     SubShader
     {
        Blend One Zero

        Tags 
		{
			 "RenderPipeline"="UniversalPipeline"
			 "RenderType"="Transparent"
			 "Queue"="Transparent"
		}

        
        Pass
        {
            Name "Water"
    
            HLSLPROGRAM
			#pragma enable_d3d11_debug_symbols
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            ENDHLSL
        }


    }
}
