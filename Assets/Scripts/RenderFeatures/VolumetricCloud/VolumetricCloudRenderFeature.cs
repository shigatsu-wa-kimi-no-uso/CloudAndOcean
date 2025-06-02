using System.Collections.Generic;
using RenderFeatures.VolumetricCloud.RenderPasses;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine;

namespace RenderFeatures.VolumetricCloud {


	[DisallowMultipleRendererFeature("VolumetricCloudRenderFeature")]
	public class VolumetricCloudRenderFeature : ScriptableRendererFeature {
		
		private PostProcessCloudRenderPass postProcessPass;
		private SkyBoxCloudRenderPass skyBoxPass;

	
		public enum CloudRenderType {
			ScreenSpacePostProcess,
			HemiOctahedronSkyBox
		}

		[SerializeField]
		public CloudRenderType cloudRenderType;
		

		[SerializeField]
		public RenderPassEvent renderPassEvent;

		[SerializeField]
		public bool checkerboardRendering;

		[SerializeField]
		public bool fullRenderingWhenInView;

		[SerializeField]
		public bool splitCloudRendering;

		[SerializeField]
		public Material material;

		[SerializeField]
		private Rect HemiOctaTextureRect = new(0, 0, 768, 768);

		public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData) {
			if (material == null) {
				return;
			}
			RenderTextureDescriptor rtDescriptor = renderingData.cameraData.cameraTargetDescriptor;
			switch (cloudRenderType) {
				case CloudRenderType.ScreenSpacePostProcess:
					if (checkerboardRendering) {
						material.SetVector("_CheckerboardSampling_OriginalRTResolution",renderingData.cameraData.camera.pixelRect.size);
					}
					postProcessPass.Setup(material,checkerboardRendering);
					renderer.EnqueuePass(postProcessPass);
					break;
				case CloudRenderType.HemiOctahedronSkyBox:
					skyBoxPass.Setup(material,rtDescriptor,HemiOctaTextureRect,checkerboardRendering);
					renderer.EnqueuePass(skyBoxPass);
					break;
			}
			

		}

		public override void Create() {
			switch (cloudRenderType) {
				case CloudRenderType.ScreenSpacePostProcess:
					postProcessPass = new ();
					postProcessPass.renderPassEvent = renderPassEvent;
					if (RenderSettings.skybox != null) {
						RenderSettings.skybox.SetFloat("_HemiOctahedron",0);
						RenderSettings.skybox.SetTexture("_Cloud",null);
					}
					material.SetKeyword(new LocalKeyword(material.shader,"_CHECKERBOARD_SAMPLING_ON"),checkerboardRendering);
					material.SetKeyword(new LocalKeyword(material.shader,"_RAYMARCH_SCREEN_SPACE"),true);
					material.SetKeyword(new LocalKeyword(material.shader,"_RAYMARCH_HEMI_OCTAHEDRON_SPACE"),false);
					material.SetKeyword(new LocalKeyword(material.shader,"_RAYMARCH_TEMPORAL_FILTER_NO_REPROJECTION"),false);
					if (splitCloudRendering) {
						material.SetKeyword(new LocalKeyword(material.shader,"_RAYMARCH_BLEND_BACKGROUND"),false);
						material.SetKeyword(new LocalKeyword(material.shader,"_RAYMARCH_TEMPORAL_FILTER_BLEND_BACKGROUND"),true);
					} else {
						material.SetKeyword(new LocalKeyword(material.shader,"_RAYMARCH_BLEND_BACKGROUND"),true);
						material.SetKeyword(new LocalKeyword(material.shader,"_RAYMARCH_TEMPORAL_FILTER_BLEND_BACKGROUND"),false);
					}
				
					material.SetKeyword(new LocalKeyword(material.shader,"_CHECKERBOARD_OCTAHEDRON_SPACE"),false);
					break;
				case CloudRenderType.HemiOctahedronSkyBox:
					skyBoxPass = new();
					skyBoxPass.renderPassEvent = renderPassEvent;
					if (RenderSettings.skybox != null) {
						RenderSettings.skybox.SetTexture("_Cloud", null);
						RenderSettings.skybox.SetFloat("_HemiOctahedron",1);
					}
					material.SetVector("_CheckerboardSampling_OriginalRTResolution",HemiOctaTextureRect.size);
					material.SetKeyword(new LocalKeyword(material.shader,"_CHECKERBOARD_SAMPLING_ON"),checkerboardRendering);
					material.SetKeyword(new LocalKeyword(material.shader,"_RAYMARCH_SCREEN_SPACE"),false);
					material.SetKeyword(new LocalKeyword(material.shader,"_RAYMARCH_HEMI_OCTAHEDRON_SPACE"),true);
					material.SetKeyword(new LocalKeyword(material.shader,"_RAYMARCH_TEMPORAL_FILTER_NO_REPROJECTION"),true);
					material.SetKeyword(new LocalKeyword(material.shader,"_RAYMARCH_BLEND_BACKGROUND"),false);
					material.SetKeyword(new LocalKeyword(material.shader,"_RAYMARCH_TEMPORAL_FILTER_BLEND_BACKGROUND"),false);
					material.SetKeyword(new LocalKeyword(material.shader,"_CHECKERBOARD_OCTAHEDRON_SPACE"),true);
					if (checkerboardRendering) {
						material.SetKeyword(new LocalKeyword(material.shader,"_CHECKERBOARD_FULL_RENDERING_WHEN_INVIEW"),fullRenderingWhenInView);
					}
					break;
			}

		
		}

