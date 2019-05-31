"use strict";
/*global getURLParameter:true, imagePreloader:true */

function processStudy(){
	var studyName = getURLParameter('studyName');
	console.log(studyName);
	var jqXHR = $.getJSON('/design/static/json/designABStudies/'+ studyName +'.json',function(data)
		{
			console.log(data);
			$('body').data('studyData',data);
			setupStudyWithData(data);
		}
	)
	.fail(
		function(){
			console.error('study not found');
			verbalFailure('Invalid study name.');
		}
	);
}

function verbalFailure(reason){
	$('#subtaskContainer').empty();
	$('#subtaskContainer').text(reason);
	$('#subtaskContainer').addClass('failure');
	$('#submitButton').remove();
	$('#isFailure').attr('value',reason);
}

function getDesignImageURL(designName){
	return '/design/static/images/layouts/' + designName + '.png';
	// return 'http://www.cs.toronto.edu/~donovan/mturk/images/font_user/' + designName + '.jpg';
	//'http://www.cs.toronto.edu/~donovan/mturk/images/font_user/bday2-2-ElsieBlack-Regular.jpg'
	//return '/design/static/List/'+ designName +'.png';
}

function setupStudyWithData(data){
	var imageFilenames = [];
	var tasks = data.tasks;
	var i;
	// detach template task
	var taskTemplate = $('#subtaskContainer .subtask').detach();
	$('body').data('taskTemplate',taskTemplate);
	$('input[name=hitNumber]').attr('value',data.hitNumber);
	$('input[name=hitCreationTime]').attr('value',data.fileCreated);
	$('input[name=hitBatchNumber]').attr('value',data.hitBatchNumber);

	// get all image URLs, preload them, upon callback, populate subtasks
	for (i=0;i<tasks.length;i++){
		var task = tasks[i];
		console.log(task);
		var designA = task.designA;
		var designB = task.designB;
		imageFilenames.push(getDesignImageURL(designA));
		imageFilenames.push(getDesignImageURL(designB));
	}
	var progress = function($images,$proper,$broken){
	};
	imagePreloader(imageFilenames,populateTasks,progress);
}

function populateTasks($images,$proper,$broken){
	if ($broken.length>0){
		console.error('The following images failed to load:');
		for (var j=0;j<$broken.length;j++){
			console.error($broken[j].src);
		}
		verbalFailure('Some images failed to load. Please reload this page.');
	}
	else{
		var tasks = $('body').data('studyData').tasks;
		var taskContainer = $('#subtaskContainer');
		var i;

		var radioChangeFunction = function(){
			var name = this.name;
			var parent = $(this).parents('.subtask');
			var subtask = parent.find('.subtaskLabel');
			parent.find('.completeString').text('Complete');
			subtask.animate({color:'#329603'},300);
		};

		taskContainer.find('.pleaseWait').detach();
		for (i=0;i<tasks.length;i++){
			var task = tasks[i];
			var taskTemplate = $('body').data('taskTemplate').clone();
			console.log(task);
			console.log(task);
			var designA_URL = getDesignImageURL(task.designA);
			var designB_URL = getDesignImageURL(task.designB);
			taskTemplate.find('img.imageA').attr('src',designA_URL);
			taskTemplate.find('img.imageB').attr('src',designB_URL);
			
			taskTemplate
			var subtaskName = task.designA + '.' + task.designB + '.' + task.taskType + '.' + task.taskID+'.'+task.suggID;
			console.log(subtaskName);
			taskTemplate.find('input:radio.answer').attr('name',subtaskName);
			//taskTemplate.find('input:radio.answer.more').attr('id',subtaskName + '.more');
			//taskTemplate.find('input:radio.answer.less').attr('id',subtaskName + '.less');
			//taskTemplate.find('label.more').attr('for',subtaskName + '.more');
			//taskTemplate.find('label.less').attr('for',subtaskName + '.less');
			taskTemplate.find('.subtaskID').text(i+1);
			taskContainer.append(taskTemplate);
			taskTemplate.find('input:radio.answer').change(radioChangeFunction);
		}
		var startTime = new Date().getTime();
		$('body').data('startTime',startTime);
		$('#submitButton').show();
		$('#submitButton').click(checkSubmission);

	}
}

function getAllCheckedValues() {
	var selectedValue = $("input[name='radio_name']:checked").val();
}

function checkTask(taskName){
	var answer = false;
	var question1 = "input[name='"+taskName+":1']:checked";
	var question2 = "input[name='"+taskName+":2']:checked";
	var answer1 = $(question1).val();
	var answer2 = $(question2).val();
	if (typeof answer1 !== 'undefined'){
		if (answer1.length>0 && answer1=='same'){
			answer = true;
		}
		else if (typeof answer2 !== 'undefined'){
			if (answer2.length>0){
				answer = true;
			}
		}
	}
	if (!(typeof answer1 === 'undefined' || typeof answer2=== 'undefined')){
		if (answer1.length>0 && answer1=='same'){
			answer = true;
		}
		else if (answer1.length>0 && answer2.length>0){
			answer = true;
		}
	}
	return answer;
}

function getTaskNameFromTaskIndex(taskIndex){
	var headerObj;
	var taskName;
	if (taskIndex>0 || taskIndex.length>0){
		headerObj = $('h2[id="task'+taskIndex+'"]');
		if (headerObj.length>0){
			var headerName = headerObj.attr('name');
			taskName = headerName.split('title_')[1];
			return taskName;
		}
		else{
			return "";
		}
	}
	else{
		return "";
	}
}

function submitFormWithAjax(serializedForm){
	console.log('about to submit to server');
	var loadURL = '/design/saveABStudyData';
	$.ajax(
		{
			type:'POST',
			url:loadURL,
			data:{'json':serializedForm},
			error: function (request, status, error) {
				console.error('study not found');
				verbalFailure('Submission failed.');
				console.error(request.responseText);
				console.error(status);
				console.error(error);
			},
			cache: false,
			success: function(data){
				console.log(data);
				console.log('submitting form');
				/*
				if (getURLParameter('hitId') === ''){
					$('#confirmationText').text(data);
					$('.dumbBoxWrap').show();
				}
				else{
					$('#mturk_form').submit();	
				}
				*/
				$('#mturk_form').submit();	
				
			}
		}
	);
}

function checkSubmission(){
	console.log('check submission');
	var taskIndex;
	var incompleteTasks =[];
	var i;
	var tasks = $('.subtask');
	for (i=0;i<tasks.length;i++){
		var task = $(tasks[i]);
		if (task.find('input.answer:checked').length===0){
			var taskID = task.find('.subtaskID').text();
			incompleteTasks.push(taskID);
		}
	}
	if (incompleteTasks.length===0){
		var timeTaken =  new Date().getTime() - $('body').data('startTime');
		$('input[name=timeTaken]').attr('value',timeTaken);
		var features = {};    // Create empty javascript object

		$("form input").each(function() {           // Iterate over inputs
			var ans;
			if ($(this).attr('type')=='radio'){
				if (this.checked){
					features[$(this).attr('name')] = $(this).val();
				}
			}
			else{
				features[$(this).attr('name')] = $(this).val();  // Add each to features object
			}
		
		});
		
		features['hit_comments']=$('#hit_comments').val()

		var serializedForm = JSON.stringify(features);
		console.log(serializedForm);
		submitFormWithAjax(serializedForm);
		return false;
	}
	else{
		alert("These tasks are incomplete: "+incompleteTasks.join(', ')+".");
		return false;
	}
}