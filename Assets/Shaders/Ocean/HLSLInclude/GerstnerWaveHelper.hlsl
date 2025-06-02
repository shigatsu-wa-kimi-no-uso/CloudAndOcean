#ifndef GERSTNER_WAVE_HELPER_HLSL
#define GERSTNER_WAVE_HELPER_HLSL

#define TWO_PI 6.28318530717958647693

struct GerstnerWaveInput
{
    float3 position;
    float3 direction;
    float wavelength;
    float steepness;
    float speed;
    float time;
};

static float GetPhase(float wavelength,float speed,float position,float time)
{
    float k = TWO_PI / wavelength;
    float phase = k * (position - speed * time);
    return phase;
}

static float GetAmplitude(float wavelength,float steepness)
{
    float k = TWO_PI / wavelength;
    float amplitude = steepness / k;
    return amplitude;
}

float3 GetGerstnerWavePosition(GerstnerWaveInput input)
{
    float amplitude = GetAmplitude(input.wavelength,input.steepness);
    float2 projectedPos = dot(input.direction.xz,input.position.xz);
    float phase = GetPhase(input.wavelength,input.speed,projectedPos,input.time);
    float3 wavePoint;
    wavePoint.xz = amplitude * cos(phase) * input.direction.xz;
    wavePoint.y = amplitude * sin(phase);
    return wavePoint;
}


// Note: this function only calculates derivatives of trigonometric terms, and result is not normalized.
float3 GetGerstnerWaveTangent(GerstnerWaveInput input)
{
    float2 projectedPos = dot(input.direction.xz,input.position.xz);
    float phase = GetPhase(input.wavelength,input.speed,projectedPos,input.time);
    float3 tangent;
    tangent.xz = - input.direction.x * input.steepness * sin(phase) * input.direction.xz;
    tangent.y =  input.direction.x * input.steepness * cos(phase);
    return tangent;
}

// Note: this function only calculates derivatives of trigonometric terms, and result is not normalized.
float3 GetGerstnerWaveBitangent(GerstnerWaveInput input)
{
    float2 projectedPos = dot(input.direction.xz,input.position.xz);
    float phase = GetPhase(input.wavelength,input.speed,projectedPos,input.time);
    float3 bitangent;
    bitangent.xz = - input.direction.z * input.steepness * sin(phase) * input.direction.xz;
    bitangent.y =  input.direction.z * input.steepness * cos(phase);
    return bitangent;
}


// Method: calculate cross product of tangent and vertical direction of the traveling direction.
// cross(tangent,(-dir.z,0,dir.x))
// Note: this function only calculates derivatives of trigonometric terms, and result is not normalized.
float3 GetGerstnerWaveNormal(GerstnerWaveInput input)
{
    float2 projectedPos = dot(input.direction.xz,input.position.xz);
    float phase = GetPhase(input.wavelength,input.speed,projectedPos,input.time);
    float2 normalXZ = -input.direction.xz * input.steepness * cos(phase);
    float normalY = -input.steepness * sin(phase);
    return float3(normalXZ.x,normalY,normalXZ.y);
}




#endif