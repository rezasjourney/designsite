/*
 * Copyright 1993-2012 NVIDIA Corporation.  All rights reserved.
 *
 * Please refer to the NVIDIA end user license agreement (EULA) associated
 * with this source code for terms and conditions that govern your use of
 * this software. Any use, reproduction, disclosure, or distribution of
 * this software and related documentation outside the terms of the EULA
 * is strictly prohibited.
 *
 */

/* Template project which demonstrates the basics on how to setup a project
* example application, doesn't use cutil library.
*/

#include <stdio.h>
#include <string.h>
#include <iostream>
#include <time.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <signal.h>

#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>


#include <cuda.h>
#include <curand.h>

#include "design.cuh"
#include "model.cuh"
#include "saoptimizer.cuh"
#include "settings.cuh"

#include "svd.c"


using namespace std;

#ifdef _WIN32
#define STRCASECMP  _stricmp
#define STRNCASECMP _strnicmp
#else
#define STRCASECMP  strcasecmp
#define STRNCASECMP strncasecmp
#endif

//char *home_dir="./";

char default_param_file[1024];
char param_file[1024];
char param_type[1024];
char param_change_file[1024];
char design_file[1024];
char check_layout_file[1024];
int run_id=1;
bool interactive_run=true;

struct addrinfo *host_info;
char hostname[100];

char *host_name = "127.0.0.1";
	
char layout_file[1024],layout_tmp_file[1024],layout_features_file[1024],layout_features_file2[1024],check_layout_features_file[1024],run_host_file[1024],host_run_file[1024],host_pid_file[1024];;
	
Design *h_d, *d;

float *h_evals;
float *h_opt_layouts;
float *h_params_grads;
float *h_temperatures;
int *h_temp_ids;
float *init_params;
float *h_params;
float *layouts,*evals,*params,*params_grads, *opt_layouts,*proposals, *temperatures;
float *opt_steps_all;
float *opt_steps;
int *temp_ids;


#define IGNORE_VAL -9999

cudaError_t err;

#define CHECKCALL(x)\
		err=x;\
		if (err!=cudaSuccess){\
			printf("ERROR: %s\n", cudaGetErrorString(err));\
			exit(-1);\
		}


void sig_handler (int sig);

//extern "C" void float *loadParametersFromFile(char *filename);
int optimizeLayout(Design *d,int num_kernels,int num_params,int num_outer, int num_inner, float *params,float *temperatures,int *temp_ids,float *layouts,float *params_grads,float *opt_layouts, float *evals,float *proposals,Design *h_d,float *h_temperatures,float *h_evals,int *h_temp_ids,float *h_params_grads,float *h_opt_layouts,bool silent,int debug_mode,float *h_opt_steps);
int nio(Design *d,Design *h_d,int num_kernels,int num_params,int num_outer,int num_inner,float *params,float *temperatures,int *temp_ids,float *layouts,float *params_grads,float *opt_layouts, float *evals,float *proposals,float *h_temperatures,float *h_evals,int *h_temp_ids,float *h_params_grads,float *h_opt_layouts, int debug_mode,int nio_layout_num,char *design_name);
float evaluateLayoutHost(Design *d,Design *h_d,int num_params, float *params, float *params_grad,  float *h_layout,float *h_params,  float *h_params_grad, int num_prev_layout,float *previous_layout, bool debug);
void finiteDiffGrad(Design *d,Design *h_d,int num_params, float *params, float *params_grad,  float *h_layout,float *h_params,  float *h_params_grad,float *h_params_grad_fd);
bool updateCheckLayout(Design *d,Design *h_d, int num_params, int num_kernels,float *params, float *params_grad,float *layouts, float *h_params,char *check_layout_features_file);
bool updateParameterFile(float **h_params, float *params, int num_params);
void sendLayoutToServer(Design *d, float *layout, float energy);
float constrainedGradientDescent(Design *h_d,Design *d,int num_params, float *params,float *atan_params, float *params_grads, float *h_params,  float *h_init_layout,int num_previous_layout, float *previous_layout);
int getConstraints(Design *d, float *layout, float ***C_out,float **b_out,float **loc_out,float ***H_out,  bool debug);
void getSVD(int num_constraints, int num_var, float **C, float ***Q_out, float ***W_out, float **a_out);
int  getConstraintDirections(Design *h_d, float *h_init_layout, float **D_out, bool debug);
void writeOptimizationSteps(int run_id, int num_outer,int num_inner,int curr_run, int num_run,float *opt_steps_all);
void freeMemory();
void cleanup();
void writeHostFiles();
void writeOutFeatures(char *features_file,float opt_eval,float *h_params,float *h_params_grad);
bool loadParameterSample(float **h_params, float *params, int num_params);

int main(int argc, char **argv)
{

	const int kb = 1024;
    const int mb = kb * kb;
	int devCount;
    cudaGetDeviceCount(&devCount);
    cout << "CUDA Devices: "  << endl;
	 cudaError_t cuda_status;

    for(int i = 0; i < devCount; ++i)
    {
      	cudaSetDevice (i);
      	cudaDeviceReset ();
      	
      	if ( cudaSuccess != cuda_status ){
      		printf("Error: cudaDeviceReset fails, %s \n", cudaGetErrorString(cuda_status) );
      	}
    	
        cudaDeviceProp props;
        cudaGetDeviceProperties(&props, i);
        

        
        cout << i << ": " << props.name << ": " << props.major << "." << props.minor << endl;
        cout << "  Global memory:   " << props.totalGlobalMem / mb << "mb" << endl;
        cout << "  Shared memory:   " << props.sharedMemPerBlock / kb << "kb" << endl;
        cout << "  Constant memory: " << props.totalConstMem / kb << "kb" << endl;
        cout << "  Block registers: " << props.regsPerBlock << endl << endl;

        cout << "  Warp size:         " << props.warpSize << endl;
        cout << "  Threads per block: " << props.maxThreadsPerBlock << endl;
        cout << "  Max block dimensions: [ " << props.maxThreadsDim[0] << ", " << props.maxThreadsDim[1]  << ", " << props.maxThreadsDim[2] << " ]" << endl;
        cout << "  Max grid dimensions:  [ " << props.maxGridSize[0] << ", " << props.maxGridSize[1]  << ", " << props.maxGridSize[2] << " ]" << endl;
        cout << "  Multiprocessors:         " << props.multiProcessorCount << endl;
        cout << "  Concurrent kernels:         " << props.concurrentKernels << endl;
        cout << endl;
        
       
     	size_t free_byte ;
        size_t total_byte ;
        cuda_status = cudaMemGetInfo( &free_byte, &total_byte ) ;
        if ( cudaSuccess != cuda_status ){
            printf("Error: cudaMemGetInfo fails, %s \n", cudaGetErrorString(cuda_status) );
            exit(1);
        }
        
        double free_db = (double)free_byte ;
        double total_db = (double)total_byte ;
        double used_db = total_db - free_db ;
        printf("GPU memory usage: used = %f, free = %f MB, total = %f MB\n",
            used_db/1024.0/1024.0, free_db/1024.0/1024.0, total_db/1024.0/1024.0);
        
        
    }
	    
	    
	 signal(SIGTERM, sig_handler);
	 //signal(SIGINT, sig_handler);
	// cudaSetDeviceFlags(cudaDeviceScheduleBlockingSync);

	//CHECKCALL(cudaSetDevice(0));
	//cout << " post list" << endl;

    //optimization parameters
	int num_outer=1000000;
	int num_inner=25;
    int num_kernels=128;
    int num_run=200;
    char *design_name="artshow";
    bool nio_mode=false;
    int nio_layout_num=-1;
    bool interactive_mode=false;
    sprintf(param_type,"near");
    
    int debug_mode=0;


    int num_params=3*NUM_FEATURES;


    
    for (int i=1;i < argc;i++)
    {
    	if (strcmp(argv[i],"-o")==0)
    		num_outer=atoi(argv[i+1]);
    	else if (strcmp(argv[i],"-e")==0)
    		num_inner=atoi(argv[i+1]);
    	else if (strcmp(argv[i],"-i")==0)
    		interactive_mode=true;
    	else if (strcmp(argv[i],"-b")==0)
    		debug_mode=atoi(argv[i+1]);    		
    	else if (strcmp(argv[i],"-k")==0)
    		num_kernels=atoi(argv[i+1]);
    	else if (strcmp(argv[i],"-r")==0)
    		run_id=atoi(argv[i+1]);
    	else if (strcmp(argv[i],"-d")==0)
    		design_name=argv[i+1];
    	else if (strcmp(argv[i],"-t")==0)
    		sprintf(param_type,argv[i+1]);
    	else if (strcmp(argv[i],"-n")==0)
    		nio_mode=true;
    	else if (strcmp(argv[i],"-l")==0)
    	{
    		nio_layout_num=atoi(argv[i+1]);
    	}
    	else
    	{
    		printf("unrecognized parameter %s\n",argv[i]);
    		//i--;
    	}
    }
    
    	

    if (interactive_mode)
    {
    	num_outer=1000000;
    	num_inner=25;
    	nio_mode=false;
    	num_run=1;
    }

	if ((nio_mode) || (strcmp(param_type,"nio")==0))
	{
    	num_outer=1000;
    	num_inner=25;
    	interactive_mode=false;
    	nio_mode=true;
	
		sprintf(param_type,"nio_init");
		
	}

    printf("Starting optimization with run ID %d\nDesign %s\nKernels:%d, outer iterations %d, inner iterations %d, debug mode %i\nNIO %i, layout num %d\n\n", run_id, design_name, num_kernels, num_outer, num_inner,debug_mode, nio_mode, nio_layout_num);

    char init_design_file[1024];
    char init_fname[100];
    sprintf(init_design_file,"%s/data/default/%s_150_100_default.data",home_dir,design_name);
    sprintf(init_fname,"%s/data/default/%s_150_100_default.data",home_dir,design_name);

	sprintf(check_layout_file,"%sdata/runs/r%d_check_layout.data",home_dir,run_id);
	sprintf(design_file,"%sdata/runs/r%d_design.data",home_dir,run_id);

    sprintf(param_file,"%sdata/%s_parameters.data",home_dir,param_type);
    sprintf(default_param_file,"%sdata/default_parameters.data",home_dir);
    sprintf(param_change_file,"%sdata/runs/r%d_parameter_change.data",home_dir,run_id);


	struct addrinfo hints;
	memset(&hints, 0, sizeof hints);
	hints.ai_family = AF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;
	

	getaddrinfo(host_name, "8080", &hints, &host_info);

	gethostname(hostname,100);
	
	
	sprintf(layout_file, "%sdata/runs/r%d_opt_layout.data",home_dir,run_id);
	sprintf(layout_tmp_file, "%sdata/runs/r%d_opt_layout.data.tmp",home_dir,run_id);
	sprintf(layout_features_file, "%sdata/runs/r%d_opt_layout_features.txt",home_dir,run_id);
	sprintf(layout_features_file2, "%sdata/runs/r%d_opt_layout_features2.txt",home_dir,run_id);
	sprintf(check_layout_features_file, "%sdata/runs/r%d_user_layout_features.txt",home_dir,run_id);
	sprintf(run_host_file, "%sdata/runs/r%d_host.data",home_dir,run_id);
	sprintf(host_run_file, "%sdata/runs/%s_runid.data",home_dir,hostname);
	sprintf(host_pid_file, "%sdata/runs/pid_%s_%d.data",home_dir,hostname,run_id);
	
	writeHostFiles();




    if (nio_layout_num>=0)
    	sprintf(init_design_file,"%s/data/nio/%s_%d.data",home_dir,design_name,nio_layout_num);
    else
    {
    	strcpy(init_design_file,design_file);
    	strcpy(init_fname,design_file);
    }


    h_d= loadDesignFromFile(init_design_file,interactive_mode);
    if (!h_d)
    {
    	cout << "Problem loading XML file " << init_design_file << endl;
    	return 0;
    }
    
    /*
    Design *h_init_d = loadDesignFromFile(init_fname);
	if (!h_init_d)
	{
		cout << "Problem loading XML file " << init_fname << endl;
		return 0;
	}

	memcpy(h_d->init_layout, h_init_d->layout, h_d->layout_size*sizeof(float));
	freeDesign(h_init_d);
	*/


	



	//cout << " loading parameters from " << param_file << endl;
    init_params= loadParametersFromFile(default_param_file,param_file,num_params);
    h_params=(float *)malloc(num_params*sizeof(float));
	//cout << " num_params "  << num_params <<endl;

    //allocate host memory
    h_evals=(float *)malloc(num_kernels*sizeof(float));
    h_opt_layouts= (float *)malloc(num_kernels*h_d->layout_size*sizeof(float));
    h_params_grads= (float *)malloc(num_kernels*num_params*sizeof(float));
    h_temperatures=(float *)malloc(num_kernels*sizeof(float));
    h_temp_ids=(int *)malloc(num_kernels*sizeof(int));

	//cout << " allocate device memory "<< h_d->layout_size <<endl;
 

    CHECKCALL(cudaMalloc(&layouts,num_kernels*h_d->layout_size*sizeof(float)));
    CHECKCALL(cudaMalloc(&opt_layouts,num_kernels*h_d->layout_size*sizeof(float)));
    CHECKCALL(cudaMalloc(&proposals,num_kernels*h_d->layout_size*sizeof(float)));
    CHECKCALL(cudaMalloc(&params,num_params*sizeof(float)));
    CHECKCALL(cudaMalloc(&params_grads,num_kernels*num_params*sizeof(float)));
    CHECKCALL(cudaMalloc(&evals,num_kernels*sizeof(float)));
    CHECKCALL(cudaMalloc(&temperatures,num_kernels*sizeof(float)));
    CHECKCALL(cudaMalloc(&temp_ids,num_kernels*sizeof(int)));
    CHECKCALL(cudaMalloc(&d, sizeof(Design)));
    
    //cout << " copyDesignToDevice "  << endl;
    copyDesignToDevice(d,h_d);

    CHECKCALL(cudaMemcpy(params, init_params,num_params*sizeof(float), cudaMemcpyHostToDevice));

    for (int i=0;i< num_kernels;i++)
    {
    	CHECKCALL(cudaMemcpy(&layouts[i*h_d->layout_size], h_d->init_layout,h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));
    	CHECKCALL(cudaMemcpy(&opt_layouts[i*h_d->layout_size], h_d->init_layout,h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));
    	CHECKCALL(cudaMemcpy(&proposals[i*h_d->layout_size], h_d->init_layout,h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));
    }


    if (nio_mode)
    {
    	nio(d,h_d, num_kernels, num_params,num_outer,num_inner,params,temperatures,temp_ids,layouts,params_grads,opt_layouts, evals,proposals,h_temperatures,h_evals,h_temp_ids,h_params_grads,h_opt_layouts, debug_mode,nio_layout_num,design_name);
    	CHECKCALL(cudaMemcpy(h_params, params,num_params*sizeof(float), cudaMemcpyDeviceToHost));
    	return 0;
    	
    }


    int best_id=0;
    float eval_run[1000];

    clock_t start=clock();
    float eval_mean=0;
    
	opt_steps_all=(float *)malloc(num_run*num_outer*sizeof(float));
	opt_steps=(float *)malloc(num_outer*sizeof(float));
	
	
    for (int r=0;r< num_run;r++)
    {
    	

        for (int i=0;i< num_kernels;i++)
        {
        	CHECKCALL(cudaMemcpy(&layouts[i*h_d->layout_size], h_d->init_layout,h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));
        	CHECKCALL(cudaMemcpy(&opt_layouts[i*h_d->layout_size], h_d->init_layout,h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));
        	CHECKCALL(cudaMemcpy(&proposals[i*h_d->layout_size], h_d->init_layout,h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));
        }

    	best_id=optimizeLayout(d, num_kernels, num_params,num_outer,num_inner,params,temperatures,temp_ids,layouts,params_grads,opt_layouts, evals,proposals,h_d,h_temperatures,h_evals,h_temp_ids,h_params_grads,h_opt_layouts,true,debug_mode,opt_steps); //(num_run>1)and(r>0)
    	eval_run[r]=h_evals[best_id];
    	eval_mean+=eval_run[r];
    	
    	memcpy(&(opt_steps_all[r*num_outer]),opt_steps,num_outer*sizeof(float));
    	
    	printf("run %i of %i. eval %.3f. mean eval %.3f, mean inner time %f\n",r,num_run,eval_run[r],eval_mean/(r+1),1000*(((double)(clock() - start)/(r+1)) / CLOCKS_PER_SEC)/num_outer);
    	
    	writeOptimizationSteps(run_id,num_outer,num_inner,r+1,num_run,opt_steps_all);
    }
    CHECKCALL(cudaMemcpy(h_params, params,num_params*sizeof(float), cudaMemcpyDeviceToHost));



    clock_t stop=clock();
    float t1=((double)(stop - start) / CLOCKS_PER_SEC);

	eval_mean=eval_mean/float(num_run);

	float eval_var=0;
	for (int r=0;r< num_run;r++)
		eval_var+=(eval_run[r]-eval_mean)*(eval_run[r]-eval_mean);
	eval_var=eval_var/float(num_run);

	printf("Mean time for %i runs: %.3f. Mean eval %f, var %f \n",num_run,t1/num_run,eval_mean,eval_var);


    //float opt_eval=h_evals[best_id];
    //float *output_layout;
    //output_layout=&h_opt_layouts[best_id*h_d->layout_size];


	//float *opt_params_grad=&h_params_grads[best_id*num_params];

	/*
	float h_eval=evaluateLayoutHost(d,h_d, num_params,params, params_grads, output_layout,h_params, h_params_grads,true);

	//printf("\nLayout Energy: \n");
	for (int i=0;i<NUM_FEATURES;i++)
		printf("%i\t%5.1f \t %3.2f\t %3.2f \t  nl: %3.2f\t %3.2f \t %s \n", i,h_params[i],h_params_grads[i],h_params[i]*h_params_grads[i],h_params[i+NUM_FEATURES],h_params_grads[i+NUM_FEATURES],feat_names[i]);
	cout << "Design " << h_d->name << " eval: " << opt_eval<<" h_eval: " << h_eval<<endl;

	h_eval=evaluateLayoutHost(d,h_d, num_params,params, params_grads, h_d->layout,h_params, h_params_grads,true);
	printf("\nOriginal Layout Layout Energy: \n");
	for (int i=0;i<NUM_FEATURES;i++)
		printf("%i\t%5.1f \t %.2f\t %4.2f\t  nl: %4.2f\t %4.2f \t %s \n", i,h_params[i],h_params_grads[i],h_params[i]*h_params_grads[i],h_params[i+NUM_FEATURES],h_params_grads[i+NUM_FEATURES],feat_names[i]);
	cout << "Original Layout h_eval: " << h_eval<<endl;
	

	//render output layout
	char layout_file[ 1024 ];
	sprintf(layout_file,"%s/data/opt/%s_%d.data",home_dir,design_name,nio_layout_num);
	writeLayoutToFile(h_d, output_layout, layout_file);

	*/

	//char commandline[ 1024 ];
	//snprintf( commandline, sizeof (commandline), "python /Users/donovan/Documents/work/aptana/GraphicDesign/src/renderDesign.py %s", layout_file);
	//printf(commandline);
	//system( commandline );




    //cleanup


    printf("Finished Optimization");

    return 0;

}


