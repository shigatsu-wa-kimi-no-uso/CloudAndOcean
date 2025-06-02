
using BezierEdit.Runtime;
using UnityEngine;
using UnityEditor;

namespace BezierEdit.Editor {
    

    [CustomEditor(typeof(BezierComponent))]
    public class BezierComponentEditor : UnityEditor.Editor {
        //这两个画Beizer线段的时候要用
        private Vector3 lastPosition;

        private Vector3 lastOutTangent;

        //正在操作哪个控制点
        int pickedIndex = -1;

        //正在操作控制点的哪一部分
        enum CtrlPointPickedType {
            position,
            inTangent,
            outTangent
        }

        CtrlPointPickedType pickedType = CtrlPointPickedType.position;


        private void UpdateCtrlPoint(CtrlPoint ctrlPoint) {
            //角点只能编辑位置不能编辑Tangent
            if (ctrlPoint.type == BezierPointType.corner) pickedType = CtrlPointPickedType.position;
            if (pickedType == CtrlPointPickedType.position) {
                //使用PositionHandle操作它的位置
                Vector3 newPosition = Handles.PositionHandle(ctrlPoint.position, Quaternion.identity);
                ctrlPoint.position = newPosition;
            } else if (pickedType == CtrlPointPickedType.inTangent) {
                //使用PositionHandle操作InTangent
                Vector3 position = ctrlPoint.position;
                Vector3 newInTangent = Handles.PositionHandle(ctrlPoint.InTangent + position, Quaternion.identity)
                                       - position;
                ctrlPoint.InTangent = newInTangent;
            } else if (pickedType == CtrlPointPickedType.outTangent) {
                //跟上一个差不多
                Vector3 position = ctrlPoint.position;
                Vector3 newOutTangent =
                    Handles.PositionHandle(ctrlPoint.OutTangent + position, Quaternion.identity) - position;
                ctrlPoint.OutTangent = newOutTangent;
            }
        }
        
        
        private void DrawGizmos(CtrlPoint[] ctrlPoints) {
            for (int i = 0; i < ctrlPoints.Length; i++) {
                //一个个地把控制点渲染出来
                CtrlPoint ctrlPoint = ctrlPoints[i];
                BezierPointType type = ctrlPoint.type;
                ref readonly Vector3 position = ref ctrlPoint.position;
                Vector3 inTangentPoint = ctrlPoint.InTangent + position;
                Vector3 outTangentPoint = ctrlPoint.OutTangent + position;
                bool button_picked = Handles.Button(position, Quaternion.identity, 0.1f, 0.1f, Handles.CubeHandleCap);
                if (button_picked) {
                    //只要点了这个控制点，PositionHandle就在它上面出现
                    pickedIndex = i;
                    pickedType = CtrlPointPickedType.position;
                }

                if (type != BezierPointType.corner) {
                    //画InTangent
                    Handles.DrawLine(position, inTangentPoint);
                    bool in_tangent_picked = Handles.Button(inTangentPoint, Quaternion.identity, 0.1f, 0.1f,
                        Handles.SphereHandleCap);
                    if (in_tangent_picked) {
                        pickedIndex = i;
                        pickedType = CtrlPointPickedType.inTangent;
                        //to-do:
                    }

                    //画OutTangent
                    Handles.DrawLine(position, outTangentPoint);
                    bool out_tangent_picked = Handles.Button(outTangentPoint, Quaternion.identity, 0.1f, 0.1f,
                        Handles.SphereHandleCap);
                    if (out_tangent_picked) {
                        pickedIndex = i;
                        pickedType = CtrlPointPickedType.outTangent;
                        //to_do:
                    }
                }

                //从第二个控制点开始画Bezier线段
                if (i > 0) {
                    Handles.DrawBezier(lastPosition, position, lastOutTangent, inTangentPoint, Color.green, null, 2f);
                }

                //所以每次先暂存下控制点位置和OutTangent，留给下一个控制点画线用
                lastPosition = position;
                lastOutTangent = outTangentPoint;
            }
        }
        
        private void OnSceneGUI() {
            BezierComponent bezierComponent = target as BezierComponent;
            //处理拖动操作的部分
            //防越界
            if (bezierComponent.ctrlPoints == null || pickedIndex >= bezierComponent.ctrlPoints.Length) {
                return;
            }

            if (pickedIndex != -1) {
                //得到正在操作的控制点
                CtrlPoint pickedCtrlPoint = bezierComponent.ctrlPoints[pickedIndex];
                UpdateCtrlPoint(pickedCtrlPoint);
            }

            DrawGizmos(bezierComponent.ctrlPoints);
        }
    }
}