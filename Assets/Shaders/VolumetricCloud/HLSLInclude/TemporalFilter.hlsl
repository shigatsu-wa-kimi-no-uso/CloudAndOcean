#ifndef TEMPORAL_FILTER_H
#define TEMPORAL_FILTER_H
#include "CheckerboardUitls.hlsl"
        

struct TemporalFilterInput
{
    float2 pixelPos;
    float2 screenUV;
    float depth;
    float4 blendFactor;
    float4x4 currModelMatrixInv; // can be identity if dis-considering object motion.
    float4x4 currViewProjectMatrixInv;
    float4x4 prevModelMatrix;
    float4x4 prevViewProjectMatrix; 
    sampler2D prevFrameTex;
    float2 prevFrameTexUVDelta;
    sampler2D currRawFrameTex;
    float2 currRawFrameTexUVDelta;
    bool usingReprojection;
    bool usingCheckerboardSampling;
    float evenOdd; // for checkerboard rendering
    float4 currFramePixelColor;
};

struct ColorAABB
{
    float4 boundsMin;
    float4 boundsMax;
};

// calculation of depth is broken 
static float2 GetScreenUV(float4 positionWS,float4x4 viewProjectionMatrix,out float depth)
{
    float4 positionCS = mul(viewProjectionMatrix,positionWS);
    float4 positionNDC = positionCS.xyzw / positionCS.w;
    // FIXME: depth is not correct.
    depth = positionNDC.z;
    return 0.5*positionNDC.xy + 0.5; // values within [0,1]^3
}


static float3 GetWorldSpacePosition(float2 screenUV,float depth,float4x4 viewProjectMatrixInv){
    // be careful about Unity's confusing naming: positionNDC. It's not the tradition NDC definition
    // that's a [-1,1]^3 space, but [0,1]^3.
    return ComputeWorldSpacePosition(screenUV, depth, viewProjectMatrixInv);
}



// be careful: you can set 'Model Matrix' as 'Identity Matrix', in which case
// it'll just cause the motion of objects being unconsidered.
static float2 Reproject(float2 screenUV,float depth,float4x4 currModelMatrixInv,float4x4 currViewProjectMatrixInv,
    float4x4 prevViewProjectMatrix,float4x4 prevModelMatrix,out float prevDepth)
{
    float3 positionWS = GetWorldSpacePosition(screenUV,depth,currViewProjectMatrixInv);
    float4 positionOS = mul(currModelMatrixInv,float4(positionWS,1));
    float4 prevPositionWS = mul(prevModelMatrix,positionOS);
    float2 prevScreenUV = GetScreenUV(prevPositionWS,prevViewProjectMatrix,prevDepth);
    return prevScreenUV;
}



static bool FloatEqual(float4 a, float4 b,float epsilon)
{
    return all(abs(a - b) < epsilon);
}


static bool FloatEqual(float2 a, float2 b,float epsilon)
{
    return all(abs(a - b) < epsilon);
}

static bool FloatEqual(float a, float b,float epsilon)
{
    return all(abs(a - b) < epsilon);
}

static bool FloatGreaterEqual(float4 a, float4 b,float epsilon)
{
    if (any(a - b <= -epsilon))
    {
        return false;
    }else{
        return true;
    }
}

static bool FloatLessEqual(float4 a, float4 b,float epsilon)
{
    if (any(a - b >= epsilon))
    {
        return false;
    }else{
        return true;
    }
}

bool IsValidScreenUV(float2 screenUV,float prevDepth,float currDepth,float depthEqualEpsilon)
{
    if (screenUV.x >= 0 && screenUV.x <= 1 && screenUV.y >= 0 && screenUV.y <= 1)
    {
        if (FloatEqual(prevDepth,currDepth,depthEqualEpsilon))
        {
            return true;
        }else{
            return false;
        }
         
    }
    return false;
}

static float4 VisualizeUVDifference(float2 screenUV,float2 lastScreenUV)
{
    return float4(abs(screenUV.x - lastScreenUV.x),abs(screenUV.y - lastScreenUV.y),0,1);
}

