#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include "timer.h"
#include "check.h"

#define SOFTENING 1e-9f

/*
 * Each body contains x, y, and z coordinate positions,
 * as well as velocities in the x, y, and z directions.
 */

typedef struct { float x, y, z, vx, vy, vz; } Body;

/*
 * Do not modify this function. A constraint of this exercise is
 * that it remain a host function.
 */

void randomizeBodies(float *data, int n) {
  for (int i = 0; i < n; i++) {
    data[i] = 2.0f * (rand() / (float)RAND_MAX) - 1.0f;
  }
}

/*
 * This function calculates the gravitational impact of all bodies in the system
 * on all others, but does not update their positions.
 */

__global__ void bodyForce(Body *p, float dt, int n) {
  int tid = threadIdx.x + blockIdx.x * blockDim.x;
  int gridStrid = blockDim.x * gridDim.x;

  for (; tid < n; tid += gridStrid) {
    float Fx = 0.0f; float Fy = 0.0f; float Fz = 0.0f;

    for (int j = 0; j < n; j++) {
      float dx = p[j].x - p[tid].x;
      float dy = p[j].y - p[tid].y;
      float dz = p[j].z - p[tid].z;
      float distSqr = dx*dx + dy*dy + dz*dz + SOFTENING;
      float invDist = rsqrtf(distSqr);
      float invDist3 = invDist * invDist * invDist;

      Fx += dx * invDist3; Fy += dy * invDist3; Fz += dz * invDist3;
    }

    p[tid].vx += dt*Fx; p[tid].vy += dt*Fy; p[tid].vz += dt*Fz;
  }
}

__global__ void integratePosition(Body *p, float dt, int n) {
  int tid = threadIdx.x + blockIdx.x * blockDim.x;
  int gridStride = gridDim.x * blockDim.x;
  for (; tid < n; tid += gridStride) { // integrate position
    p[tid].x += p[tid].vx*dt;
    p[tid].y += p[tid].vy*dt;
    p[tid].z += p[tid].vz*dt;
  }
}


void cudaInfo()
{
  int deviceId;
  cudaGetDevice(&deviceId);
  cudaDeviceProp prop;
  cudaGetDeviceProperties(&prop, deviceId);

  printf("Name: %s\n", prop.name);
  printf("SM's: %d\n", prop.multiProcessorCount);
  printf("Warp size: %d\n", prop.warpSize);
  printf("Max threads per block: %d\n", prop.maxThreadsPerBlock);
  printf("Max threads per multiprocessor: %d\n", prop.maxThreadsPerMultiProcessor);
}

int main(const int argc, const char** argv) {

  cudaInfo();

  /*
   * Do not change the value for `nBodies` here. If you would like to modify it,
   * pass values into the command line.
   */

  int nBodies = 2<<11;
  int salt = 0;
  if (argc > 1) nBodies = 2<<atoi(argv[1]);

  /*
   * This salt is for assessment reasons. Tampering with it will result in automatic failure.
   */

  if (argc > 2) salt = atoi(argv[2]);

  const float dt = 0.01f; // time step
  const int nIters = 10;  // simulation iterations

  int bytes = nBodies * sizeof(Body);
  float *buf;

  cudaMallocManaged(&buf, bytes);

  cudaMemPrefetchAsync(buf, bytes, cudaCpuDeviceId);
  Body *p = (Body*)buf;

  /*
   * As a constraint of this exercise, `randomizeBodies` must remain a host function.
   */

  randomizeBodies(buf, 6 * nBodies); // Init pos / vel data

  double totalTime = 0.0;


  // Blocks and threads
  int deviceId;
  cudaGetDevice(&deviceId);
  cudaDeviceProp prop;
  cudaGetDeviceProperties(&prop, deviceId);


  /*
   * This simulation will run for 10 cycles of time, calculating gravitational
   * interaction amongst bodies, and adjusting their positions to reflect.
   */

  /*******************************************************************/
  // Do not modify these 2 lines of code.
  for (int iter = 0; iter < nIters; iter++) {
    StartTimer();
  /*******************************************************************/

  /*
   * You will likely wish to refactor the work being done in `bodyForce`,
   * as well as the work to integrate the positions.
   */
    cudaMemPrefetchAsync(buf, bytes, deviceId);
    bodyForce<<<16*prop.multiProcessorCount, 2*prop.warpSize>>>(p, dt, nBodies); // compute interbody forces
    //cudaDeviceSynchronize();
  /*
   * This position integration cannot occur until this round of `bodyForce` has completed.
   * Also, the next round of `bodyForce` cannot begin until the integration is complete.
   */

    //cudaMemPrefetchAsync(buf, bytes, deviceId);
    integratePosition<<<16*prop.multiProcessorCount, 2*prop.warpSize>>>(p, dt, nBodies);
    //cudaDeviceSynchronize();

  /*******************************************************************/
  // Do not modify the code in this section.
    const double tElapsed = GetTimer() / 1000.0;
    totalTime += tElapsed;
  }

  cudaDeviceSynchronize();
  cudaMemPrefetchAsync(buf, bytes, cudaCpuDeviceId);
  double avgTime = totalTime / (double)(nIters);
  float billionsOfOpsPerSecond = 1e-9 * nBodies * nBodies / avgTime;

#ifdef ASSESS
  checkPerformance(buf, billionsOfOpsPerSecond, salt);
#else
  checkAccuracy(buf, nBodies);
  printf("%d Bodies: average %0.3f Billion Interactions / second\n", nBodies, billionsOfOpsPerSecond);
  salt += 1;
#endif
  /*******************************************************************/

  /*
   * Feel free to modify code below.
   */

  cudaFree(buf);
}