void freeMemory()
{
	
	CHECKCALL(cudaGetLastError());
	CHECKCALL(cudaDeviceSynchronize());	
	
	printf("Freeing device memory\n");
	
	freeDeviceDesign(d);
	CHECKCALL(cudaFree(d));
	CHECKCALL(cudaFree(evals));
	CHECKCALL(cudaFree(layouts));
	CHECKCALL(cudaFree(params));
	CHECKCALL(cudaFree(params_grads));
	CHECKCALL(cudaFree(opt_layouts));
	CHECKCALL(cudaFree(temperatures));
	CHECKCALL(cudaFree(temp_ids));

	printf("Freeing host memory\n");

	freeDesign(h_d);
    free(h_evals);
    free(h_params_grads);
    free(h_opt_layouts);
    free(h_temperatures);
    free(h_temp_ids);
    free(h_params);
    free(init_params);
    free(opt_steps_all);
    free(opt_steps);
}




void writeOptimizationSteps(int run_id, int num_outer,int num_inner,int curr_run, int num_run,float *opt_steps_all)
{
	char output_file[1024];
    sprintf(output_file,"%s/data/steps-r%i_%i_%i_%i.data",home_dir,run_id,num_outer,num_inner,num_run);
    
	FILE *fp=fopen(output_file,"w");

	if (fp>0)
	{		
	    
	    for (int i=0;i<num_outer;i++)
	    {
	    	float opt_sum=0;
	    	for (int j=0;j<curr_run;j++)
	    		opt_sum+=opt_steps_all[j*num_outer+i];
			
			fprintf(fp,"%.3f\n",opt_sum/curr_run);	    
	    }
		fclose(fp);
	}
	else
		printf("Error opening file %s\n",output_file);
	
}



void setParams(int num_params,float *h_params,float *h_params_temp,float *h_nio_gradient,float lambda)
{
	for (int j=0;j<num_params;j++)
	{
		float nio_grad=lambda*(h_nio_gradient[j]);
		if ( (j>=NUM_FEATURES*2))//(j==NUM_FEATURES+TEXT_SIZE_FEAT) or
		{
			h_params_temp[j]=h_params[j]-min(max(nio_grad,-1.0),1.0);
		}
		else
		{
			float log_param=log(h_params[j]);
			h_params_temp[j]=exp(log_param-min(max(nio_grad,-1.0),1.0));
		}

	}
}



void writeOutFeatures(char *features_file,float opt_eval,float *h_params,float *h_params_grad)
{

	FILE *fp=fopen(features_file,"w");

	if (fp>0)
	{
		
		float test_eval=-500;
		for (int k=0;k<NUM_FEATURES;k++)
			test_eval+=h_params[k]*h_params_grad[k];
		
		fprintf(fp,"Layout Energy: %f %f\n",opt_eval,test_eval*0.25);
		for (int k=0;k<NUM_FEATURES;k++)
			fprintf(fp,"%i\t%5.1f \t %4.2f\t %4.1f \tnl:%3.1f %s \n", k,h_params[k],h_params_grad[k],h_params[k]*h_params_grad[k],h_params[k+NUM_FEATURES],feat_names[k]);

		fprintf(fp,"Eval: %f %f\n",opt_eval,test_eval*0.25);
		
		if (abs(test_eval*0.25-opt_eval)>0.1)
			printf("Error. Opt eval %.3f doesnt match the double check %.3f\n",opt_eval,test_eval);

		fclose(fp);	

	}
}

int nio(Design *d,Design *h_d,int num_kernels,int num_params,int num_outer,int num_inner,float *params,float *temperatures,int *temp_ids,float *layouts,float *params_grads,float *opt_layouts, float *evals,float *proposals,float *h_temperatures,float *h_evals,int *h_temp_ids,float *h_params_grads,float *h_opt_layouts, int debug_mode,int nio_layout_num,char *design_name)
{
	printf("Starting NIO\n");

	float f_init;
	//float *f_init=(float *)malloc(sizeof(float));

	float *h_param_grad_init= (float *)malloc(num_params*sizeof(float));
	float *h_param_grad_temp= (float *)malloc(num_params*sizeof(float));
	float *h_params_grad_opt= (float *)malloc(num_params*sizeof(float));
	float *h_param_grad_fd= (float *)malloc(num_params*sizeof(float));
	float *h_params= (float *)malloc(num_params*sizeof(float));
	float *h_params_temp= (float *)malloc(num_params*sizeof(float));
	CHECKCALL(cudaMemcpy(h_params, params,  num_params*sizeof(float), cudaMemcpyDeviceToHost));

	float *h_nio_gradient= (float *)malloc(num_params*sizeof(float));


    for (int j=0;j< num_kernels;j++)
    	CHECKCALL(cudaMemcpy(&layouts[j*h_d->layout_size], h_d->init_layout,h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));

    int best_id=0;

    int nio_iter=200;

    float *h_layout_list= (float *)malloc((nio_iter+1)*h_d->layout_size*sizeof(float));
    memcpy(&h_layout_list[0],h_d->layout,h_d->layout_size*sizeof(float));


	float *opt_steps=(float *)malloc(num_outer*sizeof(float));



	 char nio_param_file[1024];
  	 sprintf(nio_param_file,"%s/data/nio/%s_%d_params.data",home_dir,design_name,nio_layout_num);
	 char nio_param_file2[1024];
  	 sprintf(nio_param_file2,"%s/data/nio_r%d.data",home_dir,run_id);

	int run_outer=200;

	//main NIO loop
	for (int i=0;i <nio_iter;i++)
	{

	    clock_t start=clock();
	    clock_t stop;
	    
	   //printf("starting finite diff\n");
	   // finiteDiffGrad(d,h_d, num_params,params, params_grads, h_d->layout,h_params, h_param_grad_init,h_param_grad_fd);
		//printf("ending finite diff\n");

	 	f_init=evaluateLayoutHost(d,h_d, num_params,params, params_grads, h_d->layout,h_params, h_param_grad_init,0,0, false);
	 	
		

	    //float *set_layout= &h_opt_layouts[best_id*h_d->layout_size];
	    float *set_layout=h_d->init_layout;

	    /*
	    if (i%5!=0)
	    {
	    	//run_outer=num_outer/4;

			float f_check_min=99999;
			for (int j=0;j<=i;j++)
			{

				float f_check=evaluateLayoutHost(d,h_d, num_params,params, params_grads, &h_layout_list[j*h_d->layout_size],h_params, h_param_grad_temp,false);

				if (f_check < f_check_min)
				{
					f_check_min=f_check;
					set_layout=&h_layout_list[j*h_d->layout_size];
				}
				//printf("fcheck %i %.3f\n",j,f_check);
			}
			// printf("f_check_min: %.3f f_init %.3f", f_check_min,f_init);
	    }
	    */




	    for (int k=0;k< num_kernels;k++)
			CHECKCALL(cudaMemcpy(&layouts[k*h_d->layout_size], set_layout,h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));


		best_id= optimizeLayout(d, num_kernels, num_params,run_outer,num_inner,params,temperatures,temp_ids,layouts,params_grads,opt_layouts, evals,proposals,h_d,h_temperatures,h_evals,h_temp_ids,h_params_grads,h_opt_layouts,true,debug_mode,opt_steps);

		stop=clock();
		float t1=((double)(stop - start) / CLOCKS_PER_SEC);

		float f_opt=h_evals[best_id];
		float *h_layout_opt=&h_opt_layouts[best_id*h_d->layout_size];
		

		memcpy(&h_layout_list[(i+1)*h_d->layout_size],h_layout_opt,h_d->layout_size*sizeof(float));
		
		float f_check=evaluateLayoutHost(d,h_d, num_params,params, params_grads, h_layout_opt,h_params, h_params_grad_opt,0,0, false);
		if (f_check!=f_opt)
			printf("ERROR. fcheck %.3f doesnt match fopt %.3f\n",f_check,f_opt);
		


		float lambda=0.25;
		
		printf("writing out init\n");
		writeOutFeatures(check_layout_features_file,f_init,h_params,h_param_grad_init);
		printf("writing out opt\n");
		writeOutFeatures(layout_features_file,f_opt,h_params,h_params_grad_opt);

		sendLayoutToServer(h_d, h_layout_opt,f_opt);
		
		
		if (f_opt<f_init)
		//if (true)
		{
		

		

			float weight_sum=0;
			for (int j=0;j<num_params;j++)
				weight_sum+=h_params[j];


			for (int j=0;j<num_params;j++)
			{
				h_nio_gradient[j]=h_param_grad_init[j]-h_params_grad_opt[j];


				if (j>=NUM_FEATURES)
				{
					h_nio_gradient[j]=0.1*(h_nio_gradient[j]);
					
					//if the feature weight is 0, the  has to be 0.
					if (h_params[j%NUM_FEATURES]==0)
						h_nio_gradient[j]=0;
				}
				
			}

			bool searching=true;
			while (searching)
			{

				setParams(num_params,h_params,h_params_temp,h_nio_gradient,lambda);



				float eval1Orig=evaluateLayoutHost(d,h_d, num_params,params, params_grads, h_d->layout,h_params_temp, h_param_grad_temp,0,0,false);
				float eval1Opt=evaluateLayoutHost(d,h_d, num_params,params, params_grads, h_layout_opt,h_params_temp, h_param_grad_temp,0,0,false);


				setParams(num_params,h_params,h_params_temp,h_nio_gradient,0.5*lambda);


				float eval2Orig=evaluateLayoutHost(d,h_d, num_params,params, params_grads, h_d->layout,h_params_temp, h_param_grad_temp,0,0,false);
				float eval2Opt=evaluateLayoutHost(d,h_d, num_params,params, params_grads, h_layout_opt,h_params_temp, h_param_grad_temp,0,0,false);

                float diff1=eval1Orig-eval1Opt;// + (paramReg*paramDiff1).sum()
                float diff2=eval2Orig-eval2Opt;// + (paramReg*paramDiff2).sum()

                //printf("lsearch %1.3f 1: %3.1f - %3.1f = %3.3f, 2: %3.1f - %3.1f = %3.3f\n",lambda, eval1Orig, eval1Opt, eval1Orig-eval1Opt, eval2Orig, eval2Opt, eval2Orig-eval2Opt);


                if ((diff1>diff2) and (diff2>0) and (lambda>0.01))
					lambda=lambda*0.5;
				else
					searching=false;
			}

			/*
			printf("NIO Gradient Check Breakdown: \n");
			for (int j=0;j<NUM_FEATURES;j++)
			{
				if (!strstr(feat_names[j], "Element"))
					printf("%2.0i: %5.1f \t (%5.2f / %5.2f) \t nl1: %5.2f\t (%5.2f / %5.2f) \t %s \n", j,h_params[j],h_param_grad_init[j],h_param_grad_fd[j],h_params[j+1*NUM_FEATURES],h_param_grad_init[j+1*NUM_FEATURES],h_param_grad_fd[j+1*NUM_FEATURES],feat_names[j]);
			}
			*/

			//h_params[j+NUM_FEATURES],h_param_grad_init[j+NUM_FEATURES],h_params_grad_opt[j+NUM_FEATURES],h_nio_gradient[j+NUM_FEATURES],
			printf("NIO Layout Energy: \n");
			for (int j=0;j<NUM_FEATURES;j++)
			{
				if (!strstr(feat_names[j], "Element"))
					printf("%2.0i: %5.1f \t (%3.2f / %3.2f) %3.2f \t nl1: %3.2f\t (%3.2f / %3.2f)  %3.2f \t %s \n", j,h_params[j],h_param_grad_init[j],h_params_grad_opt[j],h_nio_gradient[j],h_params[j+1*NUM_FEATURES],h_param_grad_init[j+1*NUM_FEATURES],h_params_grad_opt[j+1*NUM_FEATURES],h_nio_gradient[j+1*NUM_FEATURES],feat_names[j]);

			}

			setParams(num_params,h_params,h_params,h_nio_gradient,lambda);
			//for (int j=0;j<num_params;j++)
			//{
			//	float log_param=log(h_params[j]);
			//	float nio_grad=lambda*(h_nio_gradient[j]);
			//	h_params[j]=exp(log_param-min(max(nio_grad,-1.0),1.0));
			//}

			saveParametersToFile(nio_param_file,h_params,num_params);
			saveParametersToFile(nio_param_file2,h_params,num_params);

			CHECKCALL(cudaMemcpy(params, h_params,num_params*sizeof(float), cudaMemcpyHostToDevice));

		}
		else
			run_outer=min(run_outer+20,1000);

		printf("NIO Iteration %i g %.4f, f_init %.2f, f_opt %.2f, lambda %.2f, time %.2f\n",i,f_init-f_opt,f_init,f_opt,lambda,t1);

	}

	free(h_layout_list);
	free(h_nio_gradient);
	free(h_param_grad_init);
	free(h_param_grad_temp);
	free(h_param_grad_fd);
	free(h_params);


	return 0;

}