static float4 VisualizeColorDifference(float4 color1,float4 color2,float scalar)
{
    return abs(color1-color2)*scalar;
  //  return float4(abs(color1.r - color2.r),abs(color1.g - color2.g),abs(color1.b - color2.b),color1);
}


static float4 VisualizeUnequal(float4 a,float4 b,float epsilon)
{
    if (FloatEqual(a,b,epsilon))
    {
        return float4(1,0,0,1);
    }
    else
    {
        return float4(0,1,0,1);
    }
}

static float4 VisualizeBool(bool val,float4 colorTrue,float4 colorFalse)
{
    return val ? colorTrue : colorFalse;
}


static float4 GetColorAverage(sampler2D tex,float2 uv,float2 uvDelta,bool fromCorner)
{
    float2 neighborUV[4];
    if (fromCorner)
    {
        neighborUV[0] = uv + uvDelta;
        neighborUV[1] = uv - uvDelta;
        neighborUV[2] = uv + float2(uvDelta.x, -uvDelta.y);
        neighborUV[3] = uv - float2(uvDelta.x, -uvDelta.y);
    }else{
        neighborUV[0] = uv + float2(uvDelta.x, 0);
        neighborUV[1] = uv + float2(-uvDelta.x, 0);
        neighborUV[2] = uv + float2(0, uvDelta.y);
        neighborUV[3] = uv + float2(0, -uvDelta.y);
    }

    float4 value[4];
    value[0] = tex2D(tex,neighborUV[0]);
    value[1] = tex2D(tex,neighborUV[1]);
    value[2] = tex2D(tex,neighborUV[2]);
    value[3] = tex2D(tex,neighborUV[3]);
    
    return 0.25*value[0] + 0.25*value[1] + 0.25*value[2] + 0.25*value[3];
}

static ColorAABB GetColorAABB(sampler2D tex,float2 uv,float2 uvDelta,bool fromCorner)
{
    float2 neighborUV[4];
    if (fromCorner)
    {
        neighborUV[0] = uv + uvDelta;
        neighborUV[1] = uv - uvDelta;
        neighborUV[2] = uv + float2(uvDelta.x, -uvDelta.y);
        neighborUV[3] = uv - float2(uvDelta.x, -uvDelta.y);
    }else{
        neighborUV[0] = uv + float2(uvDelta.x, 0);
        neighborUV[1] = uv + float2(-uvDelta.x, 0);
        neighborUV[2] = uv + float2(0, uvDelta.y);
        neighborUV[3] = uv + float2(0, -uvDelta.y);
    }

    float4 value[4];
    value[0] = tex2D(tex,neighborUV[0]);
    value[1] = tex2D(tex,neighborUV[1]);
    value[2] = tex2D(tex,neighborUV[2]);
    value[3] = tex2D(tex,neighborUV[3]);
    ColorAABB result;
    result.boundsMin = min(min(min(value[0],value[1]),value[2]),value[3]);
    result.boundsMax = max(max(max(value[0],value[1]),value[2]),value[3]);
    return result;
}

static bool IsColorInBounds(float4 color,ColorAABB bounds,float epsilon)
{
    return  FloatGreaterEqual(color,bounds.boundsMin,epsilon)
    && FloatLessEqual(color,bounds.boundsMax,epsilon);
}

float ExponentialLerp(float a,float b,float t)
{
    return pow(a,t)*pow(b,1-t);
}

float4 LerpColorAndExponentialDensity(float4 a,float4 b,float t)
{
    float3 colorLerp =  lerp(a.rgb, b.rgb, t);
    float densityLerp = ExponentialLerp(a.a, b.a, t);
    return float4(colorLerp,densityLerp);
}

