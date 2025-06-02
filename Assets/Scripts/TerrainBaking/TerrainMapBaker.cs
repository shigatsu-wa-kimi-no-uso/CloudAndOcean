

using System;
using System.IO;
using UnityEditor;
using UnityEngine;
using UnityEngine.Serialization;
using Utility;
using Directory = UnityEngine.Windows.Directory;
using File = UnityEngine.Windows.File;

namespace TerrainBaking {
    public class TerrainMapBaker : MonoBehaviour{

        [Serializable]
        public class BasicConfig {
            public int textureWidth;
            
            public int textureHeight;
        }
        
        
        [Serializable]
        public class HeightMapConfig {
            public Vector3 scanBoundsMin;

            public Vector3 scanBoundsMax;
            
            public float heightMapMinZ; // -400
            
            public float heightMapMaxZ; // 0
            
            public string outputPath = "Assets/TerrainMapBakerOutput/HeightMap.tga";
            
        }
        
        [Serializable]
        public class GradientMapConfig {
            public Texture2D heightMap;
            
            public string outputPath = "Assets/TerrainMapBakerOutput/GradientMap.tga";
        }
        
        [Serializable]
        public class SDFConfig {
            public Texture2D heightMap;
            
            public int sdfMaxPixelDist; //256
            
            public string outputPath = "Assets/TerrainMapBakerOutput/SDF.tga";
        }
        
        [Serializable]
        public class RefinedGradientMapConfig {
            public Texture2D gradientMap;
            
            public int gradientCompletionFilterSize;
            
            public int gradientSmoothFilterSize;
            
            public string outputPath = "Assets/TerrainMapBakerOutput/RefinedGradientMap.tga";
        }
        
        [Serializable]
        public class TerrainMapConfig { 
            public Texture2D SDFTexture;
            
            public Texture2D gradientMap;
            
            public string outputPath = "Assets/TerrainMapBakerOutput/TerrainMap.tga";
        }
        
        [Serializable]
        public class HiZMapConfig {
            public Texture2D heightMap;

            public int blockCount;
            
            public string outputPath = "Assets/TerrainMapBakerOutput/HiZMap.tga";
            
        }
        
        [SerializeField]
        public BasicConfig basicConfig;
        
        [SerializeField]
        public HeightMapConfig  heightMapConfig;
        
        [SerializeField]
        public GradientMapConfig  gradientMapConfig;
        
        [SerializeField]
        public RefinedGradientMapConfig  refinedGradientMapConfig;
        
        [SerializeField]
        public SDFConfig  sdfConfig;
        
        [SerializeField]
        public TerrainMapConfig terrainMapConfig;
        
        [SerializeField]
        public HiZMapConfig  hiZMapConfig;

        private readonly string _bakingShaderPath = "Assets/Shaders/TerrainBaking/BakeTerrain.shader";
        
        private readonly string _hiZGeneratorComputeShaderPath = "Assets/Shaders/TerrainBaking/ComputeShader/GenerateHiZ.compute";
        
        Mesh GetTerrainMesh() {
            MeshFilter[] meshFilters = GetComponentsInChildren<MeshFilter>();
            CombineInstance[] combine = new CombineInstance[meshFilters.Length];

            int i = 0;
            while (i < meshFilters.Length)
            {
                combine[i].mesh = meshFilters[i].sharedMesh;
                combine[i].transform = meshFilters[i].transform.localToWorldMatrix;
              //  meshFilters[i].gameObject.SetActive(false);
        
                i++;
            }

            Mesh mesh = new Mesh();
            mesh.CombineMeshes(combine);
            return mesh;
        }

