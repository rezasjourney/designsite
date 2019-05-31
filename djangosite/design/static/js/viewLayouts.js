
// Programmer: Larry Battle 
// Date: Mar 06, 2011
// Purpose: Calculate standard deviation, variance, and average among an array of numbers.
var isArray = function (obj) {
	return Object.prototype.toString.call(obj) === "[object Array]";
},
getNumWithSetDec = function( num, numOfDec ){
	var pow10s = Math.pow( 10, numOfDec || 0 );
	return ( numOfDec ) ? Math.round( pow10s * num ) / pow10s : num;
},
getAverageFromNumArr = function( numArr, numOfDec ){
	if( !isArray( numArr ) ){ return false;	}
	var i = numArr.length, 
		sum = 0;
	while( i-- ){
		sum += numArr[ i ];
	}
	return getNumWithSetDec( (sum / numArr.length ), numOfDec );
},
getVariance = function( numArr, numOfDec ){
	if( !isArray(numArr) ){ return false; }
	var avg = getAverageFromNumArr( numArr, numOfDec ), 
		i = numArr.length,
		v = 0;
 
	while( i-- ){
		v += Math.pow( (numArr[ i ] - avg), 2 );
	}
	v /= numArr.length;
	return getNumWithSetDec( v, numOfDec );
},
getStandardDeviation = function( numArr, numOfDec ){
	if( !isArray(numArr) ){ return false; }
	var stdDev = Math.sqrt( getVariance( numArr, numOfDec ) );
	return getNumWithSetDec( stdDev, numOfDec );
};




function toggle(log_type,show,button)
{
	
	console.log(button)
	var parent =$(button).parent()
	
	
	if (show)
	{
		parent.find('.'+log_type+"Show").hide()
		parent.find('.'+log_type+"Hide").show()
		parent.find('.'+log_type+"Outer").show()
	}
	else
	{
		parent.find('.'+log_type+"Show").show()
		parent.find('.'+log_type+"Hide").hide()
		
		parent.find('.'+log_type+"Outer").hide()
		
	}
}



function setLayoutList(json)
{
	var layouts=json.layouts;

	$('#canvas').data("noSuggestions",1)
	
	var curr_design=''

	var num_layouts=layouts.length
	
	
	$('#stats').data("times",[])
	$('#stats').data("interactions",[])
	$('#stats').data("overallTimes",[])
	
	$('#stats').data("directRatings",[])
	$('#stats').data("suggestionRatings",[])
	$('#stats').data("adaptiveRatings",[])
	
	$('#stats').data("directTimes",[])
	$('#stats').data("suggestionTimes",[])
	$('#stats').data("adaptiveTimes",[])
	
	$('#stats').data("directInteractions",[])
	$('#stats').data("suggestionInteractions",[])
	$('#stats').data("adaptiveInteractions",[])
	
	$('#stats').data("directSuggestionPrefer",[])
	$('#stats').data("suggestionDirectPrefer",[])
	
	$('#stats').data("directAdaptivePrefer",[])
	$('#stats').data("adaptiveDirectPrefer",[])
	
	$('#stats').data("suggestionAcceptedCount",0)
	$('#stats').data("suggestionIgnoredCount",0)
	
	$('#stats').data("suggestionAcceptedImages",[])
	$('#stats').data("baselineImages",[])
	$('#stats').data("adaptiveImages",[])
	$('#comments').data("comments",[])
	
	
	$('#stats').data("brainstormAcceptedCount",0)
	$('#stats').data("tweakAcceptedCount",0)
	
	
	
	setLayout(0,layouts,'')
	
}


function mean(l)
{

	var sum=0;
	for (var i=0;i<l.length;i++)
		sum+=l[i]
	return sum/l.length
}

function median(l)
{
	l = l.slice(0);
	l.sort(function(a,b){return b-a})
	
	var idx=Math.floor(l.length/2)
	
	return l[idx]
	
}


function getStats(l)
{
	if (l.length>1)
	{
		std=getStandardDeviation(l)
		return [mean(l), std, l.length, 2*std/Math.sqrt(l.length),median(l)]
	}
	else
	{
		return [0,0,0,0,0]
	}
}


