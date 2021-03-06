.SUFFIXES:  .cpp .cu .o
CUDA_HOME := /usr/local/cuda
INC	:= -I$(CUDA_HOME)/include -I.
LIB	:= -L$(CUDA_HOME)/lib 
CC	:= nvcc
OBJS	:= cuda_audio.o
DEP	:=  

NVCCFLAGS	:= -lineinfo -arch=sm_53 -g -lcufft -lcufftw

all:	cuda_audio

cuda_audio:	$(OBJS) $(DEP)
	$(CC) $(INC) $(NVCCFLAGS) -o cuda_audio $(OBJS) $(LIB)

.cpp.o:
	$(CC) $(INC) $(NVCCFLAGS) -c $< -o $@ 

.cu.o:
	$(CC) $(INC) $(NVCCFLAGS) -c $< -o $@
	
	gcc audio.c -o audio

clean:
	rm -f *.o cuda_audio


