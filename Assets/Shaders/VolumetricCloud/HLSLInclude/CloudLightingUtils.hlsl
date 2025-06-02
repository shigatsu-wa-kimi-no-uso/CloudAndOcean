#ifndef CLOUD_LIGHTING_UTILS_HLSL
#define CLOUD_LIGHTING_UTILS_HLSL

float3 BeerLambertsTransmittance(float3 density) {
    return exp(-density);
}

float BeerLambertsTransmittance(float density) {
    return exp(-density);
}

float3 ExpAttenuateIntensity(float3 intensity, float3 factor) {
    return intensity * exp(-factor);
}

float3 BeerPowderAttenuate(float3 factor, float a) {
    float3 t = exp(-factor * a) * (1 - exp(-factor * 2 * a));
    //return t*2.5980762113533159402911695122588;
    return t;
}
  
float SchlickPhaseFunction(float cosTheta, float g) {
    /* Schlick phase function, an approximation of Hg phase function */
    float k = 1.55 * g - 0.55 * g * g * g;
    return (1.0 - k * k) / (12.56637 * pow(1 - k * cosTheta, 2));
}

float HgPhaseFunction(float cosTheta, float g) {
    /* Hg Phase Function */
                    
    float g2 = g * g;
    return (1 - g2) / (12.56637 * pow(1 + g2 - 2 * g * cosTheta, 1.5));
}

#endif

