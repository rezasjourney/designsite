

#include "model.cuh"
//#include "design.cuh"


#define NUM_POINTS 5
__device__ const float spread_check_loc_x[NUM_POINTS] = {0.0,0.0,1.0,1.0,0.5};
__device__ const float spread_check_loc_y[NUM_POINTS] = {0.0,1.0,0.0,1.0,0.5};
//#define NUM_POINTS 5
//__device__ const float spread_check_loc_x[NUM_POINTS] = {0.0,0.0,0.0,1.0,1.0,1.0,0.5,0.5,0.5};
//__device__ const float spread_check_loc_y[NUM_POINTS] = {0.0,0.5,1.0,0.0,0.5,1.0,0.0,1.0,0.5};

const char* feat_names[] = {
			"Text Size",
			"Graphic Size",
			"Min Text Size",
			"Min Graphic Size",
			"Whitespace",
			"Spread",
			"Text Out of Bounds",
			"Graphic Out of Bounds",
			"Text Overlap",
			"Graphic Overlap",
			"Graphic Text Overlap",
			"Text X Symmetry",
			"Text Y Symmetry",
			"Graphic X Symmetry",
			"Graphic Y Symmetry",
			"Align X-Left",
			"Align X-Center",
			"Align X-Right",
			"Align Y-Bottom",
			"Align Y-Center",
			"Align Y-Top",
			"Align Error X",
			"Align Error Y",
			"Align Group Sizes",
			"Text Importance Pearson",
			"Graphic Importance Pearson",
			"Text X Position",
			"Graphic X Position",
			"Text Y Position",
			"Graphic Y Position",
			"Text X Position - Reverse",
			"Graphic X Position - Reverse",
			"Text Y Position - Reverse",
			"Graphic Y Position - Reverse",
			"Pairwise Distances Avg",
			"Pairwise Distances Min",
			"Text Margins Avg",
			"Text Margins Min",
			"Graphic Margins Avg",
			"Graphic Margins Min",
			"Text Size Variance",
			"Text X Flow",
			"Text Y Flow",
			"Num Regions",
			"Text Region X Symmetry",
			"Graphic Region X Symmetry",
			"Text X Reverse Symmetry",
			"Text Y Reverse Symmetry",
			"Graphic X Reverse Symmetry",
			"Graphic Y Reverse Symmetry",
			"Text X Position Variance",
			"Graphic X Position Variance",
			"Text Y Position Variance",
			"Graphic Y Position Variance",
			"Text Distances Avg",
			"Element Region Difference",
			"Empty Region",
			"Region Overlap",
			"Line Length",
			"Element 0 Position Difference",
			"Element 1 Position Difference",
			"Element 2 Position Difference",
			"Element 3 Position Difference",
			"Element 4 Position Difference",
			"Element 5 Position Difference",
			"Element 6 Position Difference",
			"Element 7 Position Difference",
			"Element 8 Position Difference",
			"Element 9 Position Difference",
			"Element 10 Position Difference",
			"Element 11 Position Difference",
			"Element 12 Position Difference",
			"Element 13 Position Difference",
			"Element 14 Position Difference",
			"Element 0 Height Difference",
			"Element 1 Height Difference",
			"Element 2 Height Difference",
			"Element 3 Height Difference",
			"Element 4 Height Difference",
			"Element 5 Height Difference",
			"Element 6 Height Difference",
			"Element 7 Height Difference",
			"Element 8 Height Difference",
			"Element 9 Height Difference",
			"Element 10 Height Difference",
			"Element 11 Height Difference",
			"Element 12 Height Difference",
			"Element 13 Height Difference",
			"Element 14 Height Difference",
			"Graphic Size Variance",
			"Text Diag Flow",
			"Group Distance",
			"No Overlap Regions",
			"Text Size Reverse",
			"Graphic Size Reverse",
			"Whitespace Reverse",
			"Previous Layout",
			"Group Alignment",
			"Group Text Size Variance",
			"Group Graphic Size Variance",
			"Group Graphic X Align Variance",
			"Group Graphic Y Align Variance",
			"Hidden Element",
			"Alignment Lines",
			"Size Constraints",
			"Alignment Constraints",
			"Relative Difference"
};



__device__ float getAtan(Design *d,float x)
{
	int idx=abs(int(x*200.0));

	float a=0;
	if (idx>=20000)
		a= d->atan_fixed[20000-1]+x/20000.0;
	else
		a= d->atan_fixed[idx];

	if (x <0)
		return -a;
	else
		return a;
}



__global__ void evaluateLayoutKernel(Design *d, float *layout, float *params, float *atan_params, float *params_grad,int num_prev_layout,float *previous_layout,  float *eval)
{
	*eval= evaluateLayout(d, layout, params, atan_params, params_grad,num_prev_layout,previous_layout,false,false,true);
}

__global__ void evaluateLayoutKernelDebug(Design *d, float *layout, float *params, float *atan_params, float *params_grad,int num_prev_layout,float *previous_layout, float *eval)
{
	*eval= evaluateLayout(d, layout, params, atan_params, params_grad,num_prev_layout,previous_layout,false,true,true);
}

