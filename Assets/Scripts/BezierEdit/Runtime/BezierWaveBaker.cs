
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Windows;


namespace BezierEdit.Runtime {
    
    public class BezierWaveBaker : MonoBehaviour {
        
        [SerializeField]
        public int samplePointCount = 256;
        
        [SerializeField]
        public Vector3 maxValue = new Vector3(10, 10, 10);
        
        [SerializeField]
        public Vector3 minValue = new Vector3(-10, -10, -10);
        
        [SerializeField]
        public string outputPath = "Assets/output.tga";

        private BezierComponent[] GetBezierComponentsFromChildren() {
            Transform t = gameObject.GetComponent<Transform>();
            BezierComponent[] bezierComponents = new BezierComponent[t.childCount];
            for (int i = 0; i < t.childCount; i++) {
                bezierComponents[i] = t.GetChild(i).GetComponent<BezierComponent>();
            }

            return bezierComponents;
        }

        

        [ContextMenu("Generate Curve Map")]
        public void GenerateCurveMap() {

            BezierComponent[] beziers = GetComponentsInChildren<BezierComponent>();
            Color[] colors = GetEncodedColors(beziers);
            SaveToTGAFile(colors, samplePointCount, beziers.Length);
        }

        private void SaveToTGAFile(Color[] colors,int width,int height) {
            Texture2D tex = new Texture2D(width, height, TextureFormat.ARGB32, false, true);
            tex.SetPixels(colors);
            File.WriteAllBytes(outputPath, tex.EncodeToTGA());
        }
            

        private Color[] GetEncodedColors(BezierComponent[] beziers) {
            int frameCnt = beziers.Length;
            Color[] colors = new Color[frameCnt*samplePointCount];
            for (int i = 0; i < frameCnt; i++) {
                for (int j = 0; j < samplePointCount; j++) {
                    float t = Mathf.Lerp(0, beziers[i].ctrlPoints.Length - 1, j / (float)samplePointCount);
                    Vector3 pos = beziers[i].Evaluate(t);
                    colors[i*samplePointCount + j] = EncodePosition(pos);
                }
            }
            return colors;
        }

        private Color EncodePosition(in Vector3 pos) {
            float3 range = maxValue - minValue;
            if (math.any(pos < new float3(minValue)) || math.any(pos > new float3(maxValue))) {
                Debug.LogWarning($"position {(pos.x, pos.y,pos.z)} out of bound.",this);
            }

            float r = pos.x / range.x;
            float g = pos.y / range.y;
            float b = pos.z / range.z;
            return new Color(r, g, b, 1);
        }
    }

}