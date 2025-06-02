Shader "Custom/Ocean/BakedOceanWave"
{
    Properties
    {
	    [Header(Water Lighting Config)]
    	_WaterTransmissionColor("Transmission Color", Color) = (0.92, 0.95, 0.95, 1)
    	_WaterSurfaceColor("Surface Color", Color) = (0.95, 0.95, 0.95, 0.95)
    	_IndexOfRefraction("Index Of Refraction", Range(1, 2)) = 1.33
    	_DepthScale("Transmission Depth Scale", Float) = 1
    	_ScreenUVDistortionIntensity("Screen UV Distortion Intensity", Float) = 0.5
    	_Scattering_Detail("Scattering Detail Color", Color) =  (1, 1, 1, 1)
    	_Scattering_Power("Scattering Power", Float) = 1
    	_Scattering_Scale("Scattering Scale", Float) = 1
	    [NoScaleOffset]
    	_Tex("Texture", 2D) = "white" {}
	    [NoScaleOffset]
    	_FoamMap("Foam Map", 2D) = "white" {}
    	_FoamMap_UVScale("Foam Map UV Scale", Float) = 1
    	_FoamMap_Scale("Foam Map Scale",Float) = 1
		[Header(Terrain Config)]
    	[NoScaleOffset]
    	_TerrainMap("Terrain Map", 2D) = "white" {}
    	_TerrainMap_AxisU("Terrain Map Axis U", Vector) = (1,0,0,0)
    	_TerrainMap_AxisV("Terrain Map Axis V", Vector) = (0,1,0,0)
    	_TerrainMap_SizeU("Terrain Map Size U", Float) = 1
    	_TerrainMap_SizeV("Terrain Map Size V", Float) = 1
    	_TerrainMap_Origin("Terrain Map Origin", Vector) = (0,0,0,0)
	    [Toggle(_TERRAIN_MAP_INVERSE_SDF_RANGE)]
    	_TERRAIN_MAP_INVERSE_SDF_RANGE("Inverse SDF Range", Float) = 0
	    [Toggle(_TERRAIN_MAP_INVERSE_GRADIENT_X)]
    	_TERRAIN_MAP_INVERSE_GRADIENT_X("Inverse Gradient X", Float) = 0
	    [Toggle(_TERRAIN_MAP_INVERSE_GRADIENT_Z)]
    	_TERRAIN_MAP_INVERSE_GRADIENT_Z("Inverse Gradient Z", Float) = 0
	    [NoScaleOffset]
    	_NearshoreWaveMap("Nearshore Wave Map", 2D) = "white" {}
    	_NearshoreWave_WaveSpeed("Wave Speed", Float) = 1
    	_NearshoreWave_WaveCount("Wave Count", Float) = 1
    	_NearshoreWave_WaveForwardScale("Wave Forward Scale", Float) = 1
    	_NearshoreWave_WaveUpwardScale("Wave Upward Scale", Float) = 1
    	_NearshoreWave_FoamIntensity("Foam Intensity", Float) = 1
    	[Toggle(_NEARSHORE_WAVE_INVERSE_U)]
    	_NEARSHORE_WAVE_INVERSE_U("Inverse U", Float) = 0
	    [Toggle(_NEARSHORE_WAVE_INVERSE_V)]
    	_NEARSHORE_WAVE_INVERSE_V("Inverse V", Float) = 0
	    [Header(Distant Sea Wave Config)]
    	[NoScaleOffset]
    	_DistantWaveMap("Distant Sea Wave Map", 2DArray) = "white" {}
    	_DistantWave_FrameCount("Frame Count", Float) = 1
    	_DistantWave_FPS("Wave Speed (FPS)", Float) = 1
    	_DistantWave_UVScale("UV Scale",  Float) = 1
    	_DistantWave_DisplacementScale("Displacement Scale", Float) = 1
    	_DistantWave_UVRotate("UV Rotate", Float) = 0
    	_DistantWave_Direction("Direction", Vector) = (0,0,0,0)
    	[Header(Detail Wave Config)]
	    [NoScaleOffset]
	    _DetailWaveMap("Detail Wave Map", 2D) = "white" {}
    	_DetailWave_UVScale("UV Scale",  Float) = 1
    	_DetailWave_NormalDisplacementScale("Normal Displacement Scale", Float) = 1
    	_DetailWave_PositionDisplacementScale("Position Displacement Scale", Float) = 1
    	_DetailWave_Speed("Speed", Float) = 0.05
    	_DetailWave_Direction("Direction",Vector) = (0,0,0,0)
    	_DetailWave_FoamThreshold("Foam Threshold", Float) = 0.5
    	_DetailWave_FoamIntensity("Foam Intensity", Float) = 1
  
     }

    
    HLSLINCLUDE

	
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/BRDF.hlsl"
	#include "HLSLSupport.cginc"
	#include "Assets/Shaders/HLSLInclude/RandomNumberUtils.hlsl"
    #include "HLSLInclude/WaterLightingUtils.hlsl"
    #include "HLSLInclude/SeaWaveHelperStructs.hlsl"
    #include "HLSLInclude/SeaWave.hlsl"

	
    sampler2D _FoamMap;
	sampler2D _ReflectionTex;
	sampler2D _TerrainMap;
	sampler2D _NearshoreWaveMap;
	Texture2DArray _DistantWaveMap;
	SamplerState  sampler_DistantWaveMap;
	sampler2D _DetailWaveMap;
	sampler2D _Tex;

	float3 _TerrainMap_AxisU;
	float3 _TerrainMap_AxisV;
	float3 _TerrainMap_Origin;
	float4 _TerrainMap_TexelSize;
	float _TerrainMap_SizeU;
	float _TerrainMap_SizeV;
	
	float4 _Nearshore_WaveMap_TexelSize;
	float _NearshoreWave_WaveSpeed;
	float _NearshoreWave_WaveCount;
	float _NearshoreWave_WaveForwardScale;
	float _NearshoreWave_WaveUpwardScale;
	float _NearshoreWave_FoamIntensity;

	float _DistantWave_FrameCount;
	float _DistantWave_FPS;
	float _DistantWave_UVScale;
	float _DistantWave_UVRotate;
	float _DistantWave_DisplacementScale;
	float2 _DistantWave_Direction;

	float _DetailWave_UVScale;
	float _DetailWave_NormalDisplacementScale;
	float _DetailWave_PositionDisplacementScale;
	float _DetailWave_Speed;
	float2 _DetailWave_Direction;
	float _DetailWave_FoamThreshold;
	float _DetailWave_FoamIntensity;

	float4 _ReflectionTex_TexelSize;
	float4 _WaterTransmissionColor;
	float4 _WaterSurfaceColor;
	float _DepthScale;
	float _IndexOfRefraction;
	float _FoamMap_UVScale;
	float _FoamMap_Scale;

	float _ScreenUVDistortionIntensity;
	float4 _Scattering_Detail;
	float _Scattering_Power;
	float _Scattering_Scale;
	
	UNITY_INSTANCING_BUFFER_START(Props)
		UNITY_DEFINE_INSTANCED_PROP(float4, _PageStitchingMask)
	UNITY_INSTANCING_BUFFER_END(Props)
		

	
    struct Attributes
    {
	    float4 positionOS : POSITION;
    	float2 uv : TEXCOORD0;
		UNITY_VERTEX_INPUT_INSTANCE_ID
    };

    
    struct Varyings
    {
        float4 position : SV_POSITION;
        float2 screenUV : TEXCOORD0;
    	float2 worldUV: TEXCOORD1;
    	float3 viewDirWS : TEXCOORD2;
    	float3 positionWS : TEXCOORD3;
    	float3 normalWS : TEXCOORD4;
    	float3 originalPositionWS : TEXCOORD5;
		float4 velocity : TEXCOORD6;
    	float3 mask : TEXCOORD7;
    	UNITY_VERTEX_INPUT_INSTANCE_ID
    };
	
	
	
	float2 GetTerrainMapUV(float3 position,TerrainParams params)
	{
		float2 uvScale = 1.0f / float2(params.mapSizeU,params.mapSizeV);
		float3 posVec =  position - params.axisOrigin;
		float u = dot(posVec, params.axisU)*uvScale.x;
		float v = dot(posVec, params.axisV)*uvScale.y;
		return float2(u,v);
	}

	float2 GetTerrainMapUV2(float3 position,TerrainParams params)
	{
		float2 uvScale = 1.0f / float2(params.mapSizeU,params.mapSizeV);
		float3 posVec =  position - params.axisOrigin;
		float u = dot(posVec, params.axisU)*uvScale.x;
		float v = dot(posVec, params.axisV)*uvScale.y;
		
		return float2(u,v);
	}

	TerrainParams GetTerrainParams()
	{
		TerrainParams  terrainParams;
		terrainParams.terrainMap = _TerrainMap;
	//	terrainParams.terrainMap = UNITY_ACCESS_INSTANCED_PROP(Props,_TerrainMap);
		terrainParams.axisU = _TerrainMap_AxisU;
		terrainParams.axisV = _TerrainMap_AxisV;
		terrainParams.axisOrigin = _TerrainMap_Origin;
		terrainParams.mapSizeU = _TerrainMap_SizeU;
		terrainParams.mapSizeV = _TerrainMap_SizeV;
		terrainParams.terrainMap_TexelSize = _TerrainMap_TexelSize;
		terrainParams.inverseSDFRange = false;
		#ifdef _TERRAIN_MAP_INVERSE_SDF_RANGE
		terrainParams.inverseSDFRange = true;
		#endif
		terrainParams.inverseGradient = bool2(false,false);
		#ifdef _TERRAIN_MAP_INVERSE_GRADIENT_X
		terrainParams.inverseGradient.x = true;
		#endif
		#ifdef _TERRAIN_MAP_INVERSE_GRADIENT_Y
		terrainParams.inverseGradient.y = true;
		#endif
		return terrainParams;
	}

	NearshoreWaveParams GetNearshoreWaveParams()
	{
		NearshoreWaveParams  waveParams;
		waveParams.waveMap = _NearshoreWaveMap;
		//waveParams.waveMap = UNITY_ACCESS_INSTANCED_PROP(Props,_WaveMap);
		waveParams.waveMap_TexelSize = _Nearshore_WaveMap_TexelSize;
		waveParams.waveSpeed = _NearshoreWave_WaveSpeed;
		waveParams.waveCount = _NearshoreWave_WaveCount;
		waveParams.waveForwardScale = _NearshoreWave_WaveForwardScale;
		waveParams.waveUpwardScale = _NearshoreWave_WaveUpwardScale;
		waveParams.time = _Time.y;
		waveParams.foamIntensity = _NearshoreWave_FoamIntensity;
		waveParams.inverseUV = bool2(false,false);
		#ifdef _NEARSHORE_WAVE_INVERSE_V
		waveParams.inverseUV.y = true;
		#endif

		#ifdef _NEARSHORE_WAVE_INVERSE_U
		waveParams.inverseUV.x = true;
		#endif
		
		return waveParams;
	}

	

	DistantWaveParams GetDistantWaveParams()
	{
		DistantWaveParams  waveParams;
		waveParams.distantWaveMap = _DistantWaveMap;
		waveParams.mapSampler = sampler_DistantWaveMap;
		waveParams.uvScale = _DistantWave_UVScale;
		waveParams.uvRotate = _DistantWave_UVRotate;
		waveParams.displacementScale = _DistantWave_DisplacementScale;
		waveParams.frameCount = _DistantWave_FrameCount;
		waveParams.fps =_DistantWave_FPS;
		waveParams.time = _Time.y;
		waveParams.direction = _DistantWave_Direction;
		return waveParams;
	}

	DetailWaveParams GetDetailWaveParams()
	{
		DetailWaveParams detailParams;
		detailParams.detailWaveMap = _DetailWaveMap;
		detailParams.uvScale = _DetailWave_UVScale;
		detailParams.speed = _DetailWave_Speed;
		detailParams.direction = _DetailWave_Direction;
		detailParams.foamIntensity = _DetailWave_FoamIntensity;
		detailParams.foamThreshold = _DetailWave_FoamThreshold;
		detailParams.normalDisplacementScale = _DetailWave_NormalDisplacementScale;
		detailParams.positionDisplacementScale = _DetailWave_PositionDisplacementScale;
		return detailParams;
	}

	FoamMapParams GetFoamMapParams()
	{
		FoamMapParams  foamParams;
		foamParams.foamMap = _FoamMap;
		foamParams.foamMapScale = _FoamMap_Scale;
		foamParams.foamMapUVScale = _FoamMap_UVScale;
		return foamParams;
	}

	FluxLightingParams GetFluxLightingParams()
	{
		FluxLightingParams  fluxParams;
		fluxParams.reflectionTex = _ReflectionTex;
		fluxParams.reflectionTex_TexelSize = _ReflectionTex_TexelSize;
		fluxParams.waterTransmissionColor = _WaterTransmissionColor;
		fluxParams.waterSurfaceColor = _WaterSurfaceColor;
		fluxParams.depthScale = _DepthScale;
		fluxParams.indexOfRefraction = _IndexOfRefraction;
		fluxParams.screenUVDistortionIntensity = _ScreenUVDistortionIntensity;
		fluxParams.scatteringDetail = _Scattering_Detail;
		fluxParams.scatteringPower = _Scattering_Power;
		fluxParams.scatteringScale = _Scattering_Scale;
		return fluxParams;
	}
	

	
	
	struct WaveData
	{
		float3 position;
		float4 velocity; 
		float foamMask;	// represents where foam should exist.
		float2 nearDistMask; //x: near-dist 0-1 step, y: near-dist 0-1 smoothstep
		float2 worldUV; 
		float3 normal;
	};


	float4 SampleTerrainData(TerrainParams terrainParams,float2 terrainUV)
	{
		float4 terrainData = tex2Dlod(terrainParams.terrainMap,float4(terrainUV,0,0));
		if (terrainParams.inverseSDFRange){
			terrainData.r = 1.0f - terrainData.r;
		}
		if (terrainParams.inverseGradient.x){
			terrainData.g *= -1;
		}
		if (terrainParams.inverseGradient.y){
			terrainData.b *= -1;
		}
		return terrainData;
	}
	
	WaveData GetBasicWaveData(TerrainParams terrainParams,NearshoreWaveParams nearWaveParams,DistantWaveParams distWaveParams,float3 position)
	{
		WaveData waveData;
		float3 nearshorePos = position;
		float2 terrainUV = GetTerrainMapUV(nearshorePos,terrainParams);
		float4 terrainData = SampleTerrainData(terrainParams,terrainUV);
		float2 nearDistMask = GetNearDistMask(terrainUV,terrainData);
		
		NearshoreWaveResult nearshoreResult = NearshoreWaveMorphing(nearWaveParams,terrainData);
		DistantWaveResult distResult = DistantWaveMorphing(distWaveParams,terrainUV,float2(1,0));
		nearshoreResult.foamMask *= nearDistMask.x;
		waveData.foamMask = lerp(nearshoreResult.foamMask,0,nearDistMask.y);
		waveData.normal = float3(0,1,0);
		waveData.velocity =  float4(nearshoreResult.velocity,distResult.velocity);
		waveData.position = position + lerp(nearshoreResult.positionDisplacement,distResult.positionDisplacement,nearDistMask.y);
		waveData.worldUV = terrainUV;
		waveData.nearDistMask = nearDistMask;
		return waveData;
	}
	

	void StitchVertex(float4 pageStitchingMask,inout float4 positionOS)
	{
		float2 pos = positionOS.xz*pageStitchingMask.xy;
		float desiredVertexCount = pageStitchingMask.z;
		if (any(pos > 0.499))
		{
			float x = positionOS.x*desiredVertexCount;
			float z = positionOS.z*desiredVertexCount;
			positionOS.x = round(x)/desiredVertexCount;
			positionOS.z = round(z)/desiredVertexCount;
		}
	}



	void MergePositionWithDetails(FoamMapData foamMaskData,DetailWaveData detailWaveData,inout WaveData waveData){
		waveData.foamMask += lerp(0,detailWaveData.foamMask,waveData.nearDistMask.y);
		waveData.position += lerp(float3(0,0,0),detailWaveData.positionDisplacement,waveData.nearDistMask.y);
		waveData.position += foamMaskData.positionDisplacement*waveData.foamMask;
	}

	void MergeNormalWithDetails(FoamMapData foamMaskData,DetailWaveData detailWaveData,float foamMask,float2 nearDistMask,inout float3 normal){
		normal += lerp(float3(0,0,0),detailWaveData.normalDisplacement,nearDistMask.y);
		normal += foamMaskData.normalDisplacement*foamMask;
		normal = normalize(normal);
	}
	
	
	Varyings vert_wave(Attributes a2v)
	{
		Varyings v2f;
		UNITY_SETUP_INSTANCE_ID(a2v);
		UNITY_TRANSFER_INSTANCE_ID(a2v, v2f);
		
		TerrainParams terrainParams = GetTerrainParams();
		NearshoreWaveParams nearWaveParams = GetNearshoreWaveParams();
		DistantWaveParams distWaveParams = GetDistantWaveParams();
		
		float4 pageStitchingMask = UNITY_ACCESS_INSTANCED_PROP(Props,_PageStitchingMask);
		StitchVertex(pageStitchingMask,a2v.positionOS);
		
		v2f.originalPositionWS = TransformObjectToWorld(a2v.positionOS);
		float3 neighborPosWS1 = v2f.originalPositionWS + float3(0,0,1);
		float3 neighborPosWS2 = v2f.originalPositionWS + float3(1,0,0);
		
		WaveData waveData = GetBasicWaveData(terrainParams,nearWaveParams,distWaveParams,v2f.originalPositionWS);
		WaveData neighborWaveData1 = GetBasicWaveData(terrainParams,nearWaveParams,distWaveParams,neighborPosWS1);
		WaveData neighborWaveData2 = GetBasicWaveData(terrainParams,nearWaveParams,distWaveParams,neighborPosWS2);
		
		waveData.normal = normalize(cross(neighborWaveData1.position - waveData.position,
			neighborWaveData2.position - waveData.position));
		
		FoamMapData foamMapData = SampleFoamMap(GetFoamMapParams(),waveData.worldUV,waveData.velocity.xy,_Time.y);
		DetailWaveData detailWaveData = SampleDetailWaveMap(GetDetailWaveParams(),waveData.worldUV,_Time.y);
		MergePositionWithDetails(foamMapData,detailWaveData,waveData);

		
		v2f.velocity = waveData.velocity;
		v2f.mask.x = waveData.foamMask;
		v2f.mask.yz = waveData.nearDistMask;
		v2f.worldUV  = waveData.worldUV;
		v2f.normalWS = waveData.normal;
		v2f.positionWS = waveData.position;
		v2f.position = TransformWorldToHClip(v2f.positionWS);
		v2f.viewDirWS = _WorldSpaceCameraPos  - v2f.positionWS;
		float4 screenPos = ComputeScreenPos(v2f.position);
		v2f.screenUV = screenPos.xy/screenPos.w;
		//v2f.worldUV = a2v.uv;
		return v2f;
	}
	

	void ReconstructNormal(float3 positionWS,inout float3 normalWS)
	{
		float3 dpx = ddx(positionWS);
		float3 dpy = ddy(positionWS);
		float3 normal = normalize(cross(dpy,dpx));
		if (dot(normal,normalWS)<0)
		{
			normal = -normal;
		}
		normal.x = clamp(normal.x,-0.25,0.25);
		normal.z = clamp(normal.z,-0.25,0.25);
		normal.y = clamp(normal.y,0.85,1);
		normal = normalize(normal);
		float3 dnormalx = ddx(normal);
		float3 dnormaly = ddy(normal);
		normal = normalize((3*normal+dnormalx+dnormaly)/3);
		normalWS = normal;
	}



	// From FluidFlux
	float3 Scatter(float3 normalWS,float3 normalWS2,float3 viewDir,float3 scatterDetail,float scatterPower,float scatterScale)
	{
		float vertexNoV = dot(normalWS, viewDir);
		float pixelNoV = dot(normalWS2, viewDir);
		float3 scatter = lerp(vertexNoV, abs(pixelNoV),  scatterDetail);
		scatter -= viewDir.g;
		scatter = saturate(scatter);
		scatter = pow(scatter, scatterPower);
		scatter = saturate(scatter * scatterScale);
		return scatter;
	}

	//half shadow = SoftShadows(screenUV, IN.posWS, IN.viewDir, depth.x);



	float ShadowAttenuation(float2 screenUV, float3 positionWS, float3 viewDir, float depth){
		float shadowAttenuation = 0;
		float4 shadowMapCoord = TransformWorldToShadowCoord(positionWS);
		shadowAttenuation += SAMPLE_TEXTURE2D_SHADOW(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture, shadowMapCoord);
	    return BEYOND_SHADOW_FAR(shadowMapCoord) ? 1.0 : shadowAttenuation+0.3;
	}
	
	float4 frag(Varyings v2f) : SV_Target
	{
		UNITY_SETUP_INSTANCE_ID(v2f);
	//	float4 t = tex2D(_Tex,v2f.worldUV);
	//	return float4(t.rgb,1);
		FluxLightingParams fluxParams = GetFluxLightingParams();
		float ior = fluxParams.indexOfRefraction;
		
		float2 screenUV = v2f.position/_ScreenParams.xy;
		FoamMapData foamMapData = SampleFoamMap(GetFoamMapParams(),v2f.worldUV,v2f.velocity,_Time.y);
		DetailWaveData detailWaveData = SampleDetailWaveMap(GetDetailWaveParams(),v2f.worldUV,_Time.y);
		float3 vertexNormal = v2f.normalWS;
		float3 pixelNormal = v2f.normalWS;
		MergeNormalWithDetails(foamMapData,detailWaveData,v2f.mask.x,v2f.mask.yz,pixelNormal);
		
		DistortUV(v2f.normalWS,v2f.position,fluxParams.screenUVDistortionIntensity,v2f.screenUV);
		
		float waterEyeDepth = GetLinearEyeDepthFromRawZ(v2f.position.z);
		float opaqueDepth = GetLinearEyeDepthFromScene(v2f.screenUV);
		float3 distortedRayHitPointWS = TransformScreenspaceToWorld(v2f.screenUV);
		float2 sceneUV;
		float2 realScreenUV = v2f.position/_ScreenParams.xy;
		float2 realScreenUVDelta = screenUV/_ScreenParams.xy;
		if (opaqueDepth < waterEyeDepth ){
			//opaqueDepth > waterEyeDepth will get opaque color above the water.
			//cancel this screen uv shift to get more realistic result.
			sceneUV  = realScreenUV;
			//GetDistortedUV(-5*v2f.normalWS,v2f.position,fluxParams.screenUVDistortionIntensity,sceneUV);
		}else{
			sceneUV = v2f.screenUV;
		}
		
		float3 rayHitPointWS = TransformScreenspaceToWorld(sceneUV);
		float depth = length(rayHitPointWS - v2f.positionWS);

		float3 viewDirWS = normalize(v2f.viewDirWS);
		float2 refractionUV = sceneUV;//shiftedScreenUV;
	
		float3 background = SampleSceneColor(refractionUV);
		//MixedSample()
		float3 refraction = float3(0,0,0);
		refraction = Refraction(background , depth ,fluxParams.depthScale, TransmissionColorToAbsorption(fluxParams.waterTransmissionColor.rgb,1.0));
		
		float2 reflectionUV = v2f.screenUV;
		float smoothness = 0.9;
		Light light = GetMainLight();
	
		float3 f0 = SchlickFresnelF0(ior);
		float3 f = SchlickFresnel(pixelNormal,viewDirWS,ior);
		float3 reflection =  tex2D(fluxParams.reflectionTex,reflectionUV);
		refraction*=(1-f)/(ior*ior);
		reflection*=f;
	
		float3 scattering = Scatter(vertexNormal,pixelNormal,viewDirWS,fluxParams.scatteringDetail,fluxParams.scatteringPower,fluxParams.scatteringScale);
		float3 waterLighting =  lerp(fluxParams.waterSurfaceColor.rgb,refraction,fluxParams.waterSurfaceColor.a);
		float foamMask = v2f.mask.x;
		waterLighting = lerp(waterLighting,float4(1,1,1,1),foamMapData.foamAlpha*foamMask) + scattering;
		float3 specular = BRDF_Specular(smoothness,pixelNormal,light.direction,viewDirWS,light.color,f0);
		float shadowAttenuation = ShadowAttenuation(screenUV, v2f.positionWS, viewDirWS, depth);
		float3 result = waterLighting + specular + reflection;
		result*=shadowAttenuation;
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
            HLSLPROGRAM
			#pragma enable_d3d11_debug_symbols
			#pragma multi_compile_instancing
            #pragma vertex vert_wave
            #pragma fragment frag
            #pragma target 4.0
			#pragma multi_compile _ _NEARSHORE_WAVE_INVERSE_V
			#pragma multi_compile _ _NEARSHORE_WAVE_INVERSE_U
			#pragma multi_compile _ _TERRAIN_MAP_INVERSE_SDF_RANGE
			#pragma multi_compile _ _TERRAIN_MAP_INVERSE_GRADIENT_X
			#pragma multi_compile _ _TERRAIN_MAP_INVERSE_GRADIENT_Y


            ENDHLSL
        }


    }
}
