

var runID=-1;

//
// This method Gets URL Parameters (GUP)
//
function gup( name )
{
  var regexS = "[\\?&]"+name+"=([^&#]*)";
  var regex = new RegExp( regexS );
  var tmpURL = window.location.href;
  var results = regex.exec( tmpURL );
  if( results == null )
    return "";
  else
 	var res=results[1]
  	var idx1=res.indexOf("&")
  	if (idx1>-1)
  		res=res.substring(0,idx1)
  		
  	idx1=res.indexOf("?")
  	if (idx1>-1)
  		res=res.substring(0,idx1)
  
    return res
}

//
// This method decodes the query parameters that were URL-encoded
//
function decode(strToDecode)
{
  var encoded = strToDecode;
  return unescape(encoded.replace(/\+/g,  " "));
}

/*
function sendCurrentLayout(runID, layout)
{
	console.log("setting layout: "+layout);
	var time = new Date().getTime();
	//$('#layout'+imgNum).val(String(time)+','+info);
	
	$('#userLayout').val(layout);
	
	if ($('#suggLayout').data('runID')>=0)
	{
		sendLayoutToServer(designName,runID);
	}
}
*/

function updateDesignOnServer(runID,design)
{
	//console.log("setting design: "+design);
	var time = new Date().getTime();
	
	
	var layout_counter=$('#canvas').data("layout_counter")
	if (layout_counter==undefined)
		layout_counter=0;
	$('#canvas').data("layout_counter",layout_counter+1)
 	
 	design=layout_counter+"\n"+design
	
	
	$('#design_out').val(design);
	
	
	
	
	
	
	console.log("run id: "+runID);
	$.ajax({
		type:'GET',
		url:'/design/setCurrentDesign',
		error: function (request, status, error) {
			console.error('Failed to send design.');
			console.error(request.responseText);
			console.error(status);
			console.error(error);
		},
		data:{
			runID:runID,
			design:design,
			userID:$('input[name=userID]').val()
			},
		cache: false
	}).done(function(returnVal){
		if (returnVal==='1'){
			console.log('changed design');
		}else{
			console.log('error in setCurrentDesign');

		}
	});
	
}




function stopSuggestions()
{
	console.log("Stopping Suggestions")
	
	$('#canvas').data("energy_list",[])
    $('#checkingImage').css("visibility",'hidden');
    $('#canvas').data("started",false)

	$.each(runs=$('#canvas').data("runs"), function(i, run) {
		if (run.id>-1)
			stopRun(run.id, run.type)	
	});
}


function stopRun(run_id, run_type)
{
	
	debugMode=getURLParameter("debugMode")
	console.log("debug mode "+debugMode)
	
	if (debugMode.length < 1)
		debugMode='1'

	$.ajax({
		type:'GET',
		url:'/design/stopRun',
		error: function (request, status, error) {
			console.error('Failed to send layout.');
			console.error(request.responseText);
			console.error(status);
			console.error(error);
		},
		data:{
			//runID:$('#suggLayout').data('runID'),
			runID:run_id,
			runType:run_type,
			userID:$('input[name=userID]').val(),
			debugMode:debugMode
			},
		cache: false
	}).done(function(returnVal){
		if (returnVal==='1'){
			
			//setInactive()
			//$('#canvas').data('killed',true)
        	
			console.log('submitted layout')
		}else{
			console.log('error in stopRun')

		}
	});

}



function setInactive(error_str,restart)
{
	console.log("setInactive:"+error_str+ " restart "+restart)
	
	
	var inactive_str="Suggestions Inactive- Please Restart"
	
	if ($('#suggestion_status').text()==inactive_str)
		return
	
	
	$('#pauseButton').hide()
	$('#startButton').show()
	
	
	$('#checkingImage').css("visibility",'hidden');
	
	$('#canvas').data("status_log").push("Error-"+error_str)
	
	
	if (gup('hitId')=='')
	{
		$('#restartButton').show()
		$('#suggestion_status').text(error_str)
		$('#suggestion_status').css("background-color","#F00")
	}
	//else
	//{
		if (restart)
		{
			var time=(new Date()).getTime()
			var last_restart_time=$('#canvas').data("lastRestartTime")
			
			if ((last_restart_time!=undefined) && (time-last_restart_time<10000))
				console.log("wait for a few seconds before trying again...")
			else
			{
				$('#canvas').data("lastRestartTime",time)
				startSuggestions();				
			}
		}
	//}
	
	
	//logInactiveState()
	
	
	
}


