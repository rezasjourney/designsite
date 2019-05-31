

//Taken from GPU Gems 3


__device__ unsigned TausStep(unsigned &z, int S1, int S2, int S3, unsigned M)
{
  unsigned b=(((z << S1) ^ z) >> S2);
  return z = (((z & M) << S3) ^ b);
}

__device__ unsigned LCGStep(unsigned &z, unsigned A, unsigned C)
{
  return z=(A*z+C);
}


__device__ unsigned z1, z2, z3, z4;
__device__ float randu()
{
 // Combined period is lcm(p1,p2,p3,p4)~ 2^121
  return 2.3283064365387e-10 * (              // Periods
   TausStep(z1, 13, 19, 12, 4294967294UL) ^  // p1=2^31-1
   TausStep(z2, 2, 25, 4, 4294967288UL) ^    // p2=2^30-1
   TausStep(z3, 3, 11, 17, 4294967280UL) ^   // p3=2^28-1
   LCGStep(z4, 1664525, 1013904223UL)        // p4=2^32
  );
}




__device__ float2 randn()
{
	float u0=randu (), u1=randu ();
	float r=sqrt(-2*log(u0));
	float theta=2*3.14159265*u1;
	return make_float2(r*sin(theta),r*cos(theta));
}
