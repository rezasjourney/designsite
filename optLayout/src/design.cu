
#include "design.cuh"





__device__ bool anyBoxIntersection(Box b1, Box b2)
{
	if ((b1.l>=b2.r) or (b1.r<=b2.l) or (b1.t<=b2.b) or (b1.b>=b2.t))
		return false;

	return true;
}



__device__ Box getBoxIntersection(Box b1, Box b2)
{
	Box b;
	b.set(0,0,0,0);

	float xoverlap=min((b1.r-b2.l),(b2.r-b1.l));
	float yoverlap=min((b1.t-b2.b),(b2.t-b1.b));

	if (xoverlap>0)
	{
		b.l=max(b1.l,b2.l);
		b.r=min(b1.r,b2.r);
	}
	if (yoverlap>0)
	{
		b.b=max(b1.b,b2.b);
		b.t=min(b1.t,b2.t);
	}
	return b;
}


__device__ bool checkBoundingBoxOverlap(Box b1,Box *other_boxes, int num_boxes,int ignore_box)
{

	for (int i=0;i< num_boxes;i++)
	{
		if (i==ignore_box)
			continue;

		Box b2=other_boxes[i];

		if (anyBoxIntersection(b1,b2))
		{
			return true;
		}
	}
	return false;
}


char *getSubstring(char *string, char *start_tag, char *end_tag)
{

	char *str1=strstr(string,start_tag);
	char *str2=strstr(string,end_tag);

	if (!str1)
	{
		cout << "Didnt find tag " << start_tag<< endl;
		return 0;
	}
	if (!str2)
	{
		cout << "Didnt find tag " << end_tag<< endl;
		return 0;
	}

	int num_char=str2-(str1+strlen(start_tag));

	if (num_char<0)
	{
		cout << "num_char " << num_char<< endl;
		return 0;
	}
	char *substring=(char *) malloc(num_char);
	memset( substring, '\0', sizeof(char)*num_char );
	strncpy(substring,str1+strlen(start_tag),num_char );
	substring[num_char]='\0';
	return substring;

}

char *extractXMLElement(char *string, char *tag)
{

	int tag_len=strlen(tag);
	char *start_tag=(char *)malloc(tag_len+3);
	char *end_tag=(char *)malloc(tag_len+4);
	snprintf(start_tag,tag_len+3, "<%s>>",tag);
	snprintf(end_tag,tag_len+4,"</%s>>",tag);
	return getSubstring(string, start_tag, end_tag);


}


void printLayout(char *str,Design *d, float *layout,  float energy)
{


	int n=sprintf(str,"%i\n%s\n%i,%i\n%i\n",d->layout_counter,d->name,int(d->width),int(d->height),d->num_elements);
	str=str+n;


	for (int i=0;i<d->num_elements;i++)
	{
		int x = int(round(layout[i*NUM_VAR]*d->width));
		int y = int(round(layout[i*NUM_VAR+1]*d->height));
		int h = int(round(layout[i*NUM_VAR+2]*d->height));
		int a = int(round(layout[i*NUM_VAR+3]));
		float f = layout[i*NUM_VAR+4];
		int r = int(round(layout[i*NUM_VAR+5]));
		int alt = int(round(layout[i*NUM_VAR+6]));

		if ((x<-d->width) or (x>2*d->width) or (y<-d->height) or (y>2*d->height))
			printf("ERROR in layout %i %i %i %i\n", x,y,h,a);

		
		n=sprintf(str,"%i,%i,%i,%i,%.2f,%i,%i\n",x,y,h,a,f,r,alt);
		str=str+n;
	}
	
	n=sprintf(str,"E:%.3f\n",energy);
	str=str+n;

	//printf("sending: %s\n",str)	;
}


void writeLayoutToFile(Design *d, char *layout_str, char *filename)
{

	//printf("Writing layout out to file %s\n",filename);
    FILE *fp = NULL;
	fp = fopen(filename, "w");
	fprintf(fp,"%s",layout_str);
	fclose (fp);

}



