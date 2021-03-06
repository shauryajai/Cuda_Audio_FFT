#include <unistd.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>

#define SIZE_OF_HEADER 44

void audio_convertor()
{
	char* wav_filename = "test.wav";
	char* stereo_raw = "stereo_raw"; 
	char* mono_raw = "mono_raw"; 
	char* pcm_file = "pcm_file.csv"; 

	char* header;
	char* data;
	char* data_avg;
	int read = 0;

	header = (char*) malloc(SIZE_OF_HEADER);
	data = (char*) malloc(sizeof(char)*4);
	data_avg = (char*) malloc(sizeof(char)*2);

	FILE *wav_ptr = fopen(wav_filename,"rb");
	if (wav_ptr == NULL)
	{
		printf("Error opening wav file\n");
		exit(1);
	}

	FILE *stereo_ptr = fopen(stereo_raw,"w");
	if (stereo_ptr == NULL)
	{
		printf("Error opening stereo raw file\n");
		exit(1);
	}

	FILE *mono_ptr = fopen(mono_raw,"w");
	if (mono_ptr == NULL)
	{
		printf("Error opening mono raw file\n");
		exit(1);
	}

	FILE *pcm_ptr = fopen(pcm_file,"w");
	if (pcm_ptr == NULL)
	{
		printf("Error opening pcm file\n");
		exit(1);
	}

	if(!(read = fread(header, SIZE_OF_HEADER, 1, wav_ptr)))
		printf("File is empty..\n");

	while(read = fread(data, 4, 1, wav_ptr))
	{
		fwrite(data,4,1,stereo_ptr);
		data_avg[0] = (data[0] + data[2])/2;
		data_avg[1] = (data[1] + data[3])/2;
		fwrite(data_avg,2,1,mono_ptr);


		int pcm = (int)(data_avg[1]<<8 | data_avg[0]);
		if(pcm >= 32768)
			pcm -= 65536;

		fprintf(pcm_ptr,"%d\n",pcm);
	}

	fclose(stereo_ptr);
	fclose(wav_ptr);
	fclose(mono_ptr);
	fclose(pcm_ptr);

	free(header);
	free(data);
}

int main()
{
	clock_t start, end;
	double execution_time;

	printf("Executing Non-Parallelized Code...\n");

	start=clock();
	audio_convertor();
	end=clock();
	execution_time = ((double)(end-start))/CLOCKS_PER_SEC;
	
	printf("Execution time for Non-Parallelized Code = %f msec\n",execution_time*1000);

	return 0;
}
