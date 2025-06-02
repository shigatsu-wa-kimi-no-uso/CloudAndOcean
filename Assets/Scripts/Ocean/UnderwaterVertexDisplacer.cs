using System.Runtime.InteropServices;
using UnityEngine;
using UnityEngine.Rendering;

namespace Ocean {

   // [ExecuteAlways]
    public class UnderwaterVertexDisplacer : MonoBehaviour {
        
        public static ComputeShader VertexDisplacementCS; 
        
        public static WaterRefractionEffector RefractionEffector;
        
        [SerializeField]
        private WaterVolumeSettings waterVolumeSettings;
        
        [SerializeField]
        private bool settingsFromEffector = true;
   
        private WaterVolumeSettings _currentSettings;
        
        GraphicsBuffer _vertexPositionBuffer;
        GraphicsBuffer _vertexBuffer;

        private int _vertexPositionOffset;
        private int _computeShaderKernelID;
        private int _computeShaderThreadGroupCount;
        
        private Mesh _deformedMesh;
        private Mesh _templateMesh;
        private MeshFilter _meshFilter;
        
        private static readonly int ShaderVarID_vertexAttributeStride;
        private static readonly int ShaderVarID_vertexPositionOffset;
        private static readonly int ShaderVarID_vertexPositionBuffer;
        private static readonly int ShaderVarID_vertexBuffer;
        private static readonly int ShaderVarID_modelMatrix;
        private static readonly int ShaderVarID_modelMatrixInv;
        private static readonly int ShaderVarID_cameraViewMatrix;
        private static readonly int ShaderVarID_cameraViewMatrixInv;
        private static readonly int ShaderVarID_waterBoundMinWS;
        private static readonly int ShaderVarID_waterBoundMaxWS;
        private static readonly int ShaderVarID_waterPlaneNormalWS;
        private static readonly int ShaderVarID_indexOfRefraction;
        

        static UnderwaterVertexDisplacer() {
            ShaderVarID_cameraViewMatrixInv = Shader.PropertyToID("cameraViewMatrixInv");
            ShaderVarID_cameraViewMatrix = Shader.PropertyToID("cameraViewMatrix");
            ShaderVarID_vertexAttributeStride = Shader.PropertyToID("vertexAttributeStride");
            ShaderVarID_vertexPositionOffset = Shader.PropertyToID("vertexPositionOffset");
            ShaderVarID_vertexPositionBuffer = Shader.PropertyToID("vertexPositionBuffer");
            ShaderVarID_modelMatrix = Shader.PropertyToID("modelMatrix");
            ShaderVarID_modelMatrixInv = Shader.PropertyToID("modelMatrixInv");
            ShaderVarID_vertexBuffer = Shader.PropertyToID("vertexBuffer");
            ShaderVarID_waterBoundMinWS = Shader.PropertyToID("waterBoundMinWS");
            ShaderVarID_waterBoundMaxWS = Shader.PropertyToID("waterBoundMaxWS");
            ShaderVarID_waterPlaneNormalWS = Shader.PropertyToID("waterPlaneNormalWS");
            ShaderVarID_indexOfRefraction = Shader.PropertyToID("indexOfRefraction");
        }

        private void DisplaceUnderwaterVertex(ScriptableRenderContext context, Camera renderCamera) {
            SetComputeShaderVariablesPerFrame(renderCamera);
            VertexDisplacementCS.Dispatch(_computeShaderKernelID, _computeShaderThreadGroupCount, 1, 1);
        }

        
        private void InitializeSettings() {
            if (settingsFromEffector) {
                _currentSettings = RefractionEffector.Settings;
                waterVolumeSettings = RefractionEffector.Settings;
                Debug.Log("Initialized parameters from settings.", gameObject);
            } else {
                _currentSettings = waterVolumeSettings;
                if (_currentSettings.WaterGameObject != null) {
                    _currentSettings.UpdateParamsFromGameObject();
                }
                Debug.LogWarning("Initialized parameters from inspector.",gameObject);
            }
        }

        private void Awake() {
            Debug.Log("Awake",gameObject);
         

            enabled = false;
            if (TryEnable()) {
                Debug.Log("Set enabled in Awake.", gameObject);
            } else {
                Debug.LogWarning("Set disabled in Awake.", gameObject);
            }
        }

  
        
        public bool TryEnable() {
            if (enabled) {
                return true;
            }
            if (VertexDisplacementCS == null) {
                Debug.LogWarning("Compute shader is null. Set disabled in TryEnable.",gameObject);
                return false;
            }
            _meshFilter = GetComponent<MeshFilter>();
            if (_meshFilter != null) {
                Debug.Log("Set enabled in TryEnable. Mesh data loaded.", gameObject);
                StoreTemplateMesh(_meshFilter);
                SetupDeformedMesh(_meshFilter);
                SetupTemplateVertexPositionBuffer();
                SetupComputeShaderVariablesOnEnable();
                enabled = true;
                return true;
            } else {
                enabled = false;
                Debug.LogWarning("Mesh filter is null. Set disabled in TryEnable.",gameObject);
                return false;
            }
        }
        

