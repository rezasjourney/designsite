

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
    return results[1];
}

//
// This method decodes the query parameters that were URL-encoded
//
function decode(strToDecode)
{
  var encoded = strToDecode;
  return unescape(encoded.replace(/\+/g,  " "));
}

function setCurrentLayout(designName, layout)
{
	console.log("setting layout: "+layout);
	var time = new Date().getTime();
	//$('#layout'+imgNum).val(String(time)+','+info);
	
	$('#userLayout').val(layout);
	
	if ($('#userLayout').data('runID')>=0)
	{
		sendLayoutToServer(designName,layout,$('input[name=userID]').val());
	}
}

function setCurrentDesign(designName, design)
{
	console.log("setting design: "+design);
	var time = new Date().getTime();
	
	$('#design').val(design);
	
	
	console.log("run id: "+$('#userLayout').data('runID'));
	if ($('#userLayout').data('runID')>=0)
	{
		$.ajax({
			type:'GET',
			url:'setCurrentDesign',
			error: function (request, status, error) {
				console.error('Failed to send design.');
				console.error(request.responseText);
				console.error(status);
				console.error(error);
			},
			data:{
				runID:$('#userLayout').data('runID'),
				designName:designName,
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
}


function getSuggestedLayout(designName)
{

	if ($('#userLayout').data('runID')>=0)
	{
		getLayoutFromServer(designName,$('input[name=userID]').val());
	}

	return $('#suggLayout').val();
}


function stopSuggestions()
{
		$.ajax({
			type:'GET',
			url:'stopRun',
			error: function (request, status, error) {
				console.error('Failed to send layout.');
				console.error(request.responseText);
				console.error(status);
				console.error(error);
			},
			data:{
				runID:$('#userLayout').data('runID'),
				userID:$('input[name=userID]').val()
				},
			cache: false
		}).done(function(returnVal){
			if (returnVal==='1'){
				console.log('submitted layout');
			}else{
				console.log('error in stopRun');
	
			}
		});

}

function resetParameters()
{

	if ($('#userLayout').data('runID')>=0)
	{
		$.ajax({
			type:'GET',
			url:'resetParameters',
			error: function (request, status, error) {
				console.error('Failed to send layout.');
				console.error(request.responseText);
				console.error(status);
				console.error(error);
			},
			data:{
				runID:$('#userLayout').data('runID'),
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



function getImageTime() 
 {   
	return '9999';
 }  
 
 function getDesignWidth() 
 {   
	return '600';
 }  
 function getDesignHeight() 
 {   
	return '400';
 } 
 
 function getCurrentDesign() 
 {   
	return gup('design');
 }  
 
function startNewRun() 
 {   
 
 	$('#userLayout').data('runID',-1)
	var designName= gup('design');
	console.log("startNewRun for design "+designName)
	
	if ((designName != undefined) && (designName.length>0))
	{
	
		$.ajax({
			type:'GET',
			url:'startNewRun',
			error: function (request, status, error) {
				console.error('Failed to receive layout.');
				console.error(request.responseText);
				console.error(status);
				console.error(error);
			},
			data:{
				designName:designName,
				userID:$('input[name=userID]').val()
				},
			cache: false
		}).done(function(jsonString){
			
			var json = JSON.parse(jsonString);
			$('#userLayout').data('runID',(json.runID))
			 
		});
    }
	
 }  
 
 
 
 function sendLayoutToServer(designName,layout,userID){
    $.ajax({
        type:'GET',
        url:'getLayoutFromClient',
        error: function (request, status, error) {
            console.error('Failed to send layout.');
            console.error(request.responseText);
            console.error(status);
            console.error(error);
        },
        data:{
        	runID:$('#userLayout').data('runID'),
            designName:designName,
            layout:layout,
            userID:userID
            },
        cache: false
    }).done(function(returnVal){
        if (returnVal==='1'){
            console.log('submitted layout');
        }else{
            console.log('error in sendLayoutToServer');
            console.log(returnVal);
        }
    });
}
 
 
 function getLayoutFromServer(designName,userID){
    $.ajax({
        type:'GET',
        url:'sendLayoutToClient',
        error: function (request, status, error) {
            console.error('Failed to receive layout.');
            console.error(request.responseText);
            console.error(status);
            console.error(error);
        },
        data:{
        	runID:$('#userLayout').data('runID'),
            designName:designName,
            userID:userID
            },
        cache: false
    }).done(function(jsonString){
        
        var json = JSON.parse(jsonString);
        
        $('#suggLayout').val(json.layout);
        $('#suggLayoutFeatures').val(json.layoutFeatures);
        $('#userLayoutFeatures').val(json.userLayoutFeatures);
         
    });
}
 
 
 
 
 
