#include "saoptimizer.cuh"



#define CURR_LOCATION_SHIFT 0
#define GLOBAL_LOCATION_SHIFT 1
#define CURR_HEIGHT_SHIFT 2
#define GLOBAL_ALIGN 3
#define ALIGN_ELEMENT 4
#define SWITCH_ALIGNMENT 5
#define SWITCH_ALTERNATE 6
#define FLIP_TWO_ELEMENTS 7
#define SHIFT_ALIGNED_ELEMENTS 8
#define SCALE_TYPE 9

#define NUM_PROPOSALS 16
//__device__ const int prop_choice[NUM_PROPOSALS] = {0};
__device__ const int prop_choice[NUM_PROPOSALS] = {0,0,1,1,2,2,3,4,4,5,6,6,7,8,8,9};

#define NUM_REFINE_PROPOSALS 12
//__device__ const int refine_prop_choice[NUM_REFINE_PROPOSALS] = {0};
__device__ const int refine_prop_choice[NUM_REFINE_PROPOSALS] = {0,0,1,2,2,4,4,5,6,8,8,9};
//__device__ const int refine_prop_choice[NUM_PROPOSALS] = {0,0,1,1,2,2,3,4,4,5,6,7,8,9};

#define REG_ELEMENT_SWITCH 0
#define REG_ELEMENT_HEIGHT 1
#define REG_ALIGN 2
#define REG_ORIENTATION 3
#define REG_CURR_LOCATION_SHIFT 4
#define REG_GLOBAL_LOCATION_SHIFT 6
#define REG_BB_SHIFT 7
#define REG_ELEMENT_ORDER 8
#define REG_SWAP 9
#define REG_MERGE 10
#define REG_SPLIT 11
#define REG_ALIGN_TWO 12
#define REG_ELEMENT_SPLIT 13
#define REG_SWITCH_ALTERNATE 14


#define NUM_FIXED_REGION_PROPOSALS 9
#define NUM_REGION_PROPOSALS 18

//__device__ const int fix_reg_prop_choice[NUM_FIXED_REGION_PROPOSALS] = {1,1,2,4,4,6,6,12,12};
//__device__ const int reg_prop_choice[NUM_REGION_PROPOSALS] = {1,1,2,4,4,6,6,12,12, 0,0,3,7,7,10,11,13,14};


#define MAX_PROPOSAL_TRIES 5



#include "rand.cuh"

/*

//, float *opt_layout
__global__ void simulatedAnnealing(Design *d, int num_iter,float start_temp, float end_temp, float *init_layouts,float *proposals,  float *params,  float *params_grads, float *eval, int *return_status, float *opt_layouts)
{

	*return_status=-1;

	//Todo: set these with some random numbers from the GPU
	z1=200*blockIdx.x ;
	z2=200*blockIdx.y ;
	z3=200*threadIdx.x;
	z4=200*threadIdx.y;

	int thread_id=blockIdx.x;

	//access the memory for this thread
	float *init_layout=init_layouts;
	float *proposal=proposals;
	float *opt_layout=opt_layouts;
	float *params_grad=params_grads;


	float fx=evaluateLayout(d,init_layout,params,params_grad);
	float fmin=fx;
	memcpy(opt_layout,init_layout, d->layout_size*sizeof(float));

	float *curr_layout=init_layout;

	float prop, fprop;

	int prop_hist[NUM_PROPOSALS];
	memset(prop_hist,0,NUM_PROPOSALS*(sizeof(int)));


	//main annealing loop
	for (int i=0;i<num_iter;i++)
	{

		float temp=((end_temp-start_temp)* (float(i)/float(num_iter)))+start_temp;

		//generate proposal
		int prop_type=getProposal(d,curr_layout,proposal);
		prop_hist[prop_type]+=1;

		fprop=evaluateLayout(d,proposal,params,params_grad);


		if (fprop<fx)
			prop=1;
		else
		{
			prop=exp(-1*temp*fprop)/(exp(-1*temp*fx)+0.000001);

			if (isnan(prop))
				prop=0;
			else
				prop=min(1.0,prop);
		}

		printf("Annealing Iteration %i, fx %.3f,fprop %.3f, prop %.2f\n\n", i, fx, fprop,prop);

        if (prop > randu())
        {
        	memcpy(curr_layout, proposal, d->layout_size*sizeof(float));

            fx=fprop;
        }

        if (fx < fmin)
        {
        	memcpy(opt_layout, proposal, d->layout_size*sizeof(float));
        	fmin=fx;
        }
	}


	//assert(evaluateLayout(d,opt_layout,params,params_grad)==fmin);

	*eval=evaluateLayout(d,opt_layout,params,params_grad);

	float *xp=opt_layout;
	float *yp=&opt_layout[d->num_elements];
	float *hs=&opt_layout[2*d->num_elements];
	float *alts=&opt_layout[3*d->num_elements];


	printf("Best Layout\n");
	for (int i=0;i<d->num_elements;i++)
	{
		printf("\t %i x %i \t y %i \t h %i \t a %i\n",i,int(xp*d->width), int(yp*d->height), int(hs[i]*d->height), int(alts[i]));
	}
	printf("Best eval %.2f", *eval);


	*return_status=0;


	for (int i=0;i<NUM_PROPOSALS;i++)
	{
		printf("Prop %i, cnt %i", i, prop_hist[i]);
	}
}


*/


//, float *opt_layout
__global__ void parallelTempering(Design *d, int debug_mode, int iter_count, float start_temp, float end_temp, int num_iter,int num_params,float *params,float *atan_params,  float *temperatures, int *temp_ids,float *init_layouts,float *proposals,   float *params_grads, float *opt_layouts,float *evals, int num_previous_layout, float *previous_layout,float *random_seed,int *barrier, float *eval_sum)
{

	//if (blockIdx.x%EVAL_SPLIT_NUM!=0)
	//	return ;


	int thread_id= threadIdx.x + int(blockIdx.x/EVAL_SPLIT_NUM) * blockDim.x;
	
	int eval_id= blockIdx.x%EVAL_SPLIT_NUM;
	
	//Todo: set these with some random numbers from the CPU
	z3=random_seed[thread_id*4];
	z4=random_seed[thread_id*4+1];
	z1=random_seed[thread_id*4+2];
	z2=random_seed[thread_id*4+3];
	
	//access the memory for this thread
	float *init_layout=&init_layouts[thread_id*d->layout_size];
	float *proposal=&proposals[thread_id*d->layout_size];
	float *opt_layout=&opt_layouts[thread_id*d->layout_size];
	float *params_grad=&params_grads[thread_id*num_params];
	float temp=temperatures[thread_id];

	int ne=d->num_elements;
	//int offset=ne*NUM_VAR;

	
	//int prop_hist[NUM_PROPOSALS];
	//int accept_hist[NUM_PROPOSALS];
	//memset(prop_hist,0,NUM_PROPOSALS*(sizeof(int)));
	//memset(accept_hist,0,NUM_PROPOSALS*(sizeof(int)));

	float fx=evaluateLayout(d,init_layout,params,atan_params,params_grad,num_previous_layout,previous_layout,false,false,false);
	
	
	
	for (int j=0;j<d->layout_size;j++)
		opt_layout[j]=init_layout[j];

	float *curr_layout=init_layout;

	float prop, fprop;

	
	for(int i=0;i< d->num_elements;i++)
	{			
		if (curr_layout[i*NUM_VAR+2]<0)	
			printf("Error in element %i, %.3f %.3f %.3f\n",i, curr_layout[i*NUM_VAR], curr_layout[i*NUM_VAR+1], curr_layout[i*NUM_VAR+2]);
		
	}
	
	
	//main annealing loop
	for (int i=0;i<num_iter;i++)
	{
		

		//temp=((end_temp-start_temp)* (float(i)/float(num_iter)))+start_temp;
		if (end_temp!=-1)
			temp=((end_temp-start_temp)* (float(i)/float(num_iter)))+start_temp;

	
		//bool screwed_up=false;
		for (int j=0;j <ne;j++)
		{
			
			
			if((d->check_layout_exists) &&(d->check_layout[j*NUM_VAR+4]>FIX_LAYOUT_THRESH) && ((curr_layout[j*NUM_VAR]!=d->check_layout[j*NUM_VAR])||(curr_layout[j*NUM_VAR+1]!=d->check_layout[j*NUM_VAR+1])||(curr_layout[j*NUM_VAR+2]!=d->check_layout[j*NUM_VAR+2])))
			{	printf("PT error. Iteration %i. Layout vs check layout element %i (%f,%f,%f) (%f,%f,%f)\n ",i,j,curr_layout[j*NUM_VAR],curr_layout[j*NUM_VAR+1],curr_layout[j*NUM_VAR+2],d->check_layout[j*NUM_VAR],d->check_layout[j*NUM_VAR+1],d->check_layout[j*NUM_VAR+2]);
				return;
			}
			
			
			if ((curr_layout[j*NUM_VAR+2]==0) && (curr_layout[j*NUM_VAR+3]==0))
			{
				printf("element %i has an error\n",j);
				return	;
			}
		}
	

		//generate proposal
		int prop_type=-1;

		if (eval_id==0)
		{
			prop_type=getProposal(d,curr_layout,proposal,d->refine,i==0);
			
			if (prop_type<0)
				return;
		}
		
		/*
		//sync blocks
		
	    atomicSub( &(barrier[thread_id]) , 1 );
    	while ( atomicCAS( &(barrier[thread_id]) , 0 , 0 ) != 0 );  
    	
    	//reset the block counter
    	if (eval_id==0)
    	{
			barrier[thread_id]= EVAL_SPLIT_NUM;
			eval_sum[thread_id]=0;
		}
		while ( atomicCAS( &(barrier[thread_id]) , EVAL_SPLIT_NUM , EVAL_SPLIT_NUM ) != EVAL_SPLIT_NUM );  
	
		
		fprop_partial=evaluateLayout(d,proposal,params,atan_params,params_grad,num_previous_layout,previous_layout,true,false);
		
		atomicAdd( &(eval_sum[thread_id]) , fprop_partial );
		atomicSub( &(barrier[thread_id]) , 1 );
		while ( atomicCAS( &(barrier[thread_id]) , 0 , 0 ) != 0 );  
		
    	if (eval_id==0)
    		barrier[thread_id]= EVAL_SPLIT_NUM;
		while ( atomicCAS( &(barrier[thread_id]) , EVAL_SPLIT_NUM , EVAL_SPLIT_NUM ) != EVAL_SPLIT_NUM );  
		*/
		
		if (eval_id==0)
		{
			//fprop=eval_sum[thread_id];
			//fprop=randu();	
			
			fprop=evaluateLayout(d,proposal,params,atan_params,params_grad,num_previous_layout,previous_layout,false,false,false);
			
			/*
			if (abs(fprop-eval_sum[thread_id])>0.01)
				printf("fprop %.2f doesnt match fprop test %.2f\n",fprop,eval_sum[thread_id]);
			*/
			
			
			if (!isfinite(fprop))
			{
				if (thread_id==0)
				{
					
					printf("ERROR: fprop isnt finite. %.3f\n",fprop);
					
					for(int j=0;j< d->num_elements;j++)
						printf("Element %i, %.3f %.3f %.3f %.3f %.3f\n",j, curr_layout[j*NUM_VAR], curr_layout[j*NUM_VAR+1], curr_layout[j*NUM_VAR+2], curr_layout[j*NUM_VAR+3], curr_layout[j*NUM_VAR+4]);
						
					
					fprop=evaluateLayout(d,proposal,params,atan_params,params_grad,num_previous_layout,previous_layout,false,true,false);
					
					printf("Feature Breakdown:\n");
					for (int k=0;k<NUM_FEATURES;k++)
						printf("%i\t%5.1f \t %4.2f\t %4.1f \tnl:%3.1f\n", k,params[k],params_grad[k],params[k]*params_grad[k],params[k+NUM_FEATURES]);
			
					
				}
				
				return; 
				
			}
			
			if (fprop==99997)
			{
				printf("fucked up with prop type: %d\n",prop_type);
				return;
			}
			
			
			if (fprop==CHECK_LAYOUT_ERROR)
			{
				printf("check layout error: %d\n",prop_type);
				return;
			}
			
			if (fprop==ASPECT_RATIO_ERROR)
			{
				printf("aspect ratio error: %d\n",prop_type);
				return;
			}
				
			
			
			if (fprop<fx)
				prop=1;
			if (fprop>99990)
				prop=0;
			else
			{
				
				prop=exp(-1*(fprop-fx)/temp);
				//prop=fprop;
	
				if (!isfinite(prop))
					prop=0;
				else
					prop=min(1.0,prop);
					
			}
	
			
	        if (prop > randu())
	        {
	        	for (int j=0;j<d->layout_size;j++)
	        		curr_layout[j]=proposal[j];
	            fx=fprop;
	            
	            //accept_hist[prop_type]+=1;
	        }
        	
       }

	}
	
	
	if (eval_id==0)
	{
		//memcpy(opt_layout,curr_layout, d->layout_size*sizeof(float));
		//memcpy(init_layout, curr_layout, d->layout_size*sizeof(float));
		for (int  i=0;i<d->layout_size;i++)
		{
			opt_layout[i]=curr_layout[i];
			init_layout[i]=curr_layout[i];
		}
		
		evals[thread_id]=fx;

	}
	
	

	//free(param_var);
	
}



