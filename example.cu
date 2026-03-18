/*
# CUDA Vector Addition Kernel

This example demonstrates a simple parallel vector addition on the GPU.
The kernel adds two vectors element-wise: C = A + B.

## Usage

Compile with:
```bash
nvcc example.cu -o vec_add
```

Run with:
```bash
./vec_add
```

## Key Concepts

- **Blocks**: Groups of threads executed together
- **Threads**: Individual execution units
- **Grid**: All blocks in a kernel launch
- **Shared memory**: Fast on-chip memory accessible by all threads in a block
*/

#include <stdio.h>
#include <cuda_runtime.h>

/*
## The Kernel Function

This kernel runs in parallel on the GPU. Each thread handles one element
of the output vector. The kernel is called with a grid of blocks, where
each block contains multiple threads.

Parameters:
- d_A, d_B: Input vectors on device (GPU)
- d_C: Output vector on device (GPU)
- n: Number of elements
*/
__global__ void vectorAdd(float *d_A, float *d_B, float *d_C, int n) {
  int idx = blockIdx.x * blockDim.x + threadIdx.x;

  if (idx < n) {
    d_C[idx] = d_A[idx] + d_B[idx];
  }
}

/*
## Host Code

The host code (CPU-side) manages memory allocation on the GPU,
copies data to/from the device, and launches the kernel.
*/
int main() {
  int n = 1000000;
  float *h_A, *h_B, *h_C;
  float *d_A, *d_B, *d_C;

  /* Allocate host memory */
  h_A = (float*)malloc(n * sizeof(float));
  h_B = (float*)malloc(n * sizeof(float));
  h_C = (float*)malloc(n * sizeof(float));

  /* Initialize host data */
  for (int i = 0; i < n; i++) {
    h_A[i] = 1.0f;
    h_B[i] = 2.0f;
  }

  /* Allocate device memory */
  cudaMalloc(&d_A, n * sizeof(float));
  cudaMalloc(&d_B, n * sizeof(float));
  cudaMalloc(&d_C, n * sizeof(float));

  /* Copy data to device */
  cudaMemcpy(d_A, h_A, n * sizeof(float), cudaMemcpyHostToDevice);
  cudaMemcpy(d_B, h_B, n * sizeof(float), cudaMemcpyHostToDevice);

  /* Launch kernel with 256 threads per block */
  int blockSize = 256;
  int gridSize = (n + blockSize - 1) / blockSize;
  vectorAdd<<<gridSize, blockSize>>>(d_A, d_B, d_C, n);

  /* Copy result back to host */
  cudaMemcpy(h_C, d_C, n * sizeof(float), cudaMemcpyDeviceToHost);

  /* Verify result */
  printf("First 10 results: ");
  for (int i = 0; i < 10; i++) {
    printf("%.1f ", h_C[i]);
  }
  printf("\n");

  /* Cleanup */
  free(h_A);
  free(h_B);
  free(h_C);
  cudaFree(d_A);
  cudaFree(d_B);
  cudaFree(d_C);

  return 0;
}
