#ifndef UNDERWATER_VERTEX_DISPLACEMENT_HLSL
#define UNDERWATER_VERTEX_DISPLACEMENT_HLSL

float square(float x)
{
    return x*x;
}

float GetSquaredHypotenuse(float x,float y)
{
    return x*x + y*y;
}


bool IsUnderwaterVertexClipped(float3 position,float3 boundMin,float3 boundMax)
{
    if (any(position < boundMin) || any(position > boundMax)){
        return true;
    }else{
        return false;
    }
}

void IsUnderwaterVertexClipped_float(float3 position,float3 boundMin,float3 boundMax,out bool clipped)
{
    clipped = IsUnderwaterVertexClipped(position,boundMin,boundMax);
}

void IsUnderwaterVertexClipped_half(float3 position,float3 boundMin,float3 boundMax,out bool clipped)
{
    clipped = IsUnderwaterVertexClipped(position,boundMin,boundMax);
}


float3 GetUnderwaterVertexDisplacement(float3 cameraPos,float3 vertexPos,float3 waterPlaneNormal,float3 waterPlaneCenterPos,float indexOfRefraction){
    waterPlaneNormal = normalize(waterPlaneNormal);
    float heightPlaneToCam = dot(cameraPos - waterPlaneCenterPos,waterPlaneNormal);
    float heightVertexToPlane = dot(waterPlaneCenterPos - vertexPos,waterPlaneNormal);
    
    if (heightPlaneToCam < 0  || heightVertexToPlane < 0 )
    {
        return float3(0,0,0);
    }
    
    float heightVertToCam = heightPlaneToCam + heightVertexToPlane;
    float3 camToVertex = vertexPos - cameraPos;
    float3 camToVertProj = camToVertex - waterPlaneNormal * dot(camToVertex,waterPlaneNormal);
    float3 cameraPosProj = cameraPos - heightPlaneToCam * waterPlaneNormal;
  //  vertexDisplacement = length(camToVertProj);
   // return;
    float camToVertProjLen = length(camToVertProj);
    float3 camToVertDirProj = normalize(camToVertProj);

    float camToPlaneProjLen = camToVertProjLen * (heightPlaneToCam / heightVertToCam );
    float3 planeHitPos = cameraPosProj + camToVertDirProj * camToPlaneProjLen ;
  //  vertexDisplacement = float3(waterBoundMax);
   // return;
    

    float vertToPlaneProjLen = camToVertProjLen - camToPlaneProjLen;
    float delta_UB = vertToPlaneProjLen;
    float delta_LB = 0;
    float delta = 0;
    float epsilon = 0.01;
    const int maxLoopIteration = 50;
    float expectedIOR2 = indexOfRefraction*indexOfRefraction;
    for (int i = 0;i<maxLoopIteration;i++)
    {
        delta = delta_LB + 0.5*(delta_UB - delta_LB);
        float newCamToPlaneProjLen = camToPlaneProjLen + delta;
        float newVertToPlaneProjLen = vertToPlaneProjLen - delta;
        float sini2 = square(newCamToPlaneProjLen)/GetSquaredHypotenuse(newCamToPlaneProjLen,heightPlaneToCam);
        float sinr2 = square(newVertToPlaneProjLen)/GetSquaredHypotenuse(newVertToPlaneProjLen,heightVertexToPlane);
        float ior2 = sini2/sinr2;
        if (ior2 < expectedIOR2){
            delta_LB = delta;
        }else if (ior2 > expectedIOR2){
            delta_UB = delta;
        }
        if (abs(delta_UB - delta_LB) < epsilon)
        {
           
            if (abs(ior2 - expectedIOR2)<0.01)
            {
                //vertexDisplacement = float3(1,1,0);
            }else
            {
             //   vertexDisplacement = float3(0,0,0);
            }
          //  return;
            break;
        }
    }
  //  vertexDisplacement = float3(0,0,1);
   // return;
    
    float3 newPlaneHitPos =  cameraPosProj + camToVertDirProj * (camToPlaneProjLen + delta);
    float totalRayDist = length(newPlaneHitPos - cameraPos) + length(newPlaneHitPos - vertexPos);
    float3 newCamToVertDir = normalize(newPlaneHitPos - cameraPos);
    float3 newVertex = cameraPos + newCamToVertDir * totalRayDist;
    float3 displacement = newVertex - vertexPos;
    return displacement;
}


// export symbol for shader graph
void GetUnderwaterVertexDisplacement_float(in float3 cameraPos,in float3 vertexPos,in float3 waterPlaneNormal,in float3 waterPlaneCenterPos,in float indexOfRefraction,out float3 vertexDisplacement){
    vertexDisplacement = GetUnderwaterVertexDisplacement(cameraPos,vertexPos,waterPlaneNormal,waterPlaneCenterPos,indexOfRefraction);
}

#endif