__device__ float getAlignmentDisplacement(int num_elements,int elem,Box *bb,int axis,int align_type)
{

	int other_elem=(num_elements)*randu();

	int cnt=0;
	while ((cnt <100)&&(other_elem==elem))
	{
		other_elem=(num_elements)*randu();
		cnt++;	
	}
	if (cnt==100)
	{
		printf("ERROR in getAlignmentDisplacement\n");
		return 0;
	}

	//x axis alignment
	if (axis==0)
	{
		if (align_type==0)
			return bb[other_elem].l-bb[elem].l;
		else if (align_type==1)
			return (bb[other_elem].l+bb[other_elem].r)/2.0-(bb[elem].l+bb[elem].r)/2.0;
		else
			return bb[other_elem].r-bb[elem].r;
	}
	//y axis alignment
	else
	{
		if (align_type==0)
			return bb[other_elem].b-bb[elem].b;
		else if (align_type==1)
			return (bb[other_elem].b+bb[other_elem].t)/2.0-(bb[elem].b+bb[elem].t)/2.0;
		else
			return bb[other_elem].t-bb[elem].t;
	}

}

	



__device__ int getProposal(Design *d, float *curr_layout, float *proposal,bool refine,bool debug)
{



	float aspect_ratio[MAX_ELEMENTS];
	int num_lines[MAX_ELEMENTS];

	float elem_select_strength[MAX_ELEMENTS];

	int ne=d->num_elements;

	Box bb[MAX_ELEMENTS];
	Box new_bb[MAX_ELEMENTS];
	
	
	float height,width,xp,yp;
	
	
	float cum_sum=0;
	for (int i=0;i<ne;i++)
	{
		float curr_strength=1.0;
		if (d->check_layout_exists)
		{
			curr_strength=max(0.0,1-d->check_layout[NUM_VAR*i+4]);
			//printf("fix %f strength %f\n",d->check_layout[NUM_VAR*i+4],curr_strength);
		}

		if (d->check_layout[NUM_VAR*i+4]>=1)
			curr_strength=0;
		cum_sum+=curr_strength;
		elem_select_strength[i]=cum_sum;
		
		int alt=int(curr_layout[NUM_VAR*i+6]);
		
		if (alt<0)
		{
			//visible[i]=false;
			bb[i].set(-1001,-1000,-1001,-1000);
		}
		else
		{
			if (d->num_alt[i]>0)
				aspect_ratio[i]=d->alt_aspect_ratio[i*MAX_ALT+alt];
			else
				aspect_ratio[i]=d->aspect_ratio[i];
				
			if (d->num_alt[i]>0)
				num_lines[i]=d->alt_num_lines[i*MAX_ALT+alt];
			else
				num_lines[i]=d->num_lines[i];	
			
			height=round(curr_layout[NUM_VAR*i+2]*d->height);
			
			if (height<=0)
			{
				printf("Error in curr_layout element %i has height %.2f\n", i, height);
				return -1;
			}
			width=round(height/aspect_ratio[i]);
			xp=round(curr_layout[NUM_VAR*i]*d->width);
			yp=round(curr_layout[NUM_VAR*i+1]*d->height);
	
			bb[i].set(round(xp+(width*d->bb_left[i])), round(xp+(width*d->bb_right[i])), round(yp + (height*d->bb_bottom[i])), round(yp + (height*d->bb_top[i])));
		}

		/*
		if ((!isfinite(curr_layout[i*NUM_VAR]))|| (!isfinite(curr_layout[i*NUM_VAR+1]))|| (!isfinite(curr_layout[i*NUM_VAR+2])))
		{
			printf("Error in curr_layout element %i has prop %f %f %f, alt %f\n",i,curr_layout[i*NUM_VAR],curr_layout[i*NUM_VAR+1],curr_layout[i*NUM_VAR+2],curr_layout[i*NUM_VAR+6]);
			return -1;
		}
		*/
		

		//if (debug)
		//	printf("%i: %.2f %.2f %.2f %.2f\n",i,bb[i].l,bb[i].r,bb[i].b,bb[i].t);
		/*
		if ((bb[i].l<-2*d->width) || (bb[i].t<-2*d->height)|| (bb[i].r>=2*d->width)|| (bb[i].t>=2*d->height))
		{
				printf("screwed up %i: %f %f %f %f, w/h: %f %f, ar: %f\n \t l/r: %3.3f - %3.3f b/t: %3.3f - %3.3f\n",i, curr_layout[NUM_VAR*i],curr_layout[NUM_VAR*i+1],curr_layout[NUM_VAR*i+2],curr_layout[NUM_VAR*i+3],width,height,aspect_ratio[i],bb[i].l,bb[i].r,bb[i].b,bb[i].t);
				return -1;
		}
		*/

		//if ((bb[i].r<=0) || (bb[i].t<=0)|| (bb[i].l>=d->width)|| (bb[i].b>=d->height))
		//	screwed_up=true;
		//if ((curr_layout[i*NUM_VAR]>=0.99) ||  (curr_layout[i*NUM_VAR+1]>=0.99))


	}
	
	
	int elems[MAX_ELEMENTS];

	

	float disp_x=0;
	float disp_y=0;
	float scale_mod=1;

	int m=0;
	int prop_select=0;
	Box new_box;
	for (m=0;m<MAX_PROPOSAL_TRIES;m++)
	{

		
		//memcpy(proposal, curr_layout, d->layout_size*sizeof(float));
		for (int j=0;j<d->layout_size;j++)
			proposal[j]=curr_layout[j];



		float rand=randu();

		
		float elem_select=cum_sum*rand;
		int elem=-1;
		for (int i=0;i<ne;i++)
		{
			if 	(elem_select_strength[i]>elem_select)
			{
				elem=i;
				break;
			}
		}
		
		if (elem==-1)
		{
			//printf("elem neg %i %.3f cum_sum %.3f\n",elem,elem_select,cum_sum );
			
			//for (int i=0;i<ne;i++)
			//	printf("\t i%i %.3f %.3f\n",i,elem_select_strength[i],d->check_layout[NUM_VAR*i+4]);
			continue;
		}
		
		
		
		/*
		int elem=((float)ne*rand);

		int cnt=0;
		while ((cnt<20)&&((proposal[NUM_VAR*elem+4]>=1) || ((proposal[NUM_VAR*elem+4]==SELECTED_NOFIX) && (randu()<0.95))))
		{
			elem =((float)ne*randu());
			cnt++;
		}
		if (cnt==20)
			return -1;
		*/
		
		
		
		int select;
		
		//if (!refine)
		//{
			select=(((float)NUM_PROPOSALS)*randu());
			prop_select=prop_choice[select];
		
		// }
		//else
		//{
		//	select=(((float)NUM_REFINE_PROPOSALS)*randu());
		//	prop_select=refine_prop_choice[select];	
		//}
		
		if (abs(proposal[NUM_VAR*elem+4]-SELECTED_NOFIX)<0.001)
			prop_select=SWITCH_ALIGNMENT;
		
		
		
		
		//bool already_overlapped=checkBoundingBoxOverlap(new_box,bb,ne,elem);
		bool already_overlapped=false;
		
		//bool skipped=false;

		int num_mod_elements=1;

		disp_x=0;
		disp_y=0;
		scale_mod=1;
		int new_align=-1;

		if (prop_select==CURR_LOCATION_SHIFT)
		{

			float location_variance=0.1;
			float2 rands=randn();
			//printf("random n %.5f,%.5f \n",rands.x, rands.y);


			if (rands.x>0)
				disp_x=rands.y*location_variance*d->width;
			else
				disp_y=rands.y*location_variance*d->height;

			//printf("Current location shift on element %i, dim %i, added %.3f\n", elem, ((int) rands.x>0),rands.y*location_variance);

		}
		else if ((prop_select==CURR_HEIGHT_SHIFT))
		{


			float height_variance=0.05;
			if (d->type[elem]!=1)
				height_variance=height_variance*2;
				
				
			float new_height=0;
			while (new_height<0.01)
			{
				float2 rands=randn();
				new_height=proposal[elem*NUM_VAR+2]+rands.y*height_variance;
			}

			scale_mod=new_height/proposal[elem*NUM_VAR+2];
			
			

			//printf("Height shift on element %i, added %.3f\n", elem,new_height);

			float elem_width=bb[elem].r-bb[elem].l;
			float elem_height=bb[elem].t-bb[elem].b;
			if ((elem_width*scale_mod < 2) or (elem_height*scale_mod < 2))
				continue;

			/*
            disp_x=-1.0*round((round(elem_width*scale_mod)-elem_width)/2.0);
            disp_y=-1.0*round((round(elem_height*scale_mod)-elem_height)/2.0);
            
			float scale=max(d->width, d->height);
			
			for (int i=0;i<ne;i++)
			{
				if (abs(bb[elem].r/scale- (bb[i].r/scale))<ALIGN_THRESH)
				{
	                disp_x=-1.0*round((round(elem_width*scale_mod)-elem_width));
	               // disp_y=-1.0*round((round(elem_height*scale_mod)-elem_height));
				}
				else if (abs(bb[elem].mid_x()/scale - (bb[i].mid_x()/scale))<ALIGN_THRESH)
				{
	                disp_x=-1.0*round((round(elem_width*scale_mod)-elem_width)/2.0);
	              //  disp_y=-1.0*round((round(elem_height*scale_mod)-elem_height)/2.0);
				}
			
				if (abs(bb[elem].t/scale- (bb[i].t/scale))<ALIGN_THRESH)
				{
	                disp_y=-1.0*round((round(elem_height*scale_mod)-elem_height));
	               // disp_y=-1.0*round((round(elem_height*scale_mod)-elem_height));
				}
				else if (abs(bb[elem].mid_y()/scale - (bb[i].mid_y()/scale))<ALIGN_THRESH)
				{
					disp_y=-1.0*round((round(elem_height*scale_mod)-elem_height)/2.0);
				}
			}
			*/

			float r=randu();
			if (r<0.33)
                disp_x=-1.0*round((round(elem_width*scale_mod)-elem_width)/2.0);
			else if (r<0.66)
                disp_x=-1.0*round((round(elem_width*scale_mod)-elem_width));
			
			
			r=randu();
			
			if (r<0.33)
			{
               disp_y=-1.0*round((round(elem_height*scale_mod)-elem_height)/2.0);
                //printf("scale_mod %.3f, disp_x %.3f disp_y %.3f\n",scale_mod,disp_x,disp_y);
			}
			else if (r<0.66)
				disp_y=-1.0*round((round(elem_height*scale_mod)-elem_height));
			
			

			
			/*
			else if  (r<0.66)
			{
	            disp_x=-1.0*round((round(elem_width*scale_mod)-elem_width));
                disp_y=-1.0*round((round(elem_height*scale_mod)-elem_height));	
			}
			*/
			
		}




		else if (prop_select==GLOBAL_LOCATION_SHIFT)
		{

			Box shift_box;
			shift_box.set(bb[elem].l,bb[elem].r,bb[elem].b,bb[elem].t);


			int count=1;
			bool overlap=true;
			while (overlap and (count < 20))
			{
				float new_x=((d->width-(bb[elem].r-bb[elem].l))*randu());
				float new_y=((d->height-(bb[elem].t-bb[elem].b))*randu());

				shift_box.set_pos(new_x,new_y);

				overlap=checkBoundingBoxOverlap(shift_box,bb,ne,elem);
				count++;
			}

			disp_x=shift_box.l-bb[elem].l;
			disp_y=shift_box.b-bb[elem].b;

		}
		else if (prop_select==ALIGN_ELEMENT)
		{

			float rand_select=randu();

			if (rand_select<0.2)
				disp_x=getAlignmentDisplacement(d->num_elements,elem,bb,0,-1);
			else if (rand_select<0.4)
				disp_x=getAlignmentDisplacement(d->num_elements,elem,bb,0,0);
			else if (rand_select<0.6)
				disp_x=getAlignmentDisplacement(d->num_elements,elem,bb,0,1);
			else if (rand_select<0.7)
				disp_y=getAlignmentDisplacement(d->num_elements,elem,bb,1,-1);
			else if (rand_select<0.8)
				disp_y=getAlignmentDisplacement(d->num_elements,elem,bb,1,0);
			else
				disp_y=getAlignmentDisplacement(d->num_elements,elem,bb,1,1);
		}
		else if (prop_select==SWITCH_ALIGNMENT)
		{
			float rand_select=randu();
			
			if (d->fixed_alignment[elem]==0)
			{
				if (rand_select<0.5)
					new_align=0;
				//else if (rand_select<1.1)
				else
					new_align=1;
				//else
				//	new_align=2;
			}
			else
				continue;
		}
		else if (prop_select==GLOBAL_ALIGN)
		{

			float pos=int(round(randu()*10.0)/10.0);

			float axis_select=randu();

			if (axis_select <0.5)
			{
				float center=(bb[elem].l+bb[elem].r)/2.0;
				disp_x=pos*d->width - center;
			}
			else
			{
				float center=(bb[elem].b+bb[elem].t)/2.0;
				disp_y=pos*d->height - center;
			}
		}
		else if (prop_select==SWITCH_ALTERNATE)
		{

			int old_alt=proposal[elem*NUM_VAR+6];	
			
	
			if ((d->optional[elem]) && (old_alt>-1) && (randu()<0.5))
				proposal[elem*NUM_VAR+6]=-1;
			
			else if ((old_alt<0) || (d->num_alt[elem]>0))
			{
				float elem_aspect_ratio=d->aspect_ratio[elem];
				float elem_num_lines=d->num_lines[elem];

				 if (d->num_alt[elem]>0)
				 {

					int alt=(d->num_alt[elem]*randu());
					
					if ((d->alt_num_lines[elem*MAX_ALT+alt]>2)&&(d->alt_aspect_ratio[elem*MAX_ALT+alt]>0.5))
						continue;
					
					float scale=d->alt_num_lines[elem*MAX_ALT+alt]/d->alt_num_lines[elem*MAX_ALT+old_alt];
					
					elem_aspect_ratio=d->alt_aspect_ratio[elem*MAX_ALT+alt];
					elem_num_lines=d->alt_num_lines[elem*MAX_ALT+alt];
					
					proposal[NUM_VAR*elem+2]=proposal[NUM_VAR*elem+2]*scale;
					
					float scaled_height=(bb[elem].t-bb[elem].b)*scale;
					float scaled_width=scaled_height/elem_aspect_ratio;
					
					if ((scaled_width < 3) or (scaled_height < 3))
						continue;
						
					proposal[elem*NUM_VAR+6]=alt;
					
				}
				else
				{
					proposal[elem*NUM_VAR+6]=0;
				}
				
	
				height=(proposal[NUM_VAR*elem+2]*d->height);
				width=(height/elem_aspect_ratio);
				xp=(proposal[NUM_VAR*elem]*d->width);
				yp=(proposal[NUM_VAR*elem+1]*d->height);
		
				bb[elem].set(round(xp+(width*d->bb_left[elem])), round(xp+(width*d->bb_right[elem])), round(yp + (height*d->bb_bottom[elem])), round(yp + (height*d->bb_top[elem])));
				
				//if ((bb[elem].l>=bb[elem].r) || (bb[elem].b>=bb[elem].t))
				//	continue;
				
				//printf("changed alt from %i to %i. num alt %i \n",int(proposal[elem*NUM_VAR+6]),alt,d->num_alt[elem]);
				
				
			 }
			else
				continue;
			
		
		}
		
		else if ((prop_select==FLIP_TWO_ELEMENTS) && (d->num_elements>1))
		{
			
		
			int other_elem=(d->num_elements)*randu();
			
		
			int cnt=0;
			while ((cnt <50)&&((other_elem==elem)||(proposal[other_elem*NUM_VAR+4]>FIX_LAYOUT_THRESH)))
			{
				other_elem=(d->num_elements)*randu();
				cnt++;	
			}
			
			
			elems[0]=elem;
			elems[1]=other_elem;
			
			num_mod_elements=2;		
			//for (int i=0;i<ne;i++)
			//	new_bb[i].set(bb[i].l, bb[i].r,bb[i].b,bb[i].t);
			
			float rand_select=randu();
			bool flip_x=false;
			bool flip_y=false;
			if (rand_select<0.33)
				flip_y=true;
			else if (rand_select<0.66)
				flip_x=true;
			else if (rand_select<1)
			{
				flip_x=true;
				flip_y=true;

			}
			
			float tmp;
			if (flip_x)
			{
				tmp=proposal[elem*NUM_VAR];
				proposal[elem*NUM_VAR]=proposal[other_elem*NUM_VAR];
				proposal[other_elem*NUM_VAR]=tmp;		
			}
			if  (flip_y)
			{
				tmp=proposal[elem*NUM_VAR+1];
				proposal[elem*NUM_VAR+1]=proposal[other_elem*NUM_VAR+1];
				proposal[other_elem*NUM_VAR+1]=tmp;						
			}
				
		}
		else if ((prop_select==SHIFT_ALIGNED_ELEMENTS) && (d->num_elements>1))
		{
			
			float scale=max(d->width, d->height);
			
			
			float location_variance=0.1;
			float2 rands=randn();

			if (rands.x>0)
				disp_x=rands.y*location_variance*d->width;
			else
				disp_y=rands.y*location_variance*d->height;
			
			float elem_l=bb[elem].l/scale;
			float elem_m=bb[elem].mid_x()/scale;
			float elem_r=bb[elem].r/scale;
				
			num_mod_elements=0;
			for (int i=0;i<ne;i++)
			{
				if (proposal[i*NUM_VAR+4]<FIX_LAYOUT_THRESH)
					if  ((abs(elem_l- (bb[i].l/scale))<ALIGN_THRESH) || (abs(elem_m- (bb[i].mid_x()/scale))<ALIGN_THRESH) || (abs(elem_r- (bb[i].r/scale))<ALIGN_THRESH))
					{
						proposal[i*NUM_VAR]+=disp_x/d->width;
						proposal[i*NUM_VAR+1]+=disp_y/d->height;
						elems[num_mod_elements]=i;
						num_mod_elements++;
					}
				
			}
			
			if (num_mod_elements==0)
				continue;
		}
		
		
		
		else if ((prop_select==SCALE_TYPE))
		{
		
			float2 rands=randn();
			int type=0;
			if (rands.x>0)
				type=1;
		

			float height_variance=0.1;

				
			float scale_factor= 1.0+rands.y*height_variance;
			
			//printf("type %i, scale factor %.2f\n",type,scale_factor);

			num_mod_elements=0;
			for (int i=0;i<ne;i++)
			{
				if ((d->type[i]==type)  && (proposal[i*NUM_VAR+4]<FIX_LAYOUT_THRESH))
				{
					proposal[i*NUM_VAR+2]=proposal[i*NUM_VAR+2]*scale_factor;
					elems[num_mod_elements]=i;
					num_mod_elements++;
				}
			}
		}

		
		
		
		
		
		/*
		if (num_mod_elements>1)
		{
			for (int i=0;i<ne;i++)
				new_bb[i].set(bb[i].l, bb[i].r,bb[i].b,bb[i].t);
				
			for (int n=0;n<num_mod_elements;n++)
			{
	
				int i=elems[n];
				height=round(proposal[NUM_VAR*i+2]*d->height);
				width=round(height/aspect_ratio[i]);
				xp=round(proposal[NUM_VAR*i]*d->width);
				yp=round(proposal[NUM_VAR*i+1]*d->height);
				new_bb[i].set(round(xp+(width*d->bb_left[i])), round(xp+(width*d->bb_right[i])), round(yp + (height*d->bb_bottom[i])), round(yp + (height*d->bb_top[i])));
				
				
				
				if ((new_box.l<-2*d->width) || (new_box.b<-2*d->height)|| (new_box.r>2*d->width)|| (new_box.t>2*d->height))
				{
					
					printf("ERROR setting new box, prop_select %i for elem %i (of %i), fix amt %.3f, prop (%.3f %.3f %.3f ) vs curr(%.3f %.3f %.3f ) \n box l/r %.3f %.3f, b/t %.3f %.3f\n",prop_select,i,num_mod_elements,proposal[NUM_VAR*i+4],proposal[i*NUM_VAR],proposal[i*NUM_VAR+1],proposal[i*NUM_VAR+2],curr_layout[i*NUM_VAR],curr_layout[i*NUM_VAR+1],curr_layout[i*NUM_VAR+2],new_bb[i].l,new_bb[i].r,new_bb[i].b,new_bb[i].t);
					return -1;
				}
				
			}
		}
		*/

		
		
		
		if ((new_align>-1)&&(num_mod_elements==1))
		{
			proposal[elem*NUM_VAR+3]=(float)new_align;
			
			
			//if ((proposal[NUM_VAR*elem+4]>FIX_LAYOUT_THRESH))
			//	printf("switching alignment proposal %i for elem %i , fix amt %.3f, prop (%.3f) vs curr(%.3f) \n",prop_select,elem,proposal[NUM_VAR*elem+4],proposal[NUM_VAR*elem+3],curr_layout[elem*NUM_VAR+3]);
			
			
			break;
		}
		
	
		bool passed_checks=true;
		for (int n=0;n<num_mod_elements;n++)
		{
			
			if (num_mod_elements==1)
			{
				
				proposal[elem*NUM_VAR]+=disp_x/d->width;
				proposal[elem*NUM_VAR+1]+=disp_y/d->height;
		
				new_box.set(bb[elem].l+disp_x,bb[elem].r+disp_x,bb[elem].b+disp_y,bb[elem].t+disp_y);
		
				if (scale_mod!=1)
				{
					proposal[elem*NUM_VAR+2]=proposal[elem*NUM_VAR+2]*scale_mod;
					new_box.scale(scale_mod);
				}	
			}
			else
			{
				elem=elems[n];
				
				height=round(proposal[NUM_VAR*elem+2]*d->height);
				width=round(height/aspect_ratio[elem]);
				xp=round(proposal[NUM_VAR*elem]*d->width);
				yp=round(proposal[NUM_VAR*elem+1]*d->height);
				new_box.set(round(xp+(width*d->bb_left[elem])), round(xp+(width*d->bb_right[elem])), round(yp + (height*d->bb_bottom[elem])), round(yp + (height*d->bb_top[elem])));
				
				/*
				if ((new_box.l<-2*d->width) || (new_box.b<-2*d->height)|| (new_box.r>2*d->width)|| (new_box.t>2*d->height))
				{
					printf("ERROR setting new box, m %i, prop_select %i for elem %i (of %i), fix amt %.3f, ar %f,width %.3f height %.3f, prop (%.3f %.3f %.3f )  \n box old l/r %.3f %.3f, b/t %.3f %.3f, new l/r %.3f %.3f, b/t %.3f %.3f\n",m,prop_select,elem,num_mod_elements,proposal[NUM_VAR*elem+4],aspect_ratio[elem],width,height,proposal[elem*NUM_VAR],proposal[elem*NUM_VAR+1],proposal[elem*NUM_VAR+2],bb[elem].l,bb[elem].r,bb[elem].b,bb[elem].t,new_box.l,new_box.r,new_box.b,new_box.t);
					return -1;
				}
				*/
				
			}
			
			
			
			if ((!isfinite(proposal[elem*NUM_VAR]))|| (!isfinite(proposal[elem*NUM_VAR+1]))|| (!isfinite(proposal[elem*NUM_VAR+2])))
			{
				printf("Error in proposal type %i, element %i has prop %f %f %f\n",prop_select,elem,proposal[elem*NUM_VAR],proposal[elem*NUM_VAR+1],proposal[elem*NUM_VAR+2]);
				passed_checks=false;
				break;
			}
		
		

		
			//skip these checks if we're switching alternates to allow hiding/showing objects
			if ((prop_select==SWITCH_ALTERNATE))
				continue;
			
			
			float elem_size=10.0*(((new_box.t-new_box.b)/num_lines[elem])/max(d->width, d->height));
			
			if (elem_size<MIN_TEXT_SIZE)
			{
				passed_checks=false;
				break;
			}
			
			
			if ((round(new_box.r)-round(new_box.l)<3) || (round(new_box.t)-round(new_box.b)<3))
			{
				passed_checks=false;
				break;
			}
			
			/*
			if ((new_box.l<-2*d->width) || (new_box.b<-2*d->height)|| (new_box.r>2*d->width)|| (new_box.t>2*d->height))
			{
				
				printf("ERROR in proposal %i for elem %i (of %i), fix amt %.3f, prop (%.3f %.3f %.3f ) vs curr(%.3f %.3f %.3f ) \n box l/r %.3f %.3f, b/t %.3f %.3f\n",prop_select,elem,num_mod_elements,proposal[NUM_VAR*elem+4],proposal[elem*NUM_VAR],proposal[elem*NUM_VAR+1],proposal[elem*NUM_VAR+2],curr_layout[elem*NUM_VAR],curr_layout[elem*NUM_VAR+1],curr_layout[elem*NUM_VAR+2],new_box.l,new_box.r,new_box.b,new_box.t);
				passed_checks=false;
				break;
			}
			*/
				
				
			if ((new_box.r>d->width) || (new_box.t>d->height)|| (new_box.l<0)|| (new_box.b<0))
			{
				passed_checks=false;
				break;
			}
	
			/*
			if ((!already_overlapped) && (checkBoundingBoxOverlap(new_box,bb,ne,elem)))
			{
				passed_checks=false;
				break;
			}
			*/
		
			if ((proposal[NUM_VAR*elem+4]>1.0) && ((proposal[elem*NUM_VAR+2]!=curr_layout[elem*NUM_VAR+2]) || (proposal[elem*NUM_VAR+1]!=curr_layout[elem*NUM_VAR+1]) || (proposal[elem*NUM_VAR]!=curr_layout[elem*NUM_VAR])))
			{
				printf("ERROR in proposal %i for elem %i , fix amt %.3f, prop (%.3f %.3f %.3f ) vs curr(%.3f %.3f %.3f ) \n",prop_select,elem,proposal[NUM_VAR*elem+4],proposal[elem*NUM_VAR],proposal[elem*NUM_VAR+1],proposal[elem*NUM_VAR+2],curr_layout[elem*NUM_VAR],curr_layout[elem*NUM_VAR+1],curr_layout[elem*NUM_VAR+2]);
				passed_checks=false;
				break;
			} 

		
		}
		
		
		
		
		if (passed_checks)
			break;
		
	}
	

	/*
	for (int i=0;i<ne;i++)
	{
		height=round(proposal[NUM_VAR*i+2]*d->height);
		width=round(height/aspect_ratio[i]);
		xp=round(proposal[NUM_VAR*i]*d->width);
		yp=round(proposal[NUM_VAR*i+1]*d->height);

		Box elem_bb;
		elem_bb.set(round(xp+(width*d->bb_left[i])), round(xp+(width*d->bb_right[i])), round(yp + (height*d->bb_bottom[i])), round(yp + (height*d->bb_top[i])));


		//if ((elem_bb.r<=0) || (elem_bb.t<=0)|| (elem_bb.l>=d->width)|| (elem_bb.b>=d->height))
		if ((elem_bb.r==elem_bb.l)||(elem_bb.b==elem_bb.t))
		{
			printf("wtf1? %i prop select %i d %.2f %.2f, s %.2f, m %i  \n\t %1.2f %1.2f %1.2f %1.2f\n\t %1.2f %1.2f %1.2f %1.2f \n\t %1.2f %1.2f %1.2f %1.2f\n \t prop: %1.2f %1.2f %1.2f %1.2f (w/h) %3.1f %3.1f\n",i,prop_select, disp_x, disp_y, scale_mod,m,bb[i].l, bb[i].r,bb[i].b,bb[i].t,elem_bb.l,elem_bb.r,elem_bb.b,elem_bb.t,new_box.l,new_box.r,new_box.b,new_box.t,proposal[NUM_VAR*i],proposal[NUM_VAR*i+1],proposal[NUM_VAR*i+2],proposal[NUM_VAR*i+3],width,height);
		}
	}
	*/
	
	//failed to get a good proposal so give us and return the current layout
	if (m==MAX_PROPOSAL_TRIES)
	{
		for (int j=0;j<d->layout_size;j++)
			proposal[j]=curr_layout[j];
	}
	


	/*

	if (not screwed_up)
	{
		for (int i=0;i<ne;i++)
		{
			height=round(proposal[NUM_VAR*i+2]*d->height);
			width=round(height/aspect_ratio[i]);
			xp=round(proposal[NUM_VAR*i]*d->width);
			yp=round(proposal[NUM_VAR*i+1]*d->height);

			Box elem_bb;
			elem_bb.set(round(xp+(width*d->bb_left[i])), round(xp+(width*d->bb_right[i])), round(yp + (height*d->bb_bottom[i])), round(yp + (height*d->bb_top[i])));


			if ((elem_bb.r<=0) || (elem_bb.t<=0)|| (elem_bb.l>=d->width)|| (elem_bb.b>=d->height))
			{
				printf("wtf1? %i d %.2f %.2f, s %.2f, m %i , screwed %i \n\t %1.2f %1.2f %1.2f %1.2f\n\t %1.2f %1.2f %1.2f %1.2f \n\t %1.2f %1.2f %1.2f %1.2f\n \t prop: %1.2f %1.2f %1.2f %1.2f (w/h) %3.1f %3.1f\n",i,disp_x, disp_y, scale_mod,m,screwed_up,bb[i].l, bb[i].r,bb[i].b,bb[i].t,elem_bb.l,elem_bb.r,elem_bb.b,elem_bb.t,new_box.l,new_box.r,new_box.b,new_box.t,proposal[NUM_VAR*i],proposal[NUM_VAR*i+1],proposal[NUM_VAR*i+2],proposal[NUM_VAR*i+3],width,height);
			}
		}
	}
	*/


	//free(bb);
	//if (screwed_up)
	//	return -1;

	return prop_select;
}