void sendLayoutToServer(Design *d, float *layout, float energy)
{
	
	char layout_str[1000];
	memset(layout_str,0,1000);
	printLayout(layout_str,d,layout,energy);
	
	

	int sockfd = socket(host_info->ai_family, host_info->ai_socktype, host_info->ai_protocol);
	
	if (sockfd<0)
	{
		printf("can't create socket\n");
		return;
	}
	
	if (connect(sockfd, host_info->ai_addr, host_info->ai_addrlen)<0)
	{
		printf("can't create connection\n");
		return;
	}
	
	
	char send_string[1000];
	sprintf(send_string, "%d\n%s", run_id,layout_str);
	
	char sendline[1500];
	sprintf(sendline, 
	     "GET /design/computeSendLayout HTTP/1.0\r\n" 
	     "Host: %s\r\n"    
	     "Content-type: application/x-www-form-urlencoded\r\n"
	     "Content-length: %d\r\n\r\n"
	     "%s\r\n", host_name,(unsigned int)strlen(send_string), send_string);
	     
	
	int max_line=5000;
	char recvline[max_line];
	memset(recvline,0,max_line);
	size_t n;
	
	if (write(sockfd, sendline, strlen(sendline))>= 0) 
	{
	    while ((n = read(sockfd, recvline, max_line)) > 0) 
	    {
	        recvline[n] = '\0';
	    }          
	}
	
	//todo: check the re
	
	close(sockfd);
	
}

bool updateCheckLayout(Design *d,Design *h_d, int num_params, int num_kernels,float *params, float *params_grad,float *layouts, float *h_params, char *check_layout_features_file)
{


	bool using_files=false;
	bool is_new_layout=false;
	static clock_t check_layout_access_time;
	static struct stat checkLayoutStat;
	
	char layout[1000];
	int max_line=5000;
	char recvline[max_line];
	char *layout_ptr;
		
	if (using_files)
	{

		stat(check_layout_file,&checkLayoutStat);
		check_layout_access_time=0;
		
		static clock_t first_access_time=checkLayoutStat.st_mtime;
		if (first_access_time>=checkLayoutStat.st_mtime)
			return false;
			
		is_new_layout=(checkLayoutStat.st_mtime-check_layout_access_time!=0);
		
	}
	else
	{

		int sockfd = socket(host_info->ai_family, host_info->ai_socktype, host_info->ai_protocol);
		
		if (sockfd<0)
		{
			printf("can't create socket\n");
			return false;
		}
		
		if (connect(sockfd, host_info->ai_addr, host_info->ai_addrlen)<0)
		{
			printf("can't create connection\n");
			return false;
		}
		
	
		
		char run_string[10];
		sprintf(run_string, "%d", run_id);
		
		char sendline[500];
		sprintf(sendline, 
		     "GET /design/computeGetLayout HTTP/1.0\r\n" 
		     "Host: %s\r\n"    
		     "Content-type: application/x-www-form-urlencoded\r\n"
		     "Content-length: %d\r\n\r\n"
		     "%s\r\n", host_name,(unsigned int)strlen(run_string), run_string);
		     
		

		memset(recvline,0,max_line);
		size_t n;
		
		if (write(sockfd, sendline, strlen(sendline))>= 0) 
		{
		    while ((n = read(sockfd, recvline, max_line)) > 0) 
		    {
		        recvline[n] = '\0';
		    }          
		}
		close(sockfd);
		//printf("received: %s\n", recvline);
		
		int ret_code=0;
		float http_version;
		int idx=sscanf(recvline, "HTTP/%f %d OK",&http_version,&ret_code);
		
		layout_ptr=recvline;
		if (ret_code==200)
		{

			//printf("received: %s\n", layout_ptr);
			layout_ptr=strstr(layout_ptr, "Content-Type:");
			
			if (layout_ptr==0)
			{
				printf("Err: %s\n", recvline);
				return false;
			}
			layout_ptr=strstr(layout_ptr, "\n");
			
			if (layout_ptr==0)
			{
				printf("Err: %s\n", recvline);
				return false;
			}
			layout_ptr+=3;			
		}
				
				
				
		int layout_number;

		int ret=sscanf(layout_ptr,"%d\ndesign%s",&layout_number,layout);
		//printf("layout number is %d, ret %d\n",layout_number,ret);
		
		if (ret!=2)
		{
			//printf("bad line %i%s\n",recvline);
			return false;
		}
		else
		{
			is_new_layout=layout_number>h_d->layout_counter;
			//is_new_layout=false;
		}
		
		
	}
	

	if (is_new_layout)
	{
		printf("Check layout has changed, loading...\n");

		int num_regions, layout_counter;
		
		float * check_layout;
		/*
		if (using_files)
		{
			printf("Check layout file has changed, loading new file\n");
			
			check_layout=readLayoutFromFile(h_d,check_layout_file,&num_regions,&layout_counter);
	
			if (!check_layout)
			{
				printf("problem loading layout file. try next iteration\n");
				return false;
			}
			check_layout_access_time=checkLayoutStat.st_mtime;
		}
		else
		{*/
		
		//printf("parsing layout\n");
		check_layout=parseLayout(h_d,layout_ptr,&num_regions,&layout_counter);

		if (!check_layout)
		{
			printf("problem getting new layout from server. try next iteration\n");
			return false;
		}
			
			
			
			


	
		//float *directions;
	 	//int num_dir=getConstraintDirections(h_d, check_layout, &directions,false);
		/*
		
		//already has a layout, modify the parameters
		if (h_d->check_layout_exists)
		{
			
			//printf("Modifying parameters\n");
			


			/*
			int large_change=0;
			for (int i=0;i< ne;i++)
			{
				if ((abs(h_d->check_layout[i*NUM_VAR]-check_layout[i*NUM_VAR])>(100.0/h_d->width)) or (abs(h_d->check_layout[i*NUM_VAR+1]-check_layout[i*NUM_VAR+1])>(100.0/h_d->height)))
					large_change++;
			}
			
			if ((large_change==1))
			{
				
				
				float *h_layouts = (float *)malloc((h_d->layout_size)*num_kernels*sizeof(float));
				CHECKCALL(cudaMemcpy(h_layouts, layouts,num_kernels*(h_d->layout_size)*sizeof(float), cudaMemcpyDeviceToHost));
				
				for (int k=0;k<num_kernels;k++)
				{
					float *old_layout=&(h_layouts[k*((h_d)->layout_size)]);
					for(int i=0;i<ne;i++)
					{
						if (h_d->type[i]==1)		
							old_layout[i*NUM_VAR+2]=((MIN_TEXT_SIZE*max(h_d->width,h_d->height)*h_d->num_lines[i])/10.0)/h_d->height + (5.0/h_d->height);
						else
							old_layout[i*NUM_VAR+2]=MIN_GRAPHIC_SIZE+(5.0/h_d->height);
					}
				}
				
				CHECKCALL(cudaMemcpy(layouts,h_layouts,num_kernels*(h_d->layout_size)*sizeof(float), cudaMemcpyHostToDevice));
				free(h_layouts);
			}
	
			
				
			float *h_layouts = (float *)malloc((h_d->layout_size)*num_kernels*sizeof(float));
			CHECKCALL(cudaMemcpy(h_layouts, layouts,num_kernels*(h_d->layout_size)*sizeof(float), cudaMemcpyDeviceToHost));
			
			memcpy(h_layouts, check_layout, h_d->layout_size*sizeof(float));
			
			CHECKCALL(cudaMemcpy(layouts,h_layouts,num_kernels*(h_d->layout_size)*sizeof(float), cudaMemcpyHostToDevice));
			free(h_layouts);		
			
			
		}
		*/
	
		printf("align lines %i\n",h_d->num_constraints);
		if (h_d->num_constraints>0)
		{
			for (int i =0;i<4;i++)
				printf ("%i ",h_d->constraints[i]);
			printf("\n");
		}


		printf("Finished loading new layout %i. num regions %i\n",layout_counter,num_regions);
			
		int ne=h_d->num_elements;
	
		for(int i=0;i< ne;i++)
			h_d->check_layout_distances[i]=-1;

		memcpy(h_d->check_layout, check_layout, h_d->layout_size*sizeof(float));
		h_d->check_layout_exists=true;
		h_d->layout_counter=layout_counter;

		h_d->region_proposals=true;	
		h_d->fixed_regions=false;
		
		

		float *h_layouts = (float *)malloc((h_d->layout_size)*num_kernels*sizeof(float));
		CHECKCALL(cudaMemcpy(h_layouts, layouts,num_kernels*(h_d->layout_size)*sizeof(float), cudaMemcpyDeviceToHost));
		
		for (int k=0;k<num_kernels;k++)
		{
			float *old_layout=&(h_layouts[k*((h_d)->layout_size)]);
			
			
			for (int i=0;i<ne;i++)
			{
				int update=2;
				if (strcmp(param_type,"autoupdate")!=0)
					update=10;
				
				if ((check_layout[i*NUM_VAR+4]>FIX_LAYOUT_THRESH) || ((k%update==1)) || (num_regions==-2))
					for (int j=0;j<NUM_VAR;j++)
						old_layout[i*NUM_VAR+j]=check_layout[i*NUM_VAR+j];
						
				old_layout[i*NUM_VAR+4]=check_layout[i*NUM_VAR+4];
				
			}				
		}
		CHECKCALL(cudaMemcpy(layouts,h_layouts,num_kernels*(h_d->layout_size)*sizeof(float), cudaMemcpyHostToDevice));
		free(h_layouts);



		float *h_params_grad_temp=(float *)malloc(num_params*sizeof(float));
		float check_layout_eval=evaluateLayoutHost(d,h_d, num_params,params, params_grad, check_layout,h_params, h_params_grad_temp,0,0,false);
		
		h_d->refine=true;
		if ((h_params_grad_temp[TEXT_OVERLAP_FEAT]>0.01) || (h_params_grad_temp[GRAPHIC_OVERLAP_FEAT]>0.01)  || (h_params_grad_temp[GRAPHIC_TEXT_OVERLAP_FEAT]>0.01) )
			h_d->refine=false;
		
			
		freeDeviceDesign(d);
		copyDesignToDevice(d,h_d);
		
		
		
		printf("align lines %i\n",h_d->num_constraints);
		if (h_d->num_constraints>0)
		{
			for (int i =0;i<4;i++)
				printf ("%i ",h_d->constraints[i]);
			printf("\n");
		}
		
	
		printf("evaluating new layout\n");
		float check_eval=evaluateLayoutHost(d,h_d, num_params,params, params_grad, check_layout,h_params, h_params_grad_temp,0,0,true);

		FILE *fp=fopen(check_layout_features_file,"w");

		float test_eval=-500;
		if (fp>0)
		{
			fprintf(fp,"Layout Energy: %f\n",check_eval);
			for (int i=0;i<NUM_FEATURES;i++)
			{
				fprintf(fp,"%i\t%5.1f \t %4.2f\t %4.1f \tnl:%3.1f %s \n", i,h_params[i],h_params_grad_temp[i],h_params[i]*h_params_grad_temp[i],h_params[i+NUM_FEATURES],feat_names[i]);
				test_eval+=h_params[i]*h_params_grad_temp[i];
			}
			fprintf(fp,"Eval: %f %f\n",check_eval,test_eval*0.25);
			fclose(fp);
		}
		
		free(h_params_grad_temp);
	
	
		printf("Finished updating check layout\n");
		
	
	
	
		
		return true;


	}
	return false;
}