function calculateStats()
{
	
	
	console.log("overall times")
	console.log($('#stats').data("overallTimes"))
	
	$('#meanOverallTime').text(sprintf("%.2f",mean($('#stats').data("overallTimes"))))
	
	var times=$('#stats').data("times")
	
	st=getStats(times)
	
	if (times.length>0)
	{
		$('#meanDesignTime').text(sprintf("mean %.2f cnt %d std err %.3f med %.2f",st[0],st[2],st[3],st[4]))
		$('#medianDesignTime').text(sprintf("%.2f",median(times)))
	}
	var interactions=$('#stats').data("interactions")
	if (interactions.length>0)
	{
		$('#meanInteractions').text(sprintf("%.2f",mean(interactions)))
		$('#medianInteractions').text(sprintf("%.2f",median(interactions)))	
	}
	
	
	
	
	if ($('#stats').data("directRatings").length>1)
	{
		st=getStats($('#stats').data("directRatings"))
		console.log(st)
		$('#directRating').text(sprintf("mean %.2f cnt %d std err %.3f med %.2f",st[0],st[2],st[3],st[4]))
		st=getStats($('#stats').data("suggestionRatings"))
		$('#suggestionRating').text(sprintf("mean %.2f cnt %d std err %.3f, med %.2f",st[0],st[2],st[3],st[4]))
		st=getStats($('#stats').data("adaptiveRatings"))
		$('#adaptiveRating').text(sprintf("mean %.2f cnt %d std err %.3f med %.2f",st[0],st[2],st[3],st[4]))
	}
	
	st=getStats($('#stats').data("directTimes"))
	$('#directTime').text(sprintf("mean %.2f cnt %d std err %.3f",st[0],st[2],st[3]))
	st=getStats($('#stats').data("suggestionTimes"))
	$('#suggestionTime').text(sprintf("mean %.2f cnt %d std err %.3f",st[0],st[2],st[3]))
	st=getStats($('#stats').data("adaptiveTimes"))
	$('#adaptiveTime').text(sprintf("mean %.2f cnt %d std err %.3f",st[0],st[2],st[3]))
	
	st=getStats($('#stats').data("directInteractions"))
	$('#directInteractions').text(sprintf("mean %.2f cnt %d std err %.3f",st[0],st[2],st[3]))
	st=getStats($('#stats').data("suggestionInteractions"))
	$('#suggestionInteractions').text(sprintf("mean %.2f cnt %d std err %.3f",st[0],st[2],st[3]))
	st=getStats($('#stats').data("adaptiveInteractions"))
	$('#adaptiveInteractions').text(sprintf("mean %.2f cnt %d std err %.3f",st[0],st[2],st[3]))
	

	$('#directSuggestionPrefer').text($('#stats').data("directSuggestionPrefer").length)
	$('#suggestionDirectPrefer').text($('#stats').data("suggestionDirectPrefer").length)
	
	$('#directAdaptivePrefer').text($('#stats').data("directAdaptivePrefer").length)
	$('#adaptiveDirectPrefer').text($('#stats').data("adaptiveDirectPrefer").length)
	

	$('#suggestionIgnoredCount').text($('#stats').data("suggestionIgnoredCount"))
	$('#suggestionAcceptedCount').text($('#stats').data("suggestionAcceptedCount"))
	

	$('#brainstormAcceptedCount').text($('#stats').data("brainstormAcceptedCount"))
	$('#tweakAcceptedCount').text($('#stats').data("tweakAcceptedCount"))

	$('#suggestionAcceptedImages').html($('#stats').data("suggestionAcceptedImages").join("<br>"))
	$('#baselineImages').html($('#stats').data("baselineImages").join("<br>"))
	$('#adaptiveImages').html($('#stats').data("adaptiveImages").join("<br>"))	


	$('#comments').html($('#comments').data("comments").join("<br>"))	
	

}



function setLayout(idx, layouts, curr_design)
{
	if (idx>=layouts.length)
	{
		calculateStats()
		return
	}
		

	var json = JSON.parse(layouts[idx]);
	if ((curr_design!=json.design) && (gup('checkImages')!=''))
	{
		curr_design=json.design
		
		if (json.design==undefined)
		{
			console.log("design undefined?\njson:\n"+layouts[idx])
			return
		}
		loadDesignFile(json.design)
		
		setTimeout(function(){
			console.log("finished timeout");
			loadLayouts(idx,json),
			setLayout(idx+1,layouts,curr_design)			
		},500)
	}
	else
	{
		loadLayouts(idx,json)
		setLayout(idx+1,layouts,curr_design)	
	}
}



