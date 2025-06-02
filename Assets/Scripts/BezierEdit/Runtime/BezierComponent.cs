using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

namespace BezierEdit.Runtime {

    [ExecuteInEditMode]
    public class BezierComponent : MonoBehaviour {
        public CtrlPoint[] ctrlPoints;

       

        //t的位置
        public Vector3 Evaluate(float t) {
            float SegmentCount = ctrlPoints.Length - 1;

            if (ctrlPoints.Length == 0) return transform.position;
            if (ctrlPoints.Length == 1) return ctrlPoints[0].position;
            t = Mathf.Clamp(t, 0, SegmentCount);
            int segment_index = (int)t;
            if (segment_index == SegmentCount) segment_index -= 1;
            Vector3 p0 = ctrlPoints[segment_index].position;
            Vector3 p1 = ctrlPoints[segment_index].OutTangent + p0;
            Vector3 p3 = ctrlPoints[segment_index + 1].position;
            Vector3 p2 = ctrlPoints[segment_index + 1].InTangent + p3;

            t = t - segment_index;
            float u = 1 - t;
            return p0 * u * u * u + 3 * p1 * u * u * t + 3 * p2 * u * t * t + p3 * t * t * t;
        }

        //t的速度切线（曲线求导）
        public Vector3 EvaluateDerivatives(float t) {
            float SegmentCount = ctrlPoints.Length - 1;

            if (ctrlPoints.Length == 0) return transform.position;
            if (ctrlPoints.Length == 1) return ctrlPoints[0].position;
            t = Mathf.Clamp(t, 0, SegmentCount);
            int segment_index = (int)t;
            if (segment_index == SegmentCount) segment_index -= 1;
            Vector3 p0 = ctrlPoints[segment_index].position;
            Vector3 p1 = ctrlPoints[segment_index].OutTangent + p0;
            Vector3 p3 = ctrlPoints[segment_index + 1].position;
            Vector3 p2 = ctrlPoints[segment_index + 1].InTangent + p3;

            Vector3 q0 = 3 * (p1 - p0);
            Vector3 q1 = 3 * (p2 - p1);
            Vector3 q2 = 3 * (p3 - p2);

            t = t - segment_index;
            float u = 1 - t;

            return q0 * u * u + 2 * q1 * t * u + q2 * t * t;
        }



    }





//角点、贝塞尔角点、平滑  三种控制类型
    public enum BezierPointType {
        corner,
        bezierCorner,
        smooth
    }


//根据控制类型改变控制柄向量
    [System.Serializable]
    public class CtrlPoint {
        public BezierPointType type;
        public Vector3 position;

        [SerializeField]
        Vector3 inTangent;

        [SerializeField]
        Vector3 outTangent;



        public Vector3 InTangent {
            get {
                if (type == BezierPointType.corner) return Vector3.zero;
                else return inTangent;
            }
            set {
                if (type != BezierPointType.corner) inTangent = value;
                if (value.sqrMagnitude > 0.001 && type == BezierPointType.smooth) {
                    outTangent = value.normalized * ((-1) * outTangent.magnitude);
                }
            }
        }

        public Vector3 OutTangent {
            get {
                if (type == BezierPointType.corner) return Vector3.zero;
                if (type == BezierPointType.smooth) {
                    if (inTangent.sqrMagnitude > 0.001) {
                        return inTangent.normalized * ((-1) * outTangent.magnitude);
                    }
                }

                return outTangent;
            }
            set {
                if (type == BezierPointType.smooth) {
                    if (value.sqrMagnitude > 0.001) {
                        inTangent = value.normalized * ((-1) * inTangent.magnitude);
                    }

                    outTangent = value;
                }

                if (type == BezierPointType.bezierCorner) outTangent = value;
            }
        }
    }
}