__device__ double evaluateLayout(Design *d, float *layout, float *params,  float *atan_params, float *params_grad,int num_prev_layout, float *previous_layout, bool multithread,bool debug,bool calc_gradient)
{


	//if (blockIdx.x%EVAL_SPLIT_NUM!=0)
	//	return 99999;

	int thread_id =threadIdx.x +  int(blockIdx.x/EVAL_SPLIT_NUM)  * blockDim.x;


	int eval_id=blockIdx.x%EVAL_SPLIT_NUM;
        
	//printf("thread %i, block %i of %i\n",threadIdx.x,blockIdx.x , blockDim.x);



	/****************************
	 *
	 * Calculate Features Inputs
	 *
	 ***************************/
	
	
	int ne=d->num_elements;
	float scale=max(d->width, d->height);
	float atan_param=0;
	float atan_2_param=0;
	float atan_xy=0;


	Box designBB;
	designBB.set(0,d->width,0,d->height);
	float design_area=designBB.area();

	float height,width,xp,yp;
	
	float visible[MAX_ELEMENTS];
	Box elem_bb[MAX_ELEMENTS];
	
	float aspect_ratio[MAX_ELEMENTS];
	int num_lines[MAX_ELEMENTS];
	int nv=ne;


	for (int i=0;i<ne;i++)
	{
		visible[i]=true;
		
		int alt=int(layout[NUM_VAR*i+6]);
		if (alt>-1)
		{
			//printf("alt %i\n",alt);
			if ((d->num_alt[i]>0))
				aspect_ratio[i]=d->alt_aspect_ratio[i*MAX_ALT+alt];
			else
				aspect_ratio[i]=d->aspect_ratio[i];
				
			if ((d->num_alt[i]>0))
				num_lines[i]=d->alt_num_lines[i*MAX_ALT+alt];
			else
				num_lines[i]=d->num_lines[i];		
				
			
			if (aspect_ratio[i]==0)
				return ASPECT_RATIO_ERROR;
				
			
			height=round(layout[NUM_VAR*i+2]*d->height);
			width=round(height/aspect_ratio[i]);
			xp=round(layout[NUM_VAR*i]*d->width);
			yp=round(layout[NUM_VAR*i+1]*d->height);
	
			elem_bb[i].set(round(xp+(width*d->bb_left[i])), round(xp+(width*d->bb_right[i])), round(yp + (height*d->bb_bottom[i])), round(yp + (height*d->bb_top[i])));
	
			if (height<=0)
			{
				//printf("Invalid negative height: %f\n",layout[NUM_VAR*i+2]);
				return INVALID_ELEMENT_ERROR;	
			}
	
			if ((debug) and (thread_id==0))
			{
				printf("%i: %f %f %f %f, fix %f (w/h) %f %f\n",i, layout[NUM_VAR*i],layout[NUM_VAR*i+1],layout[NUM_VAR*i+2],layout[NUM_VAR*i+3],layout[NUM_VAR*i+4],width,height);
				printf("%i: l/r: %3.3f - %3.3f b/t: %3.3f - %3.3f, ar %.3f, alt %i\n",i,elem_bb[i].l,elem_bb[i].r,elem_bb[i].b,elem_bb[i].t,aspect_ratio[i],alt);
			}
	
			if ((elem_bb[i].l>=elem_bb[i].r) || (elem_bb[i].b>=elem_bb[i].t))
			{
				printf("l>r or b>t for element %i: l/r: %3.3f - %3.3f b/t: %3.3f - %3.3f\n",i,elem_bb[i].l,elem_bb[i].r,elem_bb[i].b,elem_bb[i].t);
				printf("\t %f %f %f %f, w/h: %f %f, ar: %f\n",layout[NUM_VAR*i],layout[NUM_VAR*i+1],layout[NUM_VAR*i+2],layout[NUM_VAR*i+3],width,height,aspect_ratio[i]);
				return INVALID_ELEMENT_ERROR;
			}
	
			if ((elem_bb[i].l<-5*d->width) || (elem_bb[i].t<-5*d->height)|| (elem_bb[i].r>=5*d->width)|| (elem_bb[i].t>=5*d->height))
			//if ((elem_bb[i].r<=0) || (elem_bb[i].t<=0)|| (elem_bb[i].l>=d->width)|| (elem_bb[i].b>=d->height))
			{
				printf("oob %i: %f %f %f %f, w/h: %f %f, ar: %f\n",i, layout[NUM_VAR*i],layout[NUM_VAR*i+1],layout[NUM_VAR*i+2],layout[NUM_VAR*i+3],width,height,aspect_ratio[i]);
				printf("\t l/r: %3.3f - %3.3f b/t: %3.3f - %3.3f\n",elem_bb[i].l,elem_bb[i].r,elem_bb[i].b,elem_bb[i].t);
			
				return INVALID_ELEMENT_ERROR;
			}

		}
		else
		{
			nv--;
			visible[i]=false;
			elem_bb[i].set(-1001,-1000, -1001,-1000);
		}
	}



	float bb_distance[2][MAX_ELEMENTS][MAX_ELEMENTS];

	float dist_scale=sqrt(d->height*d->height + d->width*d->width);

	for (int i=0;i<ne;i++)
	for (int j=i+1;j<ne;j++)
	{
        float locXDiff=-1*min((elem_bb[i].r-elem_bb[j].l),(elem_bb[j].r-elem_bb[i].l));
        bb_distance[0][i][j]=locXDiff;
        bb_distance[0][j][i]=locXDiff;

        float locYDiff=-1*min((elem_bb[i].t-elem_bb[j].b),(elem_bb[j].t-elem_bb[i].b));
        bb_distance[1][i][j]=locYDiff;
        bb_distance[1][j][i]=locYDiff;
	}



	//element types
	bool text_elements[MAX_ELEMENTS];
	bool graphic_elements[MAX_ELEMENTS];

	int num_text=0;
	int num_graphic=0;

	for (int i=0;i<ne;i++)
	{
		if (visible[i])
		{
			if (d->type[i]==1)
			{
				num_text++;
				text_elements[i]=1;
			}
			else
			{
				num_graphic++;
				text_elements[i]=0;
			}
	
			graphic_elements[i]=1-text_elements[i];
		}
	}
	
	if ((debug)&&(num_text==0))
	{
		printf("ERROR. No text elements\n");
		
		for (int i=0;i<ne;i++)
			printf("checking %i type %i visible %i\n",i,int(d->type[i]),int(visible[i]));
	}


	
	//calculate element sizes

	float sizes[MAX_ELEMENTS];
	
	for (int i=0;i<ne;i++)
	{
		if (!visible[i])
			continue;
			
		if (text_elements[i])
			sizes[i]=10.0*(((elem_bb[i].t-elem_bb[i].b)/num_lines[i])/(400));
		else
		{
			Box intersect=getBoxIntersection(designBB,elem_bb[i]);
			sizes[i]=(intersect.t-intersect.b)/ (400);
		}
		if ((thread_id==0) and (debug))
			printf("Size of element %d, f=%f\n", i,sizes[i]);
	}
	

	float2 center_pos[MAX_ELEMENTS];

	
	for (int i=0;i<ne;i++)
	{
		if (!visible[i])
			continue;
		center_pos[i].x=((elem_bb[i].l+elem_bb[i].r)/2.0)/float(d->width);
		center_pos[i].y=((elem_bb[i].t+elem_bb[i].b)/2.0)/float(d->height);
	}



	
	int internal_alignment[MAX_ELEMENTS];

	for (int i=0;i<ne;i++)
	{

		if (layout[NUM_VAR*i+3]==-1.0)
			internal_alignment[i]=(int) d->alignment[i];
		else
			internal_alignment[i]=(int) layout[NUM_VAR*i+3];

		if ((thread_id==0) and (debug))
			printf("Internal Alignment. Element %i, original %i, current %f, %i\n", i, d->alignment[i], layout[NUM_VAR*i+3],internal_alignment[i]);
	}

	/*
	int num_regions=0;
	int empty_regions=0;
	Box regions[MAX_ELEMENTS*2];
	Box regions_flipped_x[MAX_ELEMENTS*2];
	int region_type[MAX_ELEMENTS*2];
	int region_id[MAX_ELEMENTS];
	int offset=ne*NUM_VAR;
		
	if (layout[offset]>-1)
	{

		
		for (int i=0;i<ne;i++)
		{
			if (layout[offset+i*NUM_RVAR]>-1)
			{
				region_type[i]=layout[offset+i*NUM_RVAR];
				regions[i].set(layout[offset+i*NUM_RVAR+1],  layout[offset+i*NUM_RVAR+1]+layout[offset+i*NUM_RVAR+3],layout[offset+i*NUM_RVAR+2], layout[offset+i*NUM_RVAR+2]+layout[offset+i*NUM_RVAR+4]);
				
				regions_flipped_x[i].set(round(d->width-regions[i].r), round(d->width-regions[i].l),round(regions[i].b), round(regions[i].t));
				
				
				num_regions++;
			}
			else
				break;
		}
				
		for(int j=0;j<num_regions;j++)
		{
			bool empty_region=true;
			for(int i=0;i<ne;i++)
			{
				if (layout[i*NUM_VAR+5]==j)
				{
					region_id[i]=j;
					empty_region=false;	
				}		
			}
			if (empty_region)
				empty_regions++;
		}
		
		
	}
	
	
	if ((debug) and (thread_id==0))
	{
		for (int i=0;i < num_regions;i++)
			printf("R%i. Type %i: %.2f %.2f %.2f %.2f\n",i,region_type[i],regions[i].l,regions[i].r,regions[i].b,regions[i].t);

		for (int i=0;i < ne;i++)
			printf("Item %i in region R%i\n",i,region_id[i]);
			
			
		for (int i=0;i < ne;i++)
		{
			if (layout[ne*NUM_VAR + i*NUM_RVAR]>-1)
			{
				printf("Layout- R%i. Type %i: %.2f %.2f %.2f %.2f\n",i,layout[ne*NUM_VAR + i*NUM_RVAR + 1],layout[ne*NUM_VAR + i*NUM_RVAR + 2],layout[ne*NUM_VAR + i*NUM_RVAR + 3],layout[ne*NUM_VAR + i*NUM_RVAR + 4]);
			}
		}
			
	}
	*/
	/*

	float *region_pos=&layout[ne*NUM_VAR];
	memset(region_pos,-1,sizeof(float)*MAX_ELEMENTS*NUM_RVAR);

	for (int i=0;i < num_regions;i++)
	{

		layout[ne*NUM_VAR + i*NUM_RVAR]=region_type[i];
		layout[ne*NUM_VAR + i*NUM_RVAR + 1]=regions[i].l;
		layout[ne*NUM_VAR + i*NUM_RVAR + 2]=regions[i].r;
		layout[ne*NUM_VAR + i*NUM_RVAR + 3]=regions[i].b;
		layout[ne*NUM_VAR + i*NUM_RVAR + 4]=regions[i].t;

		if ((debug) and (thread_id==0))
			printf("Pre- R%i. Type %i: %.2f %.2f %.2f %.2f\n",i,region_type[i],regions[i].l,regions[i].r,regions[i].b,regions[i].t);
	}
	
	for (int i=num_regions;i < MAX_ELEMENTS;i++)
		layout[ne*NUM_VAR + i*NUM_RVAR]=-1;
	*/


	
	


	/****************************
	 *
	 * Calculate Features
	 *
	 ***************************/



	float *weights=params;

	double features[NUM_FEATURES];
	double nio_grads[NUM_FEATURES];
	//double nio_grads2[NUM_FEATURES];
	int features_ids[NUM_FEATURES];
	
	for (int i=0;i< NUM_FEATURES;i++)
	{
		features_ids[i]=-1;
		features[i]=0;
		params_grad[i]=0;
		params_grad[i + 2*NUM_FEATURES]=0;
		nio_grads[i]=NIO_DEFAULT;
		//nio_grads2[i]=NIO_DEFAULT;
	}



	int f_cnt=0;

	if ((eval_id==0)|| (!multithread))
	{	
		
		

	
		/*
		Box layout_regions[MAX_ELEMENTS*2];
	
		int num_layout_regions=0;
		for (int i=0;i<ne;i++)
		{
			if (layout[ne*NUM_VAR+i*NUM_RVAR]>-1)
			{
				num_layout_regions++;
				layout_regions[i].set(layout[offset+i*NUM_RVAR+1],  layout[offset+i*NUM_RVAR+1]+layout[offset+i*NUM_RVAR+3],layout[offset+i*NUM_RVAR+2], layout[offset+i*NUM_RVAR+2]+layout[offset+i*NUM_RVAR+4]);
			}
		}
	
	
		float region_overlap=0;
		for (int i=0;i < num_layout_regions;i++)
		{
			float region_area=0;
			for(int j=0;j<num_layout_regions;j++)
			{
				if (i!=j)
					region_area+=getBoxIntersection(layout_regions[j],layout_regions[i]).area();				
			}
			
			region_overlap+=region_area/layout_regions[i].area();
		}
	
		features[f_cnt]=region_overlap/(num_regions+0.0001);
		features_ids[f_cnt++]=REGION_OVERLAP_FEAT;
	
	
	
		//number of regions feature
		features[f_cnt]=float(num_layout_regions)/nv;
		features_ids[f_cnt++]=NUM_REGIONS_FEAT;
		*/
		
	
		/***************************
		 * 
		 * Scale Features
		 * 
		 **************************/
	
		float text_size_sum=0;
		float graphic_size_sum=0;
		float text_cons_sum=0;
		float graphic_cons_sum=0;
		
	
		for (int i=0;i<ne;i++)
		{
			if (!visible[i])
				continue;
				
			if (text_elements[i])
			{
				text_size_sum+=sizes[i];
				
				if (visible[i])
					text_cons_sum+=max(0.0,MIN_TEXT_SIZE-sizes[i])+ (int)(sizes[i]<MIN_TEXT_SIZE);

			}
			else
			{
				graphic_size_sum+=sizes[i];
				if (visible[i])
					graphic_cons_sum+=max(0.0,MIN_GRAPHIC_SIZE-sizes[i])+ (int)(sizes[i]<MIN_GRAPHIC_SIZE);
			}

		}
	
		float text_size_mean=text_size_sum/num_text;
	
	
		features[f_cnt]=text_cons_sum/num_text;
		features_ids[f_cnt++]=MIN_TEXT_SIZE_FEAT;
	

	
		atan_param=params[NUM_FEATURES+TEXT_SIZE_FEAT];
		atan_2_param=atan_params[NUM_FEATURES+TEXT_SIZE_FEAT];
	
		float text_size_feat=0;
		float text_size_grad1=0;
		
	
		float text_line_length_feat=0;
		//float text_line_length_grad1=0;
		
		//float line_atan_param=params[NUM_FEATURES+LINE_LENGTH_FEAT];
		//float line_atan_2_param=atan_params[NUM_FEATURES+LINE_LENGTH_FEAT];
		
		
		for (int i=0;i<ne;i++)
		{
			if (visible[i] && text_elements[i])
			{
				//atan_xy=getAtan(d,sizes[i]*atan_param);
				atan_xy=atan(sizes[i]*atan_param);
				text_size_feat+=atan_xy/atan_2_param;
				text_size_grad1+=atan_deriv(sizes[i],atan_param,atan_2_param,atan_xy);
				
	
				//float line_feat=(aspect_ratio[i]);
				text_line_length_feat+=aspect_ratio[i]*aspect_ratio[i];
				//float line_atan_xy=atan(line_feat*line_atan_param);
				
				//text_line_length_feat+=line_atan_xy/line_atan_2_param;
				//text_line_length_grad1+=atan_deriv(line_feat,line_atan_param,line_atan_2_param,line_atan_xy);
			}
		}
		
		
		
	
		features[f_cnt]=-1*text_size_feat/num_text;
		features_ids[f_cnt]=TEXT_SIZE_FEAT;
		nio_grads[f_cnt++]=text_size_grad1/num_text;
	
		features[f_cnt]=text_size_feat/num_text;
		features_ids[f_cnt]=TEXT_SIZE_REVERSE_FEAT;
		nio_grads[f_cnt++]=-1*text_size_grad1/num_text;
		
		features[f_cnt]=text_line_length_feat/num_text;
		features_ids[f_cnt++]=LINE_LENGTH_FEAT;
	
	
		float graphic_size_mean=0;
	
		if (num_graphic>0)
		{
			graphic_size_mean=graphic_size_sum/num_graphic;
	
			features[f_cnt]=graphic_cons_sum/num_graphic;
			features[f_cnt+1]=-1*graphic_size_mean;
			features[f_cnt+2]=graphic_size_mean;
		}
		else
		{
			features[f_cnt]=0;
			features[f_cnt+1]=0;
			features[f_cnt+2]=0;
		}
	
		features_ids[f_cnt]=MIN_GRAPHIC_SIZE_FEAT;
		features_ids[f_cnt+1]=GRAPHIC_SIZE_FEAT;
		features_ids[f_cnt+2]=GRAPHIC_SIZE_REVERSE_FEAT;
		f_cnt+=3;
	
	
	
	
	
	
	
	
		/**************************
		 *
		 * Importance features
		 *
		 **************************/
	
	
		 float text_imp_sum=0;
		 float graphic_imp_sum=0;
	
		 for (int i=0;i<ne;i++)
		 {
		 	if (!visible[i])
		 		continue;
		 		
			 if (text_elements[i])
				 text_imp_sum+=float(d->importance[i]);
			 else
				 graphic_imp_sum+=float(d->importance[i]);
		 }
		 float text_imp_mean=(text_imp_sum)/float(num_text);
		 float graphic_imp_mean=(graphic_imp_sum)/float(num_graphic+0.00001);
	
		 float text_size_var=0, graphic_size_var=0;
		 float text_imp_var=0,graphic_imp_var=0;
		 float text_both=0,graphic_both=0;
		 float text_xx=0, text_xy=0;
		 float graphic_xx=0, graphic_xy=0;
	
		 for (int i=0;i<ne;i++)
		 {
		 	 if (!visible[i])
		 	 	continue;
		 	 	
			 if (text_elements[i])
			 {
				 text_both+=(float(d->importance[i])-text_imp_mean)*(sizes[i]-text_size_mean);
				 text_imp_var+=((float(d->importance[i])-text_imp_mean)*((float(d->importance[i])-text_imp_mean)));
				 text_size_var +=(sizes[i]-text_size_mean)*(sizes[i]-text_size_mean);
	
				 text_xx+=(float(d->importance[i])/10.0)*(float(d->importance[i])/10.0);
				 text_xy+=(float(d->importance[i])/10.0)*sizes[i];
				 //if (thread_id==0)
				//	 printf("%i size %f, imp %f\n",i,sizes[i],float(d->importance[i]));
			 }
			 else
			 {
				 graphic_both+=(float(d->importance[i])-graphic_imp_mean)*(sizes[i]-graphic_size_mean);
				 
				 graphic_imp_var+=((float(d->importance[i])-graphic_imp_mean)*(float(d->importance[i])-graphic_imp_mean));
				 graphic_size_var+=((sizes[i]-graphic_size_mean)*(sizes[i]-graphic_size_mean));
	
	
				 graphic_xx+=sizes[i]*sizes[i];
				 graphic_xy+=float(d->importance[i])*sizes[i];
			 }
			 
		 }
	

	
		//printf("text size variance %f\n",text_size_var/num_text);
		if (num_text>1)
			features[f_cnt]=-text_size_var/num_text;
		else
			features[f_cnt]=0;
		features_ids[f_cnt++]=TEXT_SIZE_VAR_FEAT;
	
		if (num_graphic>1)
			features[f_cnt]=1000*graphic_size_var/num_graphic;
		else
			features[f_cnt]=0;
		features_ids[f_cnt++]=GRAPHIC_SIZE_VAR_FEAT;
	
		 float graphic_imp=0, text_imp=0;
		 if ((num_text>1) and (text_size_var!=0) and (text_imp_var!=0))
		 	 text_imp=text_both/(sqrt(text_size_var)*sqrt(text_imp_var));
		 else
			 text_imp=0;
	
		features[f_cnt]=-1*text_imp;
		features_ids[f_cnt++]=TEXT_IMPORTANCE_PEARSON_FEAT;
	
		if ((num_graphic>1) and (graphic_size_var!=0) and (graphic_imp_var!=0))
			graphic_imp=graphic_both/(sqrt(graphic_size_var)*sqrt(graphic_imp_var));
		else
			graphic_imp=0;
		features[f_cnt]=-1*graphic_imp;
		features_ids[f_cnt++]=GRAPHIC_IMPORTANCE_PEARSON_FEAT;
	
	
		/*
		if (num_text>1)
			features[f_cnt]=-1*(num_text/text_xx)*(text_xy/num_text);
		else
			features[f_cnt]=0;
		//if (thread_id==0)
		//	printf("text_xx %f text_xy %f b%f\n",text_xx,text_xy,(num_text/text_xx)*(text_xy/num_text));
	
		features_ids[f_cnt++]=TEXT_IMPORTANCE_REGRESSION_FEAT;
	
		if (num_graphic>1)
			features[f_cnt]=-1*(num_graphic/graphic_xx)*(graphic_xy/num_graphic);
		else
			features[f_cnt]=0;
	
		features_ids[f_cnt++]=GRAPHIC_IMPORTANCE_REGRESSION_FEAT;
		*/
	
		/**************************
		 *
		 * Positioning features
		 *
		 **************************/
		
		
		//only if 
		if (weights[TEXT_XPOS_FEAT]>=1)
		{
			//printf("calculating position features\n");
			
			float text_xpos_sum=0, graphic_xpos_sum=0;
			float text_ypos_sum=0,graphic_ypos_sum=0;

			
			for (int i=0;i<ne;i++)
			{
				if (!visible[i])
					continue;
	
				if (text_elements[i])
				{
					text_xpos_sum+=center_pos[i].x;
					text_ypos_sum+=center_pos[i].y;
				}
				else
				{
					graphic_xpos_sum+=center_pos[i].x;
					graphic_ypos_sum+=center_pos[i].y;
				}
				
		
			}
		
			float text_xpos_mean=text_xpos_sum/float(num_text+0.001);
			float text_ypos_mean=text_ypos_sum/float(num_text+0.001);
		
			float graphic_xpos_mean=graphic_xpos_sum/float(num_graphic+0.001);
			float graphic_ypos_mean=graphic_ypos_sum/float(num_graphic+0.001);
		
		
			float text_xpos_var=0, graphic_xpos_var=0;
			float text_ypos_var=0,graphic_ypos_var=0;
		
			for (int i=0;i<ne;i++)
			{
				if (!visible[i])
					continue;
					
				if (text_elements[i])
				{
					text_xpos_var+=(text_xpos_mean-center_pos[i].x)*(text_xpos_mean-center_pos[i].x);
					text_ypos_var+=(text_ypos_mean-center_pos[i].y)*(text_ypos_mean-center_pos[i].y);
				}
				else
				{
					graphic_xpos_var+=(graphic_xpos_mean-center_pos[i].x)*(graphic_xpos_mean-center_pos[i].x);
					graphic_ypos_var+=(graphic_ypos_mean-center_pos[i].y)*(graphic_ypos_mean-center_pos[i].y);
				}
				
			}
		
			text_xpos_var=10*text_xpos_var/(num_text+0.001);
			text_ypos_var=10*text_ypos_var/(num_text+0.001);
		
			graphic_xpos_var=10*graphic_xpos_var/(num_graphic+0.001);
			graphic_ypos_var=10*graphic_ypos_var/(num_graphic+0.001);
		
			//if (thread_id==0)
			//	printf("%f %f %f %f\n",text_xpos_var, text_ypos_var,graphic_xpos_var,graphic_ypos_var);
		
			features[f_cnt]=-1*text_xpos_mean;
			features_ids[f_cnt++]=TEXT_XPOS_FEAT;
			features[f_cnt]=-1*graphic_xpos_mean;
			features_ids[f_cnt++]=GRAPHIC_XPOS_FEAT;
			features[f_cnt]=-1*text_ypos_mean;
			features_ids[f_cnt++]=TEXT_YPOS_FEAT;
			features[f_cnt]=-1*graphic_ypos_mean;
			features_ids[f_cnt++]=GRAPHIC_YPOS_FEAT;
		
			features[f_cnt]=text_xpos_mean-1;
			features_ids[f_cnt++]=TEXT_XPOS_REVERSE_FEAT;
			features[f_cnt]=graphic_xpos_mean-1;
			features_ids[f_cnt++]=GRAPHIC_XPOS_REVERSE_FEAT;
			features[f_cnt]=text_ypos_mean-1;
			features_ids[f_cnt++]=TEXT_YPOS_REVERSE_FEAT;
			features[f_cnt]=graphic_ypos_mean-1;
			features_ids[f_cnt++]=GRAPHIC_YPOS_REVERSE_FEAT;
		
		
			features[f_cnt]=text_xpos_var;
			features_ids[f_cnt++]=TEXT_XPOS_VAR_FEAT;
			features[f_cnt]=graphic_xpos_var;
			features_ids[f_cnt++]=GRAPHIC_XPOS_VAR_FEAT;
			features[f_cnt]=text_ypos_var;
			features_ids[f_cnt++]=TEXT_YPOS_VAR_FEAT;
			features[f_cnt]=graphic_ypos_var;
			features_ids[f_cnt++]=GRAPHIC_YPOS_VAR_FEAT;	
		}
		

	
		/***********************
		 * 
		 * Overlap Features
		 * 
		 ***********************/
	
	
		Box overlap_regions[MAX_ELEMENTS];
		Box box;
		for (int i=0;i<d->num_overlap_regions;i++)
		{
	
			if (d->overlap_region_elem[i]>-1)
				box=elem_bb[d->overlap_region_elem[i]];
			else
				box=designBB;
	
			overlap_regions[i].l=box.l+ (box.r-box.l)*d->overlap_regions[i].l;
			overlap_regions[i].r=box.l+ (box.r-box.l)*d->overlap_regions[i].r;
			overlap_regions[i].b=box.b+ (box.t-box.b)*d->overlap_regions[i].b;
			overlap_regions[i].t=box.b+ (box.t-box.b)*d->overlap_regions[i].t;
		}

	
	
		float no_overlap_sum=0;
		
		for (int i=0;i<d->num_overlap_regions;i++)
		{
	
			if ((thread_id==0) and (debug))
				printf("region %i, id %i, %f %f %f %f\n", i,d->overlap_region_elem[i],overlap_regions[i].l,overlap_regions[i].r,overlap_regions[i].b,overlap_regions[i].t);
	
			for (int j=0;j<ne;j++)
			{
				if (d->overlap_region_elem[i]==j)
					continue;
	
				Box intersect=getBoxIntersection(elem_bb[j],overlap_regions[i]);
				if ((thread_id==0) and (debug))
					printf("%i %i, %f %f %f %f, intersect.area: %.2f\n",i,j,elem_bb[j].l, elem_bb[j].r, elem_bb[j].b, elem_bb[j].t, intersect.area());
	
				no_overlap_sum+=intersect.area()/(elem_bb[j].area());
			}
	
		}
	
	
	
		features[f_cnt]=no_overlap_sum/ne;
		features_ids[f_cnt++]=NO_OVERLAP_FEAT;
	
	
	
		float tt_overlap_sum=0;
		float gt_overlap_sum=0;
		float gg_overlap_sum=0;
	
		float overlap_area=0;
	
		for (int i=0;i<ne;i++)
		for (int j=i+1;j<ne;j++)
		{
			Box intersect=getBoxIntersection(elem_bb[i],elem_bb[j]);
			Box design_int=getBoxIntersection(designBB,intersect);
	
			float elem_area1=elem_bb[i].area();
			float elem_area2=elem_bb[j].area();
			float elem_area=min(elem_area1,elem_area2);
			float intersect_area=design_int.area();
			
			
			if (elem_area==0)
			{
				printf("wtf. element area %f. %f %f\n",elem_area,elem_area1,elem_area2);
				return ZERO_AREA_ERROR;
			}
			
			if (elem_area<=1)
				continue;
				
			overlap_area+=intersect_area;
			
			if (text_elements[i] && text_elements[j])
				tt_overlap_sum+=intersect_area/(elem_area);
			else if ((text_elements[i] && graphic_elements[j]) || (graphic_elements[i] && text_elements[j]))
				gt_overlap_sum+=intersect_area/(elem_area);
			else
				gg_overlap_sum+=intersect_area/(elem_area);
		}
		
		
	
		features[f_cnt]=gt_overlap_sum/(float(ne*ne)*0.5);
		features_ids[f_cnt++]=GRAPHIC_TEXT_OVERLAP_FEAT;
	
		features[f_cnt]=tt_overlap_sum/(float(ne*ne)*0.5);
		features_ids[f_cnt++]=TEXT_OVERLAP_FEAT;
	
		features[f_cnt]=gg_overlap_sum/(float(ne*ne)*0.5);
		features_ids[f_cnt++]=GRAPHIC_OVERLAP_FEAT;
	
		//Out of bounds features
		float text_oob_sum=0;
		float graphic_oob_sum=0;
		float inside_area=0;
	
		for (int i=0;i<ne;i++)
		{
			if (!visible[i])
				continue;
				
			Box intersect=getBoxIntersection(designBB,elem_bb[i]);
			float elem_area=elem_bb[i].area();
			
			if (elem_area==0)
			{
				printf("wtf. element area %f\n",elem_area);
				return ZERO_AREA_ERROR;
			}
			
			float indesign_area=intersect.area();
			inside_area+=indesign_area;
		
			if (text_elements[i])
				text_oob_sum+=1-indesign_area/elem_area;
			else
				graphic_oob_sum+=1-indesign_area/elem_area;
			
		}
	
	
		features[f_cnt]=graphic_oob_sum/float(num_graphic+0.01);
		features_ids[f_cnt++]=GRAPHIC_OUT_OF_BOUNDS_FEAT;
	
		features[f_cnt]=text_oob_sum/float(num_text+0.01);
		features_ids[f_cnt++]=TEXT_OUT_OF_BOUNDS_FEAT;
	
	
	
		/**************************
		 *
		 * White space features
		 *
		 **************************/
	
	
		//features[f_cnt]=-1*(1- (inside_area - overlap_area)/designBB.area());
		//features_ids[f_cnt++]=WHITESPACE_FEAT;
	
		//features[f_cnt]=(1- (inside_area - overlap_area)/designBB.area());
		//features_ids[f_cnt++]=WHITESPACE_REVERSE_FEAT;
	
	
	
		float spread_dist=0;
		float check_x=0;
		float check_y=0;
		int min_point=0;
		int min_element=0;
		for (int c=0;c < NUM_POINTS;c++)
		{		
			
			check_x=(spread_check_loc_x[c])*d->width;
			check_y=(spread_check_loc_y[c])*d->height;
			
			float min_dist=9999;
			int curr_min_element=-1;
			
			for (int i=0;i<ne;i++)
			{
				float d1=sqrt((check_x-elem_bb[i].l)*(check_x-elem_bb[i].l) + (check_y-elem_bb[i].b)*(check_y-elem_bb[i].b));
				float d2=sqrt((check_x-elem_bb[i].r)*(check_x-elem_bb[i].r) + (check_y-elem_bb[i].b)*(check_y-elem_bb[i].b));
				float d3=sqrt((check_x-elem_bb[i].l)*(check_x-elem_bb[i].l) + (check_y-elem_bb[i].t)*(check_y-elem_bb[i].t));
				float d4=sqrt((check_x-elem_bb[i].r)*(check_x-elem_bb[i].r) + (check_y-elem_bb[i].t)*(check_y-elem_bb[i].t));
				
			
				
				float mid_x=elem_bb[i].mid_x();
				float mid_y=elem_bb[i].mid_y();
				float d5=sqrt((check_x-mid_x)*(check_x-mid_x) + (check_y-mid_y)*(check_y-mid_y));
				
				
				float curr_min=	min(min(min(min(min(min_dist,d1),d2),d3),d4),d5);	
				
				if (curr_min<min_dist)		
				{
					min_dist=curr_min;
					curr_min_element=i;
					
				}
			}
			if ((thread_id==0) and (debug))
				printf("min distance to point %i is %f, curr_min element %i\n",c, min_dist,curr_min_element);

			spread_dist+=(min_dist/scale)*(min_dist/scale);
			/*
			if (min_dist>max_spread_dist)
			{
				max_spread_dist=min_dist;
				min_point=c;
				min_element=curr_min_element;
			}
			//max_spread_dist=max(max_spread_dist,min_dist);
			*/
		}	
		
		//if ((thread_id==0) and (debug))
		//	printf("min distance %f was element %i to point %i (%f %f)\n",max_spread_dist, min_element, min_point,spread_check_loc_x[min_point], spread_check_loc_y[min_point]);

			
		float spread_feat=((spread_dist/NUM_POINTS));
	
		features[f_cnt]=spread_feat;
		features_ids[f_cnt++]=SPREAD_FEAT;
	
	
	
		
		
		
	
		/**************************
		 *
		 * Pairwise Distance and Margins
		 *
		 **************************/
	
		float border_margins[MAX_ELEMENTS][2];
		float nearest_border_margin[MAX_ELEMENTS];
		float nearest_element_distance[MAX_ELEMENTS];
		//float nearest_text_distance[MAX_ELEMENTS];
	
	
		for (int i=0;i<ne;i++)
		{
	
			float min_dist=999;
			float min_text_dist=999;
	
			for (int j=0;j<ne;j++)
			{
				if (i!=j)
				{
					float elem_dist=max(max(bb_distance[0][i][j], bb_distance[1][i][j]),0.0);
					min_dist=min(min_dist, elem_dist);
	
					if (text_elements[j])
						min_text_dist=min(min_text_dist, elem_dist);
				}
			}
	
			nearest_element_distance[i]=min_dist/scale;
			//nearest_text_distance[i]=min_text_dist/scale;
	
			border_margins[i][0]=min(elem_bb[i].l,d->width-elem_bb[i].r);
			border_margins[i][1]=min(elem_bb[i].b,d->height-elem_bb[i].t);
	
			nearest_border_margin[i]=min(border_margins[i][0],border_margins[i][1])/scale;
	
		}
	
		atan_param=params[NUM_FEATURES+PAIRWISE_DIST_AVG_FEAT];
		atan_2_param=atan_params[NUM_FEATURES+PAIRWISE_DIST_AVG_FEAT];
	
	
	
		float pairwise_dist_min=999;
		float pairwise_dist_sum=0;
		float pairwise_dist_grad=0;
		float text_margin_min=999;
		//float text_margin_sum=0;
		float graphic_margin_min=999;
		//float graphic_margin_sum=0;
		//float text_dist_sum=0;
	
	
		for (int i=0;i<ne;i++)
		{
			if (!visible[i])
				continue;
	
			pairwise_dist_min=min(pairwise_dist_min,nearest_element_distance[i]);

			atan_xy=atan(nearest_element_distance[i]*atan_param);
			pairwise_dist_sum+=1-atan_xy/atan_2_param;
	
			//pairwise_dist_grad+=-1*atan_deriv(nearest_element_distance[i],atan_param,atan_2_param,atan_xy);
	
			if (text_elements[i])
			{
				text_margin_min=min(text_margin_min,nearest_border_margin[i]);
				//text_margin_sum+=nearest_border_margin[i];
				//text_dist_sum+=nearest_text_distance[i];
			}
			else
			{
				graphic_margin_min=min(graphic_margin_min,nearest_border_margin[i]);
				//graphic_margin_sum+=nearest_border_margin[i];
			}
		}
	
	
		features[f_cnt]=pairwise_dist_sum/nv;
		nio_grads[f_cnt]=pairwise_dist_grad/nv;
		features_ids[f_cnt++]=PAIRWISE_DIST_AVG_FEAT;
	
		//features[f_cnt]=0;
		//features_ids[f_cnt++]=PAIRWISE_DIST_MIN_FEAT;
	
		setFeature(PAIRWISE_DIST_MIN_FEAT,f_cnt,pairwise_dist_min,1,params,atan_params,features,features_ids,nio_grads)
	
	
	
		//float text_margin_avg=text_margin_sum/float(num_text);
		//float graphic_margin_avg=graphic_margin_sum/float(num_graphic);
		//features[f_cnt]=0;
		//features_ids[f_cnt++]=TEXT_MARGIN_DIST_AVG_FEAT;
		//features[f_cnt]=0;
		//features_ids[f_cnt++]=GRAPHIC_MARGIN_DIST_AVG_FEAT;

	
		setFeature(TEXT_MARGIN_DIST_MIN_FEAT,f_cnt,text_margin_min,1,params,atan_params,features,features_ids,nio_grads)
		setFeature(GRAPHIC_MARGIN_DIST_MIN_FEAT,f_cnt,graphic_margin_min,1,params,atan_params,features,features_ids,nio_grads);
		//setFeature(TEXT_DIST_FEAT,f_cnt,text_dist_sum/num_text,1,params,atan_params,features,features_ids,nio_grads);
	
	
		/*
		atan_param=params[NUM_FEATURES+GRAPHIC_MARGIN_DIST_MIN_FEAT];
		atan_2_param=atan_params[NUM_FEATURES+GRAPHIC_MARGIN_DIST_MIN_FEAT];
		atan_xy=atan(graphic_margin_min*atan_param);
		features[f_cnt]=1-atan_xy/atan_2_param;
		features_ids[f_cnt]=GRAPHIC_MARGIN_DIST_MIN_FEAT;
		nio_grads[f_cnt++]=-1*atan_deriv(features[f_cnt],atan_param,atan_2_param,atan_xy);
		*/
	
		//if (thread_id==0)
		//	printf("test %.2f %.2f %.2f %i %.2f\n",graphic_margin_min,atan_param,features[f_cnt-1],features_ids[f_cnt-1],weights[features_ids[f_cnt-1]]*atan_param*nio_grads[f_cnt-1]);
	
	
	
		
		/**************************
		 *
		 * Orig layout features
		 *
		 **************************/
	
	
		
		if ((d->check_layout_exists) and (!(d->fixed_regions)))
		{
			
			//need to set the distances from the selected element
			if (d->check_layout_distances[0]==-1)
			{
				
				
				int selected=-1;
				for (int i=0;i < ne;i++)
				{
					d->check_layout_distances[i]=0;
					if ((abs(d->check_layout[i*NUM_VAR+4]-SELECTED_FIX)<0.01) || (abs(d->check_layout[i*NUM_VAR+4]-SELECTED_NOFIX)<0.01) )
						selected=i;
					
				}
				
				if (selected>-1)
				{
					for (int i=0;i < ne;i++)
					{
						float x_dist=max(bb_distance[0][selected][i],0.0);
						float y_dist=max(bb_distance[1][selected][i],0.0);
						
						float selected_dist=(min(x_dist,y_dist))/dist_scale;						
						
						d->check_layout_distances[i]=selected_dist;
						//printf("distance from element %i to selected element %i: %.3f\n",i,selected,selected_dist);
					}
				}
				
			}
			
			
			if ((thread_id==0) and (debug))
			{
				for (int i=0;i < ne;i++)
					printf("check layout distance from %i %.3f\n",i,d->check_layout_distances[i]);
			}
			
			
			
			
			float relative_diff=0;
			/*	
			for (int i=0;i<ne;i++)
			{
				if((d->check_layout[i*NUM_VAR+4]==1) && ((layout[i*NUM_VAR]!=d->check_layout[i*NUM_VAR])||(layout[i*NUM_VAR+1]!=d->check_layout[i*NUM_VAR+1])||(layout[i*NUM_VAR+2]!=d->check_layout[i*NUM_VAR+2])))
				{
					printf("Possible error. Layout  vs check layout (%f,%f,%f) (%f,%f,%f)\n ",i,layout[i*NUM_VAR],layout[i*NUM_VAR+1],layout[i*NUM_VAR+2],d->check_layout[i*NUM_VAR],d->check_layout[i*NUM_VAR+1],d->check_layout[i*NUM_VAR+2]);
				
					//return CHECK_LAYOUT_ERROR;
				}
			}
			*/
			
			Box check_bbs[MAX_ELEMENTS];
			float2 check_center_pos[MAX_ELEMENTS];

			for (int i=0;i < ne;i++)
			{
				
				if (visible[i])
				{
					height=round(d->check_layout[i*NUM_VAR+2]*d->height);
					width=round(height/aspect_ratio[i]);
					xp=round(d->check_layout[i*NUM_VAR]*d->width);
					yp=round(d->check_layout[i*NUM_VAR+1]*d->height);
		
					check_bbs[i].set(round(xp+(width*d->bb_left[i])), round(xp+(width*d->bb_right[i])), round(yp + (height*d->bb_bottom[i])), round(yp + (height*d->bb_top[i])));
				
					check_center_pos[i].x=((check_bbs[i].l+check_bbs[i].r)/2.0)/float(d->width);
					check_center_pos[i].y=((check_bbs[i].t+check_bbs[i].b)/2.0)/float(d->height);
				
				}
			}
			
				
			
			for (int i=0;i < ne;i++)
			{
				
				if ((d->check_layout[i*NUM_VAR+4]<1) && (visible[i]))
				{
					float h_diff1=0,h_diff=0;
					float pos_diff=0;
					
					
					float diff_x1=0,diff_x2=0,diff_y1=0,diff_y2=0;
					for (int j=0;j < ne;j++)
					{
						diff_x1=max(check_center_pos[i].x-check_center_pos[j].x-0.03,0.0);
						diff_x2=max(center_pos[i].x-center_pos[j].x-0.03,0.0);
						
						diff_y1=max(check_center_pos[i].y-check_center_pos[j].y-0.03,0.0);
						diff_y2=max(center_pos[i].y-center_pos[j].y-0.03,0.0);
						
						
						//if ((thread_id==0) && (debug) && (i>=1)&&(j>=1))
						//	printf("i %i j %i, center check x (%.3f - %.3f=%.3f) , center curr x  (%.3f - %.3f=%.3f)\n",i,j,check_center_pos[i].x,check_center_pos[j].x,diff_x1,center_pos[i].x,center_pos[j].x,diff_x2);
							
						
						
						if (((abs(diff_x1-diff_x2)>0.001) && (diff_x1*diff_x2<=0)) || ((abs(diff_y1-diff_y2)>0.001) && (diff_y1*diff_y2<=0)))
						{
							relative_diff++;
							
							if ((thread_id==0) && (debug) && (i>=1)&&(j>=1))
								printf("relative diff err");
							
						}	
						
					}
	
					Box check_bb=check_bbs[i];
					
					int nl=0;
					int alt=int(layout[NUM_VAR*i+6]); 

					if ((d->num_alt[i]>0))
						nl=d->alt_num_lines[i*MAX_ALT+alt];
					else
						nl=d->num_lines[i];	
					
					float check_size=0;
					if (text_elements[i])
						check_size=10.0*(((check_bb.t-check_bb.b)/nl)/(400));
					else
					{
						Box intersect=getBoxIntersection(designBB,check_bb);
						check_size=(intersect.t-intersect.b)/ (400);
					}
					
					
					
					float2 check_pos;
					
					check_pos.x=((check_bb.l+check_bb.r)/2.0)/float(d->width);
					check_pos.y=((check_bb.t+check_bb.b)/2.0)/float(d->height);
					
					
					h_diff1=abs(check_size-sizes[i]) ;					
					//h_diff2=abs(((elem_bb[i].t-elem_bb[i].b) -  (check_bb.t-check_bb.b))/d->height) ;
					h_diff=h_diff1;
		
					pos_diff= sqrt((center_pos[i].x-check_pos.x)*(center_pos[i].x-check_pos.x) + (center_pos[i].y-check_pos.y)*(center_pos[i].y-check_pos.y));

				
					float pos_weight=0,height_weight=0;
					if ((d->check_layout[i*NUM_VAR+4]>0))
					{
						pos_weight=d->check_layout[i*NUM_VAR+4]*2;
						height_weight=d->check_layout[i*NUM_VAR+4]*2;	
					}
					
					if (d->check_layout[i*NUM_VAR+4]==SELECTED_NOFIX)
					{
						h_diff=0;
						pos_diff=0;
					}

					
						
					float alt_diff=0;
					
					
					if ((d->num_alt[i]>0) &&  (layout[NUM_VAR*i+6]>-1) && (d->check_layout[NUM_VAR*i+6]>-1))
						alt_diff=abs(layout[NUM_VAR*i+6]-d->check_layout[i*NUM_VAR+6]);
							
					if ((thread_id==0)&&(debug))
						printf("pos diff element %i, (bb pos %.1f %.1f) layout %f, checklayout %f, alt_diff %f, nl %i, layout align %.1f, check layout align %.1f \n",i,elem_bb[i].l, elem_bb[i].b,layout[NUM_VAR*i+6],d->check_layout[i*NUM_VAR+6],alt_diff,nl,layout[NUM_VAR*i+3],d->check_layout[NUM_VAR*i+3]);
		
					
					
					if (nl>0)
					{
						int check_align=0;
						if (d->check_layout[NUM_VAR*i+3]==-1.0)
							check_align=(int) d->alignment[i];
						else
							check_align=(int) d->check_layout[NUM_VAR*i+3];
					
						alt_diff+=abs(internal_alignment[i]-check_align);
						
						if ((thread_id==0)&&(debug))
							printf("alt diff element %i: %.1f, check align %i, internal align %i, layout %.1f, check_layout %.1f \n",i,alt_diff,check_align,internal_alignment[i],layout[NUM_VAR*i+3],d->check_layout[NUM_VAR*i+3] );
				
					}				
					
					
					//float fix_pos_weight=max(0.0,d->check_layout_distances[i])*2;
					//float fix_height_weight=max(0.0,d->check_layout_distances[i])*2;
					
					float fix_pos_weight=0;
					float fix_height_weight=0;	
						
					features[f_cnt]= pos_weight*max(pos_diff-0.00,0.0) + fix_pos_weight*pos_diff;
					features_ids[f_cnt++]=ELEMENT_POSITION_DIFF_FEATS+i;
		
					features[f_cnt]=height_weight*(max(h_diff-0.0,0.0)+(alt_diff/5)) + fix_height_weight*h_diff;
					features_ids[f_cnt++]=ELEMENT_HEIGHT_DIFF_FEATS+i;
					
					if ((thread_id==0) and (debug))
						printf("elem %i, pos diff %f h diff %f, fixed_amount %f, feat %f, loc %i\n",i,pos_diff,h_diff,layout[i*NUM_VAR+4],features[f_cnt-2],f_cnt-2 );
					
				}
				/*
				if (d->fixed_regions)
				{
					float region_area=0;
					for(int j=0;j<num_regions;j++)
					{
						if (d->type[i]==layout[ne*NUM_VAR+j*NUM_RVAR])
						{
							region_area+=getBoxIntersection(regions[j],elem_bb[i]).area();
						}				
					}
					
					outside_regions+=max(1-region_area/elem_bb[i].area(),0.0);
				}
				*/
			}
			

			
			features[f_cnt]=relative_diff/(nv*nv);
			
			if ((thread_id==0) && (debug))
				printf("relative diff sum %f %f\n",relative_diff,features[f_cnt]);
				
			features_ids[f_cnt++]=RELATIVE_DIFF_FEAT;
			
		}
		
		
		/*
		else
		{
			
			if (d->fixed_regions)
			{
				
				for (int i=0;i < ne;i++)
				{
					if (layout[i*NUM_VAR+4]>FIX_LAYOUT_THRESH)
						continue;
					
					float region_area=0;
					for(int j=0;j<num_regions;j++)
					{
						if (d->type[i]==layout[ne*NUM_VAR+j*NUM_RVAR])
						{
							region_area+=getBoxIntersection(regions[j],elem_bb[i]).area();		
						}
					}
					
					outside_regions+=max(1-region_area/elem_bb[i].area(),0.0);
				}
		
				features[f_cnt]=outside_regions/nv;
				features_ids[f_cnt++]=ELEMENT_REGION_DIFF_FEAT;
				
				
			}
			else
			{
				features[f_cnt]=0;
				features_ids[f_cnt++]=ELEMENT_REGION_DIFF_FEAT;		
		
			}
			
		
			
			for (int i=0;i < MAX_ELEMENTS;i++)
			{
				features[f_cnt]=0;
				features_ids[f_cnt++]=ELEMENT_POSITION_DIFF_FEATS+i;
				features[f_cnt]=0;
				features_ids[f_cnt++]=ELEMENT_HEIGHT_DIFF_FEATS+i;
			}
			
			
		}
	

		features[f_cnt]=empty_regions;
		features_ids[f_cnt++]=EMPTY_REGION_FEAT;
	
		/**************************
		 * Previous Layout features
		 **************************/
		
	
		float prev_diff_feat=0;
	
		if (num_prev_layout>0)
		{
			float alpha=0.8;
			float alpha_sum=0;
			
			float max_diff=0;
			for (int n=0;n < num_prev_layout;n++)
			{
			
				float prev_diff=0;
				for (int i=0;i<ne;i++)
				{
					prev_diff+=abs(previous_layout[n*d->layout_size+i*NUM_VAR] - layout[i*NUM_VAR]);
					prev_diff+=abs(previous_layout[n*d->layout_size+i*NUM_VAR+1] - layout[i*NUM_VAR+1]);
					prev_diff+=2.0*abs(previous_layout[n*d->layout_size+i*NUM_VAR+2] - layout[i*NUM_VAR+2]);
				}
				float layout_diff=prev_diff/(ne);
				max_diff=max(max_diff,exp(-(layout_diff*layout_diff)*5.0));
				//prev_diff_feat=prev_diff_feat*alpha+exp(-(layout_diff*layout_diff)*5.0);
				//alpha_sum=alpha_sum*0.9+1;
			}	
			
			//prev_diff_feat=prev_diff_feat/alpha_sum;
			
			prev_diff_feat=max_diff;
			
			//printf("prev_diff_feat %f\n",prev_diff_feat);
		}
	
	
		features[f_cnt]=prev_diff_feat;
		features_ids[f_cnt++]=PREVIOUS_LAYOUT_FEAT;
	



		/**************************
		 * Hidden element features
		 **************************/
		features[f_cnt]=ne-nv;
		features_ids[f_cnt++]=HIDDEN_ELEM_FEAT;
	
		/**************************
		 *
		 * Symmetry features
		 *
		 **************************/
		float text_xsymm_sum=0;
		float graphic_xsymm_sum=0;
		float text_ysymm_sum=0;
		float graphic_ysymm_sum=0;
	
		float text_area_sum=0.001;
		float graphic_area_sum=0.001;
	

		Box intersect_x,intersect_x2;
		Box intersect_y,intersect_y2;
	
	
		Box flipped_x[MAX_ELEMENTS];
		Box flipped_y[MAX_ELEMENTS];	

		for (int i=0;i<ne;i++)
		{
			flipped_x[i].set(round(d->width-elem_bb[i].r), round(d->width-elem_bb[i].l),round(elem_bb[i].b), round(elem_bb[i].t));
			flipped_y[i].set(round(elem_bb[i].l), round(elem_bb[i].r),round(d->height-elem_bb[i].t), round(d->height-elem_bb[i].b));
		}
	
	
	
		for (int i=0;i<ne;i++)
		{
			//curr_region=regions[region_id[i]];
	
			//flipped.set(curr_region.l+ (curr_region.r-elem_bb[i].r), curr_region.l+ (curr_region.r-elem_bb[i].l),elem_bb[i].b, elem_bb[i].t);
			//intersect_x=getBoxIntersection(flipped,elem_bb[i]);
			if (!visible[i])
				continue;
	
			if (text_elements[i])
				text_area_sum+=elem_bb[i].area();
			else
				graphic_area_sum+=elem_bb[i].area();
	
	
			for (int j=i;j<ne;j++)
			{
				
				if ((visible[j])&&(text_elements[i]==text_elements[j]))
				{
	
					intersect_x=getBoxIntersection(flipped_x[j],elem_bb[i]);
					intersect_x2=getBoxIntersection(designBB,intersect_x);
	
					intersect_y=getBoxIntersection(flipped_y[j],elem_bb[i]);
					intersect_y2=getBoxIntersection(designBB,intersect_y);
	
					float scale=1;
					if (j!=i)
						scale=2.0;
					if (text_elements[i])
					{
						text_xsymm_sum+=scale*intersect_x2.area();
						text_ysymm_sum+=scale*intersect_y2.area();
					}
					else
					{
	
						graphic_xsymm_sum+=scale*intersect_x2.area();
						graphic_ysymm_sum+=scale*intersect_y2.area();
					}
				}
			}
		}
	
	
		float symm_feat1=graphic_xsymm_sum/graphic_area_sum-1;
		float symm_feat2=graphic_ysymm_sum/graphic_area_sum-1;
		float symm_feat3=text_xsymm_sum/text_area_sum-1;
		float symm_feat4=text_ysymm_sum/text_area_sum-1;
	
	
		if ((thread_id==0) && (debug))
		{
	
			atan_param=params[NUM_FEATURES+GRAPHIC_XSYMMETRY_FEAT];
			atan_2_param=atan_params[NUM_FEATURES+GRAPHIC_XSYMMETRY_FEAT];
			atan_xy=atan(symm_feat1*atan_param);
			printf("symm %f , feat %f, %f\n", graphic_xsymm_sum/graphic_area_sum, symm_feat1, atan_xy/atan_2_param+1);
		}
	
	
		setFeature(GRAPHIC_XSYMMETRY_FEAT,f_cnt,symm_feat1,2,params,atan_params,features,features_ids,nio_grads)
		setFeature(GRAPHIC_YSYMMETRY_FEAT,f_cnt,symm_feat2,2,params,atan_params,features,features_ids,nio_grads)
		setFeature(TEXT_XSYMMETRY_FEAT,f_cnt,symm_feat3,2,params,atan_params,features,features_ids,nio_grads)
		setFeature(TEXT_YSYMMETRY_FEAT,f_cnt,symm_feat4,2,params,atan_params,features,features_ids,nio_grads)
	
		//features[f_cnt]=-1*graphic_xsymm_sum/graphic_area_sum;
		//features_ids[f_cnt++]=GRAPHIC_XSYMMETRY_FEAT;
		//features[f_cnt]=-1*graphic_ysymm_sum/graphic_area_sum;
		//features_ids[f_cnt++]=GRAPHIC_YSYMMETRY_FEAT;
		//features[f_cnt]=-1*text_xsymm_sum/text_area_sum;
		//features_ids[f_cnt++]=TEXT_XSYMMETRY_FEAT;
		//features[f_cnt]=-1*text_ysymm_sum/text_area_sum;
		//features_ids[f_cnt++]=TEXT_YSYMMETRY_FEAT;
	
	
		if (weights[GRAPHIC_XSYMMETRY_REVERSE_FEAT]+weights[GRAPHIC_YSYMMETRY_REVERSE_FEAT]+weights[TEXT_XSYMMETRY_REVERSE_FEAT]+weights[TEXT_YSYMMETRY_REVERSE_FEAT]!=0)
		{
			features[f_cnt]=graphic_xsymm_sum/graphic_area_sum -1;
			features_ids[f_cnt++]=GRAPHIC_XSYMMETRY_REVERSE_FEAT;
			features[f_cnt]=graphic_ysymm_sum/graphic_area_sum -1;
			features_ids[f_cnt++]=GRAPHIC_YSYMMETRY_REVERSE_FEAT;
		
			features[f_cnt]=text_xsymm_sum/text_area_sum -1;
			features_ids[f_cnt++]=TEXT_XSYMMETRY_REVERSE_FEAT;
			features[f_cnt]=text_ysymm_sum/text_area_sum -1;
			features_ids[f_cnt++]=TEXT_YSYMMETRY_REVERSE_FEAT;
		}
		
	
		/*
		float symm_feat5=graphic_region_xsymm_sum/graphic_area_sum-1;
		float symm_feat6=text_region_xsymm_sum/text_area_sum-1;
	
		setFeature(GRAPHIC_REGION_XSYMMETRY_FEAT,f_cnt,symm_feat5,2,params,atan_params,features,features_ids,nio_grads)
		setFeature(TEXT_REGION_XSYMMETRY_FEAT,f_cnt,symm_feat6,2,params,atan_params,features,features_ids,nio_grads)
		*/
	
		/*
		float region_area_sum=0, region_xsymm_sum=0;
	
		for (int i=0;i<num_regions;i++)
		{
	
			region_area_sum+=regions[i].area();
			
			for (int j=i;j<num_regions;j++)
			{
				
					intersect_x=getBoxIntersection(regions_flipped_x[j],regions[i]);
					intersect_x2=getBoxIntersection(designBB,intersect_x);
	
					float scale=0;
					if (j!=i)
						scale=2.0;
					
					region_xsymm_sum+=scale*intersect_x2.area();
			
				
			}
		}
		
	
		features[f_cnt]=0;
		features_ids[f_cnt++]=GRAPHIC_REGION_XSYMMETRY_FEAT;
	
		features[f_cnt]=0;
		features_ids[f_cnt++]=TEXT_REGION_XSYMMETRY_FEAT;
		*/

		float graphic_region_symm_sum=0;
		float text_region_symm_sum=0;
		for (int i=0;i<ne;i++)
		{
			
			float min_left=elem_bb[i].l, min_right=d->width-elem_bb[i].r;
			
			//check if we overlap on y-axis, then update min amounts
			for (int j=0;j<ne;j++)
			{
				
				if (i==j)
					continue;
				float y_overlap=min((elem_bb[i].t-elem_bb[j].b),(elem_bb[j].t-elem_bb[i].b));
				
				if (y_overlap>0)
				{
					float left=elem_bb[i].l-elem_bb[j].r;
					float right=elem_bb[j].l-elem_bb[i].r;
					
					if (left>0)
						min_left=min(min_left,left);
						
					if (right>0)
						min_right=min(min_right,right);		
				}
				
			}
			
			float reg_width=min_left+min_right;
			
			if (text_elements[i])
				text_region_symm_sum+=abs(min_left-min_right)/reg_width;
			else
				graphic_region_symm_sum+=abs(min_left-min_right)/reg_width;
			
	
	
		}
		
	
		features[f_cnt]=graphic_region_symm_sum/(num_graphic+0.001)-1;
		features_ids[f_cnt++]=GRAPHIC_REGION_XSYMMETRY_FEAT;
	
		features[f_cnt]=text_region_symm_sum/(num_text+0.001)-1;
		features_ids[f_cnt++]=TEXT_REGION_XSYMMETRY_FEAT;
		


	
		/**************************
		 *
		 * Flow features
		 *
		 **************************/
	
		float text_xflow_sum=0;
		float text_yflow_sum=0;
		float text_diag_flow_sum=0;
		float text_xflow_cnt=0;
		float text_yflow_cnt=0;
		float text_diag_flow_cnt=0;
	
		float x_diff, y_diff;
		float x_imp_dist, y_imp_dist;
	
		float em1_cent;
		for (int i=0;i<ne;i++)
		{
	
			float imp_i=d->importance[i];
			//if (d->group_id[i]>-1)
			//	imp_i=group_imp[d->group_id[i]];
	
			if ((visible[i]) && (text_elements[i]))
			{
				em1_cent=center_pos[i].x;
	
				for (int j=i+1;j<ne;j++)
				{
					if ((!text_elements[j]) || (!visible[j]))
						continue;
	
					float imp_j=d->importance[j];
					//if (d->group_id[j]>-1)
					//	imp_j=group_imp[d->group_id[j]];
	
					float left_diff=(elem_bb[i].l - elem_bb[j].l)/d->width;
					float cent_diff=em1_cent - center_pos[j].x;
				
					if (abs(cent_diff) < abs(left_diff))
						x_diff=cent_diff;
					else
						x_diff=left_diff;
	
					y_diff= (elem_bb[i].b - elem_bb[j].b)/d->height;
	
					if ( x_diff < -0.01)
						x_imp_dist=max(imp_j-imp_i,0.0);
					else if ( x_diff > 0.01)
						x_imp_dist=max(imp_i-imp_j,0.0);
					else
						x_imp_dist=0;
	
	
					if (y_diff <  -0.01)
						y_imp_dist=max(imp_j-imp_i,0.0);
					else if ( y_diff > 0.01)
						y_imp_dist=max(imp_i-imp_j,0.0);
					else
						y_imp_dist=0;
	
					float pix_dist=(max(bb_distance[0][i][j]/d->width,bb_distance[1][i][j]/d->height))+0.1;
	
	
					if (x_imp_dist*pix_dist>0)
					{
	
						text_xflow_sum+=x_imp_dist;
						text_xflow_cnt++;
	
						if (((y_diff <=  0.01) and (imp_j > imp_i)) or ((y_diff >=  -0.01) and (imp_j< imp_i)))
						{
							text_diag_flow_sum+=x_imp_dist;
							//text_diag_flow_sum+=x_imp_dist*pix_dist;
							text_diag_flow_cnt+=1;
						}
	
					}
	
					if (y_imp_dist*pix_dist>0)
					{
						if ((debug) and (thread_id==0))
							printf("Flow Y: %i %i, y_diff %f,y_imp_dist %f, pix_dist %f, imps %f %f, group_id %i\n",i,j,y_diff,y_imp_dist,pix_dist, imp_i,imp_j,int(d->group_id[j]));
						
						text_yflow_sum+=y_imp_dist;
						//text_yflow_sum+=y_imp_dist*pix_dist;
						text_yflow_cnt+=1;
					}
				}
			}
		}
	
	
		features[f_cnt]=text_xflow_sum/(text_xflow_cnt+0.001);
		features_ids[f_cnt++]=TEXT_XFLOW_FEAT;
		features[f_cnt]=text_yflow_sum/(text_yflow_cnt+0.001);
		features_ids[f_cnt++]=TEXT_YFLOW_FEAT;
		features[f_cnt]=text_diag_flow_sum/(text_diag_flow_cnt+0.001);
		features_ids[f_cnt++]=TEXT_DIAG_FLOW_FEAT;
	



	}
	
	
	
	if ((eval_id==1) || (!multithread))
	{
		
		

		int group_count[MAX_ELEMENTS];
		int group_imp[MAX_ELEMENTS];
		for (int i=0;i<MAX_ELEMENTS;i++)
		{
			group_imp[i]=0;
			group_count[i]=0;
		}
	
		for (int i=0;i<ne;i++)
		{
			if (d->group_id[i]>-1)
			{
				group_count[d->group_id[i]]++;
				group_imp[d->group_id[i]]=max(group_imp[d->group_id[i]],d->importance[i]);
				
				if ((debug) && (thread_id==0))
					printf("group id %i has imp %i\n",d->group_id[i],group_imp[d->group_id[i]]);
			}
		}
			
		int num_groups=0;
		for (int i=0;i<ne;i++)
		{
			if (group_count[i]>1)
				num_groups++;
		}



		/**************************
		 *
		 * Alignment features
		 *
		 **************************/
		
		float align_dist[6][MAX_ELEMENTS][MAX_ELEMENTS];
		int aligned[6][MAX_ELEMENTS][MAX_ELEMENTS];
		

			
		
		

	
		float locations[6][MAX_ELEMENTS];
	
		bool fixed_alignment=true;
	
	
		for (int k=0;k<6;k++)
		{
			bool x_align=k<3;
	
	
			for (int i=0;i<ne;i++)
			{
				if (k==0)
					locations[k][i]=elem_bb[i].l/scale;
				else if (k==1)
					locations[k][i]=((elem_bb[i].l+elem_bb[i].r)/2.0)/scale;
				else if (k==2)
					locations[k][i]=elem_bb[i].r/scale;
				else if (k==3)
					locations[k][i]=elem_bb[i].b/scale;
				else if (k==4)
					locations[k][i]=((elem_bb[i].t+elem_bb[i].b)/2.0)/scale;
				else
					locations[k][i]=elem_bb[i].t/scale;
			}
	
			for (int i=0;i<ne;i++)
			for (int j=i+1;j<ne;j++)
			{
				aligned[k][i][j]=0;


				if ((x_align and (bb_distance[0][i][j]<0)) or (!x_align and (bb_distance[1][i][j]<0)))
				{

					float loc_diff=min(abs(locations[k][i]-locations[k][j]),0.99);
	
					
					
					
					fixed_alignment=true;
					if ((num_lines[i]>1)and (k<3) and (internal_alignment[i]!=k))
							fixed_alignment=false;

					if ((num_lines[j]>1)and (k<3) and (internal_alignment[j]!=k))
							fixed_alignment=false;

					if (!fixed_alignment)
						align_dist[k][i][j]=200;
					else
						align_dist[k][i][j]=loc_diff;
						
						
					//if ((thread_id==0) and (debug))
					//	printf("align dist k %i: %i %i. dist %.3f. internal %i %i\n",k,i,j,align_dist[k][i][j],internal_alignment[i],internal_alignment[j]);

				}
				else
					align_dist[k][i][j]=100;
			

			}
			
		}
	
	

	
		for (int i=0;i<ne;i++)
		{
			if (!visible[i])
				continue;
			
			for (int k=0;k<6;k++)
				aligned[k][i][i]=1;
	
	
			for (int j=i+1;j<ne;j++)
			{
				if (!visible[j])
					continue;
				
				float d0=align_dist[0][i][j];
				float d1=align_dist[1][i][j];
				float d2=align_dist[2][i][j];
				float d3=align_dist[3][i][j];
				float d4=align_dist[4][i][j];
				float d5=align_dist[5][i][j];
	
	
				if (min(min(d0,d1),d2)<ALIGN_THRESH)
				{
					if ((d0<d1) and (d0<d2))
						aligned[0][i][j]=1;
					else if ((d1<d0) and (d1<d2))
						aligned[1][i][j]=1;
					else
						aligned[2][i][j]=1;
		
				}
	
				if (min(min(d3 ,d4),d5)<ALIGN_THRESH)
				{
					if ((d3<d4) and (d3<d5))
						aligned[3][i][j]=1;
					else if ((d4<d3) and (d3<d5))
						aligned[4][i][j]=1;
					else
						aligned[5][i][j]=1;
				}
			}
		}
	
	
	
	
		int num_multi_line=0;
		for (int i=0;i<ne;i++)
			if ((num_lines[i]>1) &&(visible[i]))
				num_multi_line++;
		
	
		
		float align_xerr=0, align_yerr=0;
		int	err_idx;
		float denom=float(nv*nv -nv + num_multi_line)+0.0001;
		
		for (int k=0;k<6;k++)
		{
	
			float align_sum=0;
			for (int i=0;i<ne;i++)
			{
				if (!visible[i])
					continue;
					
				if ((num_lines[i]>1) and (internal_alignment[i]==k))
					align_sum+=1.0;
				
				for (int j=i+1;j<ne;j++)
				{
					if (aligned[k][i][j]>0)
					{
						align_sum+=2.0;
						
						err_idx=min(int(align_dist[k][i][j]*1000.0),999);
						if (k<3)
							align_xerr+=d->align_err[err_idx];
						else
							align_yerr+=d->align_err[err_idx];
							
						if ((thread_id==0) and (debug))
							printf("alignment k %i: %i %i. dist %.3f. idx %i, err %.3f \n",k,i,j,align_dist[k][i][j],err_idx,d->align_err[err_idx]);
					}
				}	
			}
			
			features[f_cnt]=-1*align_sum/denom;
			features_ids[f_cnt++]=ALIGN_XLEFT_FEAT+k;
			
		}
		
		if ((thread_id==0) and (debug))
			printf("align err x %.3f, y %.3f \n",align_xerr, align_yerr );	
		
		
		features[f_cnt]=align_xerr/(nv*nv*3);
		features_ids[f_cnt++]=ALIGN_XERROR_FEAT;
	
		features[f_cnt]=align_yerr/(nv*nv*3);
		features_ids[f_cnt++]=ALIGN_YERROR_FEAT;

	
		if ((debug)	&& (thread_id==0))
			printf("refining %i. num constraints %i\n",d->refine,d->num_constraints);
		
		
		//if (d->refine)
		//{
		float size_constraints_err=0;
		float alignment_constraints_err=0;
		float align_lines_err=0;
		
		for (int i=0;i<d->num_constraints;i++)
		{
			int elem=d->constraints[i*NUM_AVAR];
			int k=d->constraints[i*NUM_AVAR+1];
			int num_other=d->constraints[i*NUM_AVAR+2];
			
			//do alignment constraints later
			if (k<10)
			{
					
				if ((k<2)&& (num_lines[elem]>1) &&(d->fixed_alignment[elem]==0)  && (internal_alignment[elem]!=k))
				{
					align_lines_err+=1;	
					if ((debug)	&& (thread_id==0))
						printf("internal alignment error\n");				
				}
					
				
				for (int j=0;j<num_other;j++)
				{
					int other_elem=d->constraints[i*NUM_AVAR+3+j];
					float dist=abs(locations[k][elem]-locations[k][other_elem]);
					//if (dist>ALIGN_THRESH)
					align_lines_err+=dist;
						
						
					if ((debug)	&& (thread_id==0))
					{
						printf("alignment line dist %f, elem %i, k %i, other elem %i, internal align %i\n",dist, elem,k,other_elem,internal_alignment[other_elem]);
					}
						
						
					if ((k<2) &&(num_lines[other_elem]>1)&& (d->fixed_alignment[other_elem]==0) && (internal_alignment[other_elem]!=k))
					{
						align_lines_err+=1;	
						if ((debug)	&& (thread_id==0))
							printf("internal alignment error\n");
					}
					
				}
			}
			if (k==SIZE_CONSTRAINT)
			{
				for (int j=0;j<num_other;j++)
				{
					int other_elem=d->constraints[i*NUM_AVAR+3+j];
					
					float size_diff=abs(sizes[elem]-sizes[other_elem])/sizes[elem];
					float weight=d->check_layout[elem*NUM_VAR+4]*d->check_layout[elem*NUM_VAR+4];
					size_constraints_err+=weight*size_diff;
					
					if ((debug)	&& (thread_id==0) && (size_diff>0.001))
					{
						printf("constraint size error %i %i %.3f\n", elem, other_elem, size_diff);
					}
				}
			
			}
			if (k==ALIGN_CONSTRAINT)
			{
				
				float min_align_dist=999;
				for (int a=0;a<6;a++)
				{
					if ((a==2)|| (a==5))
						continue;
					bool is_aligned=true;
				
					float curr_align_dist=0;
					
					for (int j=0;j<num_other;j++)
					{
						int other_elem=d->constraints[i*NUM_AVAR+3+j];
						float a_dist=abs(locations[a][elem]-locations[a][other_elem]);
						curr_align_dist+= a_dist;
						if (a_dist>ALIGN_THRESH);
							is_aligned=false;
						
					}
					
					if ((debug)	&& (thread_id==0))
						printf("align constraint %i, type %i, %i,%.3f \n",i, a,is_aligned,curr_align_dist);
					
					
					if (is_aligned)
					{
					
						min_align_dist=0;
						break;
					}
					else
						min_align_dist=min(min_align_dist,curr_align_dist);		
				}
				
				alignment_constraints_err+=min_align_dist;
				
			}
		}
		
		features[f_cnt]=size_constraints_err;
		features_ids[f_cnt++]=SIZE_CONSTRAINTS_FEAT;
		
		features[f_cnt]=alignment_constraints_err;
		features_ids[f_cnt++]=ALIGN_CONSTRAINTS_FEAT;
		
		features[f_cnt]=align_lines_err;
		features_ids[f_cnt++]=ALIGN_LINES_FEAT;
	
		//}
	
		/**************************
		 *
		 * Group features
		 *
		 **************************/	
		if (num_groups>0)
		{
			
	
			float group_dist_sum=0;
			float group_align_sum=0;
			float group_align_x[MAX_ELEMENTS*MAX_ELEMENTS];
			float group_align_y[MAX_ELEMENTS*MAX_ELEMENTS];
			
			int group_align_x_cnt=0;
			int group_align_y_cnt=0;
		
		
			int group_members=0;
			
			for (int i=0;i<ne;i++)
			{
		
				if ((d->group_id[i]>-1) and (group_count[d->group_id[i]]>1))
				{
					group_members++;
					float group_alignment=0;
					
					
					int nearest=-1;
					float min_dist=999;
					for (int j=0;j<ne;j++)
					{
						if ((i!=j) and (d->group_id[i]==d->group_id[j]))
						{				
							for (int k=0;k<6;k++)
							{
								//  and (align_dist[k][i][j]<ALIGN_THRESH/3.0)
								if (aligned[k][min(i,j)][max(i,j)]>0)
								{
									group_alignment=1;
									
									if (k<3)
									{
										group_align_x[group_align_x_cnt]=k;
										group_align_x_cnt++;	
									}
									else
									{
										group_align_y[group_align_y_cnt]=k;
										group_align_y_cnt++;	
									}
								}
								
							}
							
							float elem_dist=max(max(bb_distance[0][i][j], bb_distance[1][i][j]),0.0)/dist_scale;
							
							if (elem_dist <min_dist)
							{
								min_dist=elem_dist;
								nearest=j;
							}
						}
					}
					group_align_sum+=group_alignment;
					
					
					if ((thread_id==0)and (debug))
						printf("Group Nearest Distance %i: %.3f %i\n",i,min_dist,nearest);
					
					
					if (min_dist==999)
					{
						printf("error. couldn't find a group member. element %i, group id %i\n", i,d->group_id[i]);
		
						for (int j=0;j<ne;j++)
						{
							printf("\t element %i, group id %i\n", j,d->group_id[j]);
		
							if ((i!=j) and (d->group_id[i]==d->group_id[j]))
							{
								float elem_dist=max(max(bb_distance[0][i][j], bb_distance[1][i][j]),0.0);
								printf("\t dist %.2f\n",elem_dist);
							}
						}
		
					}
		
					group_dist_sum+=min_dist;
				}
		
			}
		
			features[f_cnt]=group_dist_sum/(num_groups+0.0001);
			features_ids[f_cnt++]=GROUP_DIST_FEAT;
		
			features[f_cnt]=-1*group_align_sum/(group_members+0.0001);
			features_ids[f_cnt++]=GROUP_ALIGN_FEAT;
			
			
			//float group_align_var_sum=0;
			float group_text_mean_sum=0;
			float group_graphic_mean_sum=0;
			
			float group_text=0.001;
			float group_graphic=0.001;
			for (int i=0;i<ne;i++)
			{
				if (group_count[i]>1)
				{	
					if (text_elements[i])
					{
						group_text_mean_sum+=sizes[i];
						group_text++;	
					}
					else
					{
						group_graphic_mean_sum+=sizes[i];
						group_graphic++;
					}
				}
			}
			
			float group_text_mean=group_text_mean_sum/group_text;
			float group_graphic_mean=group_graphic_mean_sum/group_text;
		
			float group_text_var=0;
			float group_graphic_var=0;
			
			for (int i=0;i<ne;i++)
			{
				if (group_count[i]>1)
				{	
					if (text_elements[i])
						group_text_var+=(sizes[i]-group_text_mean)*(sizes[i]-group_text_mean);
					else
						group_graphic_var+=(sizes[i]-group_graphic_mean)*(sizes[i]-group_graphic_mean);
				}
			}
			
			
			features[f_cnt]=group_text_var/group_text;
			features_ids[f_cnt++]=GROUP_TEXT_SIZE_VAR_FEAT;
			
			features[f_cnt]=group_graphic_var/group_graphic;
			features_ids[f_cnt++]=GROUP_GRAPHIC_SIZE_VAR_FEAT;
		
		
		
			float mean_x_align=0,mean_y_align=0;
			
			for (int i=0;i< group_align_x_cnt;i++)
				mean_x_align+=group_align_x[i];
			mean_x_align=mean_x_align/float(group_align_x_cnt+0.001);
			
			for (int i=0;i< group_align_y_cnt;i++)
				mean_y_align+=group_align_y[i];
			mean_y_align=mean_y_align/float(group_align_y_cnt+0.001);
			
			float var_x_align=0,var_y_align=0;
			for (int i=0;i< group_align_x_cnt;i++)
				var_x_align+=(mean_x_align-group_align_x[i])*(mean_x_align-group_align_x[i]);
				
			for (int i=0;i< group_align_y_cnt;i++)
				var_y_align+=(mean_y_align-group_align_y[i])*(mean_y_align-group_align_y[i]);
			
			features[f_cnt]=var_x_align/float(group_align_x_cnt+0.001);
			features_ids[f_cnt++]=GROUP_ALIGN_X_VAR_FEAT;
		
			features[f_cnt]=var_y_align/float(group_align_y_cnt+0.001);
			features_ids[f_cnt++]=GROUP_ALIGN_Y_VAR_FEAT;
			
		}
		
		
		
		
	}

	
	
	
	if ((thread_id==0)and (debug))
		printf("Evaluating model");
	/**************************
	 * Evaluate model
	 **************************/
	
	
	double feat=0;
	double eval=0;
	
	if ((eval_id==0) || (!multithread))
		eval=-500;
	
	for (int i=0;i<f_cnt;i++)
	{
		
		//params_grad[features_ids[i]]=0;
		
		//if (features_ids[i]==-1)
		//{
		//	printf("ERROR\n, undefined for feature %i\n",i);
		//	continue;	
		//}

		if (features[i]==0)
		{
			//if (debug)
			//	printf(" %i feat test %i %f  %f %f\n",i,features_ids[i],0,weights[features_ids[i]],0);
			params_grad[features_ids[i]]=0;
			params_grad[features_ids[i]+NUM_FEATURES]=0;
			continue;
		}

		atan_param=params[NUM_FEATURES+features_ids[i]];

		if (nio_grads[i]==NIO_DEFAULT)
		{


			atan_2_param=atan_params[NUM_FEATURES+features_ids[i]];
			//atan_xy=getAtan(d,features[i]*atan_param);
			atan_xy=atan(features[i]*atan_param);
			feat=atan_xy/atan_2_param;

			if (calc_gradient)
				params_grad[features_ids[i]+NUM_FEATURES]=weights[features_ids[i]]*atan_deriv(features[i],atan_param,atan_2_param,atan_xy);

			
		}
		else
		{
			feat=features[i];
			
			if (calc_gradient)
			{
				params_grad[features_ids[i]+NUM_FEATURES]=weights[features_ids[i]]*nio_grads[i];
				//params_grad[features_ids[i]+2*NUM_FEATURES]=weights[features_ids[i]]*nio_grads2[i];
			}
			
		}
		
		//params_grad[features_ids[i]+2*NUM_FEATURES]=0;

		/*
		if ( (debug))
		{
			printf(" %i feat test %i %f %f %f\n",i,features_ids[i],feat,weights[features_ids[i]],feat*weights[features_ids[i]]);
			//for (int j=0;j<ne;j++)
			//{
			//	printf("element %i: l/r: %3.3f - %3.3f b/t: %3.3f - %3.3f\n",j,elem_bb[j].l,elem_bb[j].r,elem_bb[j].b,elem_bb[j].t);
			//	printf("\t %f %f %f %f, alt: %f\n",layout[NUM_VAR*j],layout[NUM_VAR*j+1],layout[NUM_VAR*j+2],layout[NUM_VAR*j+3],layout[NUM_VAR*j+6]);
			//	return 99996;
			//}		
		}
		*/
		

		eval+=feat*weights[features_ids[i]];
		params_grad[features_ids[i]]=feat;


	}
	
	//printf("eval id %i, fcnt %i, eval %.3f\n",eval_id,f_cnt,eval);

	/*
	if ((thread_id==0) and (debug))
	{
		float test_eval=-500;
		printf("Model Feature Breakdown: %f\n",eval);
		for (int k=0;k<NUM_FEATURES;k++)
		{
			printf("%i\t%5.1f \t %4.2f\t %4.2f \t nl: %4.2f \n", k,params[k],params_grad[k],params[k]*params_grad[k],params[k+NUM_FEATURES]);
			test_eval+=params[k]*params_grad[k];
		}
		
		
		if (abs(test_eval-eval)>0.1)
			printf("error. test eval %f, eval %f\n",test_eval,eval);
	}
	*/

	/**************************
	 * Cleanup
	 **************************/


	if ((thread_id==0)and (debug))
		printf("finished debug with eval %f\n",eval*0.25);
	

	return eval*0.25;





}



