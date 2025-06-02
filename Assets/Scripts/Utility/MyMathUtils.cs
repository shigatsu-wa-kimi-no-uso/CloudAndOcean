


using System;

namespace Utility {
    
    public class MyMathUtils {
        public static int GreatestCommonDivisor(int a, int b)
        {
            while (b != 0) {
                int temp = b;
                b = a % b;
                a = temp;
            }
            return a;
        }
        
        public static int LeastCommonMultiple(int a, int b)
        {
            if (a == 0 || b == 0) {
                return 0; 
            }
            return Math.Abs(a * b) / GreatestCommonDivisor(a, b);
        }

    }
}