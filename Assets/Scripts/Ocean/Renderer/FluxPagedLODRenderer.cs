
using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

namespace Ocean.Renderer {

    [ExecuteAlways]
    public class FluxPagedLODRenderer : MonoBehaviour {
        private static readonly Vector3[] _PageOffsets = {
            new(-0.5f,0, 0.5f), new(0.5f,0, -0.5f), new(-0.5f,0, -0.5f), new(0.5f,0, 0.5f),
            new(-1.5f,0, -1.5f), new(-0.5f,0, -1.5f), new(0.5f,0, -1.5f), new(1.5f,0, -1.5f),
            new(-1.5f,0, 1.5f), new(-0.5f,0, 1.5f), new(0.5f,0, 1.5f), new(1.5f,0, 1.5f),
            new(-1.5f,0, 0.5f), new(-1.5f,0, -0.5f), new(1.5f,0, 0.5f), new(1.5f,0, -0.5f)
        };

        private static readonly Vector4[] _PageStitchingMask_LOD0 = {
            new(0,0,0), new(0,0,0), new(0,0, 0), new(0,0,0),
            new(-1,-1, 64), new(0,-1, 64), new(0,-1, 64), new(1,-1, 64),
            new(-1,1, 64), new(0,1, 64), new(0,1, 64), new(1,1, 64),
            new(-1,0, 64), new(-1,0, 64), new(1,0, 64), new(1,0, 64),
        };
        
        private static readonly Vector4[] _PageStitchingMask_LOD0ToLOD1 = {
            new(-1,-1, 16), new(0,-1, 16), new(0,-1, 16), new(1,-1, 16),
            new(-1,1, 16), new(0,1, 16), new(0,1, 16), new(1,1, 16),
            new(-1,0, 16), new(-1,0, 16), new(1,0, 16), new(1,0, 16)
        };

        
        private static readonly Vector4[] _PageStitchingMask_LOD1 = {
            new(-1,-1, 16), new(0,-1, 16), new(0,-1, 16), new(1,-1, 16),
            new(-1,1, 16), new(0,1, 16), new(0,1, 16), new(1,1, 16),
            new(-1,0, 16), new(-1,0, 16), new(1,0, 16), new(1,0, 16)
        };
        
        private static readonly Vector4[] _PageStitchingMask_LOD1ToLOD2 = {
            new(-1,-1, 2), new(0,-1, 2), new(0,-1, 2), new(1,-1, 2),
            new(-1,1, 2), new(0,1, 2), new(0,1, 2), new(1,1, 2),
            new(-1,0, 2), new(-1,0, 2), new(1,0, 2), new(1,0, 2)
        };
        
        private static readonly Vector4[] _PageStitchingMask_LOD2 = {
            new(-1,-1, 1), new(0,-1, 1), new(0,-1, 1), new(1,-1, 1),
            new(-1,1, 1), new(0,1, 1), new(0,1, 1), new(1,1, 1),
            new(-1,0, 1), new(-1,0, 1), new(1,0, 1), new(1,0, 1)
        };
  
        private static readonly int[] _PageScales ={
            1,2,4,8,16,32,64,128,256,512,1024,2048
        };
        
          
        private static readonly int[] _PageCullingLevels ={
            0,1,2,3
        };
        
        [SerializeField]
        public Vector3 baseScale = new(1, 1, 1);

        [SerializeField]
        public float centerForwardOffset;
        

        [SerializeField]
        public float centerRefreshBoundLimit; // update matrices if the new center is out of this bound.
        
        [SerializeField]
        public float altitude;

        [Serializable]
        public class CullingMapConfig {
            [SerializeField]
            public Texture2D cullingMap;
        
            [SerializeField]
            public Vector2 originWS;


            [SerializeField]
            public Vector2 topRightWS;

            [SerializeField]
            public bool flipUV;
            
        }
        
        [SerializeField]
        public CullingMapConfig cullingMapConfig;


        [SerializeField]
        public Mesh fluxPlane_LOD0;
        [SerializeField]
        public Mesh fluxPlane_LOD1;
        [SerializeField]
        public Mesh fluxPlane_LOD2;

        [SerializeField]
        public Material material;
        
        private MaterialPropertyBlock  _blockLOD0;
        private MaterialPropertyBlock  _blockLOD1;
        private MaterialPropertyBlock  _blockLOD2;


        private List<Matrix4x4> _matricesLOD0_Committed = new();
        private List<Matrix4x4> _matricesLOD1_Committed = new();
        private List<Matrix4x4> _matricesLOD2_Committed = new();

        private List<Vector4> _pageStitchingMaskLOD0_Committed = new();
        private List<Vector4> _pageStitchingMaskLOD1_Committed = new();
        private List<Vector4> _pageStitchingMaskLOD2_Committed = new();

