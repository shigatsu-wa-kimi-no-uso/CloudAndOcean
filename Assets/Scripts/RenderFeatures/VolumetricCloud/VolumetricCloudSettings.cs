using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace RenderFeatures.VolumetricCloud {
    
    [System.Serializable]
    [VolumeComponentMenuForRenderPipeline("Custom/PostProcessing/VolumetricCloud", typeof(UniversalRenderPipeline))]
    public class VolumetricCloudSettings {
        
	[Tooltip("Enable rendering volumetric cloud")]
	public BoolParameter enabled = new BoolParameter(false);


	[Header("Shape Controller")]
	[Tooltip("Min Bounds of the Volume")]
	public Vector3Parameter volumeBoundsMin = new Vector3Parameter(new Vector3(-10, -10, -10));

	[Tooltip("Max Bounds of the Volume")]
	public Vector3Parameter volumeBoundsMax = new Vector3Parameter(new Vector3(10, 10, 10));

	[Tooltip("Density Noise Texture")]
	public Texture3DParameter densityNoise = new Texture3DParameter(null);

	
	[Tooltip("Density Noise Sample Value Scale")]
	public Vector4Parameter densityScale = new Vector4Parameter(Vector4.one);

	[Tooltip("Density Noise Sample Value Offset")]
	public Vector4Parameter densityOffset = new Vector4Parameter(Vector4.zero);

	[Tooltip("Density Noise Sample UVW Scale")]
	public Vector3Parameter densityTiling = new Vector3Parameter(Vector3.one);

	[Tooltip("Density Noise Sample UVW Offset")]
	public Vector3Parameter densitySampleUVWOffset = new Vector3Parameter(Vector3.zero);

	[Tooltip("Erosion Noise Texture")]
	public Texture3DParameter erosionNoise = new Texture3DParameter(null);

	[Tooltip("Erosion Noise Sample Value Scale")]
	public Vector4Parameter erosionSampleValueScale = new Vector4Parameter(Vector4.one);

	[Tooltip("Erosion Noise Sample Value Scale")]
	public Vector4Parameter erosionSampleValueOffset = new Vector4Parameter(Vector4.zero);

	[Tooltip("Erosion Noise Sample UVW Scale")]
	public Vector3Parameter erosionSampleUVWScale = new Vector3Parameter(Vector3.one);

	[Tooltip("Erosion Noise Sample UVW Offset")]
	public Vector3Parameter erosionSampleUVWOffset = new Vector3Parameter(Vector3.zero);


    [Header("Lighting Controller")]
	[Tooltip("Base Color")]
	public ColorParameter baseColor = new ColorParameter(new Color(1, 0, 0, 1));


	[Tooltip("Base Light Intensity")]
	public FloatParameter baseLightIntensity = new FloatParameter(1.0f);


	[Tooltip("Beer Lamberts��s Law Transimttance Sigma Factor")]
	public Vector4Parameter sigma = new Vector4Parameter(new Vector4(1, 1, 1, 1));


	[Tooltip("Molar Absorption Coefficient")]
	public Vector4Parameter absorption = new Vector4Parameter(Vector4.one);


	[Tooltip("Molar Absorption Coefficient For Light")]
	public Vector4Parameter absorptionLight = new Vector4Parameter(Vector4.one);

	[Tooltip("Hg Phase Function G1 Factor")]
	public ClampedFloatParameter hgPhaseFunctionG1Factor = new ClampedFloatParameter(0.5f, -0.99f, 0.99f);

	[Tooltip("Hg Phase Function G2 Factor")]
	public ClampedFloatParameter hgPhaseFunctionG2Factor = new ClampedFloatParameter(0.5f, -0.99f, 0.99f);

	[Tooltip("Specify Marching by Stride")]
	public BoolParameter specifyingMarchByStride = new BoolParameter(false);


	

	[Tooltip("Ray Marching Step Size")]
	public FloatParameter rayMarchingStepSize = new FloatParameter(1f);


	[Tooltip("Ray Marching Max Iteration")]
	public IntParameter rayMarchingMaxIteration = new IntParameter(100);

	[Tooltip("Scatter Ray Marching Step Size")]
	public FloatParameter scatterRayMarchingStepSize = new FloatParameter(1f);


	[Tooltip("Scatter Ray Marching Max Iteration")]
	public IntParameter scatterRayMarchingMaxIteration = new IntParameter(100);

	[Tooltip("Enable jitter when sampling points on the ray marching path")]
	public BoolParameter jitterSampling = new BoolParameter(false);

	[Tooltip("Relative jitter range (in pencentage, resulting as '[samplePoint - stride*jitterRange,samplePoint + stride*jitterRange]')")]
	public ClampedFloatParameter jitterRange = new ClampedFloatParameter(0.5f, 0.0f, 0.5f);

	[Tooltip("Random seed for jittering")]
	public FloatParameter randomSeed = new FloatParameter(0.0f);


	public bool IsActive() {
		return enabled.value;
	}
	public bool IsTileCompatible() => false;

	public void load(Material material, ref RenderingData data) {
	
		
		if (densityNoise != null) {
			material.SetTexture("_DensityNoiseTex", densityNoise.value);
	
		}
		if (erosionSampleValueScale != null) {
			material.SetTexture("_ErosionNoiseTex", erosionNoise.value);
		}
		material.SetColor("_BaseColor", baseColor.value);
		material.SetFloat("_BaseLightIntensity", baseLightIntensity.value);
		material.SetVector("_Sigma", sigma.value);
		material.SetVector("_Absorption", absorption.value);
		material.SetVector("_AbsorptionLight",absorptionLight.value);
		//material.SetVector("_DensitySampleValueScale", densitySampleValueScale.value);
		//material.SetVector("_DensitySampleValueOffset", densitySampleValueOffset.value);
		//material.SetVector("_DensitySampleUVWScale", densitySampleUVWScale.value);
		material.SetVector("_DensitySampleUVWOffset", densitySampleUVWOffset.value);
		material.SetVector("_ErosionSampleValueScale", erosionSampleValueScale.value);
		material.SetVector("_ErosionSampleValueOffset", erosionSampleValueOffset.value);
		material.SetVector("_ErosionSampleUVWScale", erosionSampleUVWScale.value);
		material.SetVector("_ErosionSampleUVWOffset", erosionSampleUVWOffset.value);
		material.SetVector("_VolumeBoundsMin", volumeBoundsMin.value);
		material.SetVector("_VolumeBoundsMax", volumeBoundsMax.value);
		material.SetFloat("_RayMarchingStepSize", rayMarchingStepSize.value);
		material.SetFloat("_RayMarchingMaxIteration", rayMarchingMaxIteration.value);
		material.SetFloat("_ScatterRayMarchingStepSize", scatterRayMarchingStepSize.value);
		material.SetFloat("_ScatterRayMarchingMaxIteration", scatterRayMarchingMaxIteration.value);
		material.SetFloat("_HgPhaseG1Factor", hgPhaseFunctionG1Factor.value);
		material.SetFloat("_HgPhaseG2Factor", hgPhaseFunctionG2Factor.value);
		if (specifyingMarchByStride.value) {
			material.EnableKeyword("_RAYMARCH_SPEC_BY_STRIDE");
		} else {
			material.DisableKeyword("_RAYMARCH_SPEC_BY_STRIDE");
		}

		if(jitterSampling.value) {
			material.EnableKeyword("_RAYMARCH_JITTER");
			material.SetFloat("_RelativeJitterRange", jitterRange.value);
			material.SetFloat("_RandomSeed", randomSeed.value);
		} else {
			material.DisableKeyword("_RAYMARCH_JITTER");
		}
	
	}
    }
}