		public class PerCameraRenderContext {
			private bool _firstFrame;
			private RenderTargetIdentifier[] _frameRTIdentifiers;
			private RenderTexture[] _frameTextures;
			private Matrix4x4 _previousFrameViewProjectMatrix;
			private int _frameIndex;
			private readonly int _totalRenderTextureCount;
			private Camera _camera;
			private Rect _cameraOriginalPixelRect;
			private readonly RenderTexture _tempRT;
			private readonly RenderTargetIdentifier _tempRTIdentifier;
		
			public PerCameraRenderContext(in RenderTextureDescriptor textureDescriptor, int renderTextureCount) {
				_totalRenderTextureCount = renderTextureCount;
				_CreateFrameTextures(textureDescriptor, renderTextureCount);
				_tempRT = RenderTexture.GetTemporary(textureDescriptor);
				_tempRTIdentifier = new RenderTargetIdentifier(_tempRT);
				_firstFrame = true;
			}
			
			public PerCameraRenderContext(in RenderTextureDescriptor textureDescriptor, int renderTextureCount,bool checkerboardRendering) {
				_totalRenderTextureCount = renderTextureCount;
				_CreateFrameTextures(textureDescriptor, renderTextureCount);
				if (checkerboardRendering) {
					RenderTextureDescriptor textureDesc = textureDescriptor;
					textureDesc.width /= 2;
					//Checkerboard sampled RT has half x-axis resolution of the original RT.
					//Since the UV coordinate is the pixel center position, not the pixel grid index,
					//if sampling the RT with two times the checkerboard UV resolution, values will be interpolated.
					//Set the filterMode to point to avoid interpolation. (or rectify the uv in shader to avoid it)
					_tempRT = RenderTexture.GetTemporary(textureDesc);
					_tempRT.filterMode = FilterMode.Point;
				} else {
					_tempRT = RenderTexture.GetTemporary(textureDescriptor);
				}
				_tempRTIdentifier = new RenderTargetIdentifier(_tempRT);
				_firstFrame = true;
			}
			
			~PerCameraRenderContext() {
				for (int i = 0; i < _totalRenderTextureCount; i++) {
					RenderTexture.ReleaseTemporary(_frameTextures[i]);
				}
				RenderTexture.ReleaseTemporary(_tempRT);
			}


			public void SetCameraOriginalPixelRect(in Rect rect) {
				_cameraOriginalPixelRect = rect;
			}
			
			public ref readonly Rect GetCameraOriginalPixelRect() {
				return ref _cameraOriginalPixelRect;
			}
			
			public void SetCamera(Camera camera) {
				_camera = camera;
			}
			
			public Camera GetCamera() {
				return _camera;
			}
			
			public bool IsFirstFrame {
				get => _firstFrame;
				set => _firstFrame = value;
			}

			public int FrameParity {
				get => _frameIndex;
			}

			public RenderTexture PreviousFrameRT {
				get => _frameTextures[_GetNextFrameIndex()];
			}

			public ref readonly RenderTargetIdentifier PreviousFrameRTIdentifier {
				get => ref _frameRTIdentifiers[_GetNextFrameIndex()];
			}

			public RenderTexture TempRT {
				get => _tempRT;
			}
			
			public ref readonly RenderTargetIdentifier TempRTIdentifier {
				get => ref _tempRTIdentifier;
			}
			
			
			
			public RenderTexture CurrentFrameRT {
				get => _frameTextures[_GetCurrentFrameIndex()];
			}

			public ref readonly RenderTargetIdentifier CurrentFrameRTIdentifier {
				get => ref _frameRTIdentifiers[_GetCurrentFrameIndex()];
			}

			
	
			

			public ref readonly Matrix4x4 PreviousFrameViewProjectMatrix {
				get => ref _previousFrameViewProjectMatrix;
			}

			public void SwapFrameTexture() {
				_frameIndex = _GetNextFrameIndex();
			}

			public void SetPreviousFrameViewProjectMatrix(Camera camera) {
				// store current frame VP for next frame use
				_previousFrameViewProjectMatrix = camera.projectionMatrix * camera.worldToCameraMatrix;
			}


			private int _GetCurrentFrameIndex() {
				return _frameIndex;
			}

			private int _GetNextFrameIndex() {
				return (_GetCurrentFrameIndex() + 1) % _totalRenderTextureCount;
			}
			
		

			private void _CreateFrameTextures(in RenderTextureDescriptor rtDescriptor, int count) {
				_frameTextures = new RenderTexture[count];
				_frameRTIdentifiers = new RenderTargetIdentifier[count];
				for (int i = 0; i < count; i++) {
					_frameTextures[i] = RenderTexture.GetTemporary(rtDescriptor);
					_frameRTIdentifiers[i] = new RenderTargetIdentifier(_frameTextures[i]);
				}
				_frameIndex = 0;
			}
		}

		



	}

}