        private Vector3[] _pageScales = new Vector3[_PageScales.Length];

        private Color[] cullingMapData;


    
        private static Vector3 previousCenter;


        
        public void Initialize() {
            for (int i = 0; i < _PageScales.Length; i++) {
                _pageScales[i] = _PageScales[i] * baseScale;
            }
            _matricesLOD0_Committed.Capacity = 16;
            _matricesLOD1_Committed.Capacity = 24;
            _matricesLOD2_Committed.Capacity = 48;
            _pageStitchingMaskLOD0_Committed.Capacity = _matricesLOD0_Committed.Capacity;
            _pageStitchingMaskLOD1_Committed.Capacity = _matricesLOD1_Committed.Capacity;
            _pageStitchingMaskLOD2_Committed.Capacity = _matricesLOD2_Committed.Capacity;
            if (cullingMapConfig.cullingMap != null && cullingMapData == null) {
                cullingMapData = cullingMapConfig.cullingMap.GetPixels();
            }
            if (_blockLOD0 == null) {
                _blockLOD0 = new MaterialPropertyBlock();
            }

            if (_blockLOD1 == null) {
                _blockLOD1 = new MaterialPropertyBlock();
            }
            if (_blockLOD2 == null) {
                _blockLOD2 = new MaterialPropertyBlock();
            }
            
        }

        bool IsCulled(in Vector3 position,int level) {
           // return false;
            if (cullingMapConfig.cullingMap == null||cullingMapData == null) {
                return false;
            }
    

            Vector2 rangeVec = cullingMapConfig.topRightWS - cullingMapConfig.originWS;
            Vector2 relativePos = new Vector2(position.x - cullingMapConfig.originWS.x, position.z - cullingMapConfig.originWS.y);
            Vector2 uv;
            if (cullingMapConfig.flipUV == false) {
                uv.x = relativePos.x/rangeVec.x;
                uv.y = relativePos.y/rangeVec.y;
            } else {
                uv.y = relativePos.x/rangeVec.x;
                uv.x = relativePos.y/rangeVec.y;
            }

            if (uv.x < 0 || uv.x > 1 || uv.y < 0 || uv.y > 1) {
                return false;
            }
            
            int pixelU = Mathf.FloorToInt(uv.x * (cullingMapConfig.cullingMap.width - 1));
            int pixelV = Mathf.FloorToInt(uv.y * (cullingMapConfig.cullingMap.height - 1));
          
            Color c = cullingMapData[pixelV * cullingMapConfig.cullingMap.width + pixelU];
            if (c[0] > 0.5 && c[level] < 0.1) {
                return false;
            }
            return c[level] < 0.1;
        }
 