__global__ void finiteDiffLayoutGrad(Design *d,int num_dir,float *directions,float *dir_map,int num_params, float *params, float *atan_params,float *params_grads, float *layout,float *layouts, float *layout_grad,float *line_search,int num_previous_layout, float *previous_layout)
{
	
	//if (blockIdx.x%EVAL_SPLIT_NUM==0)
	//	return;
	
	

	int thread_id= threadIdx.x + blockIdx.x * blockDim.x;
	
	if (thread_id>=num_dir)
	{
		//printf("thread_id %i > num_dir %i\n",thread_id,num_dir);
		return;	
	}
	

	//int num_var=d->num_elements*3;
	
	
	//float *dir=&(directions[thread_id*num_var]);
	float *dir=&(dir_map[thread_id*d->layout_size]);
	float *layout_copy=&(layouts[thread_id*d->layout_size]);
	float *params_grad=&(params_grads[thread_id*num_params]);
	
	
	
	double y=evaluateLayout(d,layout,params,atan_params,params_grad,num_previous_layout,previous_layout,false,false,false);
	
	
	
	double delta=FD_DELTA;
	
	for(int j=0;j<d->layout_size;j++)
		layout_copy[j]=layout[j]+delta*dir[j];	
	
	

	/*
	for(int j=0;j<num_var;j++)
	{
		if (abs(dir[j])>0.01)
		{
			int elem=(j%d->num_elements);
			int elem_var=(j/d->num_elements);
			int idx=elem*NUM_VAR+elem_var;
			
			if (layout[elem*NUM_VAR+4]!=1.0)
				layout_copy[idx]=layout[idx]+delta*dir[j];
			
		}
	}*/


		

	double y2=evaluateLayout(d,layout_copy,params,atan_params,params_grad,num_previous_layout,previous_layout,false,false,false);
	
	for(int j=0;j<d->layout_size;j++)
		layout_copy[j]=layout[j]-delta*dir[j];	


	double y1=evaluateLayout(d,layout_copy,params,atan_params,params_grad,num_previous_layout,previous_layout,false,false,false);

	layout_grad[thread_id]=(float)((y2-y1)/(2.0*delta));
	
	
	if ((y1==INVALID_ELEMENT_ERROR) || (y2==INVALID_ELEMENT_ERROR))
	{
		printf("INVALID_ELEMENT_ERROR called in gradient check\n direction:\n");
		/*
		for(int j=0;j<num_var;j++)
		{
			if (abs(dir[j])>0.01)
			{
				int elem=(j%d->num_elements);
				int elem_var=(j/d->num_elements);
				int idx=elem*NUM_VAR+elem_var;
				printf("elem %i, var %i, delta*dir %f, delta %f,dir %f\n",elem,elem_var,delta*dir[j],delta,dir[j]);
				
			}
		}
		*/
	}
	
	//if ((y==y1) ||(y==y2))
	//	printf("delta too small. y %f, y1 %f, y2 %f\n",y,y1,y2);
	
	//if ((y<y1) && (y<y2))
	//	printf("delta too big. y %f, y1 %f, y2 %f\n",y,y1,y2);
	
	
	//do line search in this direction
	
	float *ls=&(line_search[thread_id*NUM_LINE_STEPS]);
	
	if (y2>y1)
		delta=-1*delta;
		
	ls[0]=y;
	
	for(int i=1;i< NUM_LINE_STEPS;i++)
	{

		/*
		for(int j=0;j<num_var;j++)
		{
			if (abs(dir[j])>0.01)
			{
				int elem=(j%d->num_elements);
				int elem_var=(j/d->num_elements);
				int idx=elem*NUM_VAR+elem_var;
				if (layout[elem*NUM_VAR+4]!=1.0)
				{
					layout_copy[idx]=layout[idx]+delta*dir[j];
					if (elem_var==2) 
						layout_copy[idx]=max(layout_copy[idx],0.005);
				}
			}
		}
		*/
		for(int j=0;j<d->layout_size;j++)
			layout_copy[j]=layout[j]+delta*dir[j];	
		
		double y_step=evaluateLayout(d,layout_copy,params,atan_params,params_grad,num_previous_layout,previous_layout,false,false,false);
		
		
		ls[i]=y_step;
		
		delta=delta*2;
	}
	

	
	
	if ((!isfinite(layout_grad[thread_id])))
	{
		printf("error in gradient calc %f %f\n",y1,y2);
		
		if ((!isfinite(y2)))
			y2=evaluateLayout(d,layout_copy,params,atan_params,params_grad,num_previous_layout,previous_layout,false,true,false);
	}

		
	
}