function logInactiveState()
{
	
	console.log("logInactiveState")
	
	var design=$('#canvas').data("design")
	
	
	if ($('#canvas').data("error_log")==undefined)
		$('#canvas').data("error_log",[])
	
	design.user_input_log=$('#canvas').data("user_input_log")
	design.status_log=$('#canvas').data("status_log")
	
	$('#canvas').data("stage").toDataURL({
      callback: function(dataUrl) {
      	
      	var hitId=gup('hitId')
		var fname='layouts/error/'+$('#canvas').data("design").name+'-'+gup('workerId')+"-"+hitId+"-"+String($('#canvas').data("error_log").length)
		saveDesignOnServer(dataUrl,'',fname)
		
		$('#canvas').data("error_log").push(fname)
          
      }
    });
	
	
}



function resetParameters()
{

	if ($('#suggLayout').data('runID')>=0)
	{
		$.ajax({
			type:'GET',
			url:'/design/resetParameters',
			error: function (request, status, error) {
				console.error('Failed to send layout.');
				console.error(request.responseText);
				console.error(status);
				console.error(error);
			},
			data:{
				runID:$('#suggLayout').data('runID'),
				userID:$('input[name=userID]').val()
				},
			cache: false
		}).done(function(returnVal){
			if (returnVal==='1'){
				console.log('submitted layout');
			}else{
				console.log('error in resetParameters');
	
			}
		});
	}

}


