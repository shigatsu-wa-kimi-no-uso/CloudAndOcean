
using System;
using UnityEngine.Experimental.Rendering;
using Unity.Mathematics;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Serialization;
using Object = UnityEngine.Object;


namespace Ocean {
    
    
    [ExecuteAlways]
    public class WaterReflectionEffector : MonoBehaviour {
        
        [Serializable]
        public enum ResolutionMultiplier { Full, Half, Third, Quarter }

        [Serializable]
        public class PlanarReflectionSettings {
            public ResolutionMultiplier resolutionMultiplier = ResolutionMultiplier.Third;
            public float planeOffset = 0f;
            public LayerMask reflectLayers = -1;
            public bool shadows;
        }
        
        [SerializeField]
        public PlanarReflectionSettings settings = new();
        public GameObject targetPlane;
    
        private static Camera _reflectionCamera;
        private static Matrix4x4 _reflectionMatrix;
        private static Matrix4x4 _obliqueClippedProjectionMatrix;
        private RenderTexture _reflectionTexture;
        private readonly int _planarReflectionTextureId = Shader.PropertyToID("_ReflectionTex");
        


        // public static event Action<ScriptableRenderContext, Camera> BeginPlanarReflections;
        private void OnEnable() {
            RenderPipelineManager.beginCameraRendering += RenderReflection;
        }

        private void OnDisable() {
            Cleanup();
        }

        private void OnDestroy() {
            Cleanup();
        }

        private void Cleanup() {
            RenderPipelineManager.beginCameraRendering -= RenderReflection;
            if(_reflectionCamera) {  // 释放相机
                _reflectionCamera.targetTexture = null;
                SafeDestroy(_reflectionCamera.gameObject);
            }
            if (_reflectionTexture) {  // 释放纹理
                RenderTexture.ReleaseTemporary(_reflectionTexture);
            }
        }
        private static void SafeDestroy(Object obj) {
            if (Application.isEditor) {
                DestroyImmediate(obj);  //TODO
            }
            else {
                Destroy(obj);   //TODO
            }
        }
        private void RenderReflection(ScriptableRenderContext context, Camera renderCamera) {
            // we don't want to render planar reflections when cameras is for reflection probe or preview.
            if (renderCamera.cameraType == CameraType.Reflection || renderCamera.cameraType == CameraType.Preview) {
                return;
            }
          

            if (targetPlane == null) {
                targetPlane = gameObject;
            }
            
            if (_reflectionCamera == null) {
                _reflectionCamera = CreateReflectCamera();
            }

            RendererSettingsManager.Store(); // save quality settings and lower them for the planar reflections
            RendererSettingsManager.Set(); // set quality settings

            UpdateReflectionCamera(renderCamera);  
            CreatePlanarReflectionTexture(renderCamera); 
            
            UniversalRenderPipeline.RenderSingleCamera(context, _reflectionCamera);
            
            RendererSettingsManager.Restore(); // restore the quality settings
            Shader.SetGlobalTexture(_planarReflectionTextureId, _reflectionTexture); // Assign texture to all shaders
        }

        private int2 ReflectionResolution(Camera cam, float scale) {
            var x = (int)(cam.pixelWidth * scale * GetScaleValue());
            var y = (int)(cam.pixelHeight * scale * GetScaleValue());
            return new int2(x, y);
        }

        private float GetScaleValue() {
            switch(settings.resolutionMultiplier) {
                case ResolutionMultiplier.Full:
                    return 1f;
                case ResolutionMultiplier.Half:
                    return 0.5f;
                case ResolutionMultiplier.Third:
                    return 0.33f;
                case ResolutionMultiplier.Quarter:
                    return 0.25f;
                default:
                    return 0.5f; // default to half res
            }
        }