float *parseLayout(Design *d,  char *str,int *num_regions, int *layout_counter)
{


	int width;
	int height;
	char name[100];
	int num_elements;
	sscanf(str,"%d\n",layout_counter);
	str=strchr(str,'\n')+1;
	sscanf(str,"%s\n",name);
	str=strchr(str,'\n')+1;
	
	printf("loading design %s\n",name);
	if (strcmp(name, "quit")==0)
	{
		printf("quitting\n");
		exit(-1);
	}
	
	

	sscanf(str,"%d,%d\n%d\n",&width,&height,&num_elements);
	str=strchr(str,'\n')+1;
	str=strchr(str,'\n')+1;
	//char background[100];
	//fscanf(fp,"%s\n",background);

	if ((num_elements!=d->num_elements) or (strcmp(name, d->name)!=0) or (width!=int(d->width)) or (height!=int(d->height)))
	{
		printf("Layout doesn't match design.\n");
		printf("Layout: %s, width: %d, height: %d, elem %d\n",name, width, height,num_elements);
		printf("Design: %s, width: %d, height: %d, elem %d\n", d->name,  int(d->width), int( d->height),d->num_elements);
		return 0;
	}
	float *new_layout=(float *)malloc(d->layout_size*sizeof(float));

	float x, y, h, align, fix,alt,region;

	for (int i=0;i<d->num_elements;i++)
	{
		sscanf(str,"%f,%f,%f,%f,%f,%f,%f\n",&x,&y,&h,&align,&fix,&region,&alt);
		str=strchr(str,'\n')+1;
		printf("Read in %.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f\n",x,y,h,align,fix,alt,region);
	

		new_layout[i*NUM_VAR]=x/d->width;
		new_layout[i*NUM_VAR+1]=y/d->height;
		new_layout[i*NUM_VAR+2]=h/d->height;
		new_layout[i*NUM_VAR+3]=align;
		new_layout[i*NUM_VAR+4]=fix;
		new_layout[i*NUM_VAR+5]=-1;
		new_layout[i*NUM_VAR+6]=alt;
		new_layout[i*NUM_VAR+7]=i;
		//printf("%i:%.2f,%.2f,%.2f,%.2f,%.2f,%.2f\n",i,new_layout[i*NUM_VAR],new_layout[i*NUM_VAR+1],new_layout[i*NUM_VAR+2],new_layout[i*NUM_VAR+3],new_layout[i*NUM_VAR+4],new_layout[i*NUM_VAR+6]);
	
	
	}
	
	for (int i=d->num_elements*NUM_VAR;i<d->layout_size;i++)
		new_layout[i]=-1;
	
	int num_constraints;
	sscanf(str,"%d constraints\n",&(num_constraints));
	str=strchr(str,'\n')+1;
	
	printf("num constraints %i\n",num_constraints);
	d->num_constraints=num_constraints;
	if (d->num_constraints>0)
	{
		//d->constraints=(int*) malloc(d->num_constraints*NUM_AVAR*sizeof(int));
		
		int elem_id,align_count,align_type,other_elem;
		for(int i=0;i< d->num_constraints;i++)
		{
			sscanf(str,"%d,%d,%d",&elem_id,&align_type,&align_count);
			
			str=strchr(str,',')+1;
			str=strchr(str,',')+1;
			
			if (align_count>0)
				str=strchr(str,',');
			
			int elem_idx=-1;
			for (int k=0;k<d->num_elements;k++)
			{
				if (d->id[k]==elem_id)
					elem_idx=k;
			}
			
			if (elem_idx==-1)
			{
				printf("ERROR, element index -1\n");
				return 0;
			}
			printf("alignment line. elem id: %i, idx %i, type: %i, count %i\n",elem_id,elem_idx,align_type,align_count);
			
			
			d->constraints[i*NUM_AVAR]=elem_idx;
			d->constraints[i*NUM_AVAR+1]=align_type;
			d->constraints[i*NUM_AVAR+2]=align_count;
			
			for (int j=0;j<align_count;j++)
			{
				sscanf(str,",%d",&other_elem);
				str=strchr(str,',')+1;

				
				elem_idx=-1;
				for (int k=0;k<d->num_elements;k++)
				{
					if (d->id[k]==other_elem)
						elem_idx=k;
				}
				
				if (elem_idx==-1)
				{
					printf("ERROR, element index -1\n");
					return 0;
				}			
				d->constraints[i*NUM_AVAR+3+j]=elem_idx;
				printf("\t other element: %i, idx %i\n",other_elem,elem_idx);
			}
			str=strchr(str,'\n')+1;
		}	
	}
	
	
	
	
	*num_regions=0;
	sscanf(str,"%d regions\n",num_regions);
	str=strchr(str,'\n')+1;
	
	printf("num regions %i\n",*num_regions);
	
	
	//float height,width,xp,yp;
	int cnt=0;
	for(int i=0;i< d->num_elements;i++)
	{				
		if (new_layout[i*NUM_VAR+4]>FIX_LAYOUT_THRESH)
		{
			new_layout[i*NUM_VAR+5]=-1;
			continue;
		}
		
		new_layout[i*NUM_VAR+5]=cnt;

		
		cnt++;
	}
		
	
	
	
	return new_layout;


}