function updateParameters(parameter_type, value)
{

	if ($('#suggLayout').data('runID')>=0)
	{
		$.ajax({
			type:'GET',
			url:'/design/updateParameters',
			error: function (request, status, error) {
				console.error('Failed to send layout.');
				console.error(request.responseText);
				console.error(status);
				console.error(error);
			},
			data:{
				runID:$('#suggLayout').data('runID'),
				userID:$('input[name=userID]').val(),
				parameterType:parameter_type,
				parameterValue:value,
				},
			cache: false
		}).done(function(returnVal){
			if (returnVal==='1'){
				console.log('submitted parameter change');
			}else{
				console.log('error in updateParameters');
	
			}
		});
	}

}



 
function startNewRun(run_id, run_type,design_string) 
 {   
 
 	//$('#userLayout').data('runID',-1)
	//var designName= gup('design');
	console.log("startNewRun with id "+ run_id+ " and type "+run_type+" at time: "+((new Date()).getTime()))
	
	
	//if (run_type=='gallery')
	//	return
	
	debugMode=getURLParameter("debugMode")
	console.log("debug mode "+debugMode)
	
	if (debugMode.length < 1)
		debugMode='1'
	
	$.ajax({
		type:'GET',
		url:'/design/startNewRun',
		error: function (request, status, error) {
			console.error('Failed to start new run.');
			console.error(request.responseText);
			console.error(status);
			console.error(error);
		},
		data:{
			runID:run_id,
			runType:run_type,
			design:design_string,
			debugMode:debugMode,
			userID:$('input[name=userID]').val()
			},
		cache: false
	}).done(function(jsonString){
		
		
		var json = JSON.parse(jsonString);
		//$('#suggLayout').data('runID',(json.runID))
		console.log("started new run "+json.runID)
		
		$('#canvas').data('killed',false)
		
		
		$('#canvas').data("runs")[json.runID]=$('#canvas').data("runs")[run_id]
		
		$('#canvas').data("runs")[json.runID].id=json.runID
		
		delete $('#canvas').data("runs")[run_id]
		
		console.log($('#canvas').data("runs"))
		
		//$('#suggestionButtonText').text("Stop Suggestions")
		//$('#suggestionButton').unbind()
		//$('#suggestionButton').on('click',stopSuggestions)
		//$('#user_id').text(json.userID)
		 
	});
    
	
 }  
 
 
 
 function sendLayoutToServer(runID,layout){
 	
 	
 	 	
 	
 	var d = new Date()
 	var t = d.getTime()
 	
 	console.log("Sending layout to server at "+t)
 	$('#canvas').data("sendLayoutTime",t)
 	

 	
 	var start_time=new Date()
 	
    $.ajax({
        type:'GET',
        url:'/design/getLayoutFromClient',
        error: function (request, status, error) {
            console.error('Failed to send layout.');
            console.error(request.responseText);
            console.error(status);
            console.error(error);
        },
        data:{
        	runID:runID,
            layout:layout,
            userID:$('input[name=userID]').val()
            },
        cache: false
    }).done(function(returnVal){
        if (returnVal=='1'){
        	
		 	var t = new Date().getTime()
		      
			if ($('#canvas').data("latencyLog")==undefined)
				$('#canvas').data("latencyLog",[])
			$('#canvas').data("latencyLog").push((t-start_time))
		        	
		    $('#send_layout_time').text(sprintf('%.0f',mean($('#canvas').data("latencyLog"))))
        	
        	//var d2 = new Date()
        	//var t2=d2.getTime()
            //console.log('finished sendLayoutToServer in '+(t2-t));
            // $('#canvas').data("sendLayoutToServerTimes").push(t2-t)
        }else{
        	
        	//$('#suggestion_status').text("Inactive");
        	//$('#suggestion_status').css("background-color","#F00");
            console.log('error in sendLayoutToServer');
            console.log(returnVal);
            return -1;
        }
    });
}
 
 
 
 function getLayoutFromServer(runID,runType,dirName){
 	
 	if (!$('#canvas').data("suggestionsEnabled"))	
 		return;
 		
 	var gallery_idx=-1;
 	if (runType=='gallery')	
 	{
 		var indices=$('#canvas').data("gallery_idx");
 		if (indices==undefined)
 		{
 			gallery_idx=Math.round(Math.random()*500)
 			$('#canvas').data("gallery_idx",[gallery_idx])	
 		}
 		else
 			gallery_idx=indices[indices.length-1]
 		
 		console.log(indices)
 	}
 		
 	console.log("gallery_idx:"+gallery_idx)
 		
    $.ajax({
        type:'GET',
        url:'/design/sendLayoutToClient',
        error: function (request, status, error) {
            console.error('Failed to receive layout.');
            console.error(request.responseText);
            console.error(status);
            console.error(error);
        },
        data:{
        	runID:runID,
        	runType:runType,
        	dirName:dirName,
        	galleryIdx:gallery_idx,
            userID:$('input[name=userID]').val()
            },
        cache: false
    }).done(function(jsonString){


		if ($('#canvas').data("automaticUpdate") && ((runType!='autoupdate') && (runType!='gallery')))
		{
			console.log("invalid run "+runType)
			return;
		}
			
		if ((!$('#canvas').data("automaticUpdate")) && ((runType=='autoupdate')))
			return;	
	      	
	    //1) read in layout, check layout, and respective energies
	    var json = JSON.parse(jsonString);
         
        var splt=json.layout.split("\n")        
        layout_name= splt[1]
        

        if ((runType=='gallery') && (json.galleryIdx>-1))
        {	
        	
        	if (json.galleryIdx in $('#canvas').data("gallery_idx"))
        	{
        		console.log("seen gallery style "+json.galleryIdx)
        		return
        	}
        	$('#canvas').data("gallery_idx").push(json.galleryIdx);
        	
        }
        
        if (json.layout=='')
        {
        	console.log("no layout. giving up")        	
        	return
        }
        

		if ('layoutFeatures' in json){
			$('#suggLayoutFeatures').text(json.layoutFeatures)
		}
		if ('userLayoutFeatures' in json){
			$('#userLayoutFeatures').text(json.userLayoutFeatures)
		}		
        
        
        var curr_time=new Date().getTime()
        
        //if layout's design doesn't match canvas design, error out
 		if ($('#canvas').data("design").name!=layout_name)
        {
   			var design_name=$('#canvas').data("design").name
        	var error_str="Mismatch:"+design_name+" vs "+layout_name
			setInactive(error_str,(layout_name.index("design_")>-1))
			return;
        }  
        
        
        if ((json.optimizationActive) || (runType=='gallery') || (runType=='nio'))
        {
	        $('#suggestion_status').text("")
	        $('#restartButton').hide()
        }
        else
        {
        	console.log("!optimizationActive")
			//clearInterval($('#canvas').data("suggestion_check"))
			//$('#canvas').data("suggestion_check",-1)
			
			console.log("optimization inactive for run "+runID)
			
			if (curr_time-$('#canvas').data("sendLayoutTime")>3000)
			{
				var error_str="Inactive:"
				setInactive(error_str,true)
			}
			return;
        }   
        
        

        
       
        var sugg_layout=splt.slice(0,splt.length-2).join("\n")
        
        var energy_str=splt[splt.length-2].split(":")[1]
        
        var energy = parseFloat(energy_str)
        
        counter=parseInt(splt[0])
        
        var canvas_energy=$('#canvas').data("energy")
	   
        var energy_diff=Math.abs(canvas_energy-energy)
        
       
        
        if ((runType=='gallery') || (runType=='nio'))
        {
        	setSuggestionLayout(runID, sugg_layout,energy);
        	return
        }
        
       
	   
	    var first_update=false;
	    
	    if ($('#canvas').data("automaticUpdate"))
	    {
        	//if the canvas layout counter is higher than the current one, we're getting stale data
        	var canvas_counter= $('#canvas').data("layout_counter")-1
        	if (canvas_counter!=counter)
    		{
    			//console.log("canvas counter "+canvas_counter+" doesnt match the current counter "+counter)
    			$('#counter_synced').text("Stale Layouts")
    			$('#counter_synced').css("background-color","#F00");
    			
    			
    			return
    		}
    		else
    		{
    			$('#counter_synced').text("Fresh Layouts")
    			$('#counter_synced').css("background-color","#0F0");
    		
    			first_update=addTime(counter,'latency')
    		}
    	}
        	
        		

       
       
        if (!$('#canvas').data("started")){
        	$('#checkingImage').css("visibility",'hidden');
        	return;
        }
        
        
	 	console.log(sprintf("runtype %s received layout %s. energy: \t %.2f, \t current energy %.3f (diff: %.2f)",runType,layout_name,energy,canvas_energy,energy_diff))
        

		var lists=$('#canvas').data("energy_lists")
		if (!(runID in lists))
			lists[runID]=[]
		
		var energy_list=lists[runID]   
        energy_list.push(energy)
        	
        	
		
        //if ((energy_list.length>=3) && ($('#canvas').data("dragging")==false))
		//	doubleCheckSelectedPosition(sugg_layout)
        	
	
        if (energy_list.length>=4)
        {
	
        	var last_diff=Math.abs(energy-energy_list[energy_list.length-4]);
        	if (last_diff>2)
    		{
    			console.log("skipped while working")
		        return;
    		}

        } 
      
       

       	//if ($('#canvas').data("automaticUpdate"))
       	 $('#checkingImage').css("visibility",'visible');
        
        
        var offset=3
        if ($('#canvas').data("automaticUpdate"))
        	offset=3
        	
        var converged=false;
        
        if ((energy_list.length>offset))
        {
        	var last_energy=energy_list[energy_list.length-(offset-1)]
        	if (Math.abs(energy-last_energy)<1)
    		{
    			addTime(counter,'convergence')
    			
    			converged=true
    			$('#canvas').data("runs")[runID].converged=true
    			
    			
    			var all_converged=true;
    			$.each($('#canvas').data("runs"), function(i, run) {
    				if ((run.converged==false) &&(run.type!='gallery'))
    					all_converged=false
    			})
    			
    			console.log("all_converged:"+all_converged)
    			
				
    			if (all_converged)
    			{
    				$('#canvas').data("started",false)
    				$('#checkingImage').css("visibility",'hidden');
    			}
    			
    			//	stopSuggestionsUntilUserInput()
    			
    		}
        }
        

        $('#suggLayout').val(sugg_layout);
        
        console.log("converged: "+converged)
        
        
		var last_set_time=$('#canvas').data("lastSetTime")
		
       	//(($('#canvas').data("energy")>1000)||(curr_time-last_set_time>600))
       	if ($('#canvas').data("automaticUpdate") && (energy_diff>5) && converged )
        {
       	
 	   	
	       // console.log("first update: "+first_update)
	        $('#canvas').data("energy",energy)	
	        
	        $('#canvas_energy').text(energy)
	        	
	        $('#canvas').data("lastSetTime",curr_time)
	        setCurrentLayout(sugg_layout,true)
	        	
 	   		if ($('#layoutInfo').is(':visible'))
        		setSuggestionLayout(runID, sugg_layout,energy);
        
        
        }
        else if (!$('#canvas').data("automaticUpdate") && (converged) )
        {
        	
        	var curr_energy= $('#canvas').data("runs")[runID].energy
        	
        	//if (Math.abs(curr_energy-energy)>2)
        	setSuggestionLayout(runID, sugg_layout,energy);
        	
        }

        	
       
	      

    	 
    	/*
       	
    	if ($('#canvas').data("energy")==9999)
    	{	
    		if($('#userLayout').val()==user_layout)
        	{
  	    		console.log("canvas energy: "+$('#canvas').data("energy")+", user energy:"+user_energy)
	    		$('#canvas').data("energy",user_energy)   
	    		
	    		if ($('#error_message').text()=="unknown energy")
	    			$('#error_message').text("")
    		}
    		else
    		{
    			$('#error_message').text("unknown energy")
    		}

    	}    	
    
        
	

        /*
        var num_server_suggestions=$('#canvas').data("num_server_suggestions")
        if (num_server_suggestions == undefined)
        	num_server_suggestions=1;
        $('#canvas').data("num_server_suggestions",num_server_suggestions+1)
        console.log("num_server_suggestions: "+num_server_suggestions)
        if (num_server_suggestions<=3)
        	return;
       
        */	

         
    });
}
 

