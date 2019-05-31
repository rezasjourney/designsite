//"use strict";

/*var csrftoken = $.cookie('csrftoken');
function csrfSafeMethod(method) {
    // these HTTP methods do not require CSRF protection
    return (/^(GET|HEAD|OPTIONS|TRACE)$/.test(method));
}
$.ajaxSetup({
    crossDomain: false, // obviates need for sameOrigin test
    beforeSend: function(xhr, settings) {
        if (!csrfSafeMethod(settings.type)) {
			//alert(csrftoken);
            xhr.setRequestHeader("X-CSRFToken", csrftoken);
        }
    }
});*/

var errorMessage;
$(document).ready(function(){
	errorMessage = $('#errorMessage').detach();
});


function clearError(){
	//$('#errorMessage').detach();
}

function displayError(message){
	clearError();
	var newErrorMessage = errorMessage.clone();
	$('#errorMessageContainer').append(newErrorMessage);
	$('#errorMessageContent').text(message);
}

// using jQuery
function getCookie(name) {
    var cookieValue = null;
    if (document.cookie && document.cookie !== '') {
        var cookies = document.cookie.split(';');
        for (var i = 0; i < cookies.length; i++) {
            var cookie = jQuery.trim(cookies[i]);
            // Does this cookie string begin with the name we want?
            if (cookie.substring(0, name.length + 1) == (name + '=')) {
                cookieValue = decodeURIComponent(cookie.substring(name.length + 1));
                break;
            }
        }
    }
    return cookieValue;
}
var csrftoken = getCookie('csrftoken');

function csrfSafeMethod(method) {
    // these HTTP methods do not require CSRF protection
    return (/^(GET|HEAD|OPTIONS|TRACE)$/.test(method));
}
function sameOrigin(url) {
    // test that a given url is a same-origin URL
    // url could be relative or scheme relative or absolute
    var host = document.location.host; // host + port
    var protocol = document.location.protocol;
    var sr_origin = '//' + host;
    var origin = protocol + sr_origin;
    // Allow absolute or scheme relative URLs to same origin
    return (url == origin || url.slice(0, origin.length + 1) == origin + '/') ||
        (url == sr_origin || url.slice(0, sr_origin.length + 1) == sr_origin + '/') ||
        // or any other URL that isn't scheme relative or absolute i.e relative.
        !(/^(\/\/|http:|https:).*/.test(url));
}
$.ajaxSetup({
    beforeSend: function(xhr, settings) {
        if (!csrfSafeMethod(settings.type) && sameOrigin(settings.url)) {
            // Send the token to same-origin, relative URLs only.
            // Send the token only if the method warrants CSRF protection
            // Using the CSRFToken value acquired earlier
            xhr.setRequestHeader("X-CSRFToken", csrftoken);
        }
    }
});

function sendStatToServer(statType,statValue,userID){
    $.ajax({
        type:'GET',
        url:'ajaxStatsLogger',
        error: function (request, status, error) {
            //displayError(error+" See console for details. Try refreshing the page and email the author.");
            console.error('Failed to submit stat.');
            console.error(request.responseText);
            console.error(status);
            console.error(error);
        },
        data:{
            statType:statType,
            statValue:statValue,
            userID:userID
            },
        cache: false
    }).done(function(returnVal){
        if (returnVal==='1'){
            //console.log('submitted stat');
        }else{
            console.log('stat submission was weird');
            console.log(returnVal);
        }
    });
}