float *readLayoutFromFile(Design *d,  char *filename,int *num_regions, int *layout_counter)
{

	printf("Reading layout from file %s\n",filename);
    FILE *fp = NULL;
	fp = fopen(filename, "r");

	if (fp<0)
	{
		printf("error reading layout file\n");
		return 0;
	}
	int width;
	int height;
	char name[100];
	int num_elements;
	fscanf(fp,"%d\n",layout_counter);
	fscanf(fp,"%s\n",name);
	
	printf("loading design %s\n",name);
	if (strcmp(name, "quit")==0)
	{
		printf("quitting\n");
		exit(-1);
	}
	

	fscanf(fp,"%d,%d\n%d\n",&width,&height,&num_elements);
	
	
	//char background[100];
	//fscanf(fp,"%s\n",background);

	if ((num_elements!=d->num_elements) or (strcmp(name, d->name)!=0) or (width!=int(d->width)) or (height!=int(d->height)))
	{
		printf("Layout doesn't match design.\n");
		printf("Layout: %s, width: %d, height: %d, elem %d\n",name, width, height,num_elements);
		printf("Design: %s, width: %d, height: %d, elem %d\n", d->name,  int(d->width), int( d->height),d->num_elements);
		return 0;
	}
	float *new_layout=(float *)malloc(d->layout_size*sizeof(float));

	float x, y, h, align, fix,alt,region;

	for (int i=0;i<d->num_elements;i++)
	{
		fscanf(fp,"%f,%f,%f,%f,%f,%f,%f\n",&x,&y,&h,&align,&fix,&region,&alt);
		
		printf("Read in %.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f\n",x,y,h,align,fix,alt,region);
	

		new_layout[i*NUM_VAR]=x/d->width;
		new_layout[i*NUM_VAR+1]=y/d->height;
		new_layout[i*NUM_VAR+2]=h/d->height;
		new_layout[i*NUM_VAR+3]=align;
		new_layout[i*NUM_VAR+4]=fix;
		new_layout[i*NUM_VAR+5]=-1;
		new_layout[i*NUM_VAR+6]=alt;
		new_layout[i*NUM_VAR+7]=i;
		//printf("%i:%.2f,%.2f,%.2f,%.2f,%.2f,%.2f\n",i,new_layout[i*NUM_VAR],new_layout[i*NUM_VAR+1],new_layout[i*NUM_VAR+2],new_layout[i*NUM_VAR+3],new_layout[i*NUM_VAR+4],new_layout[i*NUM_VAR+6]);
	
	
	}
	
	for (int i=d->num_elements*NUM_VAR;i<d->layout_size;i++)
		new_layout[i]=-1;
	
	int num_constraints;
	fscanf(fp,"%d lines\n",&(num_constraints));
	
	printf("num align lines %i\n",num_constraints);
	d->num_constraints=num_constraints;
	if (d->num_constraints>0)
	{
		//d->constraints=(int*) malloc(d->num_constraints*NUM_AVAR*sizeof(int));
		
		int elem_id,align_count,align_type,other_elem;
		for(int i=0;i< d->num_constraints;i++)
		{
			fscanf(fp,"%d,%d,%d",&elem_id,&align_type,&align_count);
			printf("alignment line id: %i type: %i\n",elem_id,align_type);
			
			int elem_idx=-1;
			for (int k=0;k<d->num_elements;k++)
			{
				if (d->id[k]==elem_id)
					elem_idx=k;
			}
			
			if (elem_idx==-1)
			{
				printf("ERROR, element index -1\n");
				return 0;
			}
			
			d->constraints[i*NUM_AVAR]=elem_idx;
			d->constraints[i*NUM_AVAR+1]=align_type;
			d->constraints[i*NUM_AVAR+2]=align_count;
			
			for (int j=0;j<align_count;j++)
			{
				fscanf(fp,",%d",&other_elem);
				
				elem_idx=-1;
				for (int k=0;k<d->num_elements;k++)
				{
					if (d->id[k]==other_elem)
						elem_idx=k;
				}
				
				if (elem_idx==-1)
				{
					printf("ERROR, element index -1\n");
					return 0;
				}			
				d->constraints[i*NUM_AVAR+3+j]=elem_idx;
				printf("\t other element: %i\n",other_elem);
			}
			fscanf(fp,"\n");
		}	
	}
	
	
	*num_regions=0;
	fscanf(fp,"%d regions\n",num_regions);
	
	
	printf("num regions %i\n",*num_regions);
	
	/*
	int offset=d->num_elements*NUM_VAR;
		
	if (*num_regions>0)
	{

		float type, l,b,w,h;
		for(int i=0;i< *num_regions;i++)
		{
			fscanf(fp,"%f,%f,%f,%f,%f\n",&type,&l,&b,&w,&h);
				
			new_layout[offset+i*NUM_RVAR]=type;
			new_layout[offset+i*NUM_RVAR+1]=max(l,0.0);
			new_layout[offset+i*NUM_RVAR+2]=max(b,0.0);			
			new_layout[offset+i*NUM_RVAR+3]=w;
			new_layout[offset+i*NUM_RVAR+4]=h;	
			
	
			new_layout[offset+i*NUM_RVAR+5]=1.0;	
			
			if (w>1.5*h)
				new_layout[offset+i*NUM_RVAR+6]=1.0;
			else
				new_layout[offset+i*NUM_RVAR+6]=0.0;
			
		}
	}
	
	else
	{
		*/
	
	//float height,width,xp,yp;
	int cnt=0;
	for(int i=0;i< d->num_elements;i++)
	{				
		if (new_layout[i*NUM_VAR+4]>FIX_LAYOUT_THRESH)
		{
			new_layout[i*NUM_VAR+5]=-1;
			continue;
		}
		
		new_layout[i*NUM_VAR+5]=cnt;
		/*
		height=round(new_layout[NUM_VAR*i+2]*d->height);
		width=round(height/d->aspect_ratio[i]);
		xp=round(new_layout[NUM_VAR*i]*d->width);
		yp=round(new_layout[NUM_VAR*i+1]*d->height);
		
		
		new_layout[offset+cnt*NUM_RVAR]=d->type[i];
		new_layout[offset+cnt*NUM_RVAR+1]=round(xp+(width*d->bb_left[i])); 
		new_layout[offset+cnt*NUM_RVAR+2]=round(yp+(height*d->bb_bottom[i]));
		new_layout[offset+cnt*NUM_RVAR+3]=width;
		new_layout[offset+cnt*NUM_RVAR+4]=height;
		new_layout[offset+cnt*NUM_RVAR+5]=1.0;	
		new_layout[offset+cnt*NUM_RVAR+6]=0.0;
		*/
		
		cnt++;
	}
		
	//}
	
	
	
	fclose (fp);
	return new_layout;


}


