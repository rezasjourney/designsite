



function viewABResults(json)
{
	var files=json.files;

	
	var curr_design=''

	var num_files=files.length
	
	var comments=[]
	
	var accept_hits=[]
	var reject_hits=[]
	
	var cnts={}
	
	$.each(files,function(i,f){
		
		var json = JSON.parse(f);
		console.log(json.filename)
		
		check={}
		
		for(var key in json){
			//console.log(key)
			val=json[key]			
			
			if (key.indexOf("consistency")>-1){
				var splt=key.split(".")
				imageA=splt[0]
				imageB=splt[1]	
				sugg=parseInt(splt[4])
				
				if (sugg==0)
					cons_key=imageA+"."+imageB
				else
					cons_key=imageB+"."+imageA
				
				if (!(cons_key in check))
					check[cons_key]=[]
				
				check[cons_key].push(val)				
			}			
		}
		console.log(check)
		
		var inconsistent=0;
		for(var key in check){
			comps=check[key]
			if (comps[0]==comps[1])
				inconsistent+=1
		}
		if (inconsistent>0)
		{
			
			console.log("inconsistent user, removing ")
			if (json.workerId=='A1WEK2YG2TZWJZ')
			{	
				console.log("check user ")
				console.log(json)
			}
			
			reject_hits.push("'"+json.assignmentId+"'")
			return
		}
		accept_hits.push("'"+json.assignmentId+"'")
	
		for(var key in json){
			//console.log(key)
			val=json[key]
			if ((key=='workerId') &&(val=='???'))
				continue
			if ((key=='hit_comments') && (val.length>1))
				comments.push(val)
				
			if (key.indexOf("design")>-1)
			{
				
				var splt=key.split(".")
				imageA=splt[0]
				imageB=splt[1]
				type=splt[2]
				id=splt[3]
				sugg=parseInt(splt[4])
				
				var vote
				if (val=="imageA")
					vote=1
				else if (val=="imageB")
					vote=0
				else
				{	
					console.log("ERROR:"+key+" "+val)
					continue
				}
				
				if (sugg==0)
				{
					cnt_key=imageA+'.'+imageB
				}
				else
				{
					cnt_key=imageB+'.'+imageA
					vote=Math.abs(1-vote)
				}
				
				if (!(cnt_key in cnts))
					cnts[cnt_key]=[]
					
				cnts[cnt_key].push(vote)
			}
		}
	})
	
	
	var totalA=0
	var totalB=0
	var winA=0
	var winB=0
	var ties=0
	var scores=[]
	var scoresRev=[]
	
	
	interfaces={}
	
	ranks={}
	
	
	var c=0
	for(var key in cnts){
	
		comp=cnts[key]
		
		if (comp.length<6)
			continue
		
		splt=key.split(".")
		imageA=splt[0]
		imageB=splt[1]
		
		interfaces[imageA]='Suggestion'
		interfaces[imageB]='Baseline'
		
		var cnt=0
		for (var i=0;i<comp.length;i++)
			cnt+=comp[i]
	
	
		var ab_comparison=$("#ab_comparison")
		
		ab_comparison.hide()
		
		var new_comp=ab_comparison.clone()
		//new_comp.attr("id","ab_comparison"+String(layout_idx))
		new_comp.show()
	
		var fnameA= '/design/static/images/layouts/'+imageA+".png"
		var fnameB= '/design/static/images/layouts/'+imageB+".png"
		new_comp.find("#testNumber").text(c)
		
		new_comp.find("#imageA").attr("src",fnameA)
		new_comp.find("#imageB").attr("src",fnameB)
		

		voteA=cnt
		voteB=comp.length-cnt
		
		totalA+=voteA
		totalB+=voteB
		
		if (voteA-voteB>=2)
			winA+=1
		else if (voteB-voteA>=2)
			winB+=1
		else
			ties+=1
			
		score=(voteA)/(comp.length)
		
		scores.push(score)
		scoresRev.push(1-score)
		
		new_comp.find("#votesA").text(voteA)
		new_comp.find("#votesB").text(voteB)
		
		
		new_comp.find("#rankA").addClass("rk"+imageA)
		new_comp.find("#rankB").addClass("rk"+imageB)
		
		new_comp.find("#scoreA").addClass("sc"+imageA)
		new_comp.find("#scoreB").addClass("sc"+imageB)
		
		new_comp.find("#scoreA").text(sprintf("%.3f",score))
		new_comp.find("#scoreB").text(sprintf("%.3f",1-score))
		
		if (!(imageA in ranks))
			ranks[imageA]=[]
		if (!(imageB in ranks))
			ranks[imageB]=[]	
			
		ranks[imageA].push(score)
		ranks[imageB].push(1-score)
		
		new_comp.find("#interfaceA").text("Suggestion")
		new_comp.find("#interfaceB").text("Baseline")
		
		ab_comparison.parent().append(new_comp)
		c+=1	
	}
	
	rank_list=[]
	for (var img in ranks) {
		
		sc=ranks[img]
		
		rank_list.push([mean(sc),img])
	}
	
	rank_list.sort(function(a, b)
	{
	    return a[0] - b[0];
	});
	
	console.log(rank_list)
	for (var i=0;i< rank_list.length;i++)
	{
		console.log(rank_list[i][0]+" "+rank_list[i][1])
		$('.rk'+rank_list[i][1]).text((rank_list.length-i)+".")
		
		$('.sc'+rank_list[i][1]).text(sprintf("%.3f",rank_list[i][0]))
		
		
		var elem=$('#rank_image').clone()
		
		elem.find('#img').attr("src", '/design/static/images/layouts/'+rank_list[i][1]+".png")
		elem.find('#score').text(sprintf("%.3f",rank_list[i][0]))
		elem.find('#rank').text(rank_list.length-i)
		

		elem.find('#interface').text('int: '+interfaces[rank_list[i][1]])
		
		$('#rank_image').parent().append(elem)
	}

	
	
	$('#numSuggestionVotes').text(totalA)
	$('#numBaselineVotes').text(totalB)
	
	$('#numSuggestionWins').text(winA)
	$('#numBaselineWins').text(winB)	
	$('#numTies').text(ties)	
	
	
	st=getStats(scores)
	$('#suggestionScore').text(sprintf("%.4f %.4f", st[0], st[3]))
	st=getStats(scoresRev)
	$('#baselineScore').text(sprintf("%.4f %.4f", st[0], st[3]))
	
	
	
	$('#reject_hits').html(reject_hits.join(","))
	$('#accept_hits').html(accept_hits.join(","))
	
	$('#user_comments').html(comments.join("<br>"))
	
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


function getStats(l)
{
	
	std=getStandardDeviation(l)
	return [mean(l), std, l.length, 2*std/Math.sqrt(l.length), median(l)]
}