void addParameterOffsets(char *filename, int num_params, float *h_params)
{
    FILE *fp = NULL;
	fp = fopen(filename, "r");

	if (!fp)
		return;


	char param_name[100];
	char val_str[100];
	float value;

	fgets(param_name,sizeof(param_name),fp);
	fgets(val_str,sizeof(val_str),fp);

	value = atof(val_str);
	printf("param_name: %s has value %f\n",param_name,value);

	if (!strcmp(param_name,"whitespace\n"))
	{
		if (value>=50)
			h_params[WHITESPACE_FEAT]+=(value-50)*5;
		else
			h_params[WHITESPACE_REVERSE_FEAT]+=(50-value)*5;


	}
	if (!strcmp(param_name,"text_size\n"))
	{
		if (value>=50)
			h_params[TEXT_SIZE_FEAT]+=(value-50)*5;
		else
			h_params[TEXT_SIZE_REVERSE_FEAT]+=(50-value)*5;

	}
	if (!strcmp(param_name,"graphic_size\n"))
	{
		if (value>=50)
			h_params[GRAPHIC_SIZE_FEAT]+=(value-50)*5;
		else
			h_params[GRAPHIC_SIZE_REVERSE_FEAT]+=(50-value)*5;
	}
	if (!strcmp(param_name,"symmetry\n"))
	{


	}

}