float4 GetTemporalFilteredResult(TemporalFilterInput input)
{
    
    float prevDepth;
    float2 prevScreenUV;
    float2 screenUV = input.screenUV;
    float4 currRawValue = input.currFramePixelColor;
    
    if (input.usingReprojection){
        prevScreenUV = Reproject(screenUV,input.depth, input.currModelMatrixInv,
                                          input.currViewProjectMatrixInv,input.prevViewProjectMatrix,
                                          input.prevModelMatrix,prevDepth);
        //Calculation of depth is broken. Epsilon is set to 1000 temporarily.
        //TODO: fix
        if (!IsValidScreenUV(prevScreenUV,prevDepth,input.depth,1000)){
          
         //   return float4(1,0,0,0);
            return currRawValue;
        }
       // return float4(1,1,0,1);
    }else{
        prevScreenUV = screenUV;
    }
    
    float4 prevValue = tex2D(input.prevFrameTex,prevScreenUV);

    
    
    if (input.usingCheckerboardSampling){
        bool sampleFromCurr = GetCheckerboardPositionParity(input.pixelPos,input.evenOdd);
        
       // return float4(input.currScreenUV,0,0);
        if (sampleFromCurr){
            //return float4(1,0,0,0);
            //note: checkerboard sampled texture should have nearest-neighbor filter mode, or value will be interpolated.
            ColorAABB colorBounds = GetColorAABB(input.currRawFrameTex,screenUV,input.prevFrameTexUVDelta,true);
            prevValue = clamp(prevValue,colorBounds.boundsMin,colorBounds.boundsMax);
            //return lerp(prevValue, currRawValue, input.blendFactor);
            return  LerpColorAndExponentialDensity(prevValue,currRawValue,input.blendFactor);
           // currRawValue.a = 1;
        }else{
           // return float4(0,0,0,0);
            currRawValue = GetColorAverage(input.currRawFrameTex,input.screenUV,input.prevFrameTexUVDelta,false);
           // ColorAABB colorBounds = GetColorAABB(input.currRawFrameTex,input.screenUV,input.prevFrameTexUVDelta,false);
         //   prevValue = clamp(prevValue,colorBounds.boundsMin,colorBounds.boundsMax);
           // currRawValue = lerp(prevValue, currRawValue, 1 - input.blendFactor);
          //  currRawValue.a = 0.91;
          //  return lerp(prevValue, currRawValue, input.blendFactor);
            return LerpColorAndExponentialDensity(prevValue,currRawValue,input.blendFactor);
            //currRawValue.a = 0;
        }
    }else{
        ColorAABB colorBounds = GetColorAABB(input.currRawFrameTex,screenUV,input.currRawFrameTexUVDelta,true);
        ColorAABB colorBounds2 = GetColorAABB(input.currRawFrameTex,screenUV,input.currRawFrameTexUVDelta,false);
        prevValue = clamp(prevValue,colorBounds.boundsMin,colorBounds.boundsMax);
        prevValue = clamp(prevValue,colorBounds2.boundsMin,colorBounds2.boundsMax);
        //return lerp(prevValue, currRawValue, input.blendFactor);
        return  LerpColorAndExponentialDensity(prevValue,currRawValue,input.blendFactor);
    }
  //  return currRawValue;
    
 //   ColorAABB colorBounds = GetColorAABB(input.lastFrameTex,lastScreenUV,input.uvDelta);
  //  return VisualizeBool(IsColorInBounds(currValue,colorBounds),float4(1,0,0,1),float4(0,1,0,1));
    
 
    
    /*
     
    float4 res = lerp(currValue,lastValue, input.blendFactor);
    float4 d1 = abs(res - currValue);
    float4 d2 = abs(lastValue - currValue);
    if (!FloatGreaterEqual(d2,d1,0.0001))
    {
        return float4(1,0,0,1);
    }*/
    
    // visualize how the rectification method we applied (clamp) effects the results
    /*if (!IsColorInBounds(currValue,colorBounds,0.01))
    {
       return float4(0,0,0,1);//VisualizeColorDifference(prevValue,currValue,5);
    }*/

    
    
    //return float4(lastScreenUV,0,1);
    //float4 d1 = VisualizeColorDifference(currValue,lastValue,5);
    //float4 lerped = lerp(lastValue, currValue, input.blendFactor);
   // return input.blendFactor;
  //  float4 d2 = VisualizeColorDifference(currValue,lerped,5);
    //return VisualizeBool(d2 < d1,float4(1,0,0,1),float4(0,1,0,1));
   // return float4(d1.r,d2.g,0,1);
 //   return VisualizeColorDifference(d1,d2,5);

}


#endif // TEMPORAL_FILTER_H