/*
void sampleStyleParameter(float **h_params, float *params, int num_params)
{
	
		float *h_params_new= loadParametersFromFile(default_param_file, param_file,num_params);
		free(*h_params);
		*h_params=h_params_new;
		CHECKCALL(cudaMemcpy(params,*h_params, num_params*sizeof(float), cudaMemcpyHostToDevice));
}
*/


bool updateParameterFile(float **h_params, float *params, int num_params)
{


	static struct stat paramFileStat;
	stat(param_file,&paramFileStat);
	static clock_t param_access_time=paramFileStat.st_mtime;

	//printf("Checking file %s %d\n",param_file,param_access_time);

	if (paramFileStat.st_mtime-param_access_time!=0)
	{
		printf("Parameter file has changed, loading new file\n");
		param_access_time=paramFileStat.st_mtime;
		float *h_params_new= loadParametersFromFile(default_param_file, param_file,num_params);
		free(*h_params);
		*h_params=h_params_new;
		CHECKCALL(cudaMemcpy(params,*h_params, num_params*sizeof(float), cudaMemcpyHostToDevice));
		return true;
	}


	static struct stat paramChangeFileStat;
	stat(param_change_file,&paramChangeFileStat);
	static clock_t param_change_access_time=paramChangeFileStat.st_mtime;

	//printf("Checking file %s %d\n",param_file,param_access_time);

	if (paramChangeFileStat.st_mtime-param_change_access_time!=0)
	{
		printf("Parameter change file has changed, loading new file\n");
		param_change_access_time=paramChangeFileStat.st_mtime;

		//load parameters
		float *h_params_new= loadParametersFromFile(default_param_file, param_file,num_params);

		addParameterOffsets(param_change_file,num_params,h_params_new);

		free(*h_params);
		*h_params=h_params_new;
		CHECKCALL(cudaMemcpy(params,*h_params, num_params*sizeof(float), cudaMemcpyHostToDevice));
		return true;
	}


	return false;
}

bool loadParameterSample(float **h_params, float *params, int num_params)
{

	int r = (rand() / (double)RAND_MAX)*999;

	char param_file[1024];	
	sprintf(param_file,"%sdata/style_samples/gen_style%i.data",home_dir,r);	
	
	float *h_params_new= loadParametersFromFile(default_param_file, param_file,num_params);

	free(*h_params);
	*h_params=h_params_new;
	CHECKCALL(cudaMemcpy(params,*h_params, num_params*sizeof(float), cudaMemcpyHostToDevice));
	return true;


}


bool updateDesign(Design *d,Design **h_d, float **opt_layouts,float **h_opt_layouts,int num_kernels )
{
	static struct stat designFileStat;
	stat(design_file,&designFileStat);
	static clock_t design_access_time=designFileStat.st_mtime;

	//printf("Checking file %s %d\n",design_file,design_access_time);

	if (designFileStat.st_mtime-design_access_time!=0)
	{



		/*
		for (int k=0;k<3;k++)
		{
			printf("layout kernel %i\n",k);
			float *new_layout=&((*h_opt_layouts)[k*((*h_d)->layout_size)]);

			for(int j=0;j<(*h_d)->num_elements;j++)
			{
				printf("setting %i %i, %f,%f,%f,%f,%f \n", k,j,new_layout[j*NUM_VAR], new_layout[j*NUM_VAR+1], new_layout[j*NUM_VAR+2], new_layout[j*NUM_VAR+3], new_layout[j*NUM_VAR+4]);
			}
		}
		*/

		Design *h_d_new= loadDesignFromFile(design_file,true);
		if (!h_d_new)
		{
			printf("problem loading design file. try next iteration");
			return false;
		}
		
		
		printf("Design file has changed, loading new file\n");
		design_access_time=designFileStat.st_mtime;

		//if (h_d_new->num_elements!=(*h_d)->num_elements)
		//{

		float *h_opt_layouts_new = (float *)malloc((h_d_new->layout_size)*num_kernels*sizeof(float));
		memset(h_opt_layouts_new,0,(h_d_new->layout_size)*num_kernels*sizeof(float));

		//printf("num_kernels %i\n",num_kernels);
		//printf("old layout size %i\n",((*h_d)->layout_size));
		//printf("new layout size %i\n",(h_d_new->layout_size));

		
		for (int k=0;k<num_kernels;k++)
		{
			//printf("Copying for kernel %i\n",k);
			float *old_layout=&((*h_opt_layouts)[k*((*h_d)->layout_size)]);
			float *new_layout=&(h_opt_layouts_new[k*(h_d_new->layout_size)]);

			memcpy(new_layout,h_d_new->layout, h_d_new->layout_size*sizeof(float));


			//int offset_old=(*h_d)->num_elements*NUM_VAR;
			//int offset_new=h_d_new->num_elements*NUM_VAR;

			for(int j=0;j<h_d_new->num_elements;j++)
			{
				for(int i=0;i<(*h_d)->num_elements;i++)
				{
					if ((*h_d)->id[i]== h_d_new->id[j])
					{
						for(int n=0;n<NUM_VAR;n++)
							if ((n!=3) && (n!=6))
								new_layout[j*NUM_VAR+n]=old_layout[i*NUM_VAR+n];
					}
				}
			}
			
			/*
			if ((*h_d)->num_elements==h_d_new->num_elements)
			{
				for(int j=0;j<(*h_d)->num_elements;j++)
				{													
					for(int n=0;n<NUM_RVAR;n++)						
						new_layout[offset_new+j*NUM_RVAR+n]=old_layout[offset_old+j*NUM_RVAR+n];
				}	
			}
			else
			{
				for(int j=0;j<h_d_new->num_elements;j++)
				{
					new_layout[j*NUM_VAR+5]=j;
					//new_layout[offset_new+j*NUM_RVAR]
				}
			}
			*/
		}

		cout << "finished setting layout "  <<endl;

		free(*h_opt_layouts);
		*h_opt_layouts=h_opt_layouts_new;


		//}


		*h_d=h_d_new;
		freeDeviceDesign(d);
		copyDesignToDevice(d,h_d_new);

		return true;
	}
	return false;
}


/*

int optimizeLayout(Design *d,int num_kernels,int num_params,int num_outer,int num_inner, float *params,float *temperatures,int *temp_ids,float *layouts,float *params_grads,float *opt_layouts, float *evals,float *proposals,Design *h_d,float *h_temperatures,float *h_evals,int *h_temp_ids,float *h_params_grads,float *h_opt_layouts,bool silent,bool output_layouts,int debug_mode)
{


	float end_temp=0.6;
	float start_temp=0.01;

	//float temp_range=0.6;
	//float range_step=temp_range/num_outer;
	printf("end temp %f\n",end_temp);


    for (int i=0;i< num_kernels;i++)
    {
    	h_temp_ids[i]=i;
    	h_temperatures[i]=10.0*((end_temp-start_temp)* (float(num_kernels-i)/float(num_kernels)))+start_temp;
    }


    CHECKCALL(cudaMemcpy(temperatures, h_temperatures,num_kernels*sizeof(float), cudaMemcpyHostToDevice));
    CHECKCALL(cudaMemcpy(temp_ids, h_temp_ids,num_kernels*sizeof(int), cudaMemcpyHostToDevice));


    //for (int i=0;i< num_kernels;i++)
    //	CHECKCALL(cudaMemcpy(&layouts[i*h_d->layout_size], h_d->layout,h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));

    dim3 cudaGridSize(16, 1);
    dim3 cudaBlockSize(num_kernels/16,1);
    //dim3 cudaGridSize(1, 1);
    //dim3 cudaBlockSize(1,1);


    float *h_params= (float *)malloc(num_params*sizeof(float));
    CHECKCALL(cudaMemcpy(h_params, params,num_params*sizeof(float), cudaMemcpyDeviceToHost));

	float *atan_params;
	CHECKCALL(cudaMalloc(&atan_params,num_params*sizeof(float)));
	float *h_atan_params= (float *)malloc(num_params*sizeof(float));

	for (int j=0;j<num_params;j++)
		h_atan_params[j]=atan(h_params[j]);
	CHECKCALL(cudaMemcpy(atan_params, h_atan_params,num_params*sizeof(float), cudaMemcpyHostToDevice));



	float *previous_layout;
	CHECKCALL(cudaMalloc(&previous_layout,h_d->layout_size*sizeof(float)));
	CHECKCALL(cudaMemset(previous_layout, 0,h_d->layout_size*sizeof(float)));


	float *random_seed;
	CHECKCALL(cudaMalloc(&random_seed,num_kernels*4*sizeof(float)));
	CHECKCALL(cudaMemset(random_seed, 0,num_kernels*4*sizeof(float)));

	float *h_random_seed= (float *)malloc(num_kernels*4*sizeof(float));

	//static struct stat paramFileStat;
	//if(stat(param_file,&paramFileStat) < 0)
	//	return -1;
	//static clock_t param_access_time=paramFileStat.st_atime;


	char layout_file[1024],layout_features_file[1024],check_layout_features_file[1024];
	sprintf(layout_file, "%sdata/runs/r%d_opt_layout.data",home_dir,run_id);
	sprintf(layout_features_file, "%sdata/runs/r%d_opt_layout_features.txt",home_dir,run_id);
	sprintf(check_layout_features_file, "%sdata/runs/r%d_user_layout_features.txt",home_dir,run_id);

	int best_id=0;
	float opt_eval=999999;
	float curr_opt_eval=opt_eval;
	bool new_params=true;
	//float *h_params_new;

    clock_t start=clock();
    clock_t stop;
    float pt_time_sum=0,pt_time_cnt=0;

    printf("Starting optimization with %i iterations\n",num_outer);
    

    for (int i=0;i <num_outer;i++)
    {


    	if (i%3==1)
    	{


    		if (updateParameterFile(&h_params, params, num_params) or updateCheckLayoutFile(d, h_d,num_params,num_kernels,params,params_grads,layouts,  h_params,check_layout_features_file))
    		{
    			opt_eval=999999;
    			new_params=true;
    			
    			
    			//todo: move this to updateParameterFile
				for (int j=0;j<num_params;j++)
					h_atan_params[j]=atan(h_params[j]);
				CHECKCALL(cudaMemcpy(atan_params, h_atan_params,num_params*sizeof(float), cudaMemcpyHostToDevice));
    			
    			
    		}

    		if (updateDesign(d, &h_d,&opt_layouts,&h_opt_layouts,num_kernels))
    		{
    			opt_eval=999999;
    			new_params=true;



    			pt_time_sum=0;
    			pt_time_cnt=1;
    			printf("Layout Size %i\n", h_d->layout_size);


    			CHECKCALL(cudaFree(opt_layouts));
    			CHECKCALL(cudaMalloc(&opt_layouts,num_kernels*h_d->layout_size*sizeof(float)));
    			CHECKCALL(cudaMemcpy(opt_layouts, h_opt_layouts,  num_kernels*h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));

    			CHECKCALL(cudaFree(layouts));
    			CHECKCALL(cudaMalloc(&layouts,num_kernels*h_d->layout_size*sizeof(float)));
    			CHECKCALL(cudaMemcpy(layouts, h_opt_layouts,  num_kernels*h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));

    			CHECKCALL(cudaFree(proposals));
    			CHECKCALL(cudaMalloc(&proposals,num_kernels*h_d->layout_size*sizeof(float)));
    			CHECKCALL(cudaMemcpy(proposals, h_opt_layouts,  num_kernels*h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));

				CHECKCALL(cudaFree(previous_layout));
				CHECKCALL(cudaMalloc(&previous_layout,h_d->layout_size*sizeof(float)));
				CHECKCALL(cudaMemcpy(previous_layout, h_d->layout, h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));
    		}
    	}
    	
    	for (int rs=0;rs<num_kernels*4;rs++)
    		h_random_seed[rs]=(float)rand()/(float)RAND_MAX;

		CHECKCALL(cudaMemcpy(random_seed, h_random_seed,num_kernels*4*sizeof(float), cudaMemcpyHostToDevice));


    	clock_t start_pt=clock();
    	parallelTempering<<<cudaGridSize, cudaBlockSize>>>(d,debug_mode,i, -1,-1, num_inner,num_params,params, atan_params,temperatures,temp_ids ,layouts,proposals, params_grads, opt_layouts,evals,num_previous_layout, previous_layout,random_seed);


    	CHECKCALL(cudaGetLastError());
    	CHECKCALL(cudaDeviceSynchronize());

    	clock_t stop_pt=clock();
    	pt_time_sum+=stop_pt-start_pt;
    	pt_time_cnt++;

    	CHECKCALL(cudaMemcpy(h_evals, evals,  num_kernels*sizeof(float), cudaMemcpyDeviceToHost));


		
    	//switch layouts based on
    	for (int j=0;j< num_kernels-1;j++)
    	{
    		int r1=h_temp_ids[j];
    		int r2=h_temp_ids[j+1];

    		float temp1=h_temperatures[r1];
    		float temp2=h_temperatures[r2];

    		float energy1=h_evals[r1];
    		float energy2=h_evals[r2];
    		
    		if ((energy1==9999) || (energy2==9999))
    		{
    			printf("quitting\n");
    			return -1;
    			
    		}
    			

    		float prop=exp((1.0/temp1-1.0/temp2)*(energy1-energy2));
    		float r=rand()/ double(RAND_MAX);			

    		if (r<min(1.0,prop))
			{
				int temp_id=h_temp_ids[j];
				h_temp_ids[j]=h_temp_ids[j+1];
				h_temp_ids[j+1]=temp_id;

				float temp_temp=h_temperatures[r1];
				h_temperatures[r1]=h_temperatures[r2];
				h_temperatures[r2]=temp_temp;

			}
    	}
    	
    	

    	CHECKCALL(cudaMemcpy(temperatures, h_temperatures,num_kernels*sizeof(float), cudaMemcpyHostToDevice));

        stop=clock();
        
        float energy_sum=0;


    	best_id=0;
    	curr_opt_eval=h_evals[0]+1;
    	for (int j=0;j < num_kernels;j++)
    	{
    		energy_sum+=h_evals[j];
    		if (h_evals[j]<curr_opt_eval)
    		{
    			curr_opt_eval=h_evals[j];
    			best_id=j;
    		}
    	}
    	
    	

    	
    	if ((output_layouts) and (i%3==1) or (i%10==1))
    	{
    		CHECKCALL(cudaMemcpy(h_opt_layouts, opt_layouts, num_kernels*h_d->layout_size*sizeof(float), cudaMemcpyDeviceToHost));
			float *output_layout=&h_opt_layouts[(best_id)*h_d->layout_size];

			if ((curr_opt_eval<opt_eval) or (new_params) or (i%10==1))
			{
				if (curr_opt_eval<opt_eval)
					opt_eval=curr_opt_eval;
				
				writeLayoutToFile(h_d, output_layout,layout_file );

				new_params=false;
				CHECKCALL(cudaMemcpy(h_params_grads, params_grads, num_kernels*num_params*sizeof(float), cudaMemcpyDeviceToHost));

				CHECKCALL(cudaFree(previous_layout));
				CHECKCALL(cudaMalloc(&previous_layout,h_d->layout_size*sizeof(float)));
				CHECKCALL(cudaMemcpy(previous_layout, output_layout, h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));

				float *h_params_grad_opt=&h_params_grads[best_id*num_params];
				FILE *fp=fopen(layout_features_file,"w");


				if (fp>0)
				{
				
			
					//if (curr_opt_eval<opt_eval) 
					//float *h_params_grad_temp=(float *)malloc(num_params*sizeof(float));
					//float check_eval=evaluateLayoutHost(d,h_d, num_params,params, params_grads, output_layout,h_params, h_params_grad_temp,true);
					
					float test_eval=-500;
					fprintf(fp,"Layout Energy: %f\n",opt_eval);
					for (int k=0;k<NUM_FEATURES;k++)
					{
						fprintf(fp,"%i\t%5.1f \t %4.2f\t %4.2f \t nl: %4.2f %s \n", k,h_params[k],h_params_grad_opt[k],h_params[k]*h_params_grad_opt[k],h_params[k+NUM_FEATURES],feat_names[k]);
						test_eval+=h_params[k]*h_params_grad_opt[k];
					}


					fprintf(fp,"Eval: %f %f\n",opt_eval,test_eval*0.25);
					fclose(fp);	

					//free(h_params_grad_temp);
				}



			}

    	}

        if ((output_layouts) and (i%20==1) )
        {
        	float overall_time=((double)(stop - start) / CLOCKS_PER_SEC);
        	float pt_time=((double)(stop_pt - start_pt) / CLOCKS_PER_SEC);

        	printf("PT Iteration %i, steps %i, opt %f, overall time %f, pt time %f (mean %f), mean energy %f debug_mode %i,region proposals %i\n", i,num_inner,opt_eval,overall_time, pt_time, (pt_time_sum/pt_time_cnt)/ CLOCKS_PER_SEC,energy_sum/float(num_kernels),debug_mode,h_d->region_proposals);
        }

        start=stop;
    }

    free(h_params);
    free(h_atan_params);
    free(h_random_seed);
    CHECKCALL(cudaFree(atan_params));
    CHECKCALL(cudaFree(random_seed));
    //CHECKCALL(cudaFree(check_layout));

	CHECKCALL(cudaMemcpy(h_evals, evals,  num_kernels*sizeof(float), cudaMemcpyDeviceToHost));
	CHECKCALL(cudaMemcpy(h_params_grads, params_grads, num_kernels*num_params*sizeof(float), cudaMemcpyDeviceToHost));
	CHECKCALL(cudaMemcpy(h_opt_layouts, opt_layouts, num_kernels*h_d->layout_size*sizeof(float), cudaMemcpyDeviceToHost));


	best_id=0;
	opt_eval=h_evals[0]+1;
	for (int j=0;j < num_kernels;j++)
	{
		if (h_evals[j]<opt_eval)
		{
			opt_eval=h_evals[j];
			best_id=j;
		}
	}
	return best_id;

}

*/



