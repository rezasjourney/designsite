#include "model.cuh"


#define START_TEMP 0.0001
#define END_TEMP 0.6

#define NUM_LINE_STEPS 8
#define FD_DELTA 0.005

extern __device__ int num_iter;


__device__ int getProposal(Design *d, float *curr_layout, float *proposal,bool refine,bool debug);
__global__ void parallelTempering(Design *d, int debug_mode,int iter_count, float start_temp, float end_temp, int num_iter,int num_params,float *params, float *atan_params, float *temperatures, int *temp_ids, float *init_layouts,float *proposals,   float *params_grads, float *opt_layouts,float *evals, int num_previous_layout, float *previous_layout,float *random_seed,int *barrier, float *eval_sum);
__global__ void finiteDiffLayoutGrad(Design *d,int num_dir,float *directions,float *dir_map, int num_params, float *params, float *atan_params,float *params_grads, float *layout,float *layouts, float *layout_grad,float *line_search,int num_previous_layout, float *previous_layout);



//__device__ int getRegionProposal(Design *d, float *curr_layout, float *proposal,bool debug);
//__device__ int getRegionProposalOld(Design *d, float *curr_layout, float *proposal,bool debug);
//__device__ void assignElementRegion(Design *d, float *proposal, float *curr_layout, int elem, int num_text_regions, int num_graphic_regions, int *);
//__global__ void simulatedAnnealing(Design *d, int num_iter,float start_temp, float end_temp,float *init_layouts,float *proposals,  float *params,  float *params_grads, float *eval, int *return_status, float *opt_layouts);