void saveParametersToFile(char *filename,float *params,int num_params)
{
	//printf("Saving parameters to file %s\n",filename);
	
	
	FILE *fp = fopen(filename, "w");
	
	fprintf(fp,"Weights,,,\n");
	
	for (int i=0;i< NUM_FEATURES;i++)
	{
		fprintf(fp,"%s,",feat_names[i]);
		for (int j=0;j<3;j++)
		{
			float fl=params[i+j*NUM_FEATURES];
			if (ceilf(fl) == fl)
				fprintf(fp,"%i",int(fl));
			else
				fprintf(fp,"%f",fl);
			if (j <2)
				fprintf(fp,",");
		}
		
		fprintf(fp,"\n",feat_names[i]);		
	}
	fclose(fp);
	
}


float *loadParametersFromFile(char * default_param_file, char *filename,int num_params)
{
	float *default_params=readParameters(default_param_file,num_params);
	float *params=readParameters(filename,num_params);
	
	for (int i=0;i<num_params;i++)
	{
		if (default_params[i]==-1)
		{
			printf("Error, default parameter %i is uninitialized \n",i);
			default_params[i]=0;
		}
	
		if (params[i]==-1)
			params[i]=default_params[i];
			
	}
	
	free(default_params);
	return params;
}

float *readParameters(char *filename,int num_params)
{
	printf("Loading parameters from file %s\n",filename);
	float *params = (float*)malloc( sizeof(float)*num_params);

	for(int i=0;i<num_params;i++)
		params[i]=-1;

	FILE *fp = fopen(filename, "r");

	if (!fp)
		return 0;

	char str[200];
	char param_name[100];

	while(fgets(str,sizeof(str),fp) != NULL)
    {
	   // strip trailing '\n' if it exists
	   int len = strlen(str)-1;
	   if(str[len] == '\n')
		  str[len] = 0;

	   char *comma = strstr(str, ",");


	   memset(param_name,0,100);
	   strncpy(param_name,str,comma-str);

	   comma=comma+sizeof(char);
	   float val=atof(comma);

	   char *next_val = strstr(comma, ",");
	   next_val=next_val+sizeof(char);
	   float val2=atof(next_val);

	   next_val = strstr(next_val, ",");
	   next_val=next_val+sizeof(char);
	   float val3=atof(next_val);

	   //printf("%s %.2f %.2f %.2f\n", param_name,val,val2,val3);

	   for (int i=0;i < NUM_FEATURES;i++)
	   {
		   if (!strcmp(param_name,feat_names[i]))
		   {
			   	params[i]=val;
			   	params[i+NUM_FEATURES]=val2;
			   	params[i+2*NUM_FEATURES]=val3;
			   /*
		   		if (val3>1)
		   		{
		   			
		   			float r=float(rand())/RAND_MAX;
		   			//printf ("%i, %f, %i, %f\n",rand(),float(rand()),RAND_MAX,r);
		   			params[i]=max(params[i]+(r-0.5)*val3,0.0);
		   			printf("setting param %s to %.3f\n",feat_names[i],params[i]);
		   		}
		   		*/
		   }
	   }
	}
	fclose (fp);

	printf("Finished loading parameters\n");


	return params;
}



	/*

	//create alignment groups
	for (int k=0;k<6;k++)
	{
		bool x_align=k<3;

		bool changed=true;

		while (changed)
		{
			changed=false;

			for (int i=0;i<ne;i++)
			for (int j=i+1;j<ne;j++)
			{
				if (aligned[k][i][j]==1)
				{

					for (int q=0;q<ne;q++)
					{
						if ((q==i) or (q==j))
							continue;

						if ((aligned[k][i][q] or aligned[k][q][i]) and (aligned[k][q][j]==0))
						{
							if ((x_align and bb_distance[1][j][q]>0) or ((not x_align) and bb_distance[0][j][q]>0) )
							{
								changed=true;
								aligned[k][q][j]=1;
								aligned[k][j][q]=1;
							}
						}
						if ((aligned[k][j][q] or aligned[k][q][j]) and (aligned[k][q][i]==0))
						{
							if ((x_align and bb_distance[1][i][q]>0) or ((not x_align) and bb_distance[0][i][q]>0) )
							{
								changed=true;
								aligned[k][q][i]=1;
								aligned[k][i][q]=1;
							}
						}
					}
				}
			}
		}
	}
	
	
	
	
	
	*/


	/*
	//take this code out eventually. only here for comparing with element 
	else
	{		
		num_regions=ne+d->num_overlap_regions;
		for (int i=0;i<ne;i++)
		{
			if (text_elements[i])
				region_type[i]=1;
			else
				region_type[i]=2;
				
			regions[i]=elem_bb[i];
	
		}
		for (int i=0;i<d->num_overlap_regions;i++)
		{
			region_type[i+ne]=2;
			regions[i+ne]=overlap_regions[i];
		}
	
	
		bool merge_complete=false;
		Box proposed;
	
		while (not merge_complete)
		{
	
			merge_complete=true;
	
			for (int i=0;i<num_regions;i++)
			for (int j=i+1;j<num_regions;j++)
			{
				if (region_type[i]!=region_type[j])
					continue;
	
				proposed.set(min(regions[i].l,regions[j].l), max(regions[i].r,regions[j].r),min(regions[i].b,regions[j].b), max(regions[i].t,regions[j].t));
	
				//try to merge i and j
				bool merge=true;
	
				for (int k=0;k<num_regions;k++)
				{
					if ((i==k) or (j==k))
						continue;
	
					if (not ((regions[k].l>=proposed.r) or (regions[k].r<=proposed.l) or \
							(regions[k].t<=proposed.b) or (regions[k].b>=proposed.t)))
					{
						merge=false;
						k=num_regions;
						break;
					}
				}
	
				//merge i and j
				if (merge)
				{
					//if ((debug) and (thread_id==0))
					//	printf("Merging %i and %i\n",i,j);
	
	
					regions[j]=regions[num_regions-1];
					region_type[j]=region_type[num_regions-1];
					regions[i]=proposed;
	
					merge_complete=false;
					num_regions--;
					i=MAX_ELEMENTS;
					j=MAX_ELEMENTS;
					break;
				}
			}
	
		}
	
	
	
	
	
	
		//bool left_region=false,bottom_region=false;
		float dist;
		bool overlap1, overlap2;
	
		//expand the boundaries of the regions to the edge of the designs
		for (int i=0;i<num_regions;i++)
		{
			float nearest_dist[4];
			int nearest_idx[4];
	
			for (int dir=0;dir<4;dir++)
			{
				nearest_dist[dir]=9999;
				nearest_idx[dir]=-1;
			}
	
			for (int dir=0;dir<4;dir++)
			{
	
				for (int j=0;j<num_regions;j++)
				{
					if (i==j)
						continue;
	
					if 	(dir==0)
						dist=regions[i].l-regions[j].r;
					if (dir==1)
						dist=regions[j].l-regions[i].r;
					if (dir==2)
						dist=regions[i].b-regions[j].t;
					if (dir==3)
						dist=regions[j].b-regions[i].t;
	
					if ((dist>=0) and (dist<nearest_dist[dir]))
					{
						nearest_dist[dir]=dist;
						nearest_idx[dir]=j;
					}
				}
	
				//expand to the boundary if there's nothing else
				if ((nearest_idx[dir]==-1) and (nearest_dist[dir]>0))
				{
					if ((debug) and (thread_id==0))
						printf("shifting region %i, boundary %i\n", i,dir);
	
					if 	(dir==0)
						regions[i].l=0;
					if (dir==1)
						regions[i].r=d->width;
					if (dir==2)
						regions[i].b=0;
					if (dir==3)
						regions[i].t=d->height;
				}
				//push boundaries to halfway point between nearest
				else
	
				{
	
	
					float cut=0;
					if 	(dir==0)
					{
	
						regions[i].l=regions[i].l-nearest_dist[dir]/2.0;
						regions[nearest_idx[dir]].r=regions[i].l;
						cut=regions[i].l;
					}
					else if (dir==1)
					{
						regions[i].r=regions[i].r+nearest_dist[dir]/2.0;
						regions[nearest_idx[dir]].l=regions[i].r;
						cut=regions[i].r;
					}
					else if (dir==2)
					{
						regions[i].b=regions[i].b-nearest_dist[dir]/2.0;
						regions[nearest_idx[dir]].t=regions[i].b;
						cut=regions[i].b;
					}
					else if (dir==3)
					{
						regions[i].t=regions[i].t+nearest_dist[dir]/2.0;
						regions[nearest_idx[dir]].b=regions[i].t;
						cut=regions[i].t;
					}
	
					if ((debug) and (thread_id==0))
						printf("merging boundary region %i and %i, boundary %i, %f \n", i,nearest_idx[dir],dir,cut);
	
				}
			}
	
		}
	
		Box proposed1;
		Box proposed2;
		//bool corner=false;
	
		//expand filled regions into remaining empty space
		for (int i=0;i<num_regions;i++)
		{
			for (int k=0;k<num_regions;k++)
			{
				if (k==i)
					continue;
	
				///if (((regions[i].l==regions[k].r) and (regions[i].t==regions[k].b)) or ((regions[k].l==regions[i].r) and (regions[k].t==regions[i].b)))
				//if (((regions[i].l==regions[k].r) or (regions[i].r==regions[k].l)) and ((regions[i].t==regions[k].b) or (regions[i].b==regions[k].t)))
	
				//check corners
				//corner=false;
				if (((regions[i].l==regions[k].r) or (regions[i].r==regions[k].l)) and ((regions[i].t==regions[k].b) or (regions[i].b==regions[k].t)))
				{
					proposed1.set(regions[k].l,regions[k].r, regions[i].b,regions[i].t);
					proposed2.set(regions[i].l,regions[i].r, regions[k].b,regions[k].t);
	
					overlap1=false;
					overlap2=false;
					for (int j=0;j < num_regions;j++)
					{
						if ((j!=i)and (j!=k))
						{
							overlap1= overlap1 or anyBoxIntersection(regions[j], proposed1);
							overlap2= overlap2 or anyBoxIntersection(regions[j], proposed2);
						}
					}
					if (not overlap1)
					{
						
						//if (regions[i].l < regions[k].l)
						//	regions[k].l=regions[i].l;
						//else
						//	regions[i].l=regions[k].l;
						
						if (regions[i].b < regions[k].b)
							regions[k].b=regions[i].b;
						else
							regions[i].b=regions[k].b;
					}
	
					if (not overlap2)
					{
	
						if (regions[i].b < regions[k].b)
							regions[k].t=regions[i].t;
						else
							regions[i].t=regions[k].t;
						
						//if (regions[i].l < regions[k].l)
						//	regions[i].r=regions[k].r;
						//else
						//	regions[k].r=regions[i].r;
						
					}
				}
			}
		}
	

		for (int i=0;i<ne;i++)
		{
			float overlap_area=0;
	
			for (int j=0;j<num_regions;j++)
			{
				if (anyBoxIntersection(regions[j], elem_bb[i]))
				{
					float area=getBoxIntersection(regions[j], elem_bb[i]).area();
					if (area > overlap_area)
					{
						overlap_area=area;
						region_id[i]=j;
					}
				}
			}
		}
		
	}
	*/


