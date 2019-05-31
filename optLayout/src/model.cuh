
#ifndef __MODEL_H__
#define __MODEL_H__

#include "design.cuh"





#define TEXT_SIZE_FEAT 0
#define GRAPHIC_SIZE_FEAT 1
#define MIN_TEXT_SIZE_FEAT 2
#define MIN_GRAPHIC_SIZE_FEAT 3
#define WHITESPACE_FEAT 4
#define SPREAD_FEAT 5
#define TEXT_OUT_OF_BOUNDS_FEAT 6
#define GRAPHIC_OUT_OF_BOUNDS_FEAT 7
#define TEXT_OVERLAP_FEAT 8
#define GRAPHIC_OVERLAP_FEAT 9
#define GRAPHIC_TEXT_OVERLAP_FEAT 10
#define TEXT_XSYMMETRY_FEAT 11
#define TEXT_YSYMMETRY_FEAT 12
#define GRAPHIC_XSYMMETRY_FEAT 13
#define GRAPHIC_YSYMMETRY_FEAT 14
#define ALIGN_XLEFT_FEAT 15
#define ALIGN_XCENTER_FEAT 16
#define ALIGN_XRIGHT_FEAT 17
#define ALIGN_YBOTTOM_FEAT 18
#define ALIGN_YCENTER_FEAT 19
#define ALIGN_YTOP_FEAT 20
#define ALIGN_XERROR_FEAT 21
#define ALIGN_YERROR_FEAT 22
#define ALIGN_GROUP_SIZES_FEAT 23
#define TEXT_IMPORTANCE_PEARSON_FEAT 24
#define GRAPHIC_IMPORTANCE_PEARSON_FEAT 25
#define TEXT_XPOS_FEAT 26
#define GRAPHIC_XPOS_FEAT 27
#define TEXT_YPOS_FEAT 28
#define GRAPHIC_YPOS_FEAT 29
#define TEXT_XPOS_REVERSE_FEAT 30
#define GRAPHIC_XPOS_REVERSE_FEAT 31
#define TEXT_YPOS_REVERSE_FEAT 32
#define GRAPHIC_YPOS_REVERSE_FEAT 33
#define PAIRWISE_DIST_AVG_FEAT 34
#define PAIRWISE_DIST_MIN_FEAT 35
#define TEXT_MARGIN_DIST_AVG_FEAT 36
#define TEXT_MARGIN_DIST_MIN_FEAT 37
#define GRAPHIC_MARGIN_DIST_AVG_FEAT 38
#define GRAPHIC_MARGIN_DIST_MIN_FEAT 39
#define TEXT_SIZE_VAR_FEAT 40
#define TEXT_XFLOW_FEAT 41
#define TEXT_YFLOW_FEAT 42
#define NUM_REGIONS_FEAT 43
#define TEXT_REGION_XSYMMETRY_FEAT 44
#define GRAPHIC_REGION_XSYMMETRY_FEAT 45
#define TEXT_XSYMMETRY_REVERSE_FEAT 46
#define TEXT_YSYMMETRY_REVERSE_FEAT 47
#define GRAPHIC_XSYMMETRY_REVERSE_FEAT 48
#define GRAPHIC_YSYMMETRY_REVERSE_FEAT 49
#define TEXT_XPOS_VAR_FEAT 50
#define GRAPHIC_XPOS_VAR_FEAT 51
#define TEXT_YPOS_VAR_FEAT 52
#define GRAPHIC_YPOS_VAR_FEAT 53
#define TEXT_DIST_FEAT 54
#define ELEMENT_REGION_DIFF_FEAT 55
#define EMPTY_REGION_FEAT 56
#define REGION_OVERLAP_FEAT 57
#define LINE_LENGTH_FEAT 58
//max element features
#define ELEMENT_POSITION_DIFF_FEATS 59
#define ELEMENT_HEIGHT_DIFF_FEATS 74
#define GRAPHIC_SIZE_VAR_FEAT 89
#define TEXT_DIAG_FLOW_FEAT 90
#define GROUP_DIST_FEAT 91
#define NO_OVERLAP_FEAT 92
#define TEXT_SIZE_REVERSE_FEAT 93
#define GRAPHIC_SIZE_REVERSE_FEAT 94
#define WHITESPACE_REVERSE_FEAT 95
#define PREVIOUS_LAYOUT_FEAT 96
#define GROUP_ALIGN_FEAT 97
#define GROUP_TEXT_SIZE_VAR_FEAT 98
#define GROUP_GRAPHIC_SIZE_VAR_FEAT 99
#define GROUP_ALIGN_X_VAR_FEAT 100
#define GROUP_ALIGN_Y_VAR_FEAT 101
#define HIDDEN_ELEM_FEAT 102
#define ALIGN_LINES_FEAT 103
#define SIZE_CONSTRAINTS_FEAT 104
#define ALIGN_CONSTRAINTS_FEAT 105
#define RELATIVE_DIFF_FEAT 106