Design *loadDesignFromFile(char *filename,bool interactive_mode)
{



	printf("Reading design from file %s\n",filename);
    FILE *fp = NULL;
	fp = fopen(filename, "r");

	if (fp<0)
	{
		printf("error reading design file\n");
		return 0;
	}
	
	Design *d = (Design*)malloc( sizeof(Design) );
	d->name=(char *)malloc(1000*sizeof(char));	
	
	//int width;
	//int height;
	int ne;
	int layout_counter;

	fscanf(fp,"%d\n",&layout_counter);
	fscanf(fp,"%s\n",d->name);
	fscanf(fp,"%f,%f\n%d\n",&(d->width),&(d->height),&ne);

	char background[500];
	fscanf(fp,"%s\n",background);

	cout << "Design Name " << d->name  << " Width "<< d->width << " Height "<< d->height << " Num elements "<< ne << endl;




	d->num_elements=ne;
	d->layout_counter=layout_counter;
	//cout << "Design Number of Elements " << d->num_elements << endl;


	d->id=(int *)malloc(d->num_elements*sizeof(int));
	d->importance=(int *)malloc(d->num_elements*sizeof(int));
	d->type=(int *)malloc(d->num_elements*sizeof(int));
	d->bb_left=(float *)malloc(d->num_elements*sizeof(float));
	d->bb_right=(float *)malloc(d->num_elements*sizeof(float));
	d->bb_bottom=(float *)malloc(d->num_elements*sizeof(float));
	d->bb_top=(float *)malloc(d->num_elements*sizeof(float));

	d->tight_bb_left=(float *)malloc(d->num_elements*sizeof(float));
	d->tight_bb_right=(float *)malloc(d->num_elements*sizeof(float));
	d->tight_bb_bottom=(float *)malloc(d->num_elements*sizeof(float));
	d->tight_bb_top=(float *)malloc(d->num_elements*sizeof(float));

	d->num_lines=(int *)malloc(d->num_elements*sizeof(int));
	d->aspect_ratio=(float *)malloc(d->num_elements*sizeof(float));
	d->line_gap=(float *)malloc(d->num_elements*sizeof(float));
	d->group_id=(int *)malloc(d->num_elements*sizeof(int));
	d->alignment=(int *)malloc(d->num_elements*sizeof(int));
	d->fixed_alignment=(int *)malloc(d->num_elements*sizeof(int));
	
	d->num_constraints=0;
	d->constraints=(int*) malloc(MAX_ELEMENTS*3*NUM_AVAR*sizeof(int));
	
	//d->alt_alignment=(int **)malloc(d->num_elements*sizeof(int *));

	//d->layout_size=d->num_elements*NUM_VAR + MAX_ELEMENTS*NUM_RVAR;
	d->layout_size=d->num_elements*NUM_VAR;
	d->layout=(float *)malloc(d->layout_size*sizeof(float));
	d->init_layout=(float *)malloc(d->layout_size*sizeof(float));
	d->check_layout=(float *)malloc(d->layout_size*sizeof(float));
	d->check_layout_distances=(float *)malloc(MAX_ELEMENTS*sizeof(float));

	d->check_layout_exists=interactive_mode;
	d->fixed_regions=false;
	d->region_proposals=false;

	d->num_alt=(int *)malloc(d->num_elements*sizeof(int));
	d->alt_aspect_ratio=(float *)malloc(d->num_elements*MAX_ALT*sizeof(float));
	d->alt_num_lines=(int *)malloc(d->num_elements*MAX_ALT*sizeof(int));
	
	d->optional=(int *)malloc(d->num_elements*sizeof(int));
	
	if ((d->num_elements<0) || (d->num_elements>MAX_ELEMENTS))
	{
		free(d);
		
		printf("error reading design file\n");
		return 0;
	}

	for (int i=0 ; i < d->num_elements ; i++)
	{

		int x,y,h,align,alt;
		float fix;
		char fname[100];

		fscanf(fp,"%d,%d,%d,%d,%d,%f,%d,%d,%d,%d,%f,%d,%d,%f,%f,%f,%f,%f,%s\n",&(d->id[i]),&(d->type[i]),&(d->importance[i]),&(d->num_lines[i]),&(d->group_id[i]),&(d->aspect_ratio[i]),&x,&y,&h,&align,&fix,&alt,&(d->fixed_alignment[i]),&(d->optional[i]),&(d->bb_left[i]),&(d->bb_right[i]),&(d->bb_bottom[i]),&(d->bb_top[i]),fname);

		if ((d->importance[i]<0) || (d->importance[i]>10))
		{
			printf("design importance is fucked %i\n",d->importance[i]);
			return 0;
		}

		d->layout[i*NUM_VAR]=x/d->width;
		d->layout[i*NUM_VAR+1]=y/d->height;
		d->layout[i*NUM_VAR+2]=h/d->height;
		d->layout[i*NUM_VAR+3]=align;
		d->layout[i*NUM_VAR+4]=fix;
		d->layout[i*NUM_VAR+5]=-1;
		d->layout[i*NUM_VAR+6]=alt;
		d->layout[i*NUM_VAR+7]=i;
		
		d->alignment[i]=align;
		
		d->num_alt[i]=0;
		d->alt_num_lines[i*MAX_ALT]=d->num_lines[i];
		d->alt_aspect_ratio[i*MAX_ALT]=d->aspect_ratio[i];

		printf("Loaded element %d , id %d (%s), group id %i, imp %d, ar %f, fixed alignment %d. num lines %d.optional %d, alt %i,layout: %.2f,%.2f,%.2f,%.2f,%.2f  \n",i,d->id[i],fname,d->group_id[i], d->importance[i],d->aspect_ratio[i],d->fixed_alignment[i],d->num_lines[i],d->optional[i],alt,d->layout[i*NUM_VAR],d->layout[i*NUM_VAR+1],d->layout[i*NUM_VAR+2],d->layout[i*NUM_VAR+3],d->layout[i*NUM_VAR+4]);

		if (d->aspect_ratio[i]==0)
		{
			printf("aspect ratio is 0\n");
			return 0;
		}

	}
	
	
	/*	
	for (int i=d->num_elements*NUM_VAR;i<d->layout_size;i++)
		d->layout[i]=-1;


	int offset=d->num_elements*NUM_VAR;
	float height,width,xp,yp;
	for(int i=0;i< d->num_elements;i++)
	{				
		d->layout[i*NUM_VAR+5]=i;
		
		height=round(d->layout[NUM_VAR*i+2]*d->height);
		width=round(height/d->aspect_ratio[i]);
		xp=round(d->layout[NUM_VAR*i]*d->width);
		yp=round(d->layout[NUM_VAR*i+1]*d->height);
		
		d->layout[offset+i*NUM_RVAR]=d->type[i];
		d->layout[offset+i*NUM_RVAR+1]=round(xp+(width*d->bb_left[i])); 
		d->layout[offset+i*NUM_RVAR+2]=round(yp+(height*d->bb_bottom[i]));
		//d->layout[offset+i*NUM_RVAR+3]=round(yp+(height*d->bb_bottom[i]));
		d->layout[offset+i*NUM_RVAR+3]=width;	
		d->layout[offset+i*NUM_RVAR+4]=height;
		d->layout[offset+i*NUM_RVAR+5]=1.0;	
		d->layout[offset+i*NUM_RVAR+6]=0;
	}
	*/


	fscanf(fp,"%d overlap regions\n",&d->num_overlap_regions);

	d->overlap_region_elem=(int *)malloc(d->num_overlap_regions*sizeof(int));
	d->overlap_regions=(Box *)malloc(d->num_overlap_regions*sizeof(Box));

	int id;
	float x1,x2,y1,y2;
	for (int i=0 ; i <d->num_overlap_regions ; i++)
	{
		fscanf(fp,"%d,%f,%f,%f,%f\n",&id,&x1,&x2,&y1,&y2);

		if (id==0)
			d->overlap_region_elem[i]=-1;

		for (int j=0 ; j < d->num_elements ; j++)
		{
			if (id== d->id[j])
			{
				d->overlap_region_elem[i]=j;
			}
		}
		d->overlap_regions[i].l=x1;
		d->overlap_regions[i].r=x2;
		d->overlap_regions[i].b=y1;
		d->overlap_regions[i].t=y2;

		//printf ("%i: %f,%f,%f,%f\n",id,x1,x2,y1,y2);
	}

	//for (int i=0;i<d->num_overlap_regions;i++)
	//	printf("region %i, id %i\n", i,d->overlap_region_elem[i]);
	
	
	int num_alt_lines;
	fscanf(fp,"%d alternates\n",&num_alt_lines);
	
	for (int a=0; a <num_alt_lines; a++)
	{
		int elem_id=0;
		int num_alt=0;
		
		fscanf(fp,"%d,%d,",&elem_id,&num_alt);
		
		int idx=0;
		for(int i=0;i< d->num_elements;i++)
		{	
			if (elem_id==d->id[i])
				idx=i;
		}
		d->num_alt[idx]=num_alt;
		
		int num_lines,max_line_length;
		float aspect_ratio;
		for (int i=0; i <num_alt; i++)
		{
			fscanf(fp,"%d,%f,%d,",&num_lines,&aspect_ratio,&max_line_length);
			
			d->alt_num_lines[idx*MAX_ALT+i]=num_lines;
			d->alt_aspect_ratio[idx*MAX_ALT+i]=aspect_ratio;
			
			//printf("element %i has alternate with %i lines and ar %f\n",idx,num_lines,aspect_ratio);
			
			
			if (aspect_ratio==0)
			{
				printf("aspect ratio of alt %i is 0\n",i);
				return 0;
			}
		}
	
		fscanf(fp,"\n");
	
	}
	
	float curr_x=0,curr_y=0;
	for(int i=0;i< d->num_elements;i++)
	{		
		d->init_layout[i*NUM_VAR]=curr_x;
		

		if (d->type[i]==1)		
			d->init_layout[i*NUM_VAR+2]=((MIN_TEXT_SIZE*max(d->width,d->height)*d->num_lines[i])/10.0)/d->height + (5.0/d->height);
		else
			d->init_layout[i*NUM_VAR+2]=MIN_GRAPHIC_SIZE+(5.0/d->height);
		
		if (d->init_layout[i*NUM_VAR+2]+curr_y>1)
		{
			d->init_layout[i*NUM_VAR+1]=0;	
			
			curr_x+=0.34;
			if (curr_x>=1)
				curr_x=0;
				
			d->init_layout[i*NUM_VAR]=curr_x;
			curr_y=d->init_layout[i*NUM_VAR+2];	
		}
		else
		{
			d->init_layout[i*NUM_VAR+1]=curr_y;	
			curr_y+=d->init_layout[i*NUM_VAR+2];	
		}	
		
		for (int j=3;j<NUM_VAR;j++)
			d->init_layout[i*NUM_VAR+j]=d->layout[i*NUM_VAR+j];	
	}
	
	
	/*
	for(int i=0;i< d->num_elements;i++)
	{				
		d->init_layout[i*NUM_VAR+5]=i;
		
		height=round(d->init_layout[NUM_VAR*i+2]*d->height);
		width=round(height/d->aspect_ratio[i]);
		xp=round(d->init_layout[NUM_VAR*i]*d->width);
		yp=round(d->init_layout[NUM_VAR*i+1]*d->height);
		
		d->init_layout[offset+i*NUM_RVAR]=d->type[i];
		d->init_layout[offset+i*NUM_RVAR+1]=round(xp+(width*d->bb_left[i])); 
		d->init_layout[offset+i*NUM_RVAR+2]=round(yp+(height*d->bb_bottom[i]));
		d->init_layout[offset+i*NUM_RVAR+3]=width;	
		d->init_layout[offset+i*NUM_RVAR+4]=height;
		d->init_layout[offset+i*NUM_RVAR+5]=1.0;	
		d->init_layout[offset+i*NUM_RVAR+6]=0;
		d->init_layout[offset+i*NUM_RVAR+7]=i;
	}
	
	for(int i=d->num_elements;i < MAX_ELEMENTS;i++)
		d->init_layout[offset+i*NUM_RVAR]=-1;
	
		

	
	for (int j=0;j<d->num_elements;j++)
	{
		int check_r=d->init_layout[offset+j*NUM_RVAR];
		bool no_elements=true;
		if (check_r>-1)
		{
			for (int k=0;k<ne;k++)
			{
				if (d->init_layout[k*NUM_VAR+5]==j)
					no_elements=false;
			}
			
			if ((no_elements))
			{
				printf("ERROR in design init. region %i has no elements\n",j);
			}
		}

	}
	*/
		
	if (interactive_mode)	
	{
		memcpy(d->check_layout,d->layout, d->layout_size*sizeof(float));
		memcpy(d->init_layout,d->layout, d->layout_size*sizeof(float));
	}
	

	int max_num=1000;
	int skip=1;
	d->align_err=(float *)malloc(max_num*sizeof(float));
	for (int i=0;i< max_num;i++)
	{

		if (i <= skip)
			d->align_err[i]=0;
		else
		{
			float frac=(i-skip)/((float) max_num);
			d->align_err[i]=5*atan(frac/0.015);
		}
	}

	int max_atan_num=20000;
	d->atan_fixed=(float *)malloc(max_atan_num*sizeof(float));
	for (int i=0;i< max_atan_num;i++)
		d->atan_fixed[i]=atan(float(i)/200.0);



	cout << "Finished loading" << endl;


	return d;
}

