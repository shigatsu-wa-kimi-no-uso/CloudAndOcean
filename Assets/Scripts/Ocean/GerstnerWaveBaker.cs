using System;
using System.Linq;
using Unity.VisualScripting;
using UnityEditor;
using UnityEditor.VersionControl;
using UnityEngine;
using UnityEngine.Windows;

namespace Ocean {
    
    
    public class GerstnerWaveBaker : MonoBehaviour {


        [Serializable]
        public class GerstnerWaveConfig {
            public float wavelength;
            [Range(0,1)]
            public float steepness;
            public Vector3 direction;
            public int loopCount;
        } 
        

        [SerializeField]
        public int width;
        
        [SerializeField]
        public int height;

        
        [SerializeField]
        int frameCount;
        
        [SerializeField]
        public string outputPath = "Assets/outputGerstnerWaveMap.asset";
        
        [SerializeField]
        public GerstnerWaveConfig[] gerstnerWaves;

        
        private readonly string _bakingShaderPath = "Assets/Shaders/ShaderLabs/BakeGerstner.shader";

  
        [ContextMenu("Generate Gerstner Wave Map")]
        void BakeGerstnerWaveMap() {
            RenderTexture rt = new RenderTexture(width,height, 0, RenderTextureFormat.ARGBFloat,
                RenderTextureReadWrite.Linear);
            Shader shader = AssetDatabase.LoadAssetAtPath<Shader>(_bakingShaderPath);
            Material material = new Material(shader);
            Texture2DArray texArray = new Texture2DArray(rt.width,  rt.height, frameCount, TextureFormat.RGBAFloat,false);
            
            float[] wavelengths = gerstnerWaves.Select(x => x.wavelength).ToArray();
            float[] steepnesses = gerstnerWaves.Select(x => x.steepness).ToArray();
            Vector4[] directions = gerstnerWaves.Select(x => new Vector4(x.direction.x, x.direction.y, x.direction.z, 0)).ToArray();
            float[] loopCount = gerstnerWaves.Select(x => (float)x.loopCount).ToArray();
            material.SetFloatArray("_Wavelength", wavelengths);
            material.SetFloatArray("_Steepness", steepnesses);
            material.SetVectorArray("_Direction", directions);
            material.SetFloatArray("_LoopCount", loopCount);
            material.SetInt("_WaveCount",  gerstnerWaves.Length);
            material.SetInt("_FrameCount",  frameCount);
            Texture2D tex = new Texture2D(rt.width, rt.height, TextureFormat.RGBAFloat, false);
            for (int i = 1; i <= frameCount; i++) {
                material.SetInt("_FrameIndex",  i);
                Graphics.Blit(null,rt, material,material.FindPass("BakeGerstner"));
                Graphics.SetRenderTarget(rt);
                tex.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0,0);
                Graphics.CopyTexture(tex,0,texArray,i-1);
            }
            AssetDatabase.CreateAsset(texArray, outputPath);
            texArray.Apply();
            Graphics.SetRenderTarget(null);
            rt.Release();
            DestroyImmediate(tex);
        }
        
        
        [ContextMenu("Create Texture2DArray From Maps")]
        void MakeTexture2DArray() {
            Texture2DArray texArray = new Texture2DArray(width,  height, frameCount, TextureFormat.RGBAFloat,false);
            
            for (int i = 0; i < frameCount; i++) {
                Texture2D texture = AssetDatabase.LoadAssetAtPath<Texture2D>($"{outputPath}/Frame_{i}.tga");
                Graphics.CopyTexture(texture,texArray);
                texArray.SetPixels(texture.GetPixels(),i);
                DestroyImmediate(texture);
            }
            texArray.Apply();
            AssetDatabase.CreateAsset(texArray, $"{outputPath}/array.asset");
            DestroyImmediate(texArray);
        }
        
        
    }
}