#ifndef FILTERS_HLSL
#define FILTERS_HLSL
#include "CheckerboardUitls.hlsl"
#define PI 3.1415926535897932384626433832795
#define TAU (PI * 2.0)

const float GaussianKernel[25] = {
    0.00297,   0.01331,   0.02194,   0.01331,   0.00297,   
    0.01331,   0.05963,   0.09832,   0.05963,   0.01331,   
    0.02194,   0.09832,   0.16210,   0.09832,   0.02194,   
    0.01331,   0.05963,   0.09832,   0.05963,   0.01331,   
    0.00297,   0.01331,   0.02194,   0.01331,   0.00297 
};



float GaussianWeight(float d, float sigma) {
    return 1.0 / (sigma * sqrt(TAU)) * exp(-(d * d) / (2.0 * sigma * sigma));
}

float2 GaussianWeight(float2 d, float2 sigma) {
    return 1.0 / (sigma * sqrt(TAU)) * exp(-(d * d) / (2.0 * sigma * sigma));
}

float4 GaussianWeight(float4 d, float4 sigma) {
    return 1.0 / (sigma * sqrt(TAU)) * exp(-(d * d) / (2.0 * sigma * sigma));
}

float4 BilateralWeight(float2 centerPos, float4 centerColor,float2 currentPos, float4 currentColor,float spatialSigma,float4 tonalSigma) {
    float spatialDiff = length(centerPos - currentPos);
    float4 tonalDiff = centerColor - currentColor;
    return GaussianWeight(spatialDiff, spatialSigma) * GaussianWeight(tonalDiff, tonalSigma);
}


struct GaussianFilterInput {
    float4 centerColor;
    float2 pixelPos;
    float2 screenUV;
    float2 screenUVDelta;
    float4 tonalSigma;
    int spatialKernelSize;
    sampler2D prevFrameTex;
   // float2 prevFrameTexUVDelta;
    sampler2D currRawFrameTex;
    //float2 currRawFrameTexUVDelta;
    float evenOdd; // for checkerboard rendering
    bool usingCheckerboardSampling;
};

float4 GetBilateralFilteredResult(GaussianFilterInput input)
{
    float spatialSigma = ((float)input.spatialKernelSize - 1)/6.0f;
    int halfKernelSize = input.spatialKernelSize/2;
  
    float4 weightSum = 0.00000000001;
    float4 result = 0.0;
    for (int i = -halfKernelSize; i < halfKernelSize; i++)
    {
        for (int j = -halfKernelSize; j < halfKernelSize; j++)
        {
            if (i == 0 && j == 0)
            {
                continue;
            }
            float2 pixelPos = input.pixelPos + float2(i, j);
            float2 uv = input.screenUV + input.screenUVDelta*float2(i,j);
            float4 color = tex2D(input.currRawFrameTex,uv);
            /*if (input.usingCheckerboardSampling)
            {
                bool sampleFromCurr = GetCheckerboardPositionParity(pixelPos,input.evenOdd);
                if (sampleFromCurr){
                    color = tex2D(input.currRawFrameTex,uv);
                }else{
                    color = tex2D(input.prevFrameTex,uv);
                }
                color = tex2D(input.prevFrameTex,uv);
            }else
            {
                color = tex2D(input.currRawFrameTex,uv);
            }*/
            
            float4 weight = BilateralWeight(input.pixelPos, input.centerColor*255,
                pixelPos, color*255, spatialSigma, input.tonalSigma*255);
            result+=weight*color;
            //return float4(uv,0,1);
            weightSum+=weight;
        }
    }
   // return result;
    return result/weightSum;
}

#endif