/*
Design *loadDesignFromXML(char *filename)
{

	Design *d = (Design*)malloc( sizeof(Design) );

	//hacky. should find the size first
    int size=999999;

    FILE *fp = NULL;
	fp = fopen(filename, "r");

	if (!fp)
		return 0;

	char *str = (char *) malloc(size+1);
	int bytes_read = fread (str, sizeof (char), size, fp);
	fclose (fp);

	cout << "finished reading " << bytes_read << " bytes " << endl;


	d->name=extractXMLElement(str, "Name");
	d->width=float(atoi(extractXMLElement(str, "Width")));
	d->height=float(atoi(extractXMLElement(str, "Height")));

	cout << "Design Name " << d->name << endl;
	cout << "Design Width " << d->width << endl;
	cout << "Design Height " << d->height << endl;


	char *element_list=extractXMLElement(str, "ElementList");

	if (!element_list)
	{
		cout << "No Element List" << endl;
		return 0;
	}

	char *em_list=element_list;


	int em_cnt=0;
	while (true)
	{
		char *element_str=getSubstring(em_list, "<Element>","</Element>");
		if (!element_str)
			break;
		em_list=strstr(em_list,"</Element>")+9;
		em_cnt++;
		free(element_str);
	}

	d->num_elements=em_cnt;
	cout << "Design Number of Elements " << d->num_elements << endl;



	d->id=(int *)malloc(d->num_elements*sizeof(int));
	d->importance=(int *)malloc(d->num_elements*sizeof(int));
	d->type=(int *)malloc(d->num_elements*sizeof(int));
	d->bb_left=(float *)malloc(d->num_elements*sizeof(float));
	d->bb_right=(float *)malloc(d->num_elements*sizeof(float));
	d->bb_bottom=(float *)malloc(d->num_elements*sizeof(float));
	d->bb_top=(float *)malloc(d->num_elements*sizeof(float));

	d->tight_bb_left=(float *)malloc(d->num_elements*sizeof(float));
	d->tight_bb_right=(float *)malloc(d->num_elements*sizeof(float));
	d->tight_bb_bottom=(float *)malloc(d->num_elements*sizeof(float));
	d->tight_bb_top=(float *)malloc(d->num_elements*sizeof(float));

	d->num_lines=(int *)malloc(d->num_elements*sizeof(int));
	d->aspect_ratio=(float *)malloc(d->num_elements*sizeof(float));
	d->line_gap=(float *)malloc(d->num_elements*sizeof(float));
	d->group_id=(int *)malloc(d->num_elements*sizeof(int));
	d->alignment=(int *)malloc(d->num_elements*sizeof(int));
	d->num_alt=(int *)malloc(d->num_elements*sizeof(int));

	//d->alt_alignment=(int **)malloc(d->num_elements*sizeof(int *));



	d->layout_size=d->num_elements*NUM_VAR;
	d->layout=(float *)malloc(d->layout_size*sizeof(float));
	d->init_layout=(float *)malloc(d->layout_size*sizeof(float));
	d->check_layout=(float *)malloc(d->layout_size*sizeof(float));

	d->check_layout_exists=false;
	d->fixed_regions=false;
	d->region_proposals=true;

	em_list=element_list;
	for (int i=0 ; i < d->num_elements ; i++)
	{
		char *element_str=extractXMLElement(em_list, "Element");

		if (!element_str)
			break;


		em_list=strstr(em_list,"</Element>")+9;

		d->id[i]=i+1;
		d->importance[i]=atoi(extractXMLElement(element_str, "Importance"));
		d->type[i]=atoi(extractXMLElement(element_str, "Type"));


		d->group_id[i]=atoi(extractXMLElement(element_str, "GroupID"));
		d->aspect_ratio[i]=atof(extractXMLElement(element_str, "AspectRatio"));
		d->line_gap[i]=atof(extractXMLElement(element_str, "LineGap"));
		d->num_lines[i]=atoi(extractXMLElement(element_str, "NumberOfLines"));
		//d->width[i]=atoi(extractXMLElement(element_str, "Width"));
		//d->height[i]=atoi(extractXMLElement(element_str, "Height"));
		d->alignment[i]=atoi(extractXMLElement(element_str, "Alignment"));
		d->num_alt[i]=atoi(extractXMLElement(element_str, "NumberAlternate"));


		d->bb_left[i]=atof(extractXMLElement(element_str, "BoundingBoxLeft"))-0.05;
		d->bb_right[i]=atof(extractXMLElement(element_str, "BoundingBoxRight"))+0.05;
		d->bb_top[i]=atof(extractXMLElement(element_str, "BoundingBoxTop"))+0.05;
		d->bb_bottom[i]=atof(extractXMLElement(element_str, "BoundingBoxBottom"))-0.05;

		//d->bb_left[i]=max(atof(extractXMLElement(element_str, "BoundingBoxLeft")),0.0);
		//d->bb_right[i]=min(atof(extractXMLElement(element_str, "BoundingBoxRight")),1.0);
		//d->bb_top[i]=min(atof(extractXMLElement(element_str, "BoundingBoxTop")),1.0);
		//d->bb_bottom[i]=max(atof(extractXMLElement(element_str, "BoundingBoxBottom")),0.0);

		//printf("bb of element %i: %.2f %.2f %.2f %.2f\n",i,d->bb_left[i],d->bb_right[i],d->bb_bottom[i],d->bb_top[i]);

		d->tight_bb_left[i]=atof(extractXMLElement(element_str, "TightBoundingBoxLeft"));
		d->tight_bb_right[i]=atof(extractXMLElement(element_str, "TightBoundingBoxRight"));
		d->tight_bb_top[i]=atof(extractXMLElement(element_str, "TightBoundingBoxTop"));
		d->tight_bb_bottom[i]=atof(extractXMLElement(element_str, "TightBoundingBoxBottom"));

		d->layout[i*NUM_VAR]=atof(extractXMLElement(element_str, "X"))/d->width;
		d->layout[i*NUM_VAR+1]=atof(extractXMLElement(element_str, "Y"))/d->height;
		d->layout[i*NUM_VAR+2]=atof(extractXMLElement(element_str, "Height"))/d->height;
		d->layout[i*NUM_VAR+3]=atof(extractXMLElement(element_str, "Alternate"));
		d->layout[i*NUM_VAR+4]=0;

		//d->alt_alignment[i]=(int *)malloc(d->num_alt[i]*sizeof(int));

		cout << "Loaded element: " <<extractXMLElement(element_str, "FileName") << endl;

		free(element_str);
	}

	d->num_overlap_regions=0;

	int max_num=1000;
	int skip=1;
	d->align_err=(float *)malloc(max_num*sizeof(float));
	for (int i=0;i< max_num;i++)
	{

		if (i <= skip)
			d->align_err[i]=0;
		else
		{
			float frac=(i-skip)/((float) max_num);
			d->align_err[i]=5*atan(frac/0.015);
		}
	}

	int max_atan_num=20000;
	d->atan_fixed=(float *)malloc(max_atan_num*sizeof(float));
	for (int i=0;i< max_atan_num;i++)
		d->atan_fixed[i]=atan(float(i)/200.0);


	free(str);

	return d;
}
*/

