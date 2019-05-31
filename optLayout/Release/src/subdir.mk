################################################################################
# Automatically-generated file. Do not edit!
################################################################################

# Add inputs and outputs from these tool invocations to the build variables 
O_SRCS += \
../src/optLayout.cu.o 

CU_SRCS += \
../src/design.cu \
../src/model.cu \
../src/optLayout.cu \
../src/saoptimizer.cu 

CU_DEPS += \
./src/design.d \
./src/model.d \
./src/optLayout.d \
./src/saoptimizer.d 

OBJS += \
./src/design.o \
./src/model.o \
./src/optLayout.o \
./src/saoptimizer.o 


# Each subdirectory must supply rules for building sources it contributes
src/%.o: ../src/%.cu
	@echo 'Building file: $<'
	@echo 'Invoking: NVCC Compiler'
	nvcc -O3 -gencode arch=compute_30,code=sm_30 -odir "src" -M -o "$(@:%.o=%.d)" "$<"
	nvcc --compile -O3 -gencode arch=compute_30,code=compute_30 -gencode arch=compute_30,code=sm_30  -x cu -o  "$@" "$<"
	@echo 'Finished building: $<'
	@echo ' '


