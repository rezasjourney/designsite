

#ifndef __DESIGN_H__
#define __DESIGN_H__


#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <iostream>
#include <errno.h>
#include <sys/stat.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>


using namespace std;


#define FIX_LAYOUT_THRESH 0.9
#define SELECTED_NOFIX 0.95
#define SELECTED_FIX 1.05

#define TEXT_ELEMENT 0
#define GRAPHIC_ELEMENT 1


#define MIN_TEXT_SIZE 0.25
#define MIN_GRAPHIC_SIZE 0.15


#define MAX_ELEMENTS 15
#define MAX_ALT 10

#define NUM_VAR 8
#define NUM_RVAR 7
#define NUM_AVAR 17



#define ASSERT(x, msg, retcode) \
    if (!(x)) \
    { \
        cout << msg << " " << __FILE__ << ":" << __LINE__ << endl; \
        return retcode; \
    }

struct Box {

	float l;
	float r;
	float b;
	float t;

	__device__  void set(float l1,float r1,float b1,float t1)
	{
		l=l1;
		r=r1;
		b=b1;
		t=t1;
	}
	
	void set_h(float l1,float r1,float b1,float t1)
	{
		l=l1;
		r=r1;
		b=b1;
		t=t1;
	}


	__device__  float area()
	{
		return (r-l)*(t-b);
	}

	__device__  void set_pos(float l1, float b1)
	{
		float w=r-l;
		float h=t-b;
		l=l1;
		r=l1+w;
		b=b1;
		t=b+h;
	}

	__device__  void scale(float scale_mod)
	{
		r+=(r-l)*(scale_mod-1.0);
		t+=(t-b)*(scale_mod-1.0);
	}



	__device__  float width()
	{
		return (r-l);
	}
	__device__  float height()
	{
		return (t-b);
	}

	__device__  float mid_x()
	{
		return (r+l)/2.0;
	}
	
	__device__  float mid_y()
	{
		return (t+b)/2.0;
	}
};


struct Design {
	char *name;
	float width;
	float height;
	int layout_counter;
	//int layout_counter;

	//DesignElement **elements;
	int num_elements;
	int layout_size;
	float *layout;
	float *init_layout;
	float *check_layout;
	bool check_layout_exists;
	float *check_layout_distances;
	bool fixed_regions;
	bool region_proposals;
	
	
	//Element properties
	int *id;
	int *importance;
	int *type;
	float *bb_left;
	float *bb_right;
	float *bb_bottom;
	float *bb_top;

	float *tight_bb_left;
	float *tight_bb_right;
	float *tight_bb_bottom;
	float *tight_bb_top;

	float *align_err;
	float *atan_fixed;

	int *num_lines;
	float *aspect_ratio;
	float *line_gap;
	int *group_id;
	int *alignment;
	int *fixed_alignment;

	float **bp_x;
	float **bp_y;

	int num_overlap_regions;
	Box *overlap_regions;
	int *overlap_region_elem;
	
	int *num_alt;
	float *alt_aspect_ratio;
	int *alt_num_lines;
	
	int *optional;
	
	int num_constraints;
	int *constraints;
	
	bool refine;

};




__device__ Box getBoxIntersection(Box b1, Box b2);

__device__ bool anyBoxIntersection(Box b1, Box b2);

__device__ bool checkBoundingBoxOverlap(Box b1,Box *other_boxes, int num_boxes,int ignore_box);


char *getSubstring(char *string, char *start_tag, char *end_tag);

char *extractXMLElement(char *string, char *tag);

Design *loadDesignFromXML(char *filename);
Design *loadDesignFromFile(char *filename, bool interactive);

void writeLayoutToFile(Design *d, float *layout, char *filename, float energy);
float * readLayoutFromFile(Design *d, char *filename, int *num_regions, int *layout_counter);

float *parseLayout(Design *d,  char *str,int *num_regions, int *layout_counter);
void printLayout(char *str,Design *d, float *layout,  float energy);



int freeDeviceDesign(Design *d);
int freeDesign(Design *d);

int copyDesignToDevice(Design *device, Design *host);





#endif