int freeDesign(Design *d)
{

	cout << "Free design " << endl;
	free(d->id);
	free(d->type);
	free(d->importance);
	free(d->group_id);
	free(d->num_lines);
	free(d->name);
	free(d->alignment);
	free(d->fixed_alignment);
	free(d->line_gap);
	free(d->bb_left);
	free(d->bb_right);
	free(d->bb_top);
	free(d->bb_bottom);
	free(d->tight_bb_left);
	free(d->tight_bb_right);
	free(d->tight_bb_top);
	free(d->tight_bb_bottom);
	free(d->align_err);
	free(d->atan_fixed);
	free(d->layout);
	free(d->init_layout);
	free(d->check_layout);
	free(d->check_layout_distances);
	free(d->overlap_region_elem);
	free(d->overlap_regions);
	free(d->num_alt);
	free(d->alt_num_lines);
	free(d->alt_aspect_ratio);
	free(d->optional);
	free(d->constraints);
	
	free(d);
	return 0;
}



int freeDeviceDesign(Design *d)
{

	Design *h=(Design *)malloc(sizeof(Design));
	ASSERT(cudaSuccess == cudaMemcpy(h, d, sizeof(Design), cudaMemcpyDeviceToHost),"cuda copy to device fail",-1);
	ASSERT(cudaSuccess == cudaFree(h->id),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->type),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->importance),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->group_id),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->num_lines),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->name),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->alignment),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->line_gap),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->bb_left),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->bb_right),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->bb_top),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->bb_bottom),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->tight_bb_left),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->tight_bb_right),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->tight_bb_top),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->tight_bb_bottom),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->align_err),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->atan_fixed),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->layout),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->init_layout),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->check_layout),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->check_layout_distances),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->overlap_region_elem),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->overlap_regions),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->num_alt),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->alt_num_lines),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->alt_aspect_ratio),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->optional),       "Device deallocation failed", -1);
	ASSERT(cudaSuccess == cudaFree(h->constraints),       "Device deallocation failed", -1);
	//for (int i=0;i<d->num_elements;i++)
	//	ASSERT(cudaSuccess == cudaFree(d->alt_alignment[i]),       "Device deallocation failed", -1);

	//ASSERT(cudaSuccess == cudaFree(d->alt_alignment),       "Device deallocation failed", -1);



	free(h);
	return 0;
}

