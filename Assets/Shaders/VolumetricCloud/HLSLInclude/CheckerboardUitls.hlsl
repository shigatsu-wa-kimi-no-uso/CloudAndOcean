#ifndef CHECKERBOARD_UTILS_HLSL
#define CHECKERBOARD_UTILS_HLSL

// Check whether the pixel position is even or odd in the checkerboard.
// if even, the pixel position is like (0,0),(0,2),(1,1)...which (x+y)%2 == 0
bool GetCheckerboardPositionParity(float2 pixelPos,float parity)
{
    // parityis either 0 or 1, when equals 0, return whether a position is even.
    // note: pixelPos will be floored first.
    pixelPos = floor(pixelPos);
    float shift = fmod(pixelPos.y + parity,2.0);       // shift is either 0 or 1, denoting whether to shift or not in this row
    float pixelParity = fmod(pixelPos.x + shift,2.0);
    if (pixelParity < 0.5){
        return true;
    }else{
        return false;
    }
}

// Get the checkerboard pixel position from sampled pixel position.
// When checkerboard rendering, the original render target with resolution [x,y] is cut apart as checkerboard,
// and only half of the pixels will be sampled to render. If sampling on x, the pixelPos will range in [x/2,y].
// What we need to do is to remap [x/2,y] to [x,y].
// Two ways to remap x:
// multiply with 2: (0,0)->(0,0), (1,1)->(2,1), (2,3)->(4,3)...
// (all remapped coords x are even, missing points like (1,0), (3,1), (5,3), (3,5)...)
// multiply with 2 and add 1 offset to x: (0,0)->(1,0), (1,1)->(3,1), (2,3)->(5,3)..
// (all remapped coords x are odd, compensating points like (1,0), (3,1), (5,3), (3,5)...)
// Alternating two ways according to pixelPos.y to get checkerboard sample.

float2 ResolveCheckerboardSampledPixelPos(float2 pixelPos,float parity)
{
    pixelPos = floor(pixelPos);
    float shift = fmod(pixelPos.y + parity,2.0); // shift or not
    return float2(pixelPos.x * 2.0 + shift, pixelPos.y) + float2(0.5,0.5);
}

float2 GetCheckerboardSampledUV(float3 pixelPos,float2 sampledRTResolution, float parity)
{
    float2 sampledPixelPos = ResolveCheckerboardSampledPixelPos(pixelPos,parity);
    return sampledPixelPos/sampledRTResolution;
}




#endif