#define NUM_FEATURES 107


#define SIZE_CONSTRAINT 10
#define ALIGN_CONSTRAINT 11


#define DEBUG 1


#define EVAL_SPLIT_NUM 2


#define INVALID_ELEMENT_ERROR 99998
#define OOB_ERROR 99997
#define INVERTED_ERROR 99996
#define CHECK_LAYOUT_ERROR 99995
#define ASPECT_RATIO_ERROR 99994
#define ZERO_AREA_ERROR 99993

#define sum(x, y, select) \
    y=0;							\
	for (int q=0;q<sizeof(x);q++)	\
	{								\
		if (select[q])				\
		{							\
			y+=x[q];				\
		}							\
	}								\


#define square(x) x*x

float *loadParametersFromFile(char * default_param_file, char *filename,int num_params);
float *readParameters(char *filename,int num_params);
void saveParametersToFile(char *filename,float *params,int num_params);
void addParameterOffsets(char *filename, int num_params, float *h_params);
__device__ double evaluateLayout(Design *d, float *layout, float *params,   float *atan_params,float *params_grad, int num_previous_layout, float *previous_layout, bool multithread,bool debug, bool calc_gradient);
__device__ float atan_deriv(float x,float y);

__global__ void evaluateLayoutKernel(Design *d, float *layout, float *params, float *atan_params, float *params_grad, int num_previous_layout, float *previous_layout, float *eval);
__global__ void evaluateLayoutKernelDebug(Design *d, float *layout, float *params, float *atan_params, float *params_grad, int num_previous_layout, float *previous_layout, float *eval);




#define ALIGN_THRESH 0.045

#define NIO_DEFAULT -99999

/*
__device__ void getWhiteSpaceFeatures(float *feat, Design *d,float *xpos,float *ypos,float *heights,float *alts)
{
}
*/

extern const char* feat_names[];



#define sigmoid(x) (1.0/(1.0+exp(-1.0*x)))

//__device__ float atan_deriv(float x,float y,float atan_y,float atan_xy)
//{
//	 float a=x/(((y*y*x*x)+1)*atan_y);
//	 float b=atan_xy / (((y*y)+1)*(atan_y*atan_y));
//	 return (a-b);
//}

#define atan_deriv(x,y,atan_y,atan_xy) (x/(((y*y*x*x)+1)*atan_y)  - atan_xy / (((y*y)+1)*(atan_y*atan_y)))


/*
 * 	if (type==1)\
	{\
		features[f_cnt]=(1-atan_xy/atan_2_param);\
		//nio_grads[f_cnt]=-1*atan_deriv(feat,atan_param,atan_2_param,atan_xy);\
	}\
	else if (type==2)\
	{\
		features[f_cnt]=(-1-atan_xy/atan_2_param);\
		nio_grads[f_cnt]=-1*atan_deriv(feat,atan_param,atan_2_param,atan_xy);\
	}\
	else\
	{\
		nio_grads[f_cnt]=atan_deriv(feat,atan_param,atan_2_param,atan_xy);\
		features[f_cnt]=atan_xy/atan_2_param;\
	}\
 */


#define setFeature(feat_num,f_cnt, feat,type,params,atan_params,features,features_ids,nio_grads) \
{ \
	atan_param=params[NUM_FEATURES+feat_num];\
	atan_2_param=atan_params[NUM_FEATURES+feat_num];\
	atan_xy=atan(feat*atan_param); \
	if (type==1)\
	{\
		features[f_cnt]=(1-atan_xy/atan_2_param);\
		nio_grads[f_cnt]=-1*atan_deriv(feat,atan_param,atan_2_param,atan_xy);\
	}\
	else if (type==2)\
	{\
		features[f_cnt]=(-1-atan_xy/atan_2_param);\
		nio_grads[f_cnt]=-1*atan_deriv(feat,atan_param,atan_2_param,atan_xy);\
	}\
	else\
	{\
		features[f_cnt]=atan_xy/atan_2_param;\
		nio_grads[f_cnt]=atan_deriv(feat,atan_param,atan_2_param,atan_xy);\
	}\
	nio_grads[f_cnt]=0;\
	features_ids[f_cnt]=feat_num;\
	f_cnt++;\
}





#endif