int optimizeLayout(Design *d,int num_kernels,int num_params,int num_outer,int num_inner, float *params,float *temperatures,int *temp_ids,float *layouts,float *params_grads,float *opt_layouts, float *evals,float *proposals,Design *h_d,float *h_temperatures,float *h_evals,int *h_temp_ids,float *h_params_grads,float *h_opt_layouts,bool silent,int debug_mode,float *h_opt_steps)
{


	float end_temp=0.6;
	float start_temp=0.01;

	//float temp_range=0.6;
	//float range_step=temp_range/num_outer;
	//printf("end temp %f\n",end_temp);

	
	int num_ladders=2;
	int ladder_size=num_kernels/num_ladders;

    for (int i=0;i< num_ladders;i++)
    for (int j=0;j< ladder_size;j++)
    	h_temperatures[i*ladder_size+j]=10.0*((end_temp-start_temp)* (float(ladder_size-j)/float(ladder_size)))+start_temp;
   
  	/*
  	int grid_size=sqrt(num_kernels);
    
    for (int i=0;i< grid_size;i++)
    for (int j=0;j< grid_size;j++)
    	h_temperatures[i*grid_size+j]=10.0*((end_temp-start_temp)* (float(grid_size-j)/float(grid_size)))+start_temp;
    */
    
    //for (int i=0;i< num_kernels;i++)
    //{
    //	h_temperatures[i]=((end_temp-start_temp)* (float(i)/float(num_kernels)))+start_temp;
    //}


    CHECKCALL(cudaMemcpy(temperatures, h_temperatures,num_kernels*sizeof(float), cudaMemcpyHostToDevice));
    //CHECKCALL(cudaMemcpy(temp_ids, h_temp_ids,num_kernels*sizeof(int), cudaMemcpyHostToDevice));


    //for (int i=0;i< num_kernels;i++)
    //	CHECKCALL(cudaMemcpy(&layouts[i*h_d->layout_size], h_d->layout,h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));

    dim3 cudaGridSize(16, 1);
    dim3 cudaBlockSize((num_kernels/16)*EVAL_SPLIT_NUM,1);
    //dim3 cudaGridSize(1, 1);
    //dim3 cudaBlockSize(1,1);


    float *h_params= (float *)malloc(num_params*sizeof(float));
    CHECKCALL(cudaMemcpy(h_params, params,num_params*sizeof(float), cudaMemcpyDeviceToHost));

	float *atan_params;
	CHECKCALL(cudaMalloc(&atan_params,num_params*sizeof(float)));
	float *h_atan_params= (float *)malloc(num_params*sizeof(float));

	for (int j=0;j<num_params;j++)
		h_atan_params[j]=atan(h_params[j]);
	CHECKCALL(cudaMemcpy(atan_params, h_atan_params,num_params*sizeof(float), cudaMemcpyHostToDevice));


	
	int *barrier, *h_barrier;
	//int *barrier, *h_barrier=(int *)malloc(num_kernels*sizeof(int));
	//for (int j=0;j<num_kernels;j++)
	//	h_barrier[j]=EVAL_SPLIT_NUM;
	//CHECKCALL(cudaMalloc(&barrier,num_kernels*sizeof(int)));
	//CHECKCALL(cudaMemcpy(barrier, h_barrier,num_kernels*sizeof(int), cudaMemcpyHostToDevice));
	
	float *eval_sum;
	CHECKCALL(cudaMalloc(&eval_sum,num_kernels*sizeof(float)));
	CHECKCALL(cudaMemset(eval_sum, 0,num_kernels*sizeof(float)));	

	float *previous_layout;
	CHECKCALL(cudaMalloc(&previous_layout,num_outer*h_d->layout_size*sizeof(float)));
	CHECKCALL(cudaMemset(previous_layout, 0,num_outer*h_d->layout_size*sizeof(float)));

	float *h_previous_layout= (float *)malloc(num_outer*h_d->layout_size*sizeof(float));

	float *h_best_layout= (float *)malloc(h_d->layout_size*sizeof(float));

	//static struct stat paramFileStat;
	//if(stat(param_file,&paramFileStat) < 0)
	//	return -1;
	//static clock_t param_access_time=paramFileStat.st_atime;

	float *random_seed;
	CHECKCALL(cudaMalloc(&random_seed,num_kernels*4*sizeof(float)));
	CHECKCALL(cudaMemset(random_seed, 0,num_kernels*4*sizeof(float)));

	float *h_random_seed= (float *)malloc(num_kernels*4*sizeof(float));
	
	

	
	int best_id=0;
	float opt_eval=999999;
	float curr_opt_eval=opt_eval;
	//bool new_params=true;
	//float *h_params_new;
	clock_t last_time=clock();
    clock_t start=clock();
    clock_t stop;
    float pt_time_sum=0;
    float it_time_sum=0;

	cout << "Starting optimization with "<< num_outer<<" iterations " << endl;
    
    
    int num_previous_layout=0;
    
    int last_add=-100;
    
    bool gallery=(strcmp(param_type,"gallery")==0);	
    bool nio=(strcmp(param_type,"nio_init")==0);
	
    	
    float refine_design= ((!gallery) && (!nio));
    	
    float gd_imp_sum=0,gd_time_sum=0;
    int gd_cnt=0,gd_imp_fail=0;
    
    float *h_params_grad_temp=(float *)malloc(num_params*sizeof(float));
    
    int last_update=-1;
    clock_t last_update_time=clock();

    for (int r=0;r <num_outer;r++)
    {
		//printf("Iteration %i\n",r);
		
		//printf("iteration %i\n",r);
    	
		
    	//if (r%2==1)
    	//{

			//updateParameterFile(&h_params, params, num_params) or 
    		if ((refine_design)&& updateCheckLayout(d, h_d,num_params,num_kernels,params,params_grads,layouts,  h_params,check_layout_features_file))
    		{
    			
    			last_update=r;
    			
    			opt_eval=999999;
    			//new_params=true;
    			last_update_time=clock();

			    			
    		}

    		if (updateDesign(d, &h_d,&opt_layouts,&h_opt_layouts,num_kernels))
    		{
    			opt_eval=999999;
    			//new_params=true;


    			pt_time_sum=0;
    			printf("Layout Size %i\n", h_d->layout_size);


    			CHECKCALL(cudaFree(opt_layouts));
    			CHECKCALL(cudaMalloc(&opt_layouts,num_kernels*h_d->layout_size*sizeof(float)));
    			CHECKCALL(cudaMemcpy(opt_layouts, h_opt_layouts,  num_kernels*h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));

    			CHECKCALL(cudaFree(layouts));
    			CHECKCALL(cudaMalloc(&layouts,num_kernels*h_d->layout_size*sizeof(float)));
    			CHECKCALL(cudaMemcpy(layouts, h_opt_layouts,  num_kernels*h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));

    			CHECKCALL(cudaFree(proposals));
    			CHECKCALL(cudaMalloc(&proposals,num_kernels*h_d->layout_size*sizeof(float)));
    			CHECKCALL(cudaMemcpy(proposals, h_opt_layouts,  num_kernels*h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));

				CHECKCALL(cudaFree(previous_layout));
				CHECKCALL(cudaMalloc(&previous_layout,num_outer*h_d->layout_size*sizeof(float)));
				CHECKCALL(cudaMemcpy(previous_layout, h_d->layout, h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));

    		}
    	//}

		clock_t start_pt=clock();
		
    	parallelTempering<<<cudaGridSize, cudaBlockSize>>>(d,debug_mode,r, -1,-1, num_inner,num_params,params, atan_params,temperatures,temp_ids ,layouts,proposals, params_grads, opt_layouts,evals,num_previous_layout, previous_layout,random_seed,barrier,eval_sum);


    	CHECKCALL(cudaGetLastError());
    	CHECKCALL(cudaDeviceSynchronize());

    	clock_t stop_pt=clock();
    	pt_time_sum+=stop_pt-start_pt;

    	CHECKCALL(cudaMemcpy(h_evals, evals,  num_kernels*sizeof(float), cudaMemcpyDeviceToHost));
		CHECKCALL(cudaMemcpy(h_opt_layouts, opt_layouts, num_kernels*h_d->layout_size*sizeof(float), cudaMemcpyDeviceToHost));


		//for (int i=0;i< num_kernels;i++)
		//	for (int j=0;j<h_d->num_elements;j++)
		//		if ((h_opt_layouts[i*h_d->layout_size + j*NUM_VAR+2]==0) && (h_opt_layouts[i*h_d->layout_size+ j*NUM_VAR+3]==0))
		//			printf("ERROR-1 in kernel %i element %i. init element is 0\n",i,j);
    	
    	
    	//do refinement updates first
		for (int i=0;i< num_ladders;i++)
		{
	    	for (int j=0;j< ladder_size-1;j++)
	    	{
	    		int curr=i*ladder_size+j;
	    		float temp1=h_temperatures[curr];
	    		float temp2=h_temperatures[curr+1];
	
	    		float energy1=h_evals[curr];
	    		float energy2=h_evals[curr+1];
	
	    		float prop=exp((1.0/temp1-1.0/temp2)*(energy1-energy2));
	    		float r=rand()/ double(RAND_MAX);			
						
				
				//switch state
	    		if (r<min(1.0,prop))
				{
					
					float temp_eval=h_evals[curr];
					h_evals[curr]=h_evals[curr+1];
					h_evals[curr+1]=temp_eval;
					
					for (int k=0;k<h_d->layout_size;k++)
					{
						float temp_layout=h_opt_layouts[curr*h_d->layout_size+k];
						h_opt_layouts[curr*h_d->layout_size+k]=h_opt_layouts[(curr+1)*h_d->layout_size+k];
						h_opt_layouts[(curr+1)*h_d->layout_size+k]=temp_layout;
					}
					
					
					//just promoted a new state to the top rung, move it to the next ladder.
					if ((i<num_ladders-1)&& (j==ladder_size-2))
					{
						//printf("reseting refinement optimization %.2f %.2f. temp %.2f %.2f. energy %.2f %.2f \n",r,prop,temp1, temp2, energy1,energy2);
						
						for (int m=0;m< ladder_size;m++) 
						{
							h_evals[(i+1)*ladder_size+m]=h_evals[curr+1];	
							
							for (int k=0;k<h_d->layout_size;k++)
								h_opt_layouts[((i+1)*ladder_size+m)*h_d->layout_size+k]=h_opt_layouts[(curr+1)*h_d->layout_size+k];
								
						}
						
					}
				
				}
			}
    	}


    	CHECKCALL(cudaMemcpy(evals, h_evals,num_kernels*sizeof(float), cudaMemcpyHostToDevice));
    	//CHECKCALL(cudaMemcpy(opt_layouts,h_opt_layouts,  num_kernels*h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));
		CHECKCALL(cudaMemcpy(layouts,h_opt_layouts,  num_kernels*h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));
		
		
		
        
        
        float energy_sum=0;


    	best_id=0;
    	curr_opt_eval=h_evals[0]+1;
    	for (int j=0;j < num_kernels;j++)
    	{
    		energy_sum+=h_evals[j];
    		if (h_evals[j]<curr_opt_eval)
    		{
    			curr_opt_eval=h_evals[j];
    			best_id=j;
    			
    			
    		}    		
    	}
      	
      	h_opt_steps[r]=opt_eval;
    	
    	
    	
    	
    	float *output_layout=&h_opt_layouts[(best_id)*h_d->layout_size];
    	
    	
    	bool write_layout=(r-last_update>0);
    	
		
		if ((gallery) && (r>120) && (h_opt_steps[r-50]-h_opt_steps[r]<1) && (r-last_add>120))
		{
		
			last_add=r;
			

			
			//check distance to previous layouts
			
			float min_dist=999;
			
			for (int i=0;i< num_previous_layout;i++)
			{
			
				float *prev_layout =&(h_previous_layout[i*h_d->layout_size]);
				float curr_dist=0;
				
				for (int j=0;j<h_d->num_elements;j++)
				{
					curr_dist+=abs(prev_layout[j*NUM_VAR]-output_layout[j*NUM_VAR]);
					curr_dist+=abs(prev_layout[j*NUM_VAR+1]-output_layout[j*NUM_VAR+1]);
					curr_dist+=2*abs(prev_layout[j*NUM_VAR+2]-output_layout[j*NUM_VAR+2]);
				}
					

				printf("dist to prev layout %i: %.3f\n",i,curr_dist/h_d->num_elements); 
				min_dist=min(curr_dist/h_d->num_elements,min_dist);
				
			}
			
			
			if (min_dist>0.1)
			{
				memcpy(&(h_previous_layout[num_previous_layout*h_d->layout_size]),output_layout,h_d->layout_size*sizeof(float));
				CHECKCALL(cudaMemcpy(previous_layout, h_previous_layout, num_outer*h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));
				num_previous_layout++;
				
				//opt_eval=999999;
				printf("added previous layout, iter %i, count %i, curr_opt_eval %f\n",r,num_previous_layout,curr_opt_eval);
			
				CHECKCALL(cudaMemcpy(h_best_layout,output_layout ,  h_d->layout_size*sizeof(float), cudaMemcpyHostToHost));
	
				
				
				sendLayoutToServer(h_d, h_best_layout,curr_opt_eval);
				opt_eval=curr_opt_eval;
			
			}
			
		
			loadParameterSample(&h_params, params, num_params);
			
    			
			//todo: move this to updateParameterFile
			for (int j=0;j<num_params;j++)
				h_atan_params[j]=atan(h_params[j]);
			CHECKCALL(cudaMemcpy(atan_params, h_atan_params,num_params*sizeof(float), cudaMemcpyHostToDevice));
			
			
			write_layout=false;
			
		}
		
		if (write_layout)
		{	


			if ((curr_opt_eval<opt_eval))
			{
				
			
				CHECKCALL(cudaMemcpy(h_best_layout,output_layout ,  h_d->layout_size*sizeof(float), cudaMemcpyHostToHost));




				if (refine_design)
					sendLayoutToServer(h_d, h_best_layout,curr_opt_eval);
				
				opt_eval=curr_opt_eval;
				
			}
			else if ((r%10==1) && (refine_design))
				sendLayoutToServer(h_d, h_best_layout,opt_eval);
			
				/*
				float new_eval=curr_opt_eval;
				clock_t start_gd=clock();
				if (debug_mode==2)
					new_eval=constrainedGradientDescent(h_d,d,num_params, params,atan_params, params_grads, h_params,output_layout,num_previous_layout, previous_layout);
				clock_t end_gt=clock();
				
				
				gd_time_sum+=(end_gt-start_gd);
				gd_imp_sum+=abs(new_eval-curr_opt_eval);
				gd_cnt++;		
				
				
				if (new_eval==curr_opt_eval)
					gd_imp_fail++;
			
				if (new_eval<curr_opt_eval)
				{
					for (int m=0;m< ladder_size;m++) 
					{
						h_evals[ladder_size+m]=new_eval;	
						
						for (int k=0;k<h_d->layout_size;k++)
							h_opt_layouts[(ladder_size+m)*h_d->layout_size+k]=output_layout[k];
							
					}
					
	    			CHECKCALL(cudaMemcpy(evals, h_evals,num_kernels*sizeof(float), cudaMemcpyHostToDevice));
					CHECKCALL(cudaMemcpy(layouts,h_opt_layouts,  num_kernels*h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));
					
				}
				else if (abs(new_eval-curr_opt_eval)>0.01)
					printf("ERROR. curr_opt_eval %f < new_eval %f\n",curr_opt_eval,new_eval);

					*/
					
			

			
	
			
    	}
    	
    	stop=clock();
		it_time_sum+=stop - start;

        if (r%40==1) 
        {
        	
        	
        	float time_since_last_update= (stop-last_update_time)  / CLOCKS_PER_SEC;
        	
        	
        	
        	if (time_since_last_update>300)
        	{
        		printf("inactive. quitting...");
        		cleanup();
        		exit(1);
        	}
        	
        	
        	
        	float overall_time=1000*(it_time_sum/r) / CLOCKS_PER_SEC;
        	float pt_time=1000*(pt_time_sum/r)/ CLOCKS_PER_SEC;
        	float gd_time=1000*(gd_time_sum/gd_cnt)/ CLOCKS_PER_SEC;
        		

			clock_t curr_time=clock();
			last_time=curr_time;
		
        	printf("PT Iteration %i, steps %i, opt %.2f, overall time mean %.2f, pt time mean %.2f, GD imp %.2f time %.2f fail %.2f\n", r,num_inner,opt_eval,overall_time, pt_time,gd_imp_sum/gd_cnt,gd_time,float(gd_imp_fail)/gd_cnt);
        	
        	writeHostFiles();
		
			//for (int j=0;j<h_d->num_elements;j++)
			//	printf("opt layout. elem %i %.1f %.1f %.1f %.2f %.2f\n", j,  h_best_layout[j*NUM_VAR]*h_d->width,h_best_layout[j*NUM_VAR+1]*h_d->height,h_best_layout[j*NUM_VAR+2]*h_d->height,h_best_layout[j*NUM_VAR+3],h_best_layout[j*NUM_VAR+4]);
			
			float check_eval=evaluateLayoutHost(d,h_d, num_params,params, params_grads, h_best_layout,h_params, h_params_grad_temp,num_previous_layout,previous_layout, false);
			
			if (nio)
				writeOutFeatures(layout_features_file2,check_eval,h_params,h_params_grad_temp);
			else
				writeOutFeatures(layout_features_file,check_eval,h_params,h_params_grad_temp);

		
			
        }

        start=stop;
    }

	free(h_params_grad_temp);
    free(h_params);
    free(h_atan_params);
    
    //CHECKCALL(cudaFree(barrier));
    //CHECKCALL(cudaFree(atan_params));
   // free(h_row_ids);
    //CHECKCALL(cudaFree(check_layout));

	CHECKCALL(cudaMemcpy(h_evals, evals,  num_kernels*sizeof(float), cudaMemcpyDeviceToHost));
	CHECKCALL(cudaMemcpy(h_params_grads, params_grads, num_kernels*num_params*sizeof(float), cudaMemcpyDeviceToHost));
	CHECKCALL(cudaMemcpy(h_opt_layouts, opt_layouts, num_kernels*h_d->layout_size*sizeof(float), cudaMemcpyDeviceToHost));



	best_id=0;
	curr_opt_eval=h_evals[0]+1;
	for (int j=0;j < num_kernels;j++)
	{
		if (h_evals[j]<opt_eval)
		{
			curr_opt_eval=h_evals[j];
			best_id=j;
		}
	}
	
	
	h_evals[best_id]=opt_eval;
	CHECKCALL(cudaMemcpy(&h_opt_layouts[best_id*h_d->layout_size], h_best_layout,  h_d->layout_size*sizeof(float), cudaMemcpyHostToHost));
	free(h_best_layout);
	
	
	return best_id;

}



