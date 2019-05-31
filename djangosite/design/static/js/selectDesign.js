

function setDesignList(json)
{
	var designs=json.designs;

	images={}
	loadedImages=0
	$.each(designs, function(i,fname){
		
			
		images[fname]= new Image();
		images[fname].onload = function() {
			
			
            if(++loadedImages >= designs.length) {
             $('#canvas').data("images",images);
              setDesignImages(images);
            }
			
		};
		var rand=Math.random()
		console.log(fname)
		images[fname].src = sprintf('/design/static/designs/%s?r=%.5f',fname.replace("json","png"),rand);
		console.log(images[fname].src)
	});
	
}

function setDesignImages(images)
{
	var names=Object.keys(images)
	
	names.sort()
	
	var num_rows=((names.length-1)/3);
	
	var row_select=$("#layout_row")
	
	for (var i=0;i<num_rows;i++)
	{
		var new_row=row_select.clone()
		new_row.find("#design0").attr("id",'design'+((i+1)*3));
		new_row.find("#design1").attr("id",'design'+((i+1)*3+1));
		new_row.find("#design2").attr("id",'design'+((i+1)*3+2));
		row_select.parent().append(new_row)
	}
	
	
	for (var i=0;i<names.length;i++)
	{
		console.log('name: '+names[i])
		var canvas=$('#design'+String(i))[0];
		var ctx=canvas.getContext("2d")
		console.log(canvas)
		
		var link=$('#design'+String(i)).parent()
		
		var design_name=names[i].replace(".json","")
		if (design_name.indexOf("new")>-1)
			design_name='new'
		link.attr("href","/design/create&design="+design_name)
		var ratio=images[names[i]].height/images[names[i]].width
		
		
		if (ratio>1)
		{
			var width=canvas.height/ratio;
			var offset=(canvas.width-width)/2
			ctx.drawImage(images[names[i]],offset,0,canvas.height/ratio,canvas.height);	
			
		   	ctx.beginPath();
		    ctx.rect(offset,0,canvas.height/ratio,canvas.height);
		    ctx.lineWidth = 1;
		    ctx.strokeStyle = 'black';
		    ctx.stroke();
		}
		else
		{
			var height=canvas.width*ratio;
			var offset=(canvas.height-height)/2
			ctx.drawImage(images[names[i]],0,offset,canvas.width,height);	
			
		   	ctx.beginPath();
		    ctx.rect(0,offset,canvas.width,height);
		    ctx.lineWidth = 0.5;
		    ctx.strokeStyle = 'black';
		    ctx.stroke();
		}
		
	}
}


