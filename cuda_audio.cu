/**
 * Copyright 1993-2015 NVIDIA Corporation.  All rights reserved.
 *
 * Please refer to the NVIDIA end user license agreement (EULA) associated
 * with this source code for terms and conditions that govern your use of
 * this software. Any use, reproduction, disclosure, or distribution of
 * this software and related documentation outside the terms of the EULA
 * is strictly prohibited.
 *
 */

/**
 * This file converts a stereo .wav file to a mono .raw file
 * The RAW file is then converted to a PCM file.
 * The PCM file is used to plot the time domain plot of the audio data
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// For the CUDA runtime routines (prefixed with "cuda_")
#include <cuda_runtime.h>
#include <cufft.h>
#include <cufftw.h>

#define SIZE_OF_HEADER 44
#define BATCH 1
/**
 * CUDA Kernel Device code
 */

//Kernel to convert stereo to mono audio file
__global__ void stereo_to_mono(const char *A, char *B)
{
	int i = blockIdx.x*blockDim.x+threadIdx.x;

	B[i*2 + 0] = (A[i*4 + 0] + A[i*4 + 2])/2;
	B[i*2 + 1] = (A[i*4 + 1] + A[i*4 + 3])/2;

}


//Kernel to convert stereo audio to PCM (Pulse Code Modulated) data
__global__ void wav_to_pcm(const char *A, int *C, int index)
{
	int i = blockIdx.x*blockDim.x+threadIdx.x;

	int left = (int)(A[i*4 + 1]<<8 | A[i*4 + 0]);
	int right = (int)(A[i*4 + 3]<<8 | A[i*4 + 2]);
	
	C[i] = (left + right)/2;
	if(C[i] >= 32768)
		C[i] -= 65536;

}

/**
 * Host main routine
 */