void writeHostFiles()
{
	int pid=getpid();
	
	FILE *fp=fopen(run_host_file,"w");
	if (fp>0)
		fprintf(fp,"%s %d\n",hostname,pid);
	fclose(fp);
	
	fp=fopen(host_run_file,"w");
	if (fp>0)
		fprintf(fp,"%d  %d\n",run_id,pid);
	fclose(fp);
	
	fp=fopen(host_pid_file,"w");
	if (fp>0)
		fprintf(fp,"%d\n",pid);
	fclose(fp);
}



int getConstraints(Design *d, float *layout, float ***C_out,  float ***H_out, bool debug)
{
	
	if (debug)
		printf("getting position constraints\n");

	int ne=d->num_elements;
	
	Box elem_bb[MAX_ELEMENTS];
	float aspect_ratio[MAX_ELEMENTS];
	
	float height, width, xp, yp;
	
	for (int i=0;i< d->num_elements;i++)
	{
		
		int alt=int(layout[NUM_VAR*i+6]);
		if (alt>-1)
		{
			if ((d->num_alt[i]>0))
				aspect_ratio[i]=d->alt_aspect_ratio[i*MAX_ALT+alt];
			else
				aspect_ratio[i]=d->aspect_ratio[i];
				
		
			height=round(layout[NUM_VAR*i+2]*d->height);
			width=round(height/aspect_ratio[i]);
			xp=round(layout[NUM_VAR*i]*d->width);
			yp=round(layout[NUM_VAR*i+1]*d->height);
	
			elem_bb[i].set_h(round(xp+(width*d->bb_left[i])), round(xp+(width*d->bb_right[i])), round(yp + (height*d->bb_bottom[i])), round(yp + (height*d->bb_top[i])));
			//printf("%i: %f %f %f %f (w/h) %f %f\n",i, layout[NUM_VAR*i],layout[NUM_VAR*i+1],layout[NUM_VAR*i+2],layout[NUM_VAR*i+3],width,height);
			
			if (debug)
				printf("%i: l/r: %3.3f - %3.3f b/t: %3.3f - %3.3f\n",i,elem_bb[i].l,elem_bb[i].r,elem_bb[i].b,elem_bb[i].t);
		}
	}
	
	
	int aligned[6][MAX_ELEMENTS][MAX_ELEMENTS];
	float align_dist[6][MAX_ELEMENTS][MAX_ELEMENTS];
	float locations[MAX_ELEMENTS];


	float scale=max(d->width, d->height);

	int align_cnt=0;

	for (int k=0;k<6;k++)
	{
		for (int i=0;i<ne;i++)
		{
			if (k==0)
				locations[i]=elem_bb[i].l/scale;
			else if (k==1)
				locations[i]=((elem_bb[i].l+elem_bb[i].r)/2.0)/scale;
			else if (k==2)
				locations[i]=elem_bb[i].r/scale;
			else if (k==3)
				locations[i]=elem_bb[i].b/scale;
			else if (k==4)
				locations[i]=((elem_bb[i].t+elem_bb[i].b)/2.0)/scale;
			else
				locations[i]=elem_bb[i].t/scale;
		}

		for (int i=0;i<ne;i++)
		{
			//aligned[k][i][i]=0;
	
			for (int j=i+1;j<ne;j++)
			{
				
				aligned[k][i][j]=0;
				aligned[k][j][i]=0;
				
				float loc_diff=min(abs(locations[i]-locations[j]),0.99);
			
				align_dist[k][i][j]=loc_diff;
				//align_dist[k][j][i]=loc_diff;

			}
		}
	}
	

	for (int i=0;i<ne;i++)
	{
		for (int k=0;k<6;k++)
			aligned[k][i][i]=0;

		for (int j=i+1;j<ne;j++)
		{

			
			float d0=align_dist[0][i][j];
			float d1=align_dist[1][i][j];
			float d2=align_dist[2][i][j];
			float d3=align_dist[3][i][j];
			float d4=align_dist[4][i][j];
			float d5=align_dist[5][i][j];



			if (min(min(d0 ,d1),d2)<ALIGN_THRESH)
			{
				if ((d0< d1) and (d0<d2))
				{
					aligned[0][i][j]=1;
					//aligned[0][j][i]=1;
				}
				else if ((d1< d0) and (d1<d2))
				{
					aligned[1][i][j]=1;
					//aligned[1][j][i]=1;
				}
				else
				{
					aligned[2][i][j]=1;
					//aligned[2][j][i]=1;
				}
				align_cnt++;
			}

			if (min(min(d3 ,d4),d5)<ALIGN_THRESH)
			{
				if ((d3< d4) and (d3<d5))
				{
					aligned[3][i][j]=1;
					//aligned[3][j][i]=1;
				}
				else if ((d4< d3) and (d3<d5))
				{
					aligned[4][i][j]=1;
					//aligned[4][j][i]=1;
				}
				else
				{
					aligned[5][i][j]=1;
					//aligned[5][j][i]=1;
				}
				align_cnt++;
			}
		}
	}

	
	
	
	int num_constraints=align_cnt;
	
	float **C=(float **)malloc(num_constraints*sizeof(float *));
	
	for (int i=0;i <num_constraints;i++)
	{
		C[i]=(float *)malloc(ne*2*sizeof(float));
		//memset(C[i],0,ne*2*sizeof(float));
		for (int j=0;j < 2*ne;j++)
			C[i][j]=0;
		
	}

	
	
	//float *loc=(float *)malloc(ne*2*sizeof(float));
	//memset(loc,0,ne*2*sizeof(float));
	//float *b=(float *)malloc(num_constraints*sizeof(float));
	//memset(b,0,num_constraints*sizeof(float));
	
	
	int cnt=0;
	
	for (int k=0;k<6;k++)
	{
		int offset = (int(k>=3))*ne;
		for (int i=0;i<ne;i++)
		for (int j=i+1;j<ne;j++)
		{		
				if (aligned[k][i][j])
				{
					if (debug)
						printf("constraint between element %i and %i, type %i, dist %f\n",i,j,k,align_dist[k][i][j]);
					C[cnt][offset+i]=1;
					C[cnt][offset+j]=-1;
					//b[cnt] = -1*align_dist[k][i][j];
					cnt++;
				}
		}
	}
	
	/*
	for (int i=0;i<ne;i++)
	{
		loc[i]=elem_bb[i].l/scale;
		loc[i+ne]=elem_bb[i].b/scale;
	}
	*/
	
	if (debug)
		printf("getting height constraints\n");
	
	
	float **H=(float **)malloc(ne*sizeof(float *));
	
	//int num_height_constraint=0;
	
	for (int i=0;i <ne;i++)
	{
		H[i]=(float *)malloc(ne*3*sizeof(float));
		//memset(C[i],0,ne*2*sizeof(float));
		for (int j=0;j < 3*ne;j++)
			H[i][j]=0;
		
		//check x-alignment
		int x_align=0;
		int y_align=3;
		

		
		for (int j=0;j<ne;j++)
		{
			int m=min(i,j);
			int n=max(i,j);
			
			if (aligned[2][m][n])
				x_align=2;
			else if (aligned[1][m][n])
				x_align=1;
				
			if (aligned[5][m][n])
				y_align=5;
			else if (aligned[4][m][n])
				y_align=4;			
		}
		
		if (debug)
			printf("height constraints %i, align %i %i\n",i,x_align,y_align);
			
		//set height 
		H[i][i+2*ne]=1;
		
		//x-center aligned, so have to shift left half the new width
		if (x_align==1)
		{
			H[i][i]=-0.5*(1.0/aspect_ratio[i]);
			if (debug)
				printf("\t center aligned, aspect ratio %f, shift %.2f\n",aspect_ratio[i],-0.5*(1.0/aspect_ratio[i]));
		}
		//right aligned, so have to shift left the new width
		else if(x_align==2)
			H[i][i]=-(1.0/aspect_ratio[i]);
		
		
		//y-center aligned, so have to shift down half the new width
		if (y_align==4)
			H[i][i+ne]=-0.5;
		//top aligned, so have to shift down the new height
		else if(y_align==5)
			H[i][i+ne]=-1;
		
	}
	
	
	
	//free(loc);

	//*b_out=b;
	//*loc_out=loc;
	*C_out=C;
	*H_out=H;
	
	return num_constraints;
	
}

       
void getSVD(int num_constraints, int num_var, float **C, float ***Q_out, float ***W_out, float **a_out)
{
	

	float **Q=(float **)malloc(num_var*sizeof(float *));
	float **W=(float **)malloc(num_var*sizeof(float *));
	
	for (int i=0;i <num_var;i++)
	{
		Q[i]=(float *)malloc(num_var*sizeof(float));
		memset(Q[i],0,num_var*sizeof(float));
		W[i]=(float *)malloc(num_var*sizeof(float));
		memset(W[i],0,num_var*sizeof(float));	
	}
	
	
	float *a=(float *)malloc(num_var*sizeof(float));
	memset(a,0,num_var*sizeof(float));	
	
	
	for (int i=0;i<num_var;i++)
	for (int j=0;j<num_var;j++)
	{
		float prod=0;
		
		for (int k=0;k<num_constraints;k++)
			prod+=C[k][i]*C[k][j];
		
		Q[i][j]=prod;
		
	}
	
	
	dsvd(Q, num_var, num_var, a,W);
	
	for (int i=0;i<num_var;i++)
	{
		//printf("SV %i, %.3f\n",i,a[i]);
		
		for (int j=0;j<num_var;j++)
		{
			//printf("\t %.3f\n",W[j][i]);
			if 	(a[i]<0.001)
			{
				if (abs(W[j][i])>0.01)
					W[j][i]=1;
				else
					W[j][i]=0;
			}
		}
		
	}
	
	/*
    Q=np.dot(C.T, C)
    W,A,V=la.svd(Q)  
    A2=np.diag(1/np.sqrt(A+0.0001))
    D=np.dot(W,A2)
	*/



	*Q_out=Q;
	*W_out=W;
	*a_out=a;
	
}      
       
       
int  getConstraintDirections(Design *h_d, float *h_init_layout, float **D_out,bool debug)
{
	
	int nv=h_d->num_elements*3;
	int ne=h_d->num_elements;
	
	float **C,**H;
	//float *b, *loc;
	int nc= getConstraints(h_d, h_init_layout, &C, &H,debug);
	
	
	float **Q,**W,*a;
	getSVD(nc,h_d->num_elements*2,C, &Q, &W, &a);
	
	
	
	int nd=0;

	for (int i=0;i <ne*2;i++)
	{
		if (a[i]<0.01)
			nd++;
		
	}

	nd+=ne;
	
	if (debug)
		printf("num dir %i, num var %i,num constraints %i, num elements %i\n",nd,nv,nc,ne);
	


	float *D=(float *)malloc(nv*nd*sizeof(float));
	memset(D,0,nv*nd*sizeof(float));

	
	//set position directions
	int d_cnt=0;
	for (int i=0;i <ne*2;i++)
	{
		if (a[i]<0.01)
		{	
			if (debug)
				printf("constraint direction %i %i\n",i,nd);
			
			for (int j=0;j<ne*2;j++)
			{
				if ((W[j][i]!=0) && (debug))
					printf("\t x/y:%i, elem:%i, c:%.3f\n",j/(ne),j%(ne),W[j][i]);
				D[d_cnt*nv+j]=W[j][i];
			}
			d_cnt+=1;
		}
	}
	
	//memcpy(&(D[((d_cnt)*nv)]), H, ne*3*sizeof(float));
	
	
	//heights
	for (int i=0;i <ne;i++)
	{	
		if (debug)
			printf("height direction %i\n",i);
			
		int idx=(i+d_cnt)*nv ;
		for (int j=0;j <3*ne;j++) 
		{
			if  ((H[i][j]!=0) && (debug))
				printf("\t %.3f\n",H[i][j]);
			D[idx+ j]=H[i][j];
		}
	}
	
	
	//free memory
	for (int i=0;i <nc;i++)
		free(C[i]);
		
	for (int i=0;i <ne;i++)
		free(H[i]);
	
	if (nc>0)
	{
		free(C);
		free(H);
		//free(b);
		//free(loc);
	}
	
	
	for (int i=0;i <ne*2;i++)
	{
		free(Q[i]);
		free(W[i]);
	}
	free(Q);
	free(W);
	free(a);
	
	
	*D_out=D;
	
	return nd;
}      
       

