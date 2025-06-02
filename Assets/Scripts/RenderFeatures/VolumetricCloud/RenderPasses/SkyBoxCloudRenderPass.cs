
using System.Collections.Generic;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine;


namespace RenderFeatures.VolumetricCloud.RenderPasses {
    public class SkyBoxCloudRenderPass : ScriptableRenderPass{
        private const string PassTag = "Volumetric Cloud Sky Box Render Pass";
        
        private Material _material;

        private static readonly int PrevFrameTexPropertyID;
        private static readonly int PrevFrameViewProjectMatrixPropertyID;
        private static readonly int CurrFrameTexPropertyID;
        private static readonly int SkyBoxTexPropertyID;
		private bool _checkerboardRendering;
		private RenderTextureDescriptor _hemiOctaTextureDescriptor;
		
        private int _rayMarchingPassID;
        private int _blendPassID;
        private CommandBuffer _command;
	
		private VolumetricCloudRenderFeature.PerCameraRenderContext _currentCameraRenderContext;
		
        // Since unity runs passes for every camera, it's needed to get some contexts being per-camera.
        private Dictionary<int, VolumetricCloudRenderFeature.PerCameraRenderContext> _perCameraContexts = new();


        static SkyBoxCloudRenderPass() {
            PrevFrameTexPropertyID = Shader.PropertyToID("_PrevFrameTex");
            PrevFrameViewProjectMatrixPropertyID = Shader.PropertyToID("_PrevFrameViewProjectMatrix");
            CurrFrameTexPropertyID = Shader.PropertyToID("_CurrFrameTex");
            
            
        }
        
  

	    ~SkyBoxCloudRenderPass() {
			
        }
         
        public void Setup(Material material,in RenderTextureDescriptor rtDescriptor,in Rect hemiOctaTextureRect,bool checkerboardRendering) {
            _material = material;
            _rayMarchingPassID = material.FindPass("Ray Marching Pass");
            _blendPassID = material.FindPass("Blend Pass");
            _command = CommandBufferPool.Get(PassTag);
            _hemiOctaTextureDescriptor = rtDescriptor;
            _hemiOctaTextureDescriptor.width = (int)hemiOctaTextureRect.width;
            _hemiOctaTextureDescriptor.height = (int)hemiOctaTextureRect.height;
            _hemiOctaTextureDescriptor.depthBufferBits = 0;
            _hemiOctaTextureDescriptor.useDynamicScale = true;
            _hemiOctaTextureDescriptor.colorFormat = RenderTextureFormat.ARGBFloat;
            _checkerboardRendering = checkerboardRendering;
        }
        
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData) {
           // base.OnCameraSetup(cmd, ref renderingData);
           Camera camera = renderingData.cameraData.camera;
           _currentCameraRenderContext = GetPerCameraRenderContext(camera,_hemiOctaTextureDescriptor);

        }

        public override void OnCameraCleanup(CommandBuffer cmd) {
	    //    _perCameraContexts.Remove(currentCameraRenderContext.GetCamera().GetInstanceID());
        }

  		private RenderTexture GetTemporaryRenderTexture(in RenderTextureDescriptor rtDescriptor) {
			return RenderTexture.GetTemporary(rtDescriptor.width, rtDescriptor.height, rtDescriptor.depthBufferBits,
				rtDescriptor.colorFormat);
		}


		private void RenderRayMarchingPass(in RenderTargetIdentifier outputRT) {
			// nothing is sent to _MainTex because we don't need it
			_command.Blit(null, outputRT, _material, _rayMarchingPassID);
		}

		private void RenderRayMarchingPass(in RenderTargetIdentifier outputRT, in RenderTargetIdentifier cameraRT) {
			// nothing is sent to _MainTex because we don't need it
			_command.Blit(cameraRT, outputRT, _material, _rayMarchingPassID);
		}