        private void CreatePlanarReflectionTexture(Camera cam) {
            if (_reflectionTexture == null) {
                int2 res = ReflectionResolution(cam, UniversalRenderPipeline.asset.renderScale);  // 获取 RT 的大小
                const bool useHdr10 = true;
                const RenderTextureFormat hdrFormat = useHdr10 ? RenderTextureFormat.RGB111110Float : RenderTextureFormat.DefaultHDR;
                _reflectionTexture = RenderTexture.GetTemporary(res.x, res.y, 16,
                    GraphicsFormatUtility.GetGraphicsFormat(hdrFormat, true));
            }
            _reflectionCamera.targetTexture =  _reflectionTexture; // 将 RT 赋予相机
        }
        private void SyncCameraSettings(Camera src, Camera dest) {
            if (dest == null) {
                return;
            }

          //  dest.CopyFrom(src);
            dest.backgroundColor = src.backgroundColor;
            // once modified this property, unity won't derive it from transform.
            dest.worldToCameraMatrix = src.worldToCameraMatrix; 
            dest.projectionMatrix = src.projectionMatrix;
            dest.transform.position = src.transform.position;
            dest.aspect = src.aspect;
            dest.cameraType = src.cameraType;   // 这个参数不同步就错
            dest.clearFlags = src.clearFlags;
            dest.fieldOfView = src.fieldOfView;
            dest.depth = src.depth;
            dest.farClipPlane = 3*src.farClipPlane;
            dest.focalLength = src.focalLength;
            dest.useOcclusionCulling = false;
        }

        // Calculates reflection matrix around the given plane
        private ref Matrix4x4 CalculateReflectionMatrix(in Vector3 planeNormal,in Vector3 position)
        {
            float d = -Vector3.Dot(planeNormal, position);
            _reflectionMatrix.m00 = (1.0f - 2.0f * planeNormal.x * planeNormal.x);
            _reflectionMatrix.m01 = (-2.0f * planeNormal.x *  planeNormal.y);
            _reflectionMatrix.m02 = (-2.0f * planeNormal.x *  planeNormal.z);
            _reflectionMatrix.m03 = (-2.0f * d * planeNormal.x);

            _reflectionMatrix.m10 = (-2.0f *  planeNormal.y * planeNormal.x);
            _reflectionMatrix.m11 = (1.0f - 2.0f *  planeNormal.y *  planeNormal.y);
            _reflectionMatrix.m12 = (-2.0f *  planeNormal.y *  planeNormal.z);
            _reflectionMatrix.m13 = (-2.0f *  d *  planeNormal.y);

            _reflectionMatrix.m20 = (-2.0f *  planeNormal.z * planeNormal.x);
            _reflectionMatrix.m21 = (-2.0f *  planeNormal.z *  planeNormal.y);
            _reflectionMatrix.m22 = (1.0f - 2.0f *  planeNormal.z *  planeNormal.z);
            _reflectionMatrix.m23 = (-2.0f *  d *  planeNormal.z);

            _reflectionMatrix.m30 = 0;
            _reflectionMatrix.m31 = 0;
            _reflectionMatrix.m32 = 0;
            _reflectionMatrix.m33 = 1.0f;

            return ref _reflectionMatrix;
        }
        // Given position/normal of the plane, calculates plane in camera space.
        private Vector4 CameraSpacePlane(Camera cam, Vector3 positionWS, Vector3 normalWS, float sideSign) {
            var offsetedPos = positionWS + normalWS *settings.planeOffset;
            var viewMat = cam.worldToCameraMatrix;
            var positionVS = viewMat.MultiplyPoint(offsetedPos);
            var normalVS = viewMat.MultiplyVector(normalWS).normalized * sideSign;
            var t = viewMat.MultiplyVector(normalVS);
            var g = viewMat.inverse.transpose.MultiplyVector(normalVS);
            return new Vector4(normalVS.x, normalVS.y, normalVS.z, -Vector3.Dot(positionVS, normalVS));
        }

        

        
        private void UpdateReflectionCamera(Camera originalCamera) {
            
            Vector3 planeNormalWS = targetPlane.transform.up;
            Vector3 planePosWS = targetPlane.transform.position + planeNormalWS * settings.planeOffset;

            // sync camera settings
            SyncCameraSettings(originalCamera, _reflectionCamera); 
            
            if (_reflectionCamera.gameObject.TryGetComponent(out UniversalAdditionalCameraData camData)) { 
                camData.renderShadows = settings.shadows; // turn off shadows for the reflection camera
            }
            
            ref Matrix4x4 reflectionMat = ref CalculateReflectionMatrix(planeNormalWS,planePosWS);
            _reflectionCamera.worldToCameraMatrix *=reflectionMat;
            /*var d = -Vector3.Dot(planeNormalWS,  planePosWS);
            var plane = new Vector4(planeNormalWS.x, planeNormalWS.y, planeNormalWS.z, d);
            //用逆转置矩阵将平面从世界空间变换到反射相机空间
            var viewSpacePlane = _reflectionCamera.worldToCameraMatrix.inverse.transpose * plane;*/
            _reflectionCamera.projectionMatrix = CalculateObliqueMatrix(_reflectionCamera,planeNormalWS,planePosWS);
          //   _reflectionCamera.projectionMatrix = _reflectionCamera.CalculateObliqueMatrix(viewSpacePlane);
            _reflectionCamera.cullingMask = settings.reflectLayers; // never render water layer
    
            Vector3 oldCameraPos = originalCamera.transform.position;
            _reflectionCamera.transform.position = reflectionMat.MultiplyPoint(oldCameraPos);
        }
        