int copyDesignToDevice(Design *device, Design *host)
{

	//cout << "Starting design copy" << endl;

	Design *host_copy=(Design *)malloc(sizeof(Design));
	memcpy(host_copy, host,sizeof(Design));



	ASSERT(cudaSuccess == cudaMalloc( (void **)(&host_copy->name), strlen(host->name)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->name), host->name, strlen(host->name), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc((void **) (&host_copy->id),host->num_elements*sizeof(int)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->id), host->id, host->num_elements*sizeof(int), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc((void **) (&host_copy->group_id),host->num_elements*sizeof(int)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->group_id), host->group_id, host->num_elements*sizeof(int), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc((void **) (&host_copy->type),host->num_elements*sizeof(int)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->type), host->type, host->num_elements*sizeof(int), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc((void **) (&host_copy->importance),host->num_elements*sizeof(int)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->importance), host->importance, host->num_elements*sizeof(int), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc((void **) (&host_copy->num_lines),host->num_elements*sizeof(int)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->num_lines), host->num_lines, host->num_elements*sizeof(int), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc((void **) (&host_copy->alignment),host->num_elements*sizeof(int)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->alignment), host->alignment, host->num_elements*sizeof(int), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc((void **) (&host_copy->optional),host->num_elements*sizeof(int)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->optional), host->optional, host->num_elements*sizeof(int), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc((void **) (&host_copy->num_alt),host->num_elements*sizeof(int)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->num_alt), host->num_alt, host->num_elements*sizeof(int), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc((void **) (&host_copy->fixed_alignment),host->num_elements*sizeof(int)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->fixed_alignment), host->fixed_alignment, host->num_elements*sizeof(int), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc((void **) (&host_copy->alt_num_lines),host->num_elements*MAX_ALT*sizeof(int)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->alt_num_lines), host->alt_num_lines, host->num_elements*MAX_ALT*sizeof(int), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc( (void **)(&host_copy->alt_aspect_ratio),host->num_elements*MAX_ALT*sizeof(float)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->alt_aspect_ratio), host->alt_aspect_ratio, host->num_elements*MAX_ALT*sizeof(float), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc( (void **)(&host_copy->aspect_ratio),host->num_elements*sizeof(float)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->aspect_ratio), host->aspect_ratio, host->num_elements*sizeof(float), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc( (void **)(&host_copy->line_gap),host->num_elements*sizeof(float)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->line_gap), host->line_gap, host->num_elements*sizeof(float), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc( (void **)(&host_copy->bb_left),host->num_elements*sizeof(float)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->bb_left), host->bb_left, host->num_elements*sizeof(float), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc( (void **)(&host_copy->bb_right),host->num_elements*sizeof(float)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->bb_right), host->bb_right, host->num_elements*sizeof(float), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc( (void **)(&host_copy->bb_top),host->num_elements*sizeof(float)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->bb_top), host->bb_top, host->num_elements*sizeof(float), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc( (void **)(&host_copy->bb_bottom),host->num_elements*sizeof(float)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->bb_bottom), host->bb_bottom, host->num_elements*sizeof(float), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc( (void **)(&host_copy->tight_bb_left),host->num_elements*sizeof(float)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->tight_bb_left), host->tight_bb_left, host->num_elements*sizeof(float), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc( (void **)(&host_copy->tight_bb_right),host->num_elements*sizeof(float)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->tight_bb_right), host->tight_bb_right, host->num_elements*sizeof(float), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc( (void **)(&host_copy->tight_bb_top),host->num_elements*sizeof(float)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->tight_bb_top), host->tight_bb_top, host->num_elements*sizeof(float), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc( (void **)(&host_copy->tight_bb_bottom),host->num_elements*sizeof(float)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->tight_bb_bottom), host->tight_bb_bottom, host->num_elements*sizeof(float), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc( (void **)(&host_copy->layout),host->layout_size*sizeof(float)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->layout), host->layout, host->layout_size*sizeof(float), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc( (void **)(&host_copy->init_layout),host->layout_size*sizeof(float)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->init_layout), host->init_layout, host->layout_size*sizeof(float), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc( (void **)(&host_copy->check_layout),host->layout_size*sizeof(float)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->check_layout), host->check_layout, host->layout_size*sizeof(float), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc( (void **)(&host_copy->check_layout_distances),MAX_ELEMENTS*sizeof(float)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->check_layout_distances), host->check_layout_distances, MAX_ELEMENTS*sizeof(float), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);


	ASSERT(cudaSuccess == cudaMalloc( (void **)(&host_copy->align_err),1000*sizeof(float)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->align_err), host->align_err, 1000*sizeof(float), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc( (void **)(&host_copy->atan_fixed),20000*sizeof(float)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->atan_fixed), host->atan_fixed, 20000*sizeof(float), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);


	ASSERT(cudaSuccess == cudaMalloc( (void **)(&host_copy->overlap_region_elem),host->num_overlap_regions*sizeof(int)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->overlap_region_elem), host->overlap_region_elem, host->num_overlap_regions*sizeof(int), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc( (void **)(&host_copy->overlap_regions),host->num_overlap_regions*sizeof(Box)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->overlap_regions), host->overlap_regions, host->num_overlap_regions*sizeof(Box), cudaMemcpyHostToDevice),"cuda copy to device fail",-1);

	ASSERT(cudaSuccess == cudaMalloc((void **) (&host_copy->constraints),MAX_ELEMENTS*3*NUM_AVAR*sizeof(int)),"cuda malloc fail",-1);
	ASSERT(cudaSuccess == cudaMemcpy((host_copy->constraints), host->constraints, MAX_ELEMENTS*3*NUM_AVAR*sizeof(int), cudaMemcpyHostToDevice),"cuda copy constraints to device fail",-1);


	ASSERT(cudaSuccess == cudaMemcpy(device, host_copy, sizeof(Design), cudaMemcpyHostToDevice),"cuda copy host_copy to device fail",-1);

	free(host_copy);
	cout << "finished design copy" << endl;

	return 0;
}
