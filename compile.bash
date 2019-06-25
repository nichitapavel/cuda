#!/bin/bash

/usr/local/cuda/bin/nvcc -arch=compute_35 -o cuda nbody.cu

gcc -fopenmp -o nbody_omp nbody.c -lm

