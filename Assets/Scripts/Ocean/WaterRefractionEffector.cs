using System;
using UnityEngine;

using Unity.VisualScripting;
using UnityEngine.Serialization;


namespace Ocean {
    
    [ExecuteAlways]
    public class WaterRefractionEffector : MonoBehaviour {
        
        [SerializeField]
        private WaterVolumeSettings waterVolumeSettings = new();
        
        [SerializeField]
        private ComputeShader displacementComputeShader;
        

    
        [SerializeField]
        private bool settingsFromCurrentGameObject = true;
        
        public WaterVolumeSettings Settings => waterVolumeSettings;

        void EnableDisplacerRecursive(GameObject obj) {
            Transform t = obj.transform;
            for (int i = 0; i < t.childCount; i++) {
                EnableDisplacerRecursive(t.GetChild(i).gameObject);
            }
            if (obj.GetComponent<MeshFilter>() != null) {
                var displacer = obj.GetOrAddComponent<UnderwaterVertexDisplacer>();
                displacer.TryEnable();
            }
        }

        void DisableDisplacerRecursive(GameObject obj) {
            Transform t = obj.transform;
            for (int i = 0; i < t.childCount; i++) {
                EnableDisplacerRecursive(t.GetChild(i).gameObject);
            }
            if (obj.GetComponent<MeshFilter>() != null) {
                obj.GetOrAddComponent<UnderwaterVertexDisplacer>().enabled = false;

            }
        }
        
        private void OnTriggerEnter(Collider other) {
            UpdateVolumeSettings();
            EnableDisplacerRecursive(other.gameObject);
        }

        private void OnTriggerStay(Collider other) {
         
        }

        private void OnTriggerExit(Collider other) {
            UpdateVolumeSettings();
            DisableDisplacerRecursive(other.gameObject);
        }

        private void Awake() {
            Camera.main.depthTextureMode = DepthTextureMode.DepthNormals;
            UnderwaterVertexDisplacer.RefractionEffector = this;
            UnderwaterVertexDisplacer.VertexDisplacementCS = displacementComputeShader;
            waterVolumeSettings.WaterGameObject = gameObject;
            UpdateVolumeSettings();
        }


        private void Update() {
            if (transform.hasChanged) {
                UpdateVolumeSettings();
            }
        }

        void UpdateVolumeSettings() {
            if (settingsFromCurrentGameObject) {
                waterVolumeSettings.UpdateParamsFromGameObject();
            }
        }
        

    }
}