		private RenderTargetHandle GetTemporaryRT(string shaderPropertyName, in RenderTextureDescriptor rtDescriptor) {
			RenderTargetHandle rt = new RenderTargetHandle();
			rt.Init(shaderPropertyName);
			_command.GetTemporaryRT(rt.id, rtDescriptor);
			return rt;
		}

		private void RenderBlendPass(RenderTexture currRawFrameTex, RenderTexture prevFrameTex,
			in RenderTargetIdentifier backgroundRT, in RenderTargetIdentifier outputRT) {

			_material.SetTexture(CurrFrameTexPropertyID, currRawFrameTex);
			_material.SetTexture(PrevFrameTexPropertyID, prevFrameTex);
			// background color as _MainTex
			_command.Blit(backgroundRT, outputRT, _material, _blendPassID);
		}

		private void RenderBlendPass(RenderTexture currRawFrameTex, RenderTexture prevFrameTex, in RenderTargetIdentifier outputRT) {

			_material.SetTexture(CurrFrameTexPropertyID, currRawFrameTex);
			_material.SetTexture(PrevFrameTexPropertyID, prevFrameTex);
			// background color as _MainTex
			_command.Blit(null, outputRT, _material, _blendPassID);
		}


		private VolumetricCloudRenderFeature.PerCameraRenderContext GetPerCameraRenderContext(Camera camera,
			in RenderTextureDescriptor textureDescriptor) {
			VolumetricCloudRenderFeature.PerCameraRenderContext renderContext;
			if (false == _perCameraContexts.TryGetValue(camera.GetInstanceID(), out renderContext)) {
				renderContext = new VolumetricCloudRenderFeature.PerCameraRenderContext(textureDescriptor, 2,_checkerboardRendering);
				renderContext.SetCameraOriginalPixelRect(camera.pixelRect);
				renderContext.SetCamera(camera);
				_perCameraContexts.Add(camera.GetInstanceID(), renderContext);
			}

			return renderContext;
		}

		
		public override void Execute(ScriptableRenderContext ctx, ref RenderingData data) {
			RenderTargetIdentifier cameraRT = data.cameraData.renderer.cameraColorTarget;
			var cameraCtx = _currentCameraRenderContext;
			Camera camera = data.cameraData.camera;
			//checkerboardSampledRTDescriptor.
			//checkerboardSampledRTDescriptor.useMipMap = false;
		//	checkerboardSampledRTDescriptor.
		
		
			_material.SetMatrix("_CurrFrameViewProjectMatrix", camera.projectionMatrix * camera.worldToCameraMatrix );

			if (_checkerboardRendering) {
				_material.SetFloat("_CheckerboardSampling_EvenOdd",_currentCameraRenderContext.FrameParity);
			}
			
			if (cameraCtx.IsFirstFrame) {
				// first frame
				cameraCtx.IsFirstFrame = false;
				RenderRayMarchingPass(cameraCtx.CurrentFrameRTIdentifier);
				cameraCtx.SwapFrameTexture();
				if (_checkerboardRendering) {
					_material.SetFloat("_CheckerboardSampling_EvenOdd",_currentCameraRenderContext.FrameParity);
				}
			}
	
			RenderRayMarchingPass(cameraCtx.TempRTIdentifier);
			RenderBlendPass(cameraCtx.TempRT, cameraCtx.PreviousFrameRT, cameraCtx.CurrentFrameRT);
			if (RenderSettings.skybox != null) {
				RenderSettings.skybox.SetTexture("_Cloud",cameraCtx.CurrentFrameRT);
			}
			
			cameraCtx.SwapFrameTexture();
			
			// CommandBuffer.Blit implicitly sets the render target to the 'dest' target,
			// since we don't use Blit to output to camera RT in the last operation, 
			// we must restore the render target to camera RT manually.

			_command.SetRenderTarget(cameraRT);	
			
			ctx.ExecuteCommandBuffer(_command);
			//_command.Clear();
			//CommandBufferPool.Release(_command);
		

		}
    }
}