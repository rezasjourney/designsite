


package 
{
	import flash.display.Loader;
	import flash.display.Bitmap;
	import flash.text.Font;

	public class Element
	{
		
	  public var loader:Loader;
	  public var alt_loaders:Array;
	  public var alt_bitmaps:Array;
	  public var type:uint;
	  public var id:uint;
	  public var importance:Number=0;
	  public var scale:Number;
	  public var group_id:int=0;
	  public var x:Number;
	  public var y:Number;
	  public var fname:String='';
	  public var height:Number;
	  public var width:Number;
	  public var aspect_ratio:Number;
	  public var text:String;
	  public var num_lines:int=0;
	  public var is_graphic:Boolean=false;
	  public var is_text:Boolean=false;
	  public var is_background:Boolean=false;
	  public var image:Boolean=true;
	  public var align:String='';
	  public var colour:String='';
	  
	  public var font:Font;
	  public var italic:Boolean=false;
	  public var bold:Boolean=false;
	  
	  public var editing:Boolean=false;
	  
	  public var fixed:Boolean=false;
	  public var multi_selected:Boolean=false;
	  public var possible_deselect:Boolean=false;
	  
  	  public var startx:Number;
	  public var starty:Number;
	  public var startheight:Number;
	  public var startwidth:Number;
	
  	  public var initx:Number;
	  public var inity:Number;
	  public var initheight:Number;
	  public var initwidth:Number;
	  
	  public var minheight:Number;
	  public var minwidth:Number;
	  
	  public var alt:Number=-1;
	  
	  public var bitmap :Bitmap
	  
	  public var suggest_bitmaps :Array;
	  public var suggest_alt_bitmaps :Array;
	  
	  public var no_overlap_regions :Array;
		
	  public function Element(start_fname:String, start_type:Number,start_scale:Number, start_nl:int, start_imp:int, start_group_id:int, start_x:Number,start_y:Number,start_width:Number,start_height:Number)
	  {
		  
		  num_lines=start_nl;
		  importance=start_imp;
		  group_id=start_group_id;
	
	
		  type=start_type;
		  
		  
		  if (type==0)
		  {
			  is_background=true
		  }		  
		  else if (type==2)
		  {
			  is_graphic=true;
		  }
		  else
		  {	
			  is_text=true; 
		  }
		 
		  scale=start_scale;
		  x=start_x;
		  y=start_y;
		  fname=start_fname;
		  
		  if (start_type==1)
		  {
			  text=fname;
		  }

		  
		  width=start_width*scale;
		  height=start_height*scale;
			  
		  
		  //while ((Math.max(height,width)<25) || (Math.min(height,width)<10))
		  //{
			//  scale=scale*1.1;
			//  width=start_width*scale;
			//  height=start_height*scale;
		 // }
		  
		  
		  aspect_ratio=width/height;
		  
		  initwidth=width;
		  initheight=height;
		  initx=start_x;
		  inity=start_y; 
		  
		  if (width>height)
		  {
			//minheight=25/aspect_ratio;
		  	//minwidth=25;
		
			minheight=7 ;
		  	minwidth=7*aspect_ratio;
		  }
		  else
		  {
			minwidth=7;
		  	minheight=7/aspect_ratio;
		  }
		  alt_bitmaps=new Array()
		  alt_loaders=new Array()
		  alt=-1
		  
		  alt_bitmaps.push(0);
		  alt_bitmaps.push(0);
		  alt_bitmaps.push(0);
		  
		  no_overlap_regions=new Array()
		  
		  
		  text=''
	  }
	
	/*
	  public function addPoint(xpt:Number, ypt:Number):void
	  {
		  x_pts.push(xpt);
		  y_pts.push(ypt);
	
		  
	  }
*/
	  
	}

}