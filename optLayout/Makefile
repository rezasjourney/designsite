NVCC   = /usr/local/cuda/bin/nvcc
LINK   = $(NVCC)

# Flags
COMMONFLAGS = 
NVCCFLAGS   = -O3 -gencode arch=compute_30,code=sm_30 -dc
LINKFLAGS   = -O3 -gencode arch=compute_30,code=sm_30 
INCLUDES	=

TARGET    = optLayout
SRC_DIR   = src
OBJ_DIR   = obj

OBJS = $(OBJ_DIR)/design.cu.o $(OBJ_DIR)/saoptimizer.cu.o $(OBJ_DIR)/model.cu.o $(OBJ_DIR)/optLayout.cu.o

$(TARGET) : $(OBJS)
	$(LINK)  $(LINKFLAGS) -o $@ $^

$(OBJ_DIR)/%.cu.o : $(SRC_DIR)/%.cu
	$(NVCC) $(NVCCFLAGS) $(INCLUDES) -c -o $@ $<

clean:
	rm $(TARGET)
	rm $(OBJ_DIR)/*
	
	