        public void UpdatePerFrameContexts(in Vector3 center,in Plane[] frustumPlanes) {
            _matricesLOD0_Committed.Clear();
            _matricesLOD1_Committed.Clear();
            _matricesLOD2_Committed.Clear();
            _pageStitchingMaskLOD0_Committed.Clear();
            _pageStitchingMaskLOD1_Committed.Clear();
            _pageStitchingMaskLOD2_Committed.Clear();
           // Vector3 fluxPlaneDisplacement1 = _pageScales[0] * _PageOffsets[0];
           // _LOD0_Matrices1[0].SetTRS(center + fluxPlaneDisplacement1, Quaternion.identity, _pageScales[0]);
         //  Vector3 complementScale = new Vector3(0.5f, 0f, 0.5f);

            int scaleLevel = 0;
            for (int i = 0; i < 4; i++) { 
                 Vector3 fluxPlaneDisplacement = _PageOffsets[i];
                 ref readonly Vector3 scale = ref _pageScales[scaleLevel];
                 fluxPlaneDisplacement.Scale(scale);
                 Vector3 position = center + fluxPlaneDisplacement;
                 Bounds bounds = new Bounds(position, scale);
                 if (GeometryUtility.TestPlanesAABB(frustumPlanes, bounds) && !IsCulled(position,_PageCullingLevels[scaleLevel])) {
                     _matricesLOD0_Committed.Add(Matrix4x4.TRS(position, Quaternion.identity, scale));
                     _pageStitchingMaskLOD0_Committed.Add(_PageStitchingMask_LOD0[i]); 
                 }
            }
            
            for (int i = 0; i < 12; i++) { 
                Vector3 fluxPlaneDisplacement = _PageOffsets[4+i%12];
                ref readonly Vector3 scale = ref _pageScales[scaleLevel];
                fluxPlaneDisplacement.Scale(scale);
                Vector3 position = center + fluxPlaneDisplacement;
                Bounds bounds = new Bounds(position, scale);
                if (GeometryUtility.TestPlanesAABB(frustumPlanes, bounds) && !IsCulled(position,_PageCullingLevels[scaleLevel])) {
                    _matricesLOD0_Committed.Add(Matrix4x4.TRS(position, Quaternion.identity, scale));
                    _pageStitchingMaskLOD0_Committed.Add(_PageStitchingMask_LOD0ToLOD1[i]); 
                }
            }

            scaleLevel++;
            for (int i = 0; i < 12; i++) {
                Vector3 fluxPlaneDisplacement = _PageOffsets[4 + i%12];
                ref readonly Vector3 scale = ref _pageScales[scaleLevel];
                fluxPlaneDisplacement.Scale(scale); 
                Vector3 position = center + fluxPlaneDisplacement;
                Bounds bounds = new Bounds(position, scale);
                if (GeometryUtility.TestPlanesAABB(frustumPlanes, bounds) && !IsCulled(position,_PageCullingLevels[scaleLevel])) {
                    _matricesLOD1_Committed.Add(Matrix4x4.TRS(position, Quaternion.identity, scale));
                    _pageStitchingMaskLOD1_Committed.Add(_PageStitchingMask_LOD1[i%12]);
                }
            }

            scaleLevel++;
            for (int i = 0; i < 12; i++) {
                Vector3 fluxPlaneDisplacement = _PageOffsets[4 + i%12];
                ref readonly Vector3 scale = ref _pageScales[scaleLevel];
                fluxPlaneDisplacement.Scale(scale); 
                Vector3 position = center + fluxPlaneDisplacement;
                Bounds bounds = new Bounds(position, scale);
                if (GeometryUtility.TestPlanesAABB(frustumPlanes, bounds) && !IsCulled(position,_PageCullingLevels[scaleLevel])) {
                    _matricesLOD1_Committed.Add(Matrix4x4.TRS(position, Quaternion.identity, scale));
                    _pageStitchingMaskLOD1_Committed.Add(_PageStitchingMask_LOD1ToLOD2[i%12]);
                }
            }

            scaleLevel++;
            for (int i = 0; i < 48; i++) {
                Vector3 fluxPlaneDisplacement = _PageOffsets[4 + i%12];
                ref readonly Vector3 scale = ref _pageScales[scaleLevel + i/12];
                fluxPlaneDisplacement.Scale(scale); 
                Vector3 position = center + fluxPlaneDisplacement;
                // don't do frustum clip, because it's not economic.
                _matricesLOD2_Committed.Add(Matrix4x4.TRS(position, Quaternion.identity, scale));
                _pageStitchingMaskLOD2_Committed.Add(_PageStitchingMask_LOD2[i%12]);
            }
            
        }
        
        private void DrawInstanced() {
             //Graphics.DrawMeshInstanced(fluxPlane_LOD0, 0,material , _LOD0_Matrices1);
            _blockLOD0.Clear();
            _blockLOD1.Clear();
            _blockLOD2.Clear();
            _blockLOD0.SetVectorArray("_PageStitchingMask", _pageStitchingMaskLOD0_Committed);
            _blockLOD1.SetVectorArray("_PageStitchingMask", _pageStitchingMaskLOD1_Committed);
          //  _blockLOD2.SetVectorArray("_PageStitchingMask", _pageStitchingMaskLOD2_Committed);
            Graphics.DrawMeshInstanced(fluxPlane_LOD0, 0,material , _matricesLOD0_Committed,_blockLOD0);
            Graphics.DrawMeshInstanced(fluxPlane_LOD1, 0,material , _matricesLOD1_Committed,_blockLOD1);
            Graphics.DrawMeshInstanced(fluxPlane_LOD2, 0,material , _matricesLOD2_Committed);
        }

        
        private void GetCenter(Camera cam,out Vector3 center) {
            center = cam.transform.position;
            center.x += cam.transform.forward.x * centerForwardOffset;
            center.y = altitude;
            center.z += cam.transform.forward.z * centerForwardOffset;
            // discretize the center to make it compatible with hi-z clipping.
            center.x = Mathf.Round(center.x/baseScale.x)  * baseScale.x; 
            center.z = Mathf.Round(center.z/baseScale.z)  * baseScale.z;
        }
        
        private void Draw(ScriptableRenderContext context, Camera cam) {
            Initialize();
            GetCenter(cam, out Vector3 center);
            Plane[] frustumPlanes = GeometryUtility.CalculateFrustumPlanes(cam);
            UpdatePerFrameContexts(center,frustumPlanes);
            DrawInstanced();
        }
        
        private void Awake() {
            Initialize();
        }

        private void OnEnable() {
            RenderPipelineManager.beginCameraRendering+= Draw;
        }
        


        private void OnDisable() {
            RenderPipelineManager.beginCameraRendering-= Draw;
        }
   
    }
}