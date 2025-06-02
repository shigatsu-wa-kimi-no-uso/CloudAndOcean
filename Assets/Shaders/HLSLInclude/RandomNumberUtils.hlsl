#ifndef RANDOM_NUMBER_UTILS_HLSL
#define RANDOM_NUMBER_UTILS_HLSL

static float randomSeed;

void SetRandomSeed(float seed) {
    randomSeed = seed;
}

float GetRandom(){
   // float result = frac(sin(randomSeed))
    float result = sin(randomSeed * 641.5467987313875 + 1.943856175);
    SetRandomSeed(result);
    return result;
}

float Get01RandomWithTimeSeed(float a,float b)
{
    return frac(sin(a + _Time.y)*sin(b - _Time.y)*999999);
}

float GetRandom(float min, float max) {
    return min + (max - min) * 0.5 * (GetRandom() + 1);
}

float GetRandom(float range) {
    return range*GetRandom();
}

#endif //RANDOM_NUMBER_UTILS_HLSL