        private void OnEnable() {
            Debug.LogWarning("OnEnable",gameObject);
            InitializeSettings();
            UseDeformedMesh();
            RenderPipelineManager.beginCameraRendering += DisplaceUnderwaterVertex;
        }

        private void OnDisable() {
            Debug.LogWarning("OnDisable",gameObject);
            RenderPipelineManager.beginCameraRendering -= DisplaceUnderwaterVertex;
            UseTemplateMesh();
        }

        private void OnDestroy() {
            Debug.LogWarning("OnDestroy",gameObject);
            RenderPipelineManager.beginCameraRendering -= DisplaceUnderwaterVertex;
            ReleaseMeshVertexBuffer();
            ReleaseVertexPositionBuffer();
        }

        void StoreTemplateMesh(MeshFilter meshFilter) {
            _templateMesh = meshFilter.sharedMesh;
        }

        void SetupTemplateVertexPositionBuffer() {
            if (_vertexPositionBuffer == null) {
                _vertexPositionBuffer = new GraphicsBuffer(GraphicsBuffer.Target.Structured, _templateMesh.vertexCount,
                    Marshal.SizeOf(typeof(Vector3)));
                _vertexPositionBuffer.SetData(_templateMesh.vertices);
            }
        }

        private void SetupDeformedMesh(MeshFilter meshFilter) {
            if (_deformedMesh == null) {
                _deformedMesh = meshFilter.mesh;
                _deformedMesh.name = _templateMesh.name + " (Script Generated)";
            }
        }

        void UseTemplateMesh() {
            if (_templateMesh != null) {
                _meshFilter.mesh = _templateMesh;
            }     
        }

        void UseDeformedMesh() {
            if (_deformedMesh != null) {
                _meshFilter.mesh = _deformedMesh;
            }
        }

        void ReleaseVertexPositionBuffer() {
            _vertexPositionBuffer?.Release();
            _vertexPositionBuffer = null;
        }

        void ReleaseMeshVertexBuffer() {
            _vertexBuffer?.Release();
            _vertexBuffer = null;
        }
        

        void SetupComputeShaderVariablesOnEnable() {
            _deformedMesh.vertexBufferTarget |= GraphicsBuffer.Target.Raw;
            if (_vertexBuffer == null) {
                _vertexBuffer = _deformedMesh.GetVertexBuffer(0);
            }
            _computeShaderKernelID = VertexDisplacementCS.FindKernel("CSMain");
            _vertexPositionOffset = _deformedMesh.GetVertexAttributeOffset(VertexAttribute.Position);
            VertexDisplacementCS.GetKernelThreadGroupSizes(_computeShaderKernelID, out var x, out _, out _);
            _computeShaderThreadGroupCount = (_vertexPositionBuffer.count + (int)x - 1) / (int)x;
        }
        void SetComputeShaderVariablesPerFrame(Camera renderCamera) {
            VertexDisplacementCS.SetBuffer(_computeShaderKernelID, ShaderVarID_vertexPositionBuffer, _vertexPositionBuffer);
            VertexDisplacementCS.SetBuffer(_computeShaderKernelID, ShaderVarID_vertexBuffer, _vertexBuffer);
            VertexDisplacementCS.SetInt(ShaderVarID_vertexAttributeStride, _vertexBuffer.stride);
            VertexDisplacementCS.SetInt(ShaderVarID_vertexPositionOffset, _vertexPositionOffset);
            VertexDisplacementCS.SetMatrix(ShaderVarID_modelMatrix, gameObject.transform.localToWorldMatrix);
            VertexDisplacementCS.SetMatrix(ShaderVarID_modelMatrixInv, gameObject.transform.worldToLocalMatrix);
            VertexDisplacementCS.SetMatrix(ShaderVarID_cameraViewMatrix, renderCamera.worldToCameraMatrix);
            VertexDisplacementCS.SetMatrix(ShaderVarID_cameraViewMatrixInv, renderCamera.cameraToWorldMatrix);
            VertexDisplacementCS.SetVector(ShaderVarID_waterBoundMinWS, _currentSettings.BoundMin);
            VertexDisplacementCS.SetVector(ShaderVarID_waterBoundMaxWS, _currentSettings.BoundMax);
            VertexDisplacementCS.SetVector(ShaderVarID_waterPlaneNormalWS, _currentSettings.WaterPlaneNormal);
            VertexDisplacementCS.SetFloat(ShaderVarID_indexOfRefraction, _currentSettings.IndexOfRefraction);
        }

        
    }

}