        // private void UpdateReflectionCamera(Camera curCamera) {
        //     // 不使用反射矩阵的方法
        //     if (targetPlane == null) {
        //         Debug.LogError("target plane is null!");
        //     }

        //     UpdateCamera(curCamera, _reflectionCamera);  // 同步当前相机数据

        //     // 将相机移转换到平面空间 plane space，再通过平面对称创建反射相机
        //     Vector3 camPosPS = targetPlane.transform.worldToLocalMatrix.MultiplyPoint(curCamera.transform.position);
        //     Vector3 reflectCamPosPS = Vector3.Scale(camPosPS, new Vector3(1, -1, 1)) + new Vector3(0, m_planeOffset, 0);  // 反射相机平面空间
        //     Vector3 reflectCamPosWS = targetPlane.transform.localToWorldMatrix.MultiplyPoint(reflectCamPosPS);  // 将反射相机转换到世界空间
        //     _reflectionCamera.transform.position = reflectCamPosWS;

        //     // 设置反射相机方向
        //     Vector3 camForwardPS = targetPlane.transform.worldToLocalMatrix.MultiplyVector(curCamera.transform.forward);
        //     Vector3 reflectCamForwardPS = Vector3.Scale(camForwardPS, new Vector3(1, -1, 1));
        //     Vector3 reflectCamForwardWS = targetPlane.transform.localToWorldMatrix.MultiplyVector(reflectCamForwardPS); 
            
        //     Vector3 camUpPS = targetPlane.transform.worldToLocalMatrix.MultiplyVector(curCamera.transform.up);
        //     Vector3 reflectCamUpPS = Vector3.Scale(camUpPS, new Vector3(-1, 1, -1));
        //     Vector3 reflectCamUpWS = targetPlane.transform.localToWorldMatrix.MultiplyVector(reflectCamUpPS); 
        //     _reflectionCamera.transform.rotation = Quaternion.LookRotation(reflectCamForwardWS, reflectCamUpWS);

        //     // 斜截视锥体
        //     Vector3 planeNormal = targetPlane.transform.up;
        //     Vector3 planePos = targetPlane.transform.position + planeNormal * m_planeOffset;
        //     var clipPlane = CameraSpacePlane(_reflectionCamera, planePos - Vector3.up * 0.1f, planeNormal, 1.0f);
        //     var newProjectionMat = CalculateObliqueMatrix(curCamera, clipPlane);
        //     _reflectionCamera.projectionMatrix = newProjectionMat;
        //     _reflectionCamera.cullingMask = m_settings.m_ReflectLayers; // never render water layer
        // }
        