function loadLayouts(layout_idx,json)
{
	
	var sequence=true;
	var retarget=false
	var paired=true;
	//if ("retarget_layout0" in json)
	//	retarget=true;
	
	
	var user_section=$("#user_layouts")
	
	user_section.hide()
	
	var new_sec=user_section.clone()
	new_sec.attr("id","user_layouts"+String(layout_idx))
	new_sec.show()


	new_sec.find(".date").text(json.startDateTime);
	
	
	new_sec.find(".hitComments").text(json.hit_comments);
	new_sec.find(".interfaceComments").text(json.interface_comments);
	
	
	
	$('#comments').data("comments").push(json.hit_comments)
	$('#comments').data("comments").push(json.interface_comments)
	
	var int_type=json.interface;
	if (int_type == undefined)
		int_type='baseline'
	new_sec.find(".interface").text(int_type);
	new_sec.find(".interface").attr("href","viewLayouts?design=all&interface="+int_type);
	
	var interfaces=json.interface.split(",")
	
	
	if ((gup("interface")!='') && (gup("interface") != int_type))
		return
		
	var adaptive=false;
	if	(json.interface.indexOf("adaptive")>-1)
		adaptive=true
		
		
	if (json.userInputLog.indexOf(",S,")==-1)
		return;

	
	var overall_time=parseFloat(json.totalTime)/60000
	new_sec.find(".totalTime").text(sprintf("%.2f",overall_time));
	
	console.log(overall_time)
	
	if (overall_time<3)
		return
	
	if (json.transferRate!=undefined)
	{
		var transfer_rate=parseFloat(json.transferRate)
		new_sec.find(".transferRate").text(sprintf("%.0f",transfer_rate));
		
		var latency=parseFloat(json.sendLayoutTime)
		new_sec.find(".latency").text(sprintf("%.0f",latency));
		
		var responseTime=parseFloat(json.initResponseTime)
		new_sec.find(".responseTime").text(sprintf("%.0f",responseTime));
	}
	

	$('#stats').data("overallTimes").push(overall_time)
		
		
		
	if (paired)
	{
		
		var ratings={verypoor:1,poor:2,neutral:3,good:4,verygood:5 }
		
		new_sec.find(".experience").text(json.typexp);
	
		new_sec.find(".directRating").text(json.directrating);
		new_sec.find(".suggRating").text(json.suggestionrating);
		new_sec.find(".interfacePref").text(json.pref);
		
		new_sec.find(".interfaceComments").text(json.interface_comments);
	
	
		
		if (json.directrating!=undefined)
			$('#stats').data("directRatings").push(ratings[json.directrating])
		
		if (json.suggestionrating!=undefined)
		{
			
			if (adaptive)
				$('#stats').data("adaptiveRatings").push(ratings[json.suggestionrating])
			else	
				$('#stats').data("suggestionRatings").push(ratings[json.suggestionrating])
		}
	
		console.log($('#directRating').data("ratings"))
	
	
		if (adaptive)
		{
			if (json.pref=='direct')
				$('#stats').data('directAdaptivePrefer').push(1)
			else if (json.pref=='suggestion')
				$('#stats').data('adaptiveDirectPrefer').push(1)
		}
		else
		{
			if (json.pref=='direct')
				$('#stats').data('directSuggestionPrefer').push(1)
			else if (json.pref=='suggestion')
				$('#stats').data('suggestionDirectPrefer').push(1)	
		}
	
	}
	else
	{
		$('#pairedStats').hide()
		$('#pairedQuestions').hide()
	}
	
	new_sec.find(".workerID").text(json.workerID);
	new_sec.find(".workerID").attr("href","viewLayouts?workerID="+json.workerID);
	
	new_sec.find(".designID").text(json.design);
	new_sec.find(".designID").attr("href","viewLayouts?design="+json.design);
	



	var layoutTimes=json.layoutTimes.split(",")
	var layoutIDs
	if (json.layoutIDs!=undefined)
		layoutIDs=json.layoutIDs.split(",")
		
	new_sec.find(".testNumber").text(layout_idx);	
	
	//if (int_type!='suggestions')
	if ((retarget) || (int_type=='suggestions'))
		new_sec.find(".states_row").show()
	else
		new_sec.find(".states_row").hide()
	
	
	var layout_user_inputs=[]
	
	
	if (sequence)
		layout_user_inputs=json.userInputLog.split("Next Design,")
	else
	{
		inp_log=new String(json.userInputLog)
		
		inp_log=inp_log.split("Reset,").join("")
		
		layout_user_inputs=inp_log.split("Save,")
		
	}
	
	var log=json.statusLog
	log=log.split("Save,").join("Save,\n")
	log=log.split("Start,").join("Start,\n")
	log=log.split("Design,").join("Design,\n")
	
	
	var count_update=log.split(",U").length

	
	
	var log_div=new_sec.find(".statusLog")
	log_div.text(log);
	log_div.html(log_div.html().replace(/\n/g,'<br/>'))
	
	var error_run=(log.indexOf("Error")>-1);
	
	
	if (error_run)
	{
		
		new_sec.find(".errors").text("Yes");	
		new_sec.find(".errors").css("background-color","#F00")
		
		new_sec.find("#crashInfo").show()
		
		
		var errors=json.errorLog.split(",")
		
		//for (var i=0;i<error.length;i++)
		//{
			var fname="/design/static/images/layouts/error/"+json.design+"-"+json.workerID +"-"+json.hitID+"-"+String(0)+".png"
			console.log('fname:'+fname)
			new_sec.find("#errorImage").attr("src",fname)

		//}
		
		$('#numErrorRuns').text(parseInt($('#numErrorRuns').text())+1)
	}
	else
		$('#numOKRuns').text(parseInt($('#numOKRuns').text())+1)
	
	
	console.log('layoutTimes:'+String(layoutTimes))
	
	//new_sec.find(".userInputLog").text(json.userInputLog);
	
	for (var i=0;i<layoutTimes.length;i++)
	{
		if (layoutTimes[i]=='')
			continue
			
		var time=parseFloat(layoutTimes[i])/60000
		
		new_sec.find("#time"+String(i)).text(sprintf("%.2f",time));
		
		
		if (sequence)
		{
			
				layout =json['layout'+String(i)]
				
				if ((layout=='') || (layout==undefined))
					continue
					
				curr_design=layout.split("\n")[0]
				
				
				

				var width=layout.split("\n")[1].split(",")[0]
				var height=layout.split("\n")[1].split(",")[1]
				
				console.log("width: "+width)
				console.log("height: "+height)
				
				console.log("curr_design:"+curr_design)
				var dname="/design/static/images/layouts/"
				var fname=curr_design+"-"+json.workerID +"-"+json.hitID+"-"+String(i)+".png"
				console.log('fname:'+fname)
				new_sec.find("#img"+String(i)).attr("src",dname+fname)
				//new_sec.find("#img"+String(i)).css("max-width","none")
			
				new_sec.find("#img"+String(i)).parent().show()
				
				//fname="/design/static/designs/layouts/"+curr_design+".png"
				//new_sec.find("#stateImg"+String(i)).attr("src",fname)		
				//new_sec.find("#stateImg"+String(i)).css("max-width","none")				
				

				var tut=(curr_design.indexOf("tut")>-1)
				
				var type='unknown'
				
			
				user_input =json['layout_input'+String(i)]
				user_input=user_input.replace("Normal-Suggestions,","")
				user_input=user_input.replace("Reset,","")
				
				console.log(i+": "+user_input)
				
				
				var num_view=0
				var num_accept=0
				user_input=user_input.split("State-").join("")
				
				console.log(user_input)
				
				if ((interfaces[i]=="suggestions") || (interfaces[i]=="adaptive"))
				{
					num_accept=(user_input.split("Load-").length-1)
					num_view=(user_input.split("View-").length-1)
					new_sec.find("#type"+String(i)).text(interfaces[i]+"("+num_view+" viewed,"+num_accept+" accepted)")
					
					
					if (num_accept>0)
					{
						$('#stats').data("suggestionAcceptedCount",$('#stats').data("suggestionAcceptedCount")+1)
						
						if (interfaces[i]!="adaptive")
							$('#stats').data("suggestionAcceptedImages").push(fname)	
						
						num_brainstorm=(user_input.split("Load-gallery").length-1)
						num_tweak=(user_input.split("Load-sugg").length-1)
						
						if (num_brainstorm>0)
							$('#stats').data("brainstormAcceptedCount",$('#stats').data("brainstormAcceptedCount")+1)
						
						if (num_tweak>0)
							$('#stats').data("tweakAcceptedCount",$('#stats').data("tweakAcceptedCount")+1)
						
						
					}
					else	
						$('#stats').data("suggestionIgnoredCount",$('#stats').data("suggestionIgnoredCount")+1)
	
	
					if (interfaces[i]=="adaptive")
					{
						new_sec.find("#type"+String(i)).text(interfaces[i])
						$('#stats').data("adaptiveImages").push(fname)	
					}
	
				}
				else
				{
					new_sec.find("#type"+String(i)).text(interfaces[i])
					$('#stats').data("baselineImages").push(fname)		
				}
				
				
				user_input=user_input.split("State-").join("")
				
				user_input_split=user_input.split(",")
				
				/*
				user_input_noview=''
				for (var u=0;u<user_input_split.length;u++)
				{
					if (user_input_split[u].indexOf("View-")==-1)
						user_input_noview+=user_input_split[u]+","
				}
				user_input_split=user_input_noview.split(",")
				*/

				num_interactions=user_input_split.length-1


				new_sec.find("#interactions"+String(i)).val(user_input_split.join(","));	
				new_sec.find("#numinteractions"+String(i)).text(num_interactions-num_view);
				new_sec.find("#interactions"+String(i)).parent().show()
				new_sec.find("#playback"+String(i)).attr("href", 'playback&json='+json['filename']+"?layout="+String(i));
				
				
				$('#stats').data("times").push(time)
				if ((num_accept>0) || (interfaces[i]=="adaptive"))
				{
					
					if ((!tut))
					{
						$('#stats').data("interactions").push(num_interactions)
						//$('#stats').data("times").push(time)
					}
	
					console.log("user_input:"+String(user_input))
					var suggestions=true;
					
					//if (user_input.indexOf("Baseline")>-1)
					//	suggestions=false;
					//else if (user_input.indexOf("uggestion")>-1)
					
					if (!tut)
					{
						if (adaptive)
						{
							$('#stats').data("adaptiveInteractions").push(num_interactions)
							$('#stats').data("adaptiveTimes").push(time)
						}
						else
						{
							$('#stats').data("suggestionInteractions").push(num_interactions)
							$('#stats').data("suggestionTimes").push(time)			
						}
						
					}
											
				}
				if (interfaces[i]=="baseline")
				{
					$('#stats').data("directInteractions").push(num_interactions)
					$('#stats').data("directTimes").push(time)
				}
				
		}
		else
		{
		
			layout=json["layout"+String(i+1)]
			
			console.log('layout:\n'+layout)
				
			if  (gup('checkImages')!='')
			{
				setCurrentLayout(layout,false);
				
				var canvas=new_sec.find("#design"+String(i))[0]
				
				console.log($('#canvas').find('canvas')[0])
				var destCtx = canvas.getContext('2d');		
				destCtx.drawImage($('#canvas').find('canvas')[0], 0, 0,300,200);
			}
				
			if (layoutIDs!=undefined)
			{
				var fname="/design/static/images/layouts/"+json.design+"-"+json.workerID +"-"+json.hitID+"-"+layoutIDs[i]+".png"
				console.log('fname:'+fname)
				new_sec.find("#img"+String(i)).attr("src",fname)
				new_sec.find("#img"+String(i)).parent().show()
				
				
				fname="/design/static/images/layouts/states/"+json.design+"-"+json.workerID +"-"+json.hitID+"-"+layoutIDs[i]+".png"
				new_sec.find("#stateImg"+String(i)).attr("src",fname)
				new_sec.find("#stateImg"+String(i)).parent().show()
			}
			else
			{
				new_sec.find(".image_row").hide()
				new_sec.find(".canvas_row").show()
			}
		
		}
		

	}
	
	
	user_section.parent().append(new_sec)
	
}