function addTime(counter,time_type)
{
	var init_time, time_array_names;
	if (time_type=='latency')
	{
		init_time= "sendLayoutTime"
		time_array_names="layoutLatencyTimes"
	}
	else
	{
		init_time= "receivedFirstResponseTime"
		time_array_names="layoutConvergenceTimes"	
	}
	
	var send_time=$('#canvas').data(init_time)
	
	if (send_time!=undefined)
	{
		var curr_time=new Date().getTime()
 	 	var time_diff=curr_time-send_time
	    
	      
	    var times=$('#canvas').data(time_array_names)
	    if (times==undefined)
	    {
	      	times ={}
	      	$('#canvas').data(time_array_names,times)
	     }
	      
	     if (!(counter in times))
	     {
		    times[counter]=time_diff;
		     
		    var time_sum=0;
		    var time_cnt=0;
		    for (var key in times)
		    {
		     	time_sum+=times[key]
		     	time_cnt++
		    }
		    
		    /*
		    console.log("times: ")
		    console.log(times)
		    console.log("counter: "+counter)
		     
		     
		    console.log("time_type: "+time_type)
		    console.log("time_cnt: "+time_cnt)
		    console.log("time_diff: "+time_diff)
		    */
			 
			if (time_type=="latency")
			{
    			$('#mean_latency_time').text(sprintf('%.0f',time_sum/time_cnt))
    			$('#canvas').data("receivedFirstResponseTime",curr_time)	
    		}
    		else
    			$('#mean_convergence_time').text(sprintf('%.0f',time_sum/time_cnt))
    		
    		return true
    	}
	}
	return false
}
 