        // Method from "Eric Lengyel. Oblique View Frustum Depth Projection and Clipping."
        private ref Matrix4x4 CalculateObliqueMatrix(Camera reflectionCamera,in Vector3 planeNormalWS,in Vector3 planePosWS) {
            Vector4 clipPlaneWS = new Vector4(planeNormalWS.x, planeNormalWS.y, planeNormalWS.z, -Vector3.Dot(planePosWS, planeNormalWS));
            Vector4 clipPlaneVS = reflectionCamera.worldToCameraMatrix.inverse.transpose * clipPlaneWS;
        
            //use view space clip plane instead of clip space to determine the sign of x and y, saving calculation.
            
            /*
            Vector4 farPlaneCornerPointCS = new Vector4(Mathf.Sign(clipPlaneVS.x), Mathf.Sign(clipPlaneVS.y), 1f, 1f);
            Vector4 farPlaneCornerPointVS = reflectionCamera.projectionMatrix.inverse.MultiplyPoint(farPlaneCornerPointCS);
            Vector4 projMat4 = reflectionCamera.projectionMatrix.GetRow(3);
            float scalar = 2.0f / Vector4.Dot(clipPlaneVS, farPlaneCornerPointVS);
            Vector4 newProjMat3 = scalar * clipPlaneVS - projMat4;
          //  reflectionCamera.projectionMatrix.SetRow(3, newProjMat3);
            _obliqueClippedProjectionMatrix = reflectionCamera.projectionMatrix;
            _obliqueClippedProjectionMatrix.SetRow(2, newProjMat3);*/
            
            /*Vector4 t = CameraSpacePlane(reflectionCamera,planePosWS,planeNormalWS, 1.0f);
            farPlaneCornerPointCS = new Vector4(Mathf.Sign(clipPlaneVS.x), Mathf.Sign(clipPlaneVS.y), 1f, 1f);
            farPlaneCornerPointVS = reflectionCamera.projectionMatrix.inverse.MultiplyPoint(farPlaneCornerPointCS);
            projMat4 = reflectionCamera.projectionMatrix.GetRow(3);
            scalar = 2.0f / Vector4.Dot(clipPlaneVS, farPlaneCornerPointVS);
            newProjMat3 = scalar * clipPlaneVS - projMat4;
            //  reflectionCamera.projectionMatrix.SetRow(3, newProjMat3);
            Matrix4x4 m1 = reflectionCamera.projectionMatrix;
            m1.SetRow(2, newProjMat3);

            Matrix4x4 m2 = reflectionCamera.CalculateObliqueMatrix(clipPlaneVS);
            Matrix4x4 m3 = reflectionCamera.CalculateObliqueMatrix(t);*/
            // using unity API
            _obliqueClippedProjectionMatrix = reflectionCamera.CalculateObliqueMatrix(clipPlaneVS);
            return ref _obliqueClippedProjectionMatrix;
        }

        private Camera CreateReflectCamera() {
            string cameraName = gameObject.name + " Planar Reflection Camera";
            GameObject gameObj = GameObject.Find(cameraName);
            if (gameObj == null) {
                gameObj = new(gameObject.name + " Planar Reflection Camera",typeof(Camera));
                var cameraData = gameObj.AddComponent(typeof(UniversalAdditionalCameraData)) as UniversalAdditionalCameraData;
                cameraData.requiresColorOption = CameraOverrideOption.Off;
                cameraData.requiresDepthOption = CameraOverrideOption.Off;
                cameraData.renderShadows = false;
                cameraData.SetRenderer(0);  // index from the renderer list
            }

            // use current GameObject transform as camera position
            Camera reflectionCamera = gameObj.GetComponent<Camera>();
            reflectionCamera.transform.SetPositionAndRotation(transform.position, transform.rotation); 
            reflectionCamera.depth = -10;  // rendering priority [-100, 100]
            reflectionCamera.enabled = false;
           // gameObj.hideFlags = HideFlags.HideAndDontSave;
            
            return reflectionCamera;
        }
        
        class RendererSettingsManager {
            private static bool _fog;
            private static int _maxLod;
            private static float _lodBias;
            private static bool _invertCulling;

            public static void Store() {
                _fog = RenderSettings.fog;
                _maxLod = QualitySettings.maximumLODLevel;
                _lodBias = QualitySettings.lodBias;
                _invertCulling = GL.invertCulling;
            }
            
            public static void Set() {
                GL.invertCulling = !_invertCulling;  // 因为镜像后绕序会反，将剔除反向
                RenderSettings.fog = false; // disable fog for now as it's incorrect with projection
                QualitySettings.maximumLODLevel = 1;
                QualitySettings.lodBias = _lodBias * 0.5f;
            }

            public static void Restore() {
                GL.invertCulling = _invertCulling;
                RenderSettings.fog = _fog;
                QualitySettings.maximumLODLevel = _maxLod;
                QualitySettings.lodBias = _lodBias;
            }
        }
    }
}