        void SaveRenderTexture(RenderTexture rt, string filepath) {
            Texture2D tex = new Texture2D(rt.width, rt.height, TextureFormat.RGBAFloat, false);
            Graphics.SetRenderTarget(rt);
            tex.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0,0);
            tex.Apply();
            Directory.CreateDirectory(Path.GetDirectoryName(filepath));
            File.WriteAllBytes(filepath, tex.EncodeToTGA());
            Graphics.SetRenderTarget(null);
            rt.Release();
            DestroyImmediate(tex);
        }
        
        
        [ContextMenu("Generate Height Map")]
        void BakeHeightMap() {
            RenderTexture rt = new RenderTexture(basicConfig.textureWidth, basicConfig.textureHeight, 0, RenderTextureFormat.ARGBFloat,
                RenderTextureReadWrite.Linear);
            GameObject bakeCameraGO = new GameObject("Bake Camera");
            Camera bakeCam = bakeCameraGO.AddComponent<Camera>();
          
            float size = (heightMapConfig.scanBoundsMax.x - heightMapConfig.scanBoundsMin.x) * 0.5f;
            Vector3 camPos = heightMapConfig.scanBoundsMin + (heightMapConfig.scanBoundsMax - heightMapConfig.scanBoundsMin) * 0.5f;
            camPos.y = heightMapConfig.scanBoundsMax.y;
            
            bakeCam.orthographic = true;
            bakeCam.nearClipPlane = 0; // for z component: [near,far] -> [1,0] after orthographic projection
            bakeCam.farClipPlane = heightMapConfig.scanBoundsMax.y - heightMapConfig.scanBoundsMin.y;
            if (heightMapConfig.heightMapMaxZ < heightMapConfig.heightMapMinZ) {
                Debug.LogWarning("invalid parameter");
                return;
            }
            float heightMapMaxZOrtho01 = (heightMapConfig.heightMapMaxZ - heightMapConfig.scanBoundsMin.y) / bakeCam.farClipPlane;
            float heightMapMinZOrtho01 = (heightMapConfig.heightMapMinZ - heightMapConfig.scanBoundsMin.y) / bakeCam.farClipPlane;
   
            bakeCam.orthographicSize = size;
            bakeCam.transform.forward = -Vector3.up; // make camera looking at '-y direction'
            bakeCam.transform.position = camPos;
            bakeCam.targetTexture = rt;
            
            Matrix4x4 m = Matrix4x4.identity;
            Matrix4x4 v = bakeCam.worldToCameraMatrix;
            Matrix4x4 p = GL.GetGPUProjectionMatrix(bakeCam.projectionMatrix, true);
            
            Graphics.SetRenderTarget(rt);
        
            GL.Clear(true, true,new Color(1,1,0,0));
            Mesh mesh = GetTerrainMesh();
            
            Material gbufferMat = new Material(AssetDatabase.LoadAssetAtPath<Shader>(_bakingShaderPath));
            gbufferMat.SetFloat("_HeightMap_MaxZ_Ortho01",  heightMapMaxZOrtho01);
            gbufferMat.SetFloat("_HeightMap_MinZ_Ortho01",  heightMapMinZOrtho01);
            gbufferMat.SetMatrix("_MVP", p * v * m);
            gbufferMat.SetPass(gbufferMat.FindPass("BakeHeightMap"));
            
            Graphics.DrawMeshNow( mesh, Matrix4x4.TRS(Vector3.zero, Quaternion.identity, Vector3.one));
            
            SaveRenderTexture(rt, heightMapConfig.outputPath);
        }
        
        

        [ContextMenu("Generate Gradient Map")]
        void BakeGradientMap() {
            RenderTexture rt = new RenderTexture(basicConfig.textureWidth, basicConfig.textureHeight, 0, RenderTextureFormat.ARGBFloat,
                RenderTextureReadWrite.Linear);
            Material material = new Material(AssetDatabase.LoadAssetAtPath<Shader>(_bakingShaderPath));
 
            Graphics.Blit(gradientMapConfig.heightMap,rt, material,material.FindPass("BakeGradientMap"));
            Texture2D tex = new Texture2D(rt.width, rt.height, TextureFormat.RGBAFloat, false);
        
            Graphics.SetRenderTarget(rt);
            tex.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0,0);
            tex.Apply();
            File.WriteAllBytes(gradientMapConfig.outputPath, tex.EncodeToTGA());
            Graphics.SetRenderTarget(null);
            rt.Release();
            DestroyImmediate(tex);
        }
        
        [ContextMenu("Refine Gradient Map")]
        void RefineGradientMap() {
            RenderTexture rt = new RenderTexture(basicConfig.textureWidth, basicConfig.textureHeight, 0, RenderTextureFormat.ARGBFloat,
                RenderTextureReadWrite.Linear);

            Material material = new Material(AssetDatabase.LoadAssetAtPath<Shader>(_bakingShaderPath));
            material.SetInteger("_RefineGradientMap_CompletionFilterSize",refinedGradientMapConfig.gradientCompletionFilterSize);
            material.SetInteger("_RefineGradientMap_SmoothFilterSize",
                refinedGradientMapConfig.gradientSmoothFilterSize);
            Graphics.Blit(refinedGradientMapConfig.gradientMap,rt, material,material.FindPass("RefineGradientMap"));
            
            
            SaveRenderTexture(rt, refinedGradientMapConfig.outputPath);
        }
        
        [ContextMenu("Generate SDF")]
        void BakeSDF() {
            RenderTexture rt = new RenderTexture(basicConfig.textureWidth, basicConfig.textureHeight, 24, RenderTextureFormat.ARGBFloat,
                RenderTextureReadWrite.Linear);
   
            Material material = new Material(AssetDatabase.LoadAssetAtPath<Shader>(_bakingShaderPath));
            material.SetInteger("_SDF_MaxPixelDist",sdfConfig.sdfMaxPixelDist);
            Graphics.Blit(sdfConfig.heightMap,rt, material,material.FindPass("BakeSDF"));

            SaveRenderTexture(rt, sdfConfig.outputPath);
        }

        [ContextMenu("Generate Terrain Map")]
        void BakeTerrainMap() {
            RenderTexture rt = new RenderTexture(basicConfig.textureWidth, basicConfig.textureHeight, 24, RenderTextureFormat.ARGBFloat,
                RenderTextureReadWrite.Linear);
            Material material = new Material(AssetDatabase.LoadAssetAtPath<Shader>(_bakingShaderPath));
            material.SetTexture("_GradientMap",terrainMapConfig.gradientMap);
            material.SetTexture("_SDFTex",terrainMapConfig.SDFTexture);
            Graphics.Blit(null,rt, material,material.FindPass("MixSDFAndGradient"));

            SaveRenderTexture(rt, terrainMapConfig.outputPath);
        }
        
        [ContextMenu("Generate Hi-Z Map")]
        public void BakeHiZMap() {
            if (hiZMapConfig.heightMap == null) {
                return;
            }
      
            ComputeShader  _computeShader = AssetDatabase.LoadAssetAtPath<ComputeShader>(_hiZGeneratorComputeShaderPath);
            int scale = 4;
            int leastSize = hiZMapConfig.blockCount*scale; //MyMathUtils.LeastCommonMultiple(hiZMapConfig.blockCount, 32);
            int width = leastSize;
            int height = leastSize;
      
            RenderTexture resizedHeightMap = new RenderTexture(width,height, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
            RenderTexture hiZMapRT = new RenderTexture(width,height, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
            hiZMapRT.enableRandomWrite = true;
            hiZMapConfig.heightMap.filterMode = FilterMode.Bilinear;
            Graphics.Blit(hiZMapConfig.heightMap,resizedHeightMap);
            int kernel4 = _computeShader.FindKernel("CSMain_4");
          //  int kernel8 = _computeShader.FindKernel("CSMain_8");
          //  int kernel16 = _computeShader.FindKernel("CSMain_16");
         //   int kernel32 = _computeShader.FindKernel("CSMain_32");
            int kernel = _computeShader.FindKernel($"CSMain");
            _computeShader.SetTexture(kernel4, "heightMap",resizedHeightMap );
            _computeShader.SetTexture(kernel4, "hiZMap", hiZMapRT);
            // first test
            _computeShader.GetKernelThreadGroupSizes(kernel4, out uint x, out uint y,  out _);
            _computeShader.Dispatch(kernel4, (int)(width/x), (int)(height/y), 1);
            int  blockSize = 2 * scale;
            _computeShader.SetTexture(kernel, "heightMap",resizedHeightMap );
            _computeShader.SetTexture(kernel, "hiZMap", hiZMapRT);
            _computeShader.SetInt("blockSize", blockSize);
            _computeShader.SetInt("slot",1);
            _computeShader.SetInt("offset",blockSize / 2 - 1);
            _computeShader.Dispatch(kernel, width-blockSize+1, height-blockSize+1, 1);
            blockSize = 4 * scale;
            _computeShader.SetInt("blockSize", blockSize);
            _computeShader.SetInt("slot",2);
            _computeShader.SetInt("offset",blockSize / 2 - 1);
            _computeShader.Dispatch(kernel, width-blockSize+1, height-blockSize+1, 1);
            blockSize = 8 * scale;
            _computeShader.SetInt("blockSize", blockSize);
            _computeShader.SetInt("slot",3);
            _computeShader.SetInt("offset",blockSize / 2 - 1);
            _computeShader.Dispatch(kernel, width-blockSize+1, height-blockSize+1, 1);
       
            Texture2D hiZMap = new Texture2D(hiZMapRT.width, hiZMapRT.height, TextureFormat.RGBAFloat, false);
            Graphics.SetRenderTarget(hiZMapRT);
            hiZMap.ReadPixels(new Rect(0, 0, hiZMapRT.width, hiZMapRT.height), 0,0);
            hiZMap.Apply();
            File.WriteAllBytes(hiZMapConfig.outputPath, hiZMap.EncodeToTGA());
            Graphics.SetRenderTarget(null);
            resizedHeightMap.Release();
            DestroyImmediate(resizedHeightMap);
            hiZMapRT.Release();
            DestroyImmediate(hiZMap);
        }

        
        
    }
}