
using System;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Serialization;

namespace Ocean {
    
    [Serializable]
    public class WaterVolumeSettings 
    {
        [SerializeField]
        private float indexOfRefraction = 1.33f;
        
        [SerializeField]
        private Vector3 boundMin;
        

        [SerializeField]
        private Vector3 boundMax;
      

        [SerializeField]
        private Vector3 planeNormal;
        

        [SerializeField]
        private GameObject waterGameObject;
        

        public Vector3 BoundMin {
            get => boundMin;
        }
    
        public Vector3 BoundMax {
            get => boundMax;
        }

        public Vector3 WaterPlaneNormal {
            get => planeNormal;
        }
    
        public float IndexOfRefraction {
            get => indexOfRefraction;
        }
        
        public GameObject WaterGameObject {
            get => waterGameObject;
            set => waterGameObject = value;
        }
        
        

        public void UpdateParamsFromGameObject() {
            BoxCollider collider = waterGameObject.GetComponent<BoxCollider>();
            Transform transform = waterGameObject.transform;
            boundMin = collider.bounds.min;
            boundMax = collider.bounds.max;
            planeNormal = transform.up;
        }
    
    }

}