function stopSuggestionsUntilUserInput()
{

		console.log("stop layout")
		$('#canvas').data("energy_list",[])
        $('#checkingImage').css("visibility",'hidden');
        $('#canvas').data("started",false)
 	
		clearInterval($('#canvas').data("suggestion_check"))
		$('#canvas').data("suggestion_check",-1)
}
 
 
function doubleCheckSelectedPosition(new_layout)
{
	
	//console.log("doubleCheckSelectedPosition")
	var elements=new_layout.split("\n");
	var layout = $('#canvas').data("layout");
	var design = $('#canvas').data("design");
	var cnt = $('#canvas').data("inconsistent_count");
	if (cnt == undefined)
		cnt=0;
		
	for (var i=3;i < design.elements.length+3;i++)
	{
		var elem=design.elements[i-3];
		
		if ((elem.selected) && (design.elements.length==elements.length-4))
		{
			
			var elem_split=elements[i].split(',');
			var layout_x=parseInt(elem_split[0])
			var layout_y=parseInt(elem_split[1])
			if ((Math.abs(elem.x-layout_x)>2) ||(Math.abs(elem.y-layout_y)>2))
			{
				console.log("Inconsistent element "+elem.id)
				console.log("elem.x:"+elem.x +" vs "+layout_x)
				console.log("elem.y:"+elem.y +" vs "+layout_y)
				
				$('#canvas').data("inconsistent_count",cnt+1)

				if (cnt>3)
					$('#error_message').text("Selected Element Inconsistent")
				sendCurrentLayout()
				return
			}
		}		
	}
	
	$('#canvas').data("inconsistent_count",0);
	if ($('#error_message').text()!='')
		$('#error_message').text('');
}

 
 
 
 function getDesignList(dir)
 {
 	
 	

 	
 	
    $.ajax({
        type:'GET',
        url:'/design/listDesigns',
        error: function (request, status, error) {
            console.error('Failed to receive layout.');
            console.error(request.responseText);
            console.error(status);
            console.error(error);
        },
        data:{
            userID:$('input[name=userID]').val(),
            dir:dir
            },
        cache: false
    }).done(function(jsonString){
        

		console.log(jsonString)
        var json = JSON.parse(jsonString);
        
        console.log(json)
        setDesignList(json)
         
    });
 }
 
 function getLayoutList()
 {
 	
 	
    $.ajax({
        type:'GET',
        url:'/design/listLayouts',
        error: function (request, status, error) {
            console.error('Failed to receive layout.');
            console.error(request.responseText);
            console.error(status);
            console.error(error);
        },
        data:{
            userID:$('input[name=userID]').val(),
      	  	workerID:gup('workerID'),
        	design:gup('design'),
        	interface:gup('interface')
            },
        cache: false
    }).done(function(jsonString){
        
        var json = JSON.parse(jsonString);
        
        console.log(json)
        setLayoutList(json)
         
    });
 }
 
 function getABResults()
 {
 	
 	
    $.ajax({
        type:'GET',
        url:'/design/getJSONFiles',
        error: function (request, status, error) {
            console.error('Failed to receive layout.');
            console.error(request.responseText);
            console.error(status);
            console.error(error);
        },
        data:{
            userID:$('input[name=userID]').val(),
      	  	workerID:gup('workerID'),
        	design:gup('design'),
        	dir:'designABResults/'
        	
            },
        cache: false
    }).done(function(jsonString){
        
        var json = JSON.parse(jsonString);
        
        console.log(json)
        viewABResults(json)
         
    });
 }
 
 function saveDesignOnServer(img, design,fname)
 {
 	if (fname==undefined)
		fname=design.name
	
 	console.log('saveDesignOnServer')
 	//console.log(img)
 	
     $.ajax({
        type:'POST',
        url:'/design/saveDesign',
        error: function (request, status, error) {
            console.error('Failed to receive layout.');
            console.error(request.responseText);
            console.error(status);
            console.error(error);
        },
        data:{
            userID:$('input[name=userID]').val(),
            designName:fname,
            design:JSON.stringify(design, null, '\t'),
            image:img
            },
        cache: false
		}).done(function(returnVal){
			if (returnVal==='1'){
				console.log('design saved');
			}else{
				alert('error saving design'+returnVal);
	
			}
		});
 }
 
 
 
 function saveImageOnServer(imgName, img)
 {
 	console.log('saveImageOnServer')
 	console.log(img)
 	
 	var start_time=new Date()
     $.ajax({
        type:'POST',
        url:'/design/saveImage',
        error: function (request, status, error) {
            console.error('Failed to receive layout.');
            console.error(request.responseText);
            console.error(status);
            console.error(error);
        },
        data:{
            userID:$('input[name=userID]').val(),
            imageName:imgName,
            image:img
            },
        cache: false
		}).done(function(returnVal){
			if (returnVal==='1'){
				var end_time=new Date()
				if ($('#canvas').data("transferRateLog")==undefined)
					$('#canvas').data("transferRateLog",[])
				console.log("start "+start_time+ " end "+ end_time +" img len "+(img.length/1000.0))
				var rate=(img.length/1024.0)/((end_time-start_time)/1000.0)
				$('#canvas').data("transferRateLog").push(rate)
				console.log('image saved. transfer rate: '+rate);
			}else{
				console.log('error in design');
	
			}
		});
 }
 
 function deleteDesignOnServer(design)
 {
 	
 	var designName=design.directory+design.name
 	console.log('deleting design off server')
     $.ajax({
        type:'GET',
        url:'/design/deleteDesign',
        error: function (request, status, error) {
            console.error('Failed to receive layout.');
            console.error(request.responseText);
            console.error(status);
            console.error(error);
        },
        data:{
            userID:$('input[name=userID]').val(),
            designName:designName
            },
        cache: false
		}).done(function(returnVal){
			if (returnVal==='1'){
				console.log('design deleted');
				
			}else{
				console.log('error in design');
	
			}
			
		});
		
		window.location.replace("/design/select/"+design.directory)	

 }
 
 
 
 
 function saveReportOnServer(reportName, img1,img2,img3,report)
 {
 	console.log('saveReportOnServer')
 
 	var start_time=new Date()
     $.ajax({
        type:'POST',
        url:'/design/saveReport',
        error: function (request, status, error) {
            console.error('Failed to receive report.');
            console.error(request.responseText);
            console.error(status);
            console.error(error);
        },
        data:{
            userID:$('input[name=userID]').val(),
           	reportName:reportName,
            image1:img1,
            image2:img2,
            image3:img3,
            report:JSON.stringify(report, null, '\t'),
            },
        cache: false
		}).done(function(returnVal){
			if (returnVal==='1'){
				
				console.log('report saved.');
			}else{
				console.log('error saving report');
	
			}
		});
 }
 
 


function mean(l)
{
	if (l==undefined)
		return undefined
	var s=0
	//console.log("mean of l: "+String(l))
	for (var i=0;i<l.length;i++)
		s+=l[i]
	return s/l.length
	
}

 
 function toggleShowInfo()
 {
 	console.log("toggling")
 	
 	if ($('#layoutInfo').is(':visible'))
 	{
 		$('#layoutInfo').hide();
 		$('#infoButton').text('Show Debug Info')
 	}
	else
	{
		$('#layoutInfo').show();
		$('#infoButton').text('Hide Debug Info')	
 	}
 
 	
 }
 
 function getURLParameter(name) {
	var regexS = "[\\?&]"+name+"=([^?&#]*)";
	var regex = new RegExp( regexS );
	var tmpURL = window.location.href;
	var results = regex.exec( tmpURL );
	if( results === null )
		return "";
	else
		return results[1];
}