float constrainedGradientDescent(Design *h_d,Design *d,int num_params, float *params,float *atan_params, float *params_grads, float *h_params,  float *h_init_layout,int num_previous_layout, float *previous_layout)
{
	
	
	int num_var=h_d->num_elements*3 ;
	
	static float dir_time=0;
	static float gd_time=0;
	static float fd_time=0;
	static int cnt_time=0;
	//float fd_time1=0;
	int fd_cnt=0;
	
	clock_t start=clock();
	
	
	float *h_directions;
	int num_dir= getConstraintDirections(h_d, h_init_layout, &h_directions,false);
	
	clock_t end_dir=clock();
	
	cnt_time++;
	dir_time+=end_dir-start;
	
	
	float *h_dir_map=(float *)malloc(num_dir*h_d->layout_size*sizeof(float));
	memset(h_dir_map,0,num_dir*h_d->layout_size*sizeof(float));
	
	for (int i=0;i< num_dir;i++)
	{
		float *h_dir=&(h_directions[i*num_var]);
		float *h_map=&(h_dir_map[i*h_d->layout_size]);
		
		for(int j=0;j<num_var;j++)
		{
			if (abs(h_dir[j])>0.01)
			{
				
				int elem=(j%h_d->num_elements);
				int elem_var=(j/h_d->num_elements);
				int idx=elem*NUM_VAR+elem_var;
				//printf("elem %i, var %i, idx %i, %f\n",elem,elem_var,idx,h_dir[j]);
				
				if (h_init_layout[elem*NUM_VAR+4]<FIX_LAYOUT_THRESH)
					h_map[idx]=h_dir[j];	
								
			}
		}
	}
		
	float *dir_map;
	CHECKCALL(cudaMalloc(&dir_map,num_dir*h_d->layout_size*sizeof(float)));
	CHECKCALL(cudaMemcpy(dir_map, h_dir_map, num_dir*h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));
	
	

	float *h_gradient=(float *)malloc(num_dir*sizeof(float));
	memset(h_gradient,0,num_dir*sizeof(float) );
	
	
	float *h_line_search=(float *)malloc(num_dir*NUM_LINE_STEPS*sizeof(float));
	memset(h_line_search,0,num_dir*NUM_LINE_STEPS*sizeof(float) );
	
	
	float *h_layout=(float *)malloc(h_d->layout_size*sizeof(float));
	memcpy(h_layout,h_init_layout,h_d->layout_size*sizeof(float));
	
	float *h_layout_next=(float *)malloc(h_d->layout_size*sizeof(float));
	memcpy(h_layout_next,h_init_layout,h_d->layout_size*sizeof(float));
	
	float *h_params_grad=(float *)malloc(num_params*sizeof(float));
	
	
	int max_iter=100;
	
	double init_fx=evaluateLayoutHost(d,h_d,num_params, params, params_grads,  h_layout,h_params,  h_params_grad,0,0,false);
	//printf("Init fx %f\n",init_fx);
	
	double fx=init_fx;
	double fx_next=fx+1;

	
    dim3 cudaGridSize(1, 1);
    dim3 cudaBlockSize(num_dir,1);
	
	
    //dim3 cudaGridSize(1, 1);
   // dim3 cudaBlockSize(num_var,1);
	
	float *layouts,*layout,*gradient, *directions,*line_search;
	CHECKCALL(cudaMalloc(&layouts,num_var*h_d->layout_size*sizeof(float)));
	CHECKCALL(cudaMalloc(&layout,h_d->layout_size*sizeof(float)));
	CHECKCALL(cudaMalloc(&directions,num_var*num_dir*sizeof(float)));
	CHECKCALL(cudaMalloc(&gradient,num_var*sizeof(float)));
	CHECKCALL(cudaMalloc(&line_search,num_dir*NUM_LINE_STEPS*sizeof(float)));
	
	CHECKCALL(cudaMemcpy(gradient, h_gradient, num_dir*sizeof(float), cudaMemcpyHostToDevice));
	CHECKCALL(cudaMemcpy(directions, h_directions, num_var*num_dir*sizeof(float), cudaMemcpyHostToDevice));
	
	bool refresh_grad=true;
	
	int i=0;
	int last_update=0;
	for (i=0;i< max_iter;i++)
	for (int dir=0;dir<num_dir;dir++)
	{
		
		
		if (refresh_grad)
		{
			CHECKCALL(cudaMemcpy(layout, h_layout,  h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));
			
			clock_t fd_start=clock();
			
			
			finiteDiffLayoutGrad<<<cudaGridSize, cudaBlockSize>>>(d,num_dir,directions,dir_map,num_params,params, atan_params, params_grads, layout,layouts, gradient,line_search,num_previous_layout, previous_layout);
	
	    	CHECKCALL(cudaGetLastError());
	    	CHECKCALL(cudaDeviceSynchronize());
	
			CHECKCALL(cudaMemcpy(h_gradient, gradient,num_dir*sizeof(float), cudaMemcpyDeviceToHost));
			CHECKCALL(cudaMemcpy(h_line_search, line_search,num_dir*NUM_LINE_STEPS*sizeof(float), cudaMemcpyDeviceToHost));
			
			fd_time+=clock()-fd_start;
			fd_cnt++;
			
			//printf("i %i, dir %i, fd_cnt %i\n",i,dir,fd_cnt);
			
			refresh_grad=false;
		}
		
		
		float *h_dir=&(h_dir_map[dir*h_d->layout_size]);
		if ((!finite(h_gradient[dir])))
		{
			printf("ERROR in gradient %f, dir %i\n",h_gradient[dir],dir);
			continue;			
		}
		
		//memcpy(h_layout_next,h_layout,h_d->layout_size*sizeof(float));
		
		
		float *h_lsearch=&(h_line_search[dir*NUM_LINE_STEPS]);
		
		
		double delta=FD_DELTA;
		if (h_gradient[dir]>0)
			delta=-1*delta;
			
		//printf("start, eval %f\n",h_lsearch[0]);
		
		float min_eval=h_lsearch[0];
		float min_delta=0;
			
		for (int j=1;j<NUM_LINE_STEPS;j++)
		{
			if (min_eval>h_lsearch[j])
			{
				min_eval=h_lsearch[j];
				min_delta=delta;
				
			}
			else
				break;
			
			delta=delta*2;
		}
		
		for(int j=0;j<h_d->layout_size;j++)
			h_layout_next[j]=h_layout[j]+min_delta*h_dir[j];	

		
		fx_next=min_eval;
		//fx_next=evaluateLayoutHost(d,h_d,num_params, params, params_grads,  h_layout_next,h_params,  h_params_grad,false);
		//if (fx_next!=min_eval)
		//	printf("ERROR dir %i, fx next %f, min_eval %f\n",dir,fx_next,min_eval);
			
		if (fx_next==INVALID_ELEMENT_ERROR)
			printf("INVALID_ELEMENT_ERROR called from outer constraint step\n");
		
		

		
		//printf("dir %i, grad %.3f,stepsize %.3f, fx %.3f,last fx %.3f,diff %.3f\n",dir,h_gradient[dir],h_gradient[dir]*grad_par,fx,last_fx,fx-last_fx);
		
		/*
		if (!finite(fx_next)) 
		{
			fx_next=evaluateLayoutHost(d,h_d,num_params, params, params_grads,  h_layout_next,h_params,  h_params_grad,true);
				
			printf("ERROR. Not finite.  %f\n",fx_next);
			
			for (int k=0;k< h_d->num_elements;k++)
				printf("%f %f %f\n",h_layout_next[k*NUM_VAR],h_layout_next[k*NUM_VAR+1],h_layout_next[k*NUM_VAR+2]);
			
			
			for (int k=0;k<NUM_FEATURES;k++)
				printf("%i\t%5.1f \t %4.2f\t %4.2f \t nl: %4.2f %s \n", k,h_params[k],h_params_grad[k],h_params[k]*h_params_grad[k],h_params[k+NUM_FEATURES],feat_names[k]);
		
		}
		*/
		
		//try to make an update 
		if ((finite(fx_next)) && (fx_next<fx-0.05))
		{
			memcpy(h_layout,h_layout_next,h_d->layout_size*sizeof(float));
			last_update=i;
			//printf("GD iteration %i,fx %.3f, dir %i, grad %.3f, fx diff %.3f\n",i,fx,dir,h_gradient[dir],last_fx-fx);	
			refresh_grad=true;
			
			fx=fx_next;
		}
	
		
		//printf("GD iteration %i, fx %.3f\n",i, fx);		
		
		if (i-last_update>1)
		{
			
			
			free(h_layout_next);
			free(h_gradient);
			
			CHECKCALL(cudaFree(line_search));
			CHECKCALL(cudaFree(directions));
			CHECKCALL(cudaFree(layouts));
			CHECKCALL(cudaFree(layout));
			CHECKCALL(cudaFree(gradient));
				
			clock_t end=clock();
			gd_time+=(end-end_dir);
			
			
			
			printf("iteration %i, last_update %i,fd cnt %i mean time %.3f, dir time %.3f, gd time %.3f\n",i,last_update,fd_cnt, 1000*(fd_time/cnt_time)/CLOCKS_PER_SEC,1000*(dir_time/cnt_time)/CLOCKS_PER_SEC , 1000*(gd_time/cnt_time)/CLOCKS_PER_SEC); 
			
			
			if (fx<init_fx)
			{
				//printf("GD from %.4f to %.4f. imp %.3f, in %i iterations \n",init_fx,fx,fx-init_fx,i-1);
				memcpy(h_init_layout ,h_layout,h_d->layout_size*sizeof(float));
				free(h_layout);
				return fx;
			}
			
			return init_fx;
		}
	}
	
	printf("Returning init fx %f\n",init_fx);
	//CHECKCALL(cudaFree(layouts));
	//return init_fx;
	return init_fx;

}




/*
void finiteDiffLayoutGrad(Design *d,Design *h_d,int num_params, float *params, float *params_grads, float *h_params,  float *h_params_grad, float *h_layout, float *h_layout_grad)
{

	int num_var=h_d->num_elements*NUM_VAR;
	
	memset(h_layout_grad,0,sizeof(float) * h_d->layout_size);

	float *h_layout_copy=(float *)malloc(sizeof(float) * h_d->layout_size);
	memcpy(h_layout_copy,h_layout,sizeof(float) * h_d->layout_size);

	double delta=0.001;

	for (int i=0;i<num_var;i++)
	{
		
		if (i%NUM_VAR>2)
			continue;

		for(int j=0;j<num_var;j++)
			h_layout_copy[j]=h_layout[j];

		h_layout_copy[i]=h_layout[i]+delta;

		double y2=evaluateLayoutHost(d,h_d,num_params, params, params_grads,  h_layout_copy,h_params,  h_params_grad,false);


		h_layout_copy[i]=h_layout[i]-delta;

		double y1=evaluateLayoutHost(d,h_d,num_params, params, params_grads,  h_layout_copy,h_params,  h_params_grad,false);



		h_layout_grad[i]=(float)((y2-y1)/(2.0*delta));

		//printf("%i y1: %.3f, y2: %.3f, grad: %.3f\n",i,y1,y2,h_params_grad_fd[i]);
	}

	free(h_layout_copy);
}
*/




void finiteDiffGrad(Design *d,Design *h_d,int num_params, float *params, float *params_grad,  float *h_layout,float *h_params,  float *h_params_grad,float *h_params_grad_fd)
{

	float *h_params_copy=(float *)malloc(sizeof(float) * num_params);

	double delta=0.001;

	for (int i=0;i<num_params;i++)
	{

		for(int j=0;j<num_params;j++)
			h_params_copy[j]=h_params[j];

		h_params_copy[i]=h_params_copy[i]+delta;

		double y2=evaluateLayoutHost(d,h_d,num_params, params, params_grad,  h_layout,h_params_copy,  h_params_grad,0,0,false);

		for(int j=0;j<num_params;j++)
			h_params_copy[j]=h_params[j];

		h_params_copy[i]=h_params_copy[i]-delta;

		double y1=evaluateLayoutHost(d,h_d,num_params, params, params_grad,  h_layout,h_params_copy,  h_params_grad,0,0,false);

		//if (i>=NUM_FEATURES)
		//	delta2=exp(delta);

		h_params_grad_fd[i]=(float)((y2-y1)/(2.0*delta));

		//printf("%i y1: %.3f, y2: %.3f, grad: %.3f\n",i,y1,y2,h_params_grad_fd[i]);
	}

	free(h_params_copy);

}


float evaluateLayoutHost(Design *d,Design *h_d,int num_params, float *params, float *params_grad,  float *h_layout,float *h_params,  float *h_params_grad,int num_prev_layout,float *previous_layout, bool debug)
{
	float *eval, h_eval;
	CHECKCALL(cudaMalloc(&eval,sizeof(float)));
	

	float *layout;
	CHECKCALL(cudaMalloc(&layout,h_d->layout_size*sizeof(float)));
	CHECKCALL(cudaMemcpy(layout, h_layout,  h_d->layout_size*sizeof(float), cudaMemcpyHostToDevice));
	CHECKCALL(cudaMemcpy(params, h_params,  num_params*sizeof(float), cudaMemcpyHostToDevice));


	float *atan_params;
	CHECKCALL(cudaMalloc(&atan_params,num_params*sizeof(float)));
	float *h_atan_params= (float *)malloc(num_params*sizeof(float));

	for (int j=0;j<num_params;j++)
		h_atan_params[j]=atan(h_params[j]);
	CHECKCALL(cudaMemcpy(atan_params, h_atan_params,num_params*sizeof(float), cudaMemcpyHostToDevice));


	if (debug)
		evaluateLayoutKernelDebug<<<1, 1>>>(d,layout,params, atan_params,params_grad,num_prev_layout,previous_layout, eval);
	else
		evaluateLayoutKernel<<<1, 1>>>(d,layout,params, atan_params,params_grad,num_prev_layout,previous_layout, eval);

	CHECKCALL(cudaGetLastError());
	CHECKCALL(cudaDeviceSynchronize());

	CHECKCALL(cudaMemcpy(&h_eval, eval,  sizeof(float), cudaMemcpyDeviceToHost));
	CHECKCALL(cudaMemcpy(h_params_grad, params_grad,  num_params*sizeof(float), cudaMemcpyDeviceToHost));


	/*
	float test_eval1=-500;
	for (int i=0;i<NUM_FEATURES;i++)
		test_eval1+=h_params[i]*h_params_grad[i];
	
	if ((!isnan(test_eval1)) && (abs(test_eval1-h_eval)>0.1))
		printf("error %f %f\n",test_eval1,h_eval);
	*/


	free(h_atan_params);
	CHECKCALL(cudaFree(eval));
	CHECKCALL(cudaFree(layout));
	CHECKCALL(cudaFree(atan_params));

	return h_eval;
}




/* Catches signal interrupts from Ctrl+c.
   If 1 signal is detected the simulation finishes the current frame and
   exits in a clean state. If Ctrl+c is pressed again it terminates the
   application without completing writes to files or calculations but
   deallocates all memory anyway. */
void sig_handler (int sig)
{
  if ((sig == SIGTERM) || (sig==SIGINT))
    {     

      // write a function to free dynamycally allocated memory
      //free_mem ();
  
      cleanup();
    
   	  exit (9);
    }
}

void cleanup()
{
  
  freeMemory();

  int devCount;
  cudaGetDeviceCount (&devCount);

  for (int i = 0; i < devCount; ++i)
    {
    std::cout << "cudaDeviceReset\n";
      cudaSetDevice (i);
      cudaDeviceReset ();
    }


}







/*
size_t free_byte ;
size_t total_byte ;
cudaError_t cuda_status = cudaMemGetInfo( &free_byte, &total_byte ) ;
if ( cudaSuccess != cuda_status ){
    printf("Error: cudaMemGetInfo fails, %s \n", cudaGetErrorString(cuda_status) );
    exit(1);
}

double free_db = (double)free_byte ;
double total_db = (double)total_byte ;
double used_db = total_db - free_db ;

printf("GPU memory usage: used = %f, free = %f MB, total = %f MB\n",
    used_db/1024.0/1024.0, free_db/1024.0/1024.0, total_db/1024.0/1024.0);
*/



    /*

		
		//do refinement updates first
		for (int i=0;i< num_kernels-1;i++)
    	{
    		int curr=i;
    		float temp1=h_temperatures[curr];
    		float temp2=h_temperatures[curr+1];

    		float energy1=h_evals[curr];
    		float energy2=h_evals[curr+1];

    		float prop=exp((1.0/temp1-1.0/temp2)*(energy1-energy2));
    		float r=rand()/ double(RAND_MAX);			
			
			
			//switch state
    		if (r<min(1.0,prop))
			{
				
				float temp_eval=h_evals[curr];
				h_evals[curr]=h_evals[curr+1];
				h_evals[curr+1]=temp_eval;
				
				for (int k=0;k<h_d->layout_size;k++)
				{
					float temp_layout=h_opt_layouts[curr*h_d->layout_size+k];
					h_opt_layouts[curr*h_d->layout_size+k]=h_opt_layouts[(curr+1)*h_d->layout_size+k];
					h_opt_layouts[(curr+1)*h_d->layout_size+k]=temp_layout;
				}
			}
			
    	}
    	
	 	for (int i=0;i< num_kernels;i++)
				for (int j=0;j<h_d->num_elements;j++)
					if ((h_opt_layouts[i*h_d->layout_size + j*NUM_VAR+2]==0) && (h_opt_layouts[i*h_d->layout_size+ j*NUM_VAR+3]==0))
						printf("ERROR-2 in kernel %i element %i. init element is 0\n",i,j);
	    
    		
    	
    	//do refinement updates first
		for (int i=0;i< grid_size;i++)
    	for (int j=0;j< grid_size-1;j++)
    	{
    		int curr=i*grid_size+j;
    		float temp1=h_temperatures[curr];
    		float temp2=h_temperatures[curr+1];

    		float energy1=h_evals[curr];
    		float energy2=h_evals[curr+1];

    		float prop=exp((1.0/temp1-1.0/temp2)*(energy1-energy2));
    		float r=rand()/ double(RAND_MAX);			
			
			
			//switch state
    		if (r<min(1.0,prop))
			{
				
				float temp_eval=h_evals[curr];
				h_evals[curr]=h_evals[curr+1];
				h_evals[curr+1]=temp_eval;
				
				for (int k=0;k<h_d->layout_size;k++)
				{
					float temp_layout=h_opt_layouts[curr*h_d->layout_size+k];
					h_opt_layouts[curr*h_d->layout_size+k]=h_opt_layouts[(curr+1)*h_d->layout_size+k];
					h_opt_layouts[(curr+1)*h_d->layout_size+k]=temp_layout;
				}
			}
    	}
    	
    	
 		for (int i=0;i< num_kernels;i++)
			for (int j=0;j<h_d->num_elements;j++)
				if ((h_opt_layouts[i*h_d->layout_size + j*NUM_VAR+2]==0) && (h_opt_layouts[i*h_d->layout_size+ j*NUM_VAR+3]==0))
					printf("ERROR-2 in kernel %i element %i. init element is 0\n",i,j);

    	//switch layouts based on the diagonal
    	for (int i=0;i< grid_size-1;i++)
    	{
    		int curr=i*grid_size+i;
    		int next=(i+1)*grid_size+i+1;
    		
    		float temp1=h_temperatures[curr];
    		float temp2=h_temperatures[curr+1];

    		float energy1=h_evals[curr];
    		float energy2=h_evals[curr+1];

    		float prop=exp((1.0/temp1-1.0/temp2)*(energy1-energy2));
    		float r=rand()/ double(RAND_MAX);	

    		if (r<min(1.0,prop))
			{
				float temp_eval=h_evals[curr];
				h_evals[curr]=h_evals[next];
				h_evals[next]=temp_eval;

				//overwrite entire refinement optimizer with new layout
				
				
				for (int k=0;k<h_d->layout_size;k++)
				{
					float temp_layout=h_opt_layouts[curr*h_d->layout_size+k];
					h_opt_layouts[curr*h_d->layout_size+k]=h_opt_layouts[next*h_d->layout_size+k];
					h_opt_layouts[next*h_d->layout_size+k]=temp_layout;
				}
				
				for (int j=0;j< grid_size;j++) 
				{
					
					h_evals[i*grid_size+j]=h_evals[curr];
					h_evals[(i+1)*grid_size+j]=h_evals[next];		
					
					for (int k=0;k<h_d->layout_size;k++)
					{
						
						h_opt_layouts[(i*grid_size+j)*h_d->layout_size+k]=h_opt_layouts[(curr)*h_d->layout_size+k];
						h_opt_layouts[((i+1)*grid_size+j)*h_d->layout_size+k]=h_opt_layouts[(next)*h_d->layout_size+k];
						
					}
				}
			}
    	}
    	
   		for (int i=0;i< num_kernels;i++)
			for (int j=0;j<h_d->num_elements;j++)
				if ((h_opt_layouts[i*h_d->layout_size + j*NUM_VAR+2]==0) && (h_opt_layouts[i*h_d->layout_size+ j*NUM_VAR+3]==0))
					printf("ERROR-3 in kernel %i element %i. init element is 0\n",i,j);
    	* */
   
   