int
main(void)
{
    printf("Executing Parallelized Code...\n");
    // Error code to check return values for CUDA calls
    cudaError_t err = cudaSuccess;
    cudaEvent_t start, stop;
    cudaEventCreate(&start);
    cudaEventCreate(&stop);
    cufftHandle handle;
    cufftResult status;

    //Input and Output files
    const char* wav_filename = "test.wav";
    const char* pcm_file = "pcm_file.csv";
    const char* fft_file = "fft_file.csv"; 
    const char* mono_raw = "mono_raw"; 

    float milliseconds = 0.0;
    char* header;
    char* data;

    // Allocate the host input vector
    char *h_A = (char *)malloc(1024*1024*4*sizeof(char));
    if (h_A == NULL)
    {
        fprintf(stderr, "Failed to allocate h_A!\n");
        exit(EXIT_FAILURE);
    }
	
    // Write the file contents on the vector and compute the size
    int numElements = 0;


	header = (char*) malloc(SIZE_OF_HEADER);
	data = (char*) malloc(sizeof(char));

	FILE *wav_ptr = fopen(wav_filename,"rb");
	if (wav_ptr == NULL)
	{
		printf("Error opening wav file\n");
		exit(1);
	}	

	if(!fread(header, SIZE_OF_HEADER, 1, wav_ptr))
		printf("File is empty..\n");

	while(fread(data, 1, 1, wav_ptr))
	{
		if(numElements < 1024*1024*4)		
			h_A[numElements] = *data;

		else if(numElements == 1024*1024*4)
			printf("File size is too large\n");

		numElements++;
	}

	printf("Size of input audio file = %d Bytes\n",numElements + SIZE_OF_HEADER);
	fclose(wav_ptr);
	free(header);
	free(data);

    size_t size = numElements * sizeof(char);

    // Allocate the host output vector B
    char *h_B = (char *)malloc(((numElements/2)*sizeof(char)));

    // Verify that allocations succeeded
    if (h_B == NULL)
    {
        fprintf(stderr, "Failed to allocate h_B!\n");
        exit(EXIT_FAILURE);
    }

    // Allocate the host output vector C
    int *h_C = (int *)malloc(((numElements/4)*sizeof(int)));

    // Verify that allocations succeeded
    if (h_C == NULL)
    {
        fprintf(stderr, "Failed to allocate h_C!\n");
        exit(EXIT_FAILURE);
    }

    char* d_A = NULL;
    err = cudaMalloc((void**)&d_A, size); 
    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to allocate device A (error code %s)!\n", 		cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    char* d_B = NULL;
    err = cudaMalloc((void**)&d_B, ((numElements/2)*sizeof(char)));
    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to allocate device B (error code %s)!\n", 		cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    int* d_C = NULL;
    err = cudaMalloc((void**)&d_C, ((numElements/4)*sizeof(int)));
    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to allocate device C (error code %s)!\n", 		cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    err = cudaMemcpy(d_A,h_A,size,cudaMemcpyHostToDevice);

    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to copy vector A from host to device (error code %s)!\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    int blocksPerGrid = ((numElements)/4)/1024;
    int threadsPerBlock = 1024;

    //wav to mono raw conversion
    printf("Converting the audio file\n");

    cudaEventRecord(start);
    stereo_to_mono<<<blocksPerGrid,threadsPerBlock>>>(d_A,d_B);

    
    err = cudaGetLastError();

    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to launch vectorAdd kernel (error code %s)!\n", 	cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

 	cudaThreadSynchronize(); 

    //Converting .wav file to PCM data
    wav_to_pcm<<<blocksPerGrid,threadsPerBlock>>>(d_A,d_C,numElements);    

    err = cudaGetLastError();

    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to launch vectorAdd kernel (error code %s)!\n", 	cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    cudaThreadSynchronize();

    cudaEventRecord(stop);

    err = cudaMemcpy(h_B, d_B, (numElements/2)*sizeof(char), cudaMemcpyDeviceToHost);
    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to copy B from device to host (error code %s)!\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }


    FILE *mono_ptr = fopen(mono_raw,"w");
    if (mono_ptr == NULL)
    {
	 printf("Error opening pcm file\n");
	 exit(1);
     }

     int writeMonoIndex;
     for(writeMonoIndex = 0; writeMonoIndex < (numElements/2); writeMonoIndex++)
      	fprintf(mono_ptr,"%c",*(h_B + writeMonoIndex));

     fclose(mono_ptr);

    err = cudaMemcpy(h_C, d_C, (numElements/4)*sizeof(int), cudaMemcpyDeviceToHost);
    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to copy C from device to host (error code %s)!\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    FILE *pcm_ptr = fopen(pcm_file,"w");
    if (pcm_ptr == NULL)
    {
	 printf("Error opening pcm file\n");
	 exit(1);
     }

     int writeIndex;
     for(writeIndex = 0; writeIndex < (numElements/4); writeIndex++)
      	fprintf(pcm_ptr,"%d\n",*(h_C + writeIndex));

     fclose(pcm_ptr); 
     cudaThreadSynchronize();


    //Fast Fourier Transformation on the PCM data
    printf("Performing FFT on PCM data\n");

    cufftReal *h_Cfft = (cufftReal*)malloc((numElements/4)*sizeof(cufftReal));
    if (h_Cfft == NULL)
    {
	fprintf(stderr, "Failed to allocate h_Cfft!\n");
	exit(EXIT_FAILURE);
    }

    for(int i = 0; i<(numElements/4); i++)
	h_Cfft[i] = (cufftReal)h_C[i];	

    cufftReal *d_Cfft = NULL;
    err = cudaMalloc((void**)&d_Cfft, ((numElements/4)/2+1)*BATCH*sizeof(cufftComplex));
    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to allocate d_Cfft\n");
        exit(EXIT_FAILURE);
    }

	
    cudaMemcpy(d_Cfft, h_Cfft, (numElements/4)*sizeof(cufftReal), cudaMemcpyHostToDevice);

	
    cufftComplex *output_Data = (cufftComplex*)malloc(((numElements/4)/2+1)*BATCH*sizeof(cufftComplex));

    status = cufftPlan1d(&handle, numElements/4, CUFFT_R2C, BATCH);
    if(status != CUFFT_SUCCESS) 
    {
        fprintf(stderr, "cufftPlan1d failed!\n");
        exit(EXIT_FAILURE);
    }

    status = cufftExecR2C(handle, d_Cfft, (cufftComplex*)d_Cfft);
    if(status != CUFFT_SUCCESS) 
    {
        fprintf(stderr, "cufftExecR2C failed!\n");
        exit(EXIT_FAILURE);
    }
	
    err = cudaMemcpy(output_Data, d_Cfft, ((numElements/4)/2+1)*sizeof(cufftComplex), cudaMemcpyDeviceToHost);
    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to copy fft output from host to device (error code %s)!\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
     }

     FILE *fft_ptr = fopen(fft_file,"w");
     if (fft_ptr == NULL)
     {
	 printf("Error opening fft file\n");
	 exit(1);
     }

      int writeFftIndex;
      float absData =0;
      for(writeFftIndex = 1; writeFftIndex < ((numElements/4)/2+1); writeFftIndex++)
      {
		absData = sqrt((((*(output_Data + writeFftIndex)).x)*((*(output_Data + writeFftIndex)).x))+(((*(output_Data + writeFftIndex)).y)*((*(output_Data + writeFftIndex)).y)));


		if(absData > 5000)
      			fprintf(fft_ptr,"%f\n",absData);
      }
      fclose(fft_ptr);

    cudaThreadSynchronize();	

    cudaEventElapsedTime(&milliseconds,start,stop);
    printf("Execution time for Parallelized Code = %f msec\n",milliseconds);
    cufftDestroy(handle);
    err = cudaFree(d_A);

    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to free device vector C (error code %s)!\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    err = cudaFree(d_C);

    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to free device vector C (error code %s)!\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    err = cudaFree(d_Cfft);

    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to free fft vector C (error code %s)!\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    free(h_A);
    free(h_C);
    free(h_Cfft);
    free(output_Data);

    err = cudaDeviceReset();

    if (err != cudaSuccess)
    {
        fprintf(stderr, "Failed to deinitialize the device! error=%s\n", cudaGetErrorString(err));
        exit(EXIT_FAILURE);
    }

    printf("Playing mono channel audio and plotting the audio spectrum.\n");

    return 0;
}