/*


__device__ int getRegionProposal(Design *d, float *curr_layout, float *proposal,bool debug)
{
	

		
	memcpy(proposal, curr_layout, d->layout_size*sizeof(float));
	
	int num_text_regions=0,num_graphic_regions=0,num_regions;
	int ne=d->num_elements;
	int offset=ne*NUM_VAR;
	int num_text=0, num_graphic=0;
	
	num_text_regions=0;
	num_graphic_regions=0;
	for(int i=0;i< ne;i++)
	{
		if (int(curr_layout[offset+i*NUM_RVAR])==1)
			num_text_regions++;
		else if (int(curr_layout[offset+i*NUM_RVAR])==2)
			num_graphic_regions++;
			
		if (d->type[i]==1)
			num_text++;
		else
			num_graphic++;
	}
	
	
	//if (debug)
	if (randu()<0.001)
		printf("getRegionProposal");
	
	
	float aspect_ratio[MAX_ELEMENTS];
	//int num_lines[MAX_ELEMENTS];



	
	int flip_cnt=0;

	float display=false;

	int prop_select=0;
			
	Box merge_r1;
	Box merge_r2;
	//bool fucked;
	//bool regions_fucked;
	int elem;
	int r;
	
	Box region_bb[MAX_ELEMENTS];
	Box bb[MAX_ELEMENTS];
	int num_elements_reg[MAX_ELEMENTS];
	int reg_change=0;
	
	
	int m;
	for (m=0;m<MAX_PROPOSAL_TRIES;m++)
	{

		memcpy(proposal, curr_layout, d->layout_size*sizeof(float));
		
		
		for (int i=0;i<ne;i++)
		{
			int alt=int(curr_layout[NUM_VAR*i+6]);
			if (alt>-1)
				aspect_ratio[i]=d->alt_aspect_ratio[i*MAX_ALT+alt];
			else
				aspect_ratio[i]=d->aspect_ratio[i];
		}

		
		num_regions=num_text_regions+num_graphic_regions;
		
		//if (((num_text>0) and (num_text_regions==0)) or ((num_graphic>0) and (num_graphic_regions==0)))
		//{	
		//	printf("error text %i %i, graphic %i %i\n",num_text,num_text_regions,num_graphic,num_graphic_regions);
		//	return -1;
		//}
		
		//bool contains_fixed[MAX_ELEMENTS];
		//for (int i=0;i<ne;i++)
		//	contains_fixed[i]=false;
		
		
		
		for (int i=0;i<ne;i++)
			num_elements_reg[i]=0;
			
		reg_change=0;

		
		
		//if element has no region, do random initial assignment
		for (int i=0;i<ne;i++)
		{
			int r=proposal[i*NUM_VAR+5];
			
			if (r>-1)
			{
				num_elements_reg[r]++;
				
				if (proposal[offset+r*NUM_RVAR]==-1)
				{
					printf("ERROR in initialization. region %i doesn't exist\n",r);
					return -1;
				}
			}
			
			//
			if ((r==-1) and (proposal[i*NUM_VAR+4]<FIX_LAYOUT_THRESH))
			{
				//printf("error, element %i has no region\n",i);
				//assignElementRegion(d,proposal,curr_layout,i,num_text_regions,num_graphic_regions);
				float height=round(proposal[NUM_VAR*i+2]*d->height);
				float width=round(height/aspect_ratio[i]);
				float xp=round(proposal[NUM_VAR*i]*d->width);
				float yp=round(proposal[NUM_VAR*i+1]*d->height);
				
				proposal[offset+num_regions*NUM_RVAR]=d->type[i];
				proposal[offset+num_regions*NUM_RVAR+1]=round(xp+(width*d->bb_left[i])); 
				proposal[offset+num_regions*NUM_RVAR+2]=round(yp+(height*d->bb_bottom[i]));
				proposal[offset+num_regions*NUM_RVAR+3]=width;
				proposal[offset+num_regions*NUM_RVAR+4]=height;
				proposal[offset+num_regions*NUM_RVAR+5]=1.0;	
				proposal[offset+num_regions*NUM_RVAR+6]=0.0;
				
				proposal[i*NUM_VAR+5]=num_regions;
				num_elements_reg[num_regions]=1;
				reg_change=1;
				num_regions++;	
			}
		}
		
		if (num_regions==0)
		{
			printf("ERROR in initialization. No regions at all?");
		
			for (int i=0;i<ne;i++)
				printf("element %i has assigned region %i\n",i,int(curr_layout[i*NUM_VAR+5]));
			
			for (int i=0;i<ne;i++)
				printf("region %i has type %i\n",i,int(curr_layout[offset+i*NUM_RVAR]))	;	

			return -1;
			
		}
		
		
		for (int reg=0;reg<num_regions;reg++)
		{
			if (num_elements_reg[reg]<1)
			{
				printf("ERROR in initialization. m %i, Region %i (type %i): %.2f %.2f %.2f %.2f has no elements. num regions %i (t %i g %i) \n",m,reg,int(proposal[offset+r*NUM_RVAR]), proposal[offset+r*NUM_RVAR+1],proposal[offset+r*NUM_RVAR+2],proposal[offset+r*NUM_RVAR+3],proposal[offset+r*NUM_RVAR+4],num_regions,num_text_regions,num_graphic_regions);
				
				
				//for (int reg2=0;reg2<num_regions;reg2++)
				//	printf("region %i has num elements %i\n",reg2,num_elements_reg[reg2]);
				
				//for (int i=0;i<ne;i++)
				//	printf("element %i has assigned region %i\n",i,int(curr_layout[i*NUM_VAR+5]));
				
				//for (int i=0;i<ne;i++)
				//	printf("region %i has type %i\n",i,int(curr_layout[offset+i*NUM_RVAR]))	;	

				
				return -1;
				
			}
		}
		
			
	
		//if (d->fixed_regions)
		//{	
		//	int select=(((float)NUM_FIXED_REGION_PROPOSALS)*randu());
		//	prop_select=fix_reg_prop_choice[select];
		//}
		//else
		//{
			int select=(((float)NUM_REGION_PROPOSALS)*randu());
			prop_select=reg_prop_choice[select];
		//}
		
		


		
		
		elem=((float)ne*randu());		
		
		int cnt=0;
		while ((proposal[elem*NUM_VAR+4]>FIX_LAYOUT_THRESH) && (cnt<20))
		{
			elem=((float)ne*randu());
			cnt++;	
		}
		if (cnt==20)	
		{
			printf("ERROR in selecting element");
			return -1;
		}
		
		r=((float)num_regions*randu());
		
		
		
	
		for (int i=0;i<num_regions;i++)
		{
			region_bb[i].set(proposal[offset+i*NUM_RVAR+1], proposal[offset+i*NUM_RVAR+1]+ proposal[offset+i*NUM_RVAR+3], proposal[offset+i*NUM_RVAR+2],proposal[offset+i*NUM_RVAR+2]+proposal[offset+i*NUM_RVAR+4]);

		}
	
		
		float height,width,xp,yp;
	
		for (int i=0;i<ne;i++)
		{
			height=(proposal[NUM_VAR*i+2]*d->height);
			width=(height/aspect_ratio[i]);
			xp=(proposal[NUM_VAR*i]*d->width);
			yp=(proposal[NUM_VAR*i+1]*d->height);
	
			bb[i].set(round(xp+(width*d->bb_left[i])), round(xp+(width*d->bb_right[i])), round(yp + (height*d->bb_bottom[i])), round(yp + (height*d->bb_top[i])));
			//bb[i].set(xp, xp+(width), yp, yp + (height));
			
			if ((bb[i].l>=bb[i].r)|| (bb[i].b>=bb[i].t))
			{
				printf("ERROR. input bounding box for element %i fucked l/r: %f %f b/t: %f %f\n",i,bb[i].l,bb[i].r,bb[i].b,bb[i].t);
				return -1;
			}	
		}
			
			
		
			
		float location_variance=0.1;

		if (prop_select==REG_SWAP)
		{
			if (num_regions>1)
			{
				int r2=((float)num_regions*randu());
				int cnt=0;
				while ((cnt<100)&&(r2==r))
				{
					r2=((float)num_regions*randu());
					cnt++;	
				}
				if (cnt==100)
				{
					printf("ERROR in selection %i\n",num_regions);
					return -1;
				}
					
				float temp;
				for (int i=1;i<3;i++)
				{
					temp=proposal[offset+r*NUM_RVAR+i];
					proposal[offset+r*NUM_RVAR+i]=proposal[offset+r2*NUM_RVAR+i];
					proposal[offset+r2*NUM_RVAR+i]=temp;
				}
			}
			else
				continue;
		}	
		
		else if (prop_select==REG_GLOBAL_LOCATION_SHIFT)
		{
	
			
			Box shift_box;
			shift_box.set(region_bb[r].l,region_bb[r].r,region_bb[r].b,region_bb[r].t);
	
			int cnt=1;
			bool overlap=true;
			while (overlap and (cnt < 20))
			{
				float new_x=((d->width-(region_bb[r].r-region_bb[r].l))*randu());
				float new_y=((d->height-(region_bb[r].t-region_bb[r].b))*randu());
	
				shift_box.set_pos(new_x,new_y);
	
				overlap=checkBoundingBoxOverlap(shift_box,region_bb,num_regions,r);
				cnt++;
			}
			
			
			proposal[offset+r*NUM_RVAR+1]+=shift_box.l-region_bb[r].l;
			proposal[offset+r*NUM_RVAR+2]+=shift_box.b-region_bb[r].b;
			//proposal[offset+r*NUM_RVAR+3]+=disp_y;
			//proposal[offset+r*NUM_RVAR+4]+=disp_y;
		}
		
		else if(prop_select==REG_CURR_LOCATION_SHIFT)
		{
			float2 rands=randn();
			
			if (randu()>0.5)
			{
				float x_offset=rands.y*location_variance*d->width;
				proposal[offset+r*NUM_RVAR+1]=min(max(proposal[offset+r*NUM_RVAR+1]+x_offset,0.0),d->width-1);	
				
			}
			else
			{
				float y_offset=rands.y*location_variance*d->height;
				proposal[offset+r*NUM_RVAR+2]=min(max(proposal[offset+r*NUM_RVAR+2]+y_offset,0.0),d->height-1);		
			}
		}
		
		
		else if(prop_select==REG_BB_SHIFT)
		{
			float2 rands=randn();
			
			int orientation=int(proposal[offset+r*NUM_RVAR+6]);
				
			if (orientation==1)	
				proposal[offset+r*NUM_RVAR+3]=min(max(proposal[offset+r*NUM_RVAR+3]+rands.y*location_variance*0.5*d->width,5.0),d->width-1);
			else
				proposal[offset+r*NUM_RVAR+4]=min(max(proposal[offset+r*NUM_RVAR+4]+rands.y*location_variance*0.5*d->height,5.0),d->height-1);
		}
	
		else if (prop_select==REG_ALIGN_TWO)
		{
	
			float rand_select=randu();
			if (num_regions>1)
			{
				if (rand_select<0.2)
					proposal[offset+r*NUM_RVAR+1]+=getAlignmentDisplacement(num_regions,r,region_bb,0,-1);
				else if (rand_select<0.4)
					proposal[offset+r*NUM_RVAR+1]+=getAlignmentDisplacement(num_regions,r,region_bb,0,0);
				else if (rand_select<0.6)
					proposal[offset+r*NUM_RVAR+1]+=getAlignmentDisplacement(num_regions,r,region_bb,0,1);
				else if (rand_select<0.7)
					proposal[offset+r*NUM_RVAR+2]+=getAlignmentDisplacement(num_regions,r,region_bb,1,-1);
				else if (rand_select<0.8)
					proposal[offset+r*NUM_RVAR+2]+=getAlignmentDisplacement(num_regions,r,region_bb,1,0);
				else
					proposal[offset+r*NUM_RVAR+2]+=getAlignmentDisplacement(num_regions,r,region_bb,1,1);
					
			}
			else
				continue;
			
		}	
			
		else if (prop_select==REG_ELEMENT_SWITCH)
		{
			//assignElementRegion(d,proposal,curr_layout,elem,num_text_regions,num_graphic_regions);
			
			
			int curr_region=proposal[elem*NUM_VAR+5];
			
			if (num_regions>2)
			{
				int r2=curr_region;
				
				int cnt=0;
				while ((cnt<100)&& (r2==curr_region))
				{
					r2=((float)num_regions*randu());
					cnt++;	
				}
				if(cnt==100)
				{
					printf("ERROR in selection %i\n",num_regions);
					return -1;
				}
					
				//this is the only element, so remove curr_region
				if (num_elements_reg[curr_region]==1)
				{
	
					if (num_regions-1 != curr_region)
					{
					
						for (int i=0;i < ne;i++)
						{
							if ((int(proposal[i*NUM_VAR+5])==num_regions-1)) 
								proposal[i*NUM_VAR+5]=curr_region;
						}	
					
						for (int i=0;i < NUM_RVAR;i++)
							proposal[offset+curr_region*NUM_RVAR+i]=proposal[offset+(num_regions-1)*NUM_RVAR+i];
	
					}
					
					proposal[offset+(num_regions-1)*NUM_RVAR]=-1;
					num_regions--;	
					reg_change=-1;			
				}
		
				if (r2==num_regions)
					proposal[elem*NUM_VAR+5]=curr_region;
				else
					proposal[elem*NUM_VAR+5]=r2;
					
			}
			else
				continue;
		}
		
	
		else if ((prop_select==REG_ELEMENT_SPLIT) and (num_regions<MAX_ELEMENTS))
		{
			
			int cnt=0;
			for (int i=0;i < ne;i++)
				if (proposal[i*NUM_VAR+5]==proposal[elem*NUM_VAR+5])
					cnt++;
					
			if (cnt>1)
			{
				
				Box shift_box;
				shift_box.set(bb[elem].l,bb[elem].r,bb[elem].b,bb[elem].t);
				
				int count=1;
				bool overlap=true;
				while (overlap and (count < 20))
				{
					float new_x=((d->width-(bb[elem].r-bb[elem].l))*randu());
					float new_y=((d->height-(bb[elem].t-bb[elem].b))*randu());
		
					shift_box.set_pos(new_x,new_y);
		
					overlap=checkBoundingBoxOverlap(shift_box,bb,d->num_elements,elem);
					count++;
				}
				
				
				proposal[offset+num_regions*NUM_RVAR]=d->type[elem];
				proposal[offset+num_regions*NUM_RVAR+1]=shift_box.l;
				proposal[offset+num_regions*NUM_RVAR+2]=shift_box.b;
				proposal[offset+num_regions*NUM_RVAR+3]=bb[elem].width();
				proposal[offset+num_regions*NUM_RVAR+4]=bb[elem].height();
				proposal[offset+num_regions*NUM_RVAR+5]=0;
				proposal[offset+num_regions*NUM_RVAR+6]=0;			
				
				proposal[elem*NUM_VAR+5]=num_regions;
				
				num_regions++;
				reg_change=1;
			}
			else
				continue;	
		}
		
		else if ((prop_select==REG_SPLIT) and (num_regions<MAX_ELEMENTS))
		{
			
	
			if (num_elements_reg[r]>1)
			{
				Box old_bb;
				old_bb.set(proposal[offset+r*NUM_RVAR+1], proposal[offset+r*NUM_RVAR+1]+proposal[offset+r*NUM_RVAR+3],proposal[offset+r*NUM_RVAR+2], proposal[offset+r*NUM_RVAR+2]+proposal[offset+r*NUM_RVAR+4]);
				
				
				//split horizontally
				if (old_bb.width() > old_bb.height())
				{
					float mid_pt=(old_bb.l + old_bb.r)/2.0;
						
					proposal[offset+num_regions*NUM_RVAR+1]=mid_pt;
					proposal[offset+num_regions*NUM_RVAR+2]=proposal[offset+r*NUM_RVAR+2];
					proposal[offset+num_regions*NUM_RVAR+3]=proposal[offset+r*NUM_RVAR+3]/2.0;
					proposal[offset+num_regions*NUM_RVAR+4]=proposal[offset+r*NUM_RVAR+4];
					
					proposal[offset+r*NUM_RVAR+3]=proposal[offset+r*NUM_RVAR+3]/2.0;	
					
				}
				//split vertically
				else
				{
					float mid_pt=(old_bb.b + old_bb.t)/2.0;
		
					proposal[offset+num_regions*NUM_RVAR+1]=proposal[offset+r*NUM_RVAR+1];
					proposal[offset+num_regions*NUM_RVAR+2]=mid_pt;
					proposal[offset+num_regions*NUM_RVAR+3]=proposal[offset+r*NUM_RVAR+3];
					proposal[offset+num_regions*NUM_RVAR+4]=proposal[offset+r*NUM_RVAR+4]/2.0;
					
					proposal[offset+r*NUM_RVAR+4]=proposal[offset+r*NUM_RVAR+4]/2.0;	
				}
				
				proposal[offset+num_regions*NUM_RVAR]=proposal[offset+r*NUM_RVAR];
				proposal[offset+num_regions*NUM_RVAR+5]=proposal[offset+r*NUM_RVAR+5];
				proposal[offset+num_regions*NUM_RVAR+6]=proposal[offset+r*NUM_RVAR+6];
				
				
				flip_cnt=0;
				for (int i=0;i < ne;i++)
				{
					
					if ((int(proposal[i*NUM_VAR+5])==r) && (randu()<0.5))
					{
						proposal[i*NUM_VAR+5]=num_regions;	
						flip_cnt++;				
					}
				}
				//make sure we don't leave an empty region
				if (flip_cnt==num_elements_reg[r])
				{
					for (int i=0;i < ne;i++)
					{
						if (int(proposal[i*NUM_VAR+5])==num_regions)
						{
							proposal[i*NUM_VAR+5]=r;	
							break;	
						}				
					}
				}
				if (flip_cnt==0)
				{
					for (int i=0;i < ne;i++)
					{
						if (int(proposal[i*NUM_VAR+5])==r)
						{
							proposal[i*NUM_VAR+5]=num_regions;	
							break;	
						}				
					}
				}
				
				
				reg_change=1;
				num_regions++;
			}
			else
				continue;
		}
		else if (prop_select==REG_MERGE)
		{
			
			//assignElementRegion(d,proposal,curr_layout,elem,num_text_regions,num_graphic_regions);
			
			float can_merge=true;
			//for (int i=0;i < num_regions;i++)
			//	if ((i!=r) && (int(proposal[offset+r*NUM_RVAR])==int(proposal[offset+i*NUM_RVAR])))
			//		can_merge=true;
			
			if ((can_merge) && (num_regions>2))
			{
				//printf("can merge\n");
				
				int cnt=0;
				int r2=r;
				while ((r2==r) &&(cnt<100)) //|| (int(proposal[offset+r*NUM_RVAR])!=int(proposal[offset+r2*NUM_RVAR])))
				{
					r2=num_regions*randu();
					cnt++;
				}
				if (cnt==100)
				{
					printf("ERROR in selecting region %i, num regions %i\n",r,num_regions);
					
					return -1;					
				}
				
					
				if (r2<r)
				{
					int temp_r=r2;
					r2=r;
					r=temp_r;
				}
				
	
		        float loc_xdiff=-1*min((region_bb[r].r-region_bb[r2].l),(region_bb[r2].r-region_bb[r].l));
	        	float loc_ydiff=-1*min((region_bb[r].t-region_bb[r2].b),(region_bb[r2].t-region_bb[r].b));
				
				
				int out_of_bounds=0;
				if ((region_bb[r].l<0)||(region_bb[r2].l<0)||(region_bb[r].b<0)||(region_bb[r2].b<0)||(region_bb[r].r>d->width)||(region_bb[r2].r>d->width)||(region_bb[r].t>d->height)||(region_bb[r2].t>d->height))
	        		out_of_bounds=1;
	        		
	        	merge_r1=region_bb[r];
	        	merge_r2=region_bb[r2];
	        		
				//if ((max(loc_xdiff,loc_ydiff))<max(d->width,d->height)/5)
				//{
					
					//check for same type
				
					//if ((int(proposal[offset+r*NUM_RVAR])==2) && (randu()<0.05))
					//	display=true;
					
					//float new_width, new_height;
					
					//int x_align=int(proposal[offset+r*NUM_RVAR+5])%2;
					//int orientation=int(proposal[offset+r*NUM_RVAR+6]);
					
					proposal[offset+r*NUM_RVAR+1]=min(proposal[offset+r*NUM_RVAR+1],proposal[offset+r2*NUM_RVAR+1]);
					proposal[offset+r*NUM_RVAR+2]=min(proposal[offset+r*NUM_RVAR+2],proposal[offset+r2*NUM_RVAR+2]);
					
					
					proposal[offset+r*NUM_RVAR+3]=max(region_bb[r].r,region_bb[r2].r)-proposal[offset+r*NUM_RVAR+1];
					proposal[offset+r*NUM_RVAR+4]=max(region_bb[r].t,region_bb[r2].t)-proposal[offset+r*NUM_RVAR+2];
					
					
					if ((!out_of_bounds) && ((proposal[offset+r*NUM_RVAR+1]<0)||(proposal[offset+r*NUM_RVAR+2]<0)||(proposal[offset+r*NUM_RVAR+1]+proposal[offset+r*NUM_RVAR+3]>d->width)||(proposal[offset+r*NUM_RVAR+2]+proposal[offset+r*NUM_RVAR+4]>d->height)))
	        		{
						printf("ERROR. Region %i out of bounds after merge. region %.2f %.2f %.2f %.2f \n", r,prop_select,proposal[offset+r*NUM_RVAR+1],proposal[offset+r*NUM_RVAR+2],proposal[offset+r*NUM_RVAR+3],proposal[offset+r*NUM_RVAR+4]);
						printf("BBs were %.2f %.2f %.2f %.2f , %.2f %.2f %.2f %.2f\n",region_bb[r].l,region_bb[r].r,region_bb[r].b,region_bb[r].t,region_bb[r2].l,region_bb[r2].r,region_bb[r2].b,region_bb[r2].t);
						return -1;
	        		}
	        			
	        			
					
					
					if (display)
						printf("num regions %i try %i) %f %f %f %f %i) %f %f %f %f merged %f %f %f %f\n",num_regions, r,region_bb[r].l,region_bb[r].r,region_bb[r].b,region_bb[r].t,r2,region_bb[r2].l,region_bb[r2].r,region_bb[r2].b,region_bb[r2].t,  proposal[offset+r*NUM_RVAR+1],proposal[offset+r*NUM_RVAR+1]+proposal[offset+r*NUM_RVAR+3],proposal[offset+r*NUM_RVAR+2],proposal[offset+r*NUM_RVAR+2]+proposal[offset+r*NUM_RVAR+4]);
					
					
					
					if (randu()<0.5)
					{
						if (proposal[offset+r*NUM_RVAR+3]>proposal[offset+r*NUM_RVAR+4])
							proposal[offset+r*NUM_RVAR+6]=1;
						else
							proposal[offset+r*NUM_RVAR+6]=0;
					}
						
					//delete region r2
					//assign all elements from r2 to r
					//fill in r2 with the last region
					for (int i=0;i < ne;i++)
					{
						if ((int(proposal[i*NUM_VAR+5])==r2))
							proposal[i*NUM_VAR+5]=r;
						else if ((int(proposal[i*NUM_VAR+5])==num_regions-1)) 
							proposal[i*NUM_VAR+5]=r2;
					}
					
					
					//overwrite r2 with the last region, but only if they're different
					if (num_regions-1 != r2)
					{
						for (int i=0;i < NUM_RVAR;i++)
							proposal[offset+r2*NUM_RVAR+i]=proposal[offset+(num_regions-1)*NUM_RVAR+i];	
					}

					//blank the last region
					proposal[offset+(num_regions-1)*NUM_RVAR]=-1;		
					reg_change=-1;
					num_regions--;	

				//}
	
			}
			else
				continue;
			
		}
		else if(prop_select==REG_ORIENTATION)
		{
			
			//printf("was %i\n",int(proposal[offset+r*NUM_RVAR+6]));	
			
			if (int(proposal[offset+r*NUM_RVAR+6])==1)
			{
				proposal[offset+r*NUM_RVAR+6]=0;
		
			}
			else
			{
				proposal[offset+r*NUM_RVAR+6]=1;
				
		
				if (randu()<0.5)
				{
					for (int i=0;i < ne;i++)
					{	
						if (proposal[i*NUM_VAR+5]==r)
							proposal[i*NUM_VAR+2]=(region_bb[r].height()-2)/d->height;
						
					}
				}
				
				
			}
			
			//printf("set to %i\n",int(proposal[offset+r*NUM_RVAR+6]));	
		}
		else if(prop_select==REG_ALIGN)
		{
	
				
			int prop =int(proposal[offset+r*NUM_RVAR+5]);
			
			//flip x axis alignment
			if (randu()<0.5)
			{
				if (prop>2)
					proposal[offset+r*NUM_RVAR+5]=prop-3;
				else
					proposal[offset+r*NUM_RVAR+5]=prop+3;
					
				//if (debug)
				//	printf("1 %i\n", int(proposal[offset+r*NUM_RVAR+5]));
			}
			//flip y axis alignment
			else
			{
				if (prop>2)
					proposal[offset+r*NUM_RVAR+5]=int(3*randu())+3;
				else 
					proposal[offset+r*NUM_RVAR+5]=int(3*randu());
					
				//if (debug)
				//	printf("2 %i\n", int(proposal[offset+r*NUM_RVAR+5]));
			}
			
	
		}
		else if ((prop_select==REG_ELEMENT_HEIGHT))
		{
			float height_variance=0.05;
		
			if (d->type[elem]!=1)
				height_variance=height_variance*2;
		
			float new_height=0;
			int cnt=0;
			while ((cnt<100)&&(new_height<0.01))
			{
				float2 rands=randn();
				new_height=proposal[elem*NUM_VAR+2]+rands.y*height_variance;
				cnt++;
			}
			if (cnt==100)
			{
				printf("ERROR in setting new height\n");
				cnt++;
			}
	
			proposal[elem*NUM_VAR+2]=new_height;	
			
			height=(proposal[NUM_VAR*elem+2]*d->height);
			width=(height/aspect_ratio[elem]);
			xp=(proposal[NUM_VAR*elem]*d->width);
			yp=(proposal[NUM_VAR*elem+1]*d->height);
	
			bb[elem].set(round(xp+(width*d->bb_left[elem])), round(xp+(width*d->bb_right[elem])), round(yp + (height*d->bb_bottom[elem])), round(yp + (height*d->bb_top[elem])));
			
			
			cnt=0;
			for (int i=0;i < ne;i++)
				if (proposal[i*NUM_VAR+5]==proposal[elem*NUM_VAR+5])
					cnt++;
					
			if (cnt==1)
			{
				int r=proposal[elem*NUM_VAR+5];
				proposal[offset+r*NUM_RVAR+1]=bb[elem].l; 
				proposal[offset+r*NUM_RVAR+2]=bb[elem].b;
				proposal[offset+r*NUM_RVAR+3]=bb[elem].width();	
				proposal[offset+r*NUM_RVAR+4]=bb[elem].height();	
			}
				
		}
		else if (prop_select==REG_SWITCH_ALTERNATE)
		{
			
			int old_alt=proposal[elem*NUM_VAR+6];
			
			if (d->num_alt[elem]>0)
			{
				
				int alt=(d->num_alt[elem]*randu());
				
				float scale=d->alt_num_lines[elem*MAX_ALT+alt]/d->alt_num_lines[elem*MAX_ALT+old_alt];
				
				if ((d->alt_num_lines[elem*MAX_ALT+alt]>2)&&(d->alt_aspect_ratio[elem*MAX_ALT+alt]>0.5))
					continue;
				
				float scaled_height=(bb[elem].t-bb[elem].b)*scale;
				float scaled_width=scaled_height/d->alt_aspect_ratio[elem*MAX_ALT+alt];
				
				if ((scaled_width < 3) or (scaled_height < 3))
					continue;
					
				proposal[NUM_VAR*elem+2]=proposal[NUM_VAR*elem+2]*scale;
	
				
				aspect_ratio[elem]=d->alt_aspect_ratio[elem*MAX_ALT+alt];
				//num_lines[elem]=d->alt_num_lines[elem*MAX_ALT+alt];
	
	
				height=(proposal[NUM_VAR*elem+2]*d->height);
				width=(height/aspect_ratio[elem]);
				xp=(proposal[NUM_VAR*elem]*d->width);
				yp=(proposal[NUM_VAR*elem+1]*d->height);
		
				bb[elem].set(round(xp+(width*d->bb_left[elem])), round(xp+(width*d->bb_right[elem])), round(yp + (height*d->bb_bottom[elem])), round(yp + (height*d->bb_top[elem])));
				
				//printf("changed alt from %i to %i. num alt %i \n",int(proposal[elem*NUM_VAR+6]),alt,d->num_alt[elem]);
				proposal[elem*NUM_VAR+6]=alt;
			}
			else
				continue;
		
		}
		else if (prop_select==REG_ELEMENT_ORDER)
		{
			
			if (ne>1)
			{
				int other_elem=(ne)*randu();
					
				while (other_elem==elem)
				{
					other_elem=(ne)*randu();
				}
			
				float temp=proposal[elem*NUM_VAR+7];
				proposal[elem*NUM_VAR+7]=proposal[other_elem*NUM_VAR+7];
				proposal[other_elem*NUM_VAR+7]=temp;
			}	
			else
				continue;
		}
		
		
			
		for (int i=0;i<num_regions;i++)
			region_bb[i].set(proposal[offset+i*NUM_RVAR+1], proposal[offset+i*NUM_RVAR+1]+ proposal[offset+i*NUM_RVAR+3], proposal[offset+i*NUM_RVAR+2],proposal[offset+i*NUM_RVAR+2]+proposal[offset+i*NUM_RVAR+4]);
		
		

		
		bool intersect=false;
		for (int i=0;i<num_regions;i++)
		for (int j=i+1;j<num_regions;j++)
		{
			//(i!=j)&& &&(((region_bb[i].l>region_bb[j].l) && (region_bb[i].r<region_bb[j].r)) || ((region_bb[i].b>region_bb[j].b) && (region_bb[i].t<region_bb[j].t)))
			if ((anyBoxIntersection(region_bb[i],region_bb[j])) )
				intersect=true;
			
		}
		
			
		if ((not intersect) && (region_bb[r].l>0)&&(region_bb[r].b>0)&&(region_bb[r].r<d->width)&&(region_bb[r].t<d->height))
		{
			break;	
			//printf("ERROR: region out of bounds with prop select %i\n",prop_select);
			//printf(" region l/r: %.2f - %.2f, b/t: %.2f - %.2f \n",proposal[offset+r*NUM_RVAR+1],proposal[offset+r*NUM_RVAR+1]+proposal[offset+r*NUM_RVAR+3],proposal[offset+r*NUM_RVAR+2],proposal[offset+r*NUM_RVAR+2]+proposal[offset+r*NUM_RVAR+4]);		
		}
			
			
	}
	
	
	
 	//if (randu()<0.001)	
 	//	printf("prop select %i\n",prop_select);
			
	int modified_reg=r;
			
			
	//ASSERTION: the number of regions is correct
	int num_regions_check=0;
	for (int reg=0;reg<ne;reg++)
	{
		if (int(proposal[offset+reg*NUM_RVAR])!=-1)
			num_regions_check++;		
	}
	
	if (num_regions_check!=num_regions)
	{
	
		printf(" ERROR. num_regions_check %i, num_regions %i. m %i. Proposal %i. modified region %i region change %i. flipped %i of %i. num text %i num graphic %i\n",num_regions_check,num_regions,m,prop_select,modified_reg,reg_change,flip_cnt,num_elements_reg[modified_reg],num_text_regions, num_graphic_regions);
		
		return -1;
	}
	
			
			
			
	//put elements in region based on parameters
	for (int r=0;r<num_regions;r++)
	{
	
		//region_bb[r].set(proposal[offset+r*NUM_RVAR+1], proposal[offset+r*NUM_RVAR+2], proposal[offset+r*NUM_RVAR+3], proposal[offset+r*NUM_RVAR+4]);
		
		//if ((region_bb[r].height()<=0) || (region_bb[r].width()<=0))
		//	printf("t %i error in region %f %f %f %f\n",t, region_bb[r].l,region_bb[r].r,region_bb[r].b,region_bb[r].t);
		
		//if (debug)
		//	printf("region %i: %f %f %f %f\n",r, region_bb[r].l,region_bb[r].r,region_bb[r].b,region_bb[r].t);
		
		float reg_width=proposal[offset+r*NUM_RVAR+3];	
		float reg_height=proposal[offset+r*NUM_RVAR+4];	
		int x_align=int(proposal[offset+r*NUM_RVAR+5])%3;
		int y_align=int(proposal[offset+r*NUM_RVAR+5]>2);
		int orientation=proposal[offset+r*NUM_RVAR+6];	
		
		//orientation=1;
		
		
		
		float element_heights=0;
		float element_widths=0;
		int elem_cnt=0;
		
		for (int s=0;s < ne;s++)
		{
			int i=proposal[s*NUM_VAR+7];
			//int i=s;
			
			if (proposal[i*NUM_VAR+5]==r)
			{
				element_heights+=bb[i].height();
				element_widths+=bb[i].width();
				elem_cnt++;
			}
		}
		
		float scale=1;
		
		if (orientation==0)
		{
			scale=min(reg_height/element_heights,1.0);	
			//if (scale <0.99)
			//	printf("scale %f %i, elem height %f, reg height %f\n",scale,prop_select,element_heights,reg_height);
		
		}
		else
		{
			scale=min(reg_width/element_widths,1.0);
			
			//if (scale <0.99)
			//	printf("scale %f %i, elem width %f, reg width %f\n",scale,prop_select,element_widths,reg_width);
		
		}		
		
		
		if (elem_cnt==0)
			continue;		
					
		float spacing=0;
			
		if ((elem_cnt>1) && (orientation==0))
			spacing=(reg_height-element_heights*scale)/(elem_cnt-1);
		else if ((elem_cnt>1) && (orientation==1))
			spacing=(reg_width-element_widths*scale)/(elem_cnt-1);
		
		spacing = max(spacing,1.0);
		
		//if (spacing >400)
		//	printf("spacing %.3f, reg width/height %.3f %.3f, element heights %.3f, elem_cnt %i\n",spacing,reg_width,reg_height,element_heights,elem_cnt);
		
		
		float curr_height=0, curr_width=0;
		
		Box new_region;
		new_region.set(d->width,0,d->height,0);
			
		for (int s=0;s < ne;s++)
		{
			int i=proposal[s*NUM_VAR+7];
			//int i=s;

			
			if (proposal[i*NUM_VAR+5]==r)
			{
					
					
				proposal[i*NUM_VAR+2]=proposal[i*NUM_VAR+2]*scale;
				
				float new_width=bb[i].width()*scale;
				float new_height=bb[i].height()*scale;	
					
				float elem_scale=reg_width/new_width;
				
				if (new_width>reg_width)
				{
					
			
					new_width=new_width*elem_scale;
					new_height=new_height*elem_scale;
					proposal[i*NUM_VAR+2]=proposal[i*NUM_VAR+2]*elem_scale;
					new_width=reg_width;
					
					if (elem_scale>5)
					{
						
						printf("scale is large %.3f\n. reg width %.3f and new width %.3f",elem_scale,reg_width, new_width);
					}				
				}

			

				
				
				
				if (orientation==0)
				{
					proposal[i*NUM_VAR+1]=(proposal[offset+r*NUM_RVAR+2]+curr_height)/d->height;				
					
					curr_height+=proposal[i*NUM_VAR+2]*d->height+spacing;
	
					if (x_align==0)
						proposal[i*NUM_VAR]=proposal[offset+r*NUM_RVAR+1]/d->width;
					else if (x_align==1)
						proposal[i*NUM_VAR]=(proposal[offset+r*NUM_RVAR+1]+reg_width/2.0-(new_width)/2.0)/d->width;
					else if (x_align==2)
						proposal[i*NUM_VAR]=(proposal[offset+r*NUM_RVAR+1]+reg_width-new_width)/d->width;
							
				}
				else
				{
					proposal[i*NUM_VAR]=(proposal[offset+r*NUM_RVAR+1]+curr_width)/d->width;	
					
					curr_width+=new_width+spacing;
					
					if (y_align==0)
						proposal[i*NUM_VAR+1]=proposal[offset+r*NUM_RVAR+2]/d->height;
					else if (y_align==1)
						proposal[i*NUM_VAR+1]=(proposal[offset+r*NUM_RVAR+2]+reg_height/2.0-(new_height)/2.0)/d->height;
					else if (y_align==2)
						proposal[i*NUM_VAR+1]=(proposal[offset+r*NUM_RVAR+2]+reg_height-new_height)/d->height;			

				}
				
				
				if (((abs(proposal[NUM_VAR*i])>2) || (abs(proposal[NUM_VAR*i+1])>2)) && (m<MAX_PROPOSAL_TRIES))
				{
					int r= proposal[NUM_VAR*i+5];
					printf("ERROR: element %i, x/y: %.3f %.3f, with prop select %i (m %i) orientation %i, xy align %i %i, curr height %.3f width %.3f ,spacing %.3f, scale %.3f, new width/height %.3f %.3f  \n",i,proposal[NUM_VAR*i],proposal[NUM_VAR*i+1], prop_select,m,orientation,x_align,y_align,curr_height,curr_width,spacing,elem_scale,new_width,new_height);
				
					printf(" region l/r: %.2f - %.2f, b/t: %.2f - %.2f \n",proposal[offset+r*NUM_RVAR+1],proposal[offset+r*NUM_RVAR+1]+proposal[offset+r*NUM_RVAR+3],proposal[offset+r*NUM_RVAR+2],proposal[offset+r*NUM_RVAR+2]+proposal[offset+r*NUM_RVAR+4]);
					
					if (prop_select==10)
						printf(" merged region1 l/r: %.2f - %.2f, b/t: %.2f - %.2f, with r2 l/r: %.2f - %.2f, b/t: %.2f - %.2f\n",merge_r1.l,merge_r1.r,merge_r1.b,merge_r1.t,merge_r2.l,merge_r2.r,merge_r2.b,merge_r2.t );
				
				
					printf(" reg width/height  %.3f %.3f, element sum width/height %.3f %.3f \n",reg_width, reg_height,element_widths, element_heights);
					
					return -1;
				}
				//if ((d->fixed_regions) && (proposal[offset+r*NUM_RVAR]==1))
				//{
				//	printf("element %i with height %f, curr_height %f, spacing %f\n",i,proposal[i*NUM_VAR+2],curr_height,spacing);
				//}
				
					
				new_region.l=min(new_region.l,round(proposal[i*NUM_VAR]*d->width));
				new_region.r=max(new_region.r,round(proposal[i*NUM_VAR]*d->width+new_width));
				
				new_region.b=min(new_region.b,round(proposal[i*NUM_VAR+1]*d->height));
				new_region.t=max(new_region.t,round((proposal[i*NUM_VAR+1]+proposal[i*NUM_VAR+2])*d->height));		
				
				
				if (d->fixed_alignment[i]<0.001)
				{
					proposal[i*NUM_VAR+3]=x_align;
				}
					
				if ((display) && (proposal[offset+r*NUM_RVAR]==2))
					printf("setting element %i: %.3f %.3f %.3f, scale %.3f\n",i,proposal[i*NUM_VAR],proposal[i*NUM_VAR+1],proposal[i*NUM_VAR+2],scale);
				//}
			}
		}
		
		if (!(d->fixed_regions))
		{
			
			
			if (scale<1)
			{
				proposal[offset+r*NUM_RVAR+3]+=3;
				proposal[offset+r*NUM_RVAR+4]+=3;
			}
		
		
			proposal[offset+r*NUM_RVAR+1]=new_region.l;
			proposal[offset+r*NUM_RVAR+2]=new_region.b;
			proposal[offset+r*NUM_RVAR+3]=new_region.width();
			proposal[offset+r*NUM_RVAR+4]=new_region.height();
			
			if ((display) && (int(proposal[offset+r*NUM_RVAR])==2))
				printf("final regions %f %f %f %f. num regions %i\n",proposal[offset+r*NUM_RVAR+1],proposal[offset+r*NUM_RVAR+2],proposal[offset+r*NUM_RVAR+3],proposal[offset+r*NUM_RVAR+4],num_regions);
			
		}

	}
	

	//assert that the assigned regions all exist
	
	for (int i=0;i<ne;i++)
	{
		int r= proposal[NUM_VAR*i+5];
		
		if (int(proposal[offset+r*NUM_RVAR])==-1)
		{
			printf("ERROR. Assigned region doesn't exist. element %i region %i with prop select %i. region %.2f %.2f %.2f %.2f \n",i, r,prop_select,proposal[offset+r*NUM_RVAR+1],proposal[offset+r*NUM_RVAR+2],proposal[offset+r*NUM_RVAR+3],proposal[offset+r*NUM_RVAR+4]);
			return -1;
		}
	}


	for (int i=0;i<ne;i++)
	{
		int r= proposal[NUM_VAR*i+5];
		
		float height=(proposal[NUM_VAR*i+2]*d->height);
		float width=(height/aspect_ratio[i]);
		float xp=(proposal[NUM_VAR*i]*d->width);
		float yp=(proposal[NUM_VAR*i+1]*d->height);

		bb[i].set(round(xp+(width*d->bb_left[i])), round(xp+(width*d->bb_right[i])), round(yp + (height*d->bb_bottom[i])), round(yp + (height*d->bb_top[i])));
		//bb[i].set(xp, xp+(width), yp, yp + (height));
		
		if ((bb[i].l>=bb[i].r)|| (bb[i].b>=bb[i].t))
		{
			printf("ERROR. output bounding box for element %i with prop_select %i l/r: %f %f b/t: %f %f\n",i,prop_select,bb[i].l,bb[i].r,bb[i].b,bb[i].t);
			
			printf("\t region l/b: %f %f w/h: %f %f\n",proposal[offset+r*NUM_RVAR+1],proposal[offset+r*NUM_RVAR+2],proposal[offset+r*NUM_RVAR+3],proposal[offset+r*NUM_RVAR+4]);
			return -1;
		}	
	}
	
	
	//assert that there are no empty regions
	for (int r=0;r<ne;r++)
	{
		
		if (int(proposal[offset+r*NUM_RVAR])!=-1)
		{
			bool empty_region=true;
			for (int i=0;i<ne;i++)
			{
				if (int(proposal[NUM_VAR*i+5])==r)
					empty_region=false;
				
			}
			
			if (empty_region)
			{
				printf("ERROR. No elements for region %i (type %i): %.2f %.2f %.2f %.2f  \n",r,int(proposal[offset+r*NUM_RVAR]), proposal[offset+r*NUM_RVAR+1],proposal[offset+r*NUM_RVAR+2],proposal[offset+r*NUM_RVAR+3],proposal[offset+r*NUM_RVAR+4]);
				
				printf(" Proposal %i. modified region %i region change %i. flipped %i of %i. num regions %i \n",prop_select,modified_reg,reg_change,flip_cnt,num_elements_reg[modified_reg],num_regions);
				
				
				return -1;
			}
		}
	}
		
	return prop_select;
}
*/


	/*
__device__ void assignElementRegion(Design *d, float *proposal, float *curr_layout, int elem, int num_text_regions, int num_graphic_regions)
{
		int region=0;
		if (d->type[elem]==1)
			region=((float)num_text_regions*randu());
		else
			region=((float)num_graphic_regions*randu());
		
		int cnt=0;
		
		for(int j=0;j< d->num_elements;j++)
		{
			if (curr_layout[d->num_elements*NUM_VAR+j*NUM_RVAR]==d->type[elem])
			{
				if (cnt==region)
				{
					proposal[elem*NUM_VAR+5]=j;
					break;
				}
				cnt++;						
			}
		}
}

*/