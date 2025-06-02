using System.Collections.Generic;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;
using UnityEngine;

namespace RenderFeatures.VolumetricCloud.RenderPasses {
    

	public class PostProcessCloudRenderPass : ScriptableRenderPass {

		private const string PassTag = "Volumetric Cloud Post Process Render Pass";

	
		private Material _material;

		private static readonly int PrevFrameTexPropertyID;
		private static readonly int PrevFrameViewProjectMatrixPropertyID;
		private static readonly int CurrFrameTexPropertyID;
		private bool _checkerboardRendering;
		private int _rayMarchingPassID;
		private int _blendPassID;
		private CommandBuffer _command;

		// Since unity runs passes for every camera, it's needed to get some contexts being per-camera.
		private Dictionary<int, VolumetricCloudRenderFeature.PerCameraRenderContext> _perCameraContexts = new();


		static PostProcessCloudRenderPass() {
			PrevFrameTexPropertyID = Shader.PropertyToID("_PrevFrameTex");
			PrevFrameViewProjectMatrixPropertyID = Shader.PropertyToID("_PrevFrameViewProjectMatrix");
			CurrFrameTexPropertyID = Shader.PropertyToID("_CurrFrameTex");
		}

		public void Setup(Material material,bool checkerboardRendering) {
			_material = material;
			_rayMarchingPassID = material.FindPass("Ray Marching Pass");
			_blendPassID = material.FindPass("Blend Pass");
			_command = CommandBufferPool.Get(PassTag);
			_checkerboardRendering = checkerboardRendering;
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

		private void RenderBlendPass(RenderTexture currentFrameTex, RenderTexture prevFrameTex,
			in RenderTargetIdentifier backgroundRT, in RenderTargetIdentifier outputRT) {

			_material.SetTexture(CurrFrameTexPropertyID, currentFrameTex);
			_material.SetTexture(PrevFrameTexPropertyID, prevFrameTex);
			// background color as _MainTex
			_command.Blit(backgroundRT, outputRT, _material, _blendPassID);
		}


		private VolumetricCloudRenderFeature.PerCameraRenderContext GetPerCameraRenderContext(Camera camera,
			in RenderTextureDescriptor textureDescriptor) {
			VolumetricCloudRenderFeature.PerCameraRenderContext renderContext;
			if (false == _perCameraContexts.TryGetValue(camera.GetInstanceID(), out renderContext)) {
				renderContext = new VolumetricCloudRenderFeature.PerCameraRenderContext(textureDescriptor, 2,_checkerboardRendering);
				_perCameraContexts.Add(camera.GetInstanceID(), renderContext);
			}

			return renderContext;
		}




		public override void Execute(ScriptableRenderContext ctx, ref RenderingData data) {
			RenderTargetIdentifier cameraRT = data.cameraData.renderer.cameraColorTarget;
			RenderTextureDescriptor textureDescriptor = data.cameraData.cameraTargetDescriptor;
			textureDescriptor.colorFormat = RenderTextureFormat.ARGBFloat;
			textureDescriptor.depthBufferBits = 24;
			Camera camera = data.cameraData.camera;
			VolumetricCloudRenderFeature.PerCameraRenderContext cameraCtx = GetPerCameraRenderContext(camera, textureDescriptor);
	
			if (_checkerboardRendering) {
				_material.SetFloat("_CheckerboardSampling_EvenOdd",cameraCtx.FrameParity);
			}
			if (cameraCtx.IsFirstFrame) {
				// first frame
				cameraCtx.IsFirstFrame = false;
				RenderRayMarchingPass(cameraCtx.TempRTIdentifier);
				RenderBlendPass(cameraCtx.TempRT, cameraCtx.PreviousFrameRT, cameraRT, cameraCtx.CurrentFrameRT);
				cameraCtx.SetPreviousFrameViewProjectMatrix(camera);
				cameraCtx.SwapFrameTexture();
				if (_checkerboardRendering) {
					_material.SetFloat("_CheckerboardSampling_EvenOdd",cameraCtx.FrameParity);
				}
			}

			_material.SetMatrix(PrevFrameViewProjectMatrixPropertyID, cameraCtx.PreviousFrameViewProjectMatrix);
			RenderRayMarchingPass(cameraCtx.TempRTIdentifier);
			
			RenderBlendPass(cameraCtx.TempRT, cameraCtx.PreviousFrameRT, cameraRT, cameraCtx.CurrentFrameRT);

			_command.Blit(cameraCtx.CurrentFrameRT, cameraRT);
			cameraCtx.SetPreviousFrameViewProjectMatrix(camera);
			cameraCtx.SwapFrameTexture();
			ctx.ExecuteCommandBuffer(_command);
		}

	}

}