"use strict";
/*global sendStatToServer:true, sprintf:true, clearSearchInterface:true */

function replaceDesignFont(fontName){
	console.log('replaceDesignFont');
	if (!isLoading()){
		var currentSize = getCurrentSize();

		replaceDesignFontImages(currentSize,fontName);
	}
}

function replaceDesignFontSize(newSize){
	console.log('replaceDesignFontSize');
	if (!isLoading()){
		var currentFont = getCurrentFont();
		console.log(newSize);
		addToUserInputHistory('size+'+String(newSize));
		replaceDesignFontImages(newSize,currentFont);
		
		if (!$('#fontMenu').data('active'))
		{
			var selected=$('#favoriteFontMenu .selectedFont');
			console.log('len of selected: '+String((selected.length))+' '+ selected.parent().data('fontName'));
			selected.parent().data('fontSize',newSize);
		}
	}
	else{
		return false;
	}
}

function isLoading(){
	// use this to retrieve the status of loading
	var isLoadingProgress = $("#studyContainer").data('isLoadingProgress');
	return isLoadingProgress;
}

function setToLoading(){
	// use this to indicate that the interface is loading and no interactivity should be permitted
	//console.log('setToLoading');
	$("#studyContainer").data('isLoadingProgress',true);
}

function setToNotLoading(){
	// use this to indicate that the interface has finished
	// loading and interactivity can be permitted once again.
	$("#studyContainer").data('isLoadingProgress',false);
	evaluateQueuedTasks();
}

function evaluateQueuedTasks(){
	if (isLoading()){
		console.error('Cannot execute task, still loading');
	}
	var queuedTasks = $('#studyContainer').data('queuedTasks');
	if (typeof queuedTasks !== 'undefined'){
		while(queuedTasks.length>0){
			console.log('evaluating queued function');
			queuedTasks.shift()();
		}	
	}
	
}

function evaluateWhenNotLoading(funct){
	if (isLoading()){
		console.log('is loading, queueing up...');
		// queue up for execution
		if (typeof $('#studyContainer').data('queuedTasks') === 'undefined'){
			$('#studyContainer').data('queuedTasks',[]);
		}
		$('#studyContainer').data('queuedTasks').push(funct);
	}
	else{
		console.log('not loading, firing away');
		funct();
	}
}

function getCurrentFont(){
	var data = $('#designContainer').data('fontName');
	if (data === undefined){
		return 'AndaleMono';
	}
	else{
		return data;
	}
}

function updateQueryDataObject(queryObject){
	// this object is used to store the results of the previous query
	// the data is used in updateURLWithQuery
	$('#designContainer').data('queryObject',queryObject);
}

function getQueryDataObject(){
	return $('#designContainer').data('queryObject');
}

function updateURLWithQuery(){
	var queryObject = getQueryDataObject();
	if (typeof queryObject !== 'undefined'){
		var queryString = $.param(queryObject);
		location.hash = queryString;	
	}
}

function getQueryObjectFromHash(){
	var hash = location.hash;
	if (hash.length>0 & hash[0]=='#')
		hash = hash.slice(1);
	var queryObject = $.deparam(hash);
	return queryObject;
}

function setToSearchFromURL(){
	$('#designContainer').data('searchFromURL',true);
}

function setToNaturalSearch(){
	$('#designContainer').data('searchFromURL',false);
}

function isSearchFromURL(){
	// return true if the current search is conducted from URL, not from controls
	var result = $('#designContainer').data('searchFromURL');
	if (typeof result === 'undefined')
		return false;
	return result;
}

function searchIfQueryDataInHash(){
	/*global submitBothForm:true */
	var hash = location.hash;
	console.log(hash);
	if(hash.length > 0){
		console.log('submitting form with hash');
		var queryObject = getQueryObjectFromHash();
		submitBothForm(queryObject);
	}
}

function getCurrentSize(){
	var data = $('#designContainer').data('fontSize');
	if (data === undefined){
		return 0;
	}
	else{
		return data;
	}
}

function imagePreloader(imageURLs,loadedCallback,progress){
	// inputs:
	// imageURLs: a javascript array of urls of images
	// loadedCallback : a callback function for when loading is finished
	// progress: a javascript function for each time a new image has completed loading
	var i,len;
	var images = $();
	
	for(i=0,len = imageURLs.length; i<len ; i++){
		var newElt = $('<img>');
		newElt.attr('src',imageURLs[i]).addClass('hiddenImages');
		images = images.add(newElt);
	}
	$(images).imagesLoaded({callback: loadedCallback, progress: progress});
}

function preloadDesignTextImages(imageURLs, imageContainers){
	setToLoading();
	var startTime = new Date().getTime();
	$('#designTextLoading').text(0);
	$("#loadingTextOverlay").show();
	$("#loadingTextOverlayText").show();
	var callback = function($images,$proper,$broken){
		var i,len;
		if ($broken.length>0){
			packageAndSendWindowError("Image not Loaded",$broken.src,'');
		}
		$("#loadingTextOverlay").hide();
		$("#loadingTextOverlayText").hide();
		var endTime = new Date().getTime();
		var timeTaken = endTime - startTime;
		console.log("Took "+ timeTaken + " ms.");
		var userID = getUserID();
		sendStatToServer("designTextLoadingTime",timeTaken,userID);
		for(i=0,len=imageURLs.length;i<len;i++){
			var imageContainer = $(imageContainers[i]);
			var imageURL = imageURLs[i];
			imageContainer.attr('src',imageURL);
		}
		setToNotLoading();
	};
	var progress= function (isBroken, $images, $proper, $broken) {
		if( isBroken ){
			console.log($broken);
		}
		var loadedLength = $proper.length + $broken.length ;
		var percentage = Math.round((loadedLength * 100 ) / $images.length);
		$('#designTextLoading').text(percentage);
		//console.log('Progress: '+ percentage);
	};
	imagePreloader(imageURLs,callback,progress);
}

function replaceDesignFontImages(fontSize,fontName){
	console.log('replaceDesignFontImages');
	var designContainer = $('#designContainer');
	designContainer.data('fontSize',fontSize);
	designContainer.data('fontName',fontName);
	var imageContainers = $('#designContainer').find('.overlayImage');
	$('input[name=selectedFont]').val(fontName);
	var i,len;
	
	var imageURLs = [];
	for (i=0,len=imageContainers.length;i<len;i++){
		var imageContainer = $(imageContainers[i]);
		var data = imageContainer.data('json');
		var imagePattern  = imageContainer.data('imgURLPattern');
		var imageURL = sprintf(imagePattern,fontSize,fontName);
		imageURLs.push(imageURL);
	}
	preloadDesignTextImages(imageURLs,imageContainers);
	enableRightButtonOnSelection();
	logFontChoice(fontSize,fontName);
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

function addToUserInputHistory(value){
	// add a value to the user design history string.
	if ($('#designContainer').data('userInputHistory') === undefined){
		$('#designContainer').data('userInputHistory',[]);
	}
	$('#designContainer').data('userInputHistory').push([value]);
}

function initializeDesignBox(json,designObject){
	setToLoading();
	console.log('initializeDesignBox');
	$('#designTextLoading').text(0);
	$("#loadingTextOverlay").show();
	$("#loadingTextOverlayText").show();
	var startTime = new Date().getTime();

	var imageURLs = [];
	var i,len;
	var designName = json.name;
	
	var URL = window.location.href;
	
	if (designName.indexOf("training")>-1)
	{
		if (URL.indexOf("Cluster")>-1)
			designName='trainingcluster';
		else if (URL.indexOf("Attribute")>-1)
			designName='trainingattribute';
		else
			designName='training';
	}
	console.log('designName: '+designName);
	
	var background = json.background;
	var URLBase = sprintf('/~libeks/fontQuery/static/studyImages/%s',designName);
	var backgroundURL = sprintf('%s/%s',URLBase,background);
	imageURLs.push(backgroundURL);
	var images = json.images;
	var fixedFontName = designObject.font;
	var fixedFontSize = designObject.fontSize;
	
	if (fixedFontName==undefined)
	{
		$('#designContainer').data('targetFontName','none');
		$('#designContainer').data('targetFontSize',-1);
	}
	else
	{
		$('#designContainer').data('targetFontName',fixedFontName);
		$('#designContainer').data('targetFontSize',fixedFontSize);
	}

	for (i=0,len=images.length;i<len;i++){
		var imageJSON = images[i];
		var imageFixedFont = imageJSON.fixed_font;
		var imageID = imageJSON.id;
		var imgURLPattern = sprintf('%s/text_images/%s-%d-%%d-%%s.png',
				URLBase,designName,imageID);
		var imageURL;
		if (imageFixedFont){
			//apply fixed font to this image
			imageURL = sprintf(imgURLPattern,fixedFontSize,fixedFontName);
		}
		else{
			imageURL = sprintf(imgURLPattern,0,'AndaleMono');
		}
		console.log(imageURL);
		imageURLs.push(imageURL);
		setToNotLoading();
	}
	console.log(images);
	console.log(imageURLs);

	addToUserInputHistory(" "+designName+":");

	var callback = function($images,$proper,$broken){
		if ($broken.length>0){
			packageAndSendWindowError("Image not Loaded",$broken.src,'');
		}
		var endTime = new Date().getTime();
		var timeTaken = endTime - startTime;
		console.log("Took "+ timeTaken + " ms.");
		var userID = getUserID();
		sendStatToServer("designTextAndBackgroundLoadingTime",timeTaken,userID);
		var designContainer = $('#designContainer');
		var imgElement = designContainer.find('.overlayImage:first').detach();
		designContainer.find('.overlayImage').remove();
		var width = json.width;
		var height = json.height;
		designContainer.data('designJSON',json);
		designContainer.data('designName',designName);
		var designBackground = designContainer.find('#designBackground');
		designBackground.attr('src',backgroundURL);
		var i,len;
		for (i=0,len=images.length;i<len;i++){
			var imageJSON = images[i];
			var imageID = imageJSON.id;
			//console.log(imageJSON);
			var imageFixedFont = imageJSON.fixed_font;
			var imgURLPattern;
			//console.log("imageFixedFont: "+imageFixedFont);
			if (imageFixedFont){
				// have to fix the font, so that 
				imgURLPattern = sprintf('%s/text_images/%s-%d-%d-%s.png',
					URLBase,designName,imageID,fixedFontSize,fixedFontName);
			}
			else{
				imgURLPattern = sprintf('%s/text_images/%s-%d-%%d-%%s.png',
					URLBase,designName,imageID);	
			}
			var newImgElt = imgElement.clone();
			newImgElt.data('json',imageJSON);
			newImgElt.data('imgURLPattern',imgURLPattern);
			newImgElt.css('top',imageJSON.location['y-pixel']);
			newImgElt.css('left',imageJSON.location['x-pixel']);
			var imageURL = sprintf(imgURLPattern,0,'AndaleMono');
			newImgElt.attr('src',imageURL);
			newImgElt.insertAfter($('#designBackground'));
		}
		$("#loadingTextOverlay").hide();
		$("#loadingTextOverlayText").hide();
	};
	var progress= function (isBroken, $images, $proper, $broken) {
		if( isBroken ){
			console.log($broken);
		}
		var loadedLength = $proper.length + $broken.length ;
		var percentage = Math.round((loadedLength * 100 ) / $images.length);
		$('#designTextLoading').text(percentage);
		//console.log('Progress: '+ percentage);
	};
	imagePreloader(imageURLs,callback,progress);
}

function downloadAndParseDesignJSON(designObject){
	console.log('downloadAndParseDesignJSON');
	var designName = designObject.design;
	var jqxhr = $.getJSON(
		sprintf('/~libeks/fontQuery/static/studyImages/%s/design.json',designName),
		function(data){
			console.log('design.json obtained');
			initializeDesignBox(data,designObject);
		}
	)
	.done(function(){console.log('success');})
	.fail(function(){console.error('JSON load failure.');});
	console.log(jqxhr);
}

function pressSizeButton(newSize){
	// simulate font size button press. Do this when a favorited item has a size.
	//console.log('pressSizeButton');
	//console.log("getCurrentSize: "+getCurrentSize());
	//console.log('pressSizeButton. New Size: '+newSize);
	if (getCurrentSize() !== newSize){
		//console.log("They are different");
		switch (newSize){
			case 0:
				$('.btn.smallFont').click();
				break;
			case 1:
				$('.btn.mediumFont').click();
				break;
			case 2:
				$('.btn.largeFont').click();
				break;
		}
	}
}

function setupSizeButtons(){
	$('.btn.smallFont').click(function(){return replaceDesignFontSize(0);});
	$('.btn.mediumFont').click(function(){return replaceDesignFontSize(1);});
	$('.btn.largeFont').click(function(){return replaceDesignFontSize(2);});
}

function setupDesignBox(designObject){
	console.log('setupDesignBox');
	console.log('designObject',designObject);
	if (designObject){
		console.log('designObject is something');
		downloadAndParseDesignJSON(designObject);
	}
}

function parseAndStartStudy(studyName){
	$.getJSON(
		sprintf('/~libeks/fontQuery/static/studyImages/HITStudies/%s.json',studyName),
		function(data){
			initializeStudy(data);
		}
	);
}

function getNextPageNumber(){
	if ($('#fontMenu').data('paginationEnabled')){
		var fontPage = $('#fontMenu').data('fontPage');
		var currentPage = fontPage.page;
		var totalPages = fontPage.totalPages;
		if (currentPage+1<totalPages){
			return currentPage+1;
		}
		else{
			return -1;
		}	
	}
	else{
		return -1;
	}
}

function resetPageCounter(){
	$('#fontMenu').data('fontPage').page=-1;
}

function getCurrentSeed(){
	var fontPage = $('#fontMenu').data('fontPage');
	var seed = fontPage.seed;
	//console.log(seed);
	return seed;
}

function initializeStudy(data){
	var designSequence = data.design_sequence;
	var designContainer = $('#designContainer');
	// perform deep copies of input lists
	
	//designContainer.data('designSequence',$.extend(true,[],designSequence));
	//designContainer.data('remainingDesigns',$.extend(true,[],designSequence));
	designContainer.data('designSequence',designSequence);
	designContainer.data('allChosenHistories',[]);
	designContainer.data('finalChoices',[]);
	designContainer.data('targetFonts',[]);
	designContainer.data('designTimes',[]);
	designContainer.data('designStart',0);
	$('#totalNumberOfDesigns').text(designSequence.length);
	$('#currentDesignIndex').text(0);
	$('#designSequence').val(String(designSequence));

	moveToNextDesign();
	setupNextDesignButton();
	disableSubmitButton();
}

function enableRightButtonOnSelection(){
	// when a selection is made, the "Next Design Task" button should be
	// enabled, except on the last design, when the "Submit Results" button
	// should be changed instead.
	
	// we also only allow the button to be enabled once the user had used the
	// interface, to prevent spammers clicking through
	var userInputHistory = String($('#designContainer').data('userInputHistory'));
	var currDesignInput=userInputHistory.substring(userInputHistory.lastIndexOf(':'),userInputHistory.length);
	console.log(userInputHistory);
	console.log(currDesignInput);
	
	var URL = window.location.href;
	var canEnable = false;

	if (URL.indexOf('studyDropdown')>-1){
		// if we are in studyDropdown:
		//console.log('selected fonts: '+$('#fontMenu .selectedFont').length);
		//canEnable = ($('#fontMenu .selectedFont').length>0);
		canEnable = $('#fontMenu').data('hasFontBeenSelected');
	}
	else if (URL.indexOf('studyAttributeDropdown')>-1){
		// if we are in studyAttributeDropdown:
		//console.log('studyAttributeDropdown');
		//canEnable = ($('#sliderContainer .attributeContainer').length>0 && $('#fontQuery .selectedFont').length>0);
		//canEnable = (currDesignInput.indexOf('+')>=0 && (userInputHistory !== undefined));
		canEnable = $('#fontMenu').data('hasInterfaceBeenUsed') && $('#fontMenu').data('hasFontBeenSelected');
		//console.log('canEnable: '+canEnable);
	}
	else if (URL.indexOf('studyClusterDropdown')>-1){
		// if we are in studyClusterDropdown:
		//console.log('cluster interface');
		//canEnable = ($('.centerCluster.selectedFont').length>0);
		canEnable = $('#fontMenu').data('hasInterfaceBeenUsed') && $('#fontMenu').data('hasFontBeenSelected');
		//canEnable = (currDesignInput.indexOf('+')>=0 && (userInputHistory !== undefined));
	}
	else if (URL.indexOf('studyStaticClusterDropdown')>-1){
		canEnable = true;
	}
	else{
		// unknown design
		console.error('unknown interface when trying to activate next design button');
	}
	if (canEnable){
		//console.log('enabling next design button');
		enableNextDesignButton();
	}
	else{
		//console.log('disabling next design button');
		disableNextDesignButton();
	}
}

function enableSubmitButton(){
	$('#submitStudyButton').removeClass('disabled');
	$('#submitStudyButton').addClass('btn-success');
}

function disableSubmitButton(){
	$('#submitStudyButton').addClass('disabled');
	$('#submitStudyButton').removeClass('btn-success');
}


function moveToNextDesign(){
	/*global clearHistory:true */
	console.log('moveToNextDesign');
	$('#fontMenu').data('fontQuery',[]);
	$('#fontMenu').data('hasFontBeenSelected',false);
	$('#fontMenu').data('hasInterfaceBeenUsed',false);
	$('#favoriteFontMenu li').remove();// remove all favorited fonts
	//console.log('submitBothForm in moveToNextDesign');
	//submitBothForm();
	
	setToLoading();
	var startTime = new Date().getTime();
	var designContainer = $('#designContainer');
	
	var designSequence = designContainer.data('designSequence');
	
	var currentDesignName = designContainer.data('designName');
	var currentDesignIndex = parseInt($('#currentDesignIndex').text(),10);
	
	
	//console.log('currentDesignIndex: ',currentDesignIndex);
	if ((currentDesignIndex>=1) && (window.location.href.indexOf('ASSIGNMENT_ID_NOT_AVAILABLE')>-1))
	{
		alert('Warning. HIT has not been accepted. Please accept the HIT before completing the designs. All choices are reset after HIT is accepted.');
	}
	
	if (typeof $('#timerTime').countdown !== 'undefined'){
		var periodsLeft = $('#timerTime').countdown('getTimes');
		if (periodsLeft){
			var secondsLeft = $.countdown.periodsToSeconds(periodsLeft);
			addToUserInputHistory("SecondsLeft+"+secondsLeft);		
		}
	}

	var nRemainingDesigns = designSequence.length-currentDesignIndex;
	console.log('designSequence',designSequence);
	
	var currChoice=currentDesignName+":"+$('#designContainer').data('fontName')+","+$('#designContainer').data('fontSize');
	$('#choice'+currentDesignIndex).val(currChoice);
	
	var currentSize = getCurrentSize();
	if (currentDesignName !== undefined){
		designContainer.data('allChosenHistories').push(
			[
				currentDesignName,
				$.extend(true,[],designContainer.data('chosenHistory'))
			]
		);
		designContainer.data('finalChoices').push(
			[
				currentDesignName,
				$('#designContainer').data('fontSize'),
				$('#designContainer').data('fontName')
			]
		);
		designContainer.data('targetFonts').push(
			[
				currentDesignName,
				$('#designContainer').data('targetFontSize'),
				$('#designContainer').data('targetFontName')
			]
		);
		designContainer.data('designTimes').push(
			[
				currentDesignName,
				designContainer.data('designStart'),
				new Date().getTime()
			]
		);	
	}
	var finalChoices = $.map(
		designContainer.data('finalChoices'),
		function(e){
			return sprintf('design:%s,size:%d,font:%s',e[0],e[1],e[2]);
		}
	).join(';');
	
	console.log('targetFonts: '+designContainer.data('targetFonts'));
	var targetFonts = $.map(
		designContainer.data('targetFonts'),
		function(e){
			return sprintf('design:%s,size:%d,font:%s',e[0],e[1],e[2]);
		}
	).join(';');	
	
	var finalChosenHistories = $.map(
		designContainer.data('allChosenHistories'),
		function (e){
			return sprintf('design:%s,choiceSequence:%s',
				e[0],
				e[1].join(',')
				);
		}
	).join(';');
	var finalTimes = $.map(
		designContainer.data('designTimes'),
		function (e){
			return sprintf('design:%s,%d,%d',e[0],e[1],e[2]);
		}
	).join(';');

	designContainer.data('designStart',new Date().getTime());
	console.log('nRemainingDesigns',nRemainingDesigns);
	console.log('currentDesignIndex',currentDesignIndex);
	if (nRemainingDesigns>0){
		var currentJSON = $('#fontMenu').data('initialJSON');
		console.log('currentJSON',currentJSON);
		if (currentJSON){
			//console.log('currentJSON: '+currentJSON);
			processJSON(currentJSON);
		}
		else
			submitBothForm();
		designContainer.data('chosenHistory',[]);
		setupDesignBox(designSequence[currentDesignIndex]);
		disableNextDesignButton();
		if (nRemainingDesigns==1){
			$('#nextDesignButton').text('Finish Study');
		}
		
		resetDesignCache();
		if (currentDesignIndex>0){
			clearSearchInterface();
		}
		
		designContainer.data('fontSize',currentSize);
		showStartTaskButton();
	}
	else{
		// all designs are finished. setup end results and hide design elements.
		var userInputHistory = designContainer.data('userInputHistory');
		$('#finalChoices').val(finalChoices);
		$('#allChosenHistories').val(finalChosenHistories);
		$('#finalTimes').val(finalTimes);
		$('#targetFonts').val(targetFonts);
		updateWindowDimensionStats();
		$('#userInputHistory').val(userInputHistory);
		userInputHistory = userInputHistory.join(';');
		sendResultsToServer(finalChoices,finalChosenHistories,finalTimes,userInputHistory);
	
		hideInterface();
		enableSubmitButton();	
	}	
	if (getURLParameter('showOutput')=='1')
	{
		var finalOutput='"finalChoices: '+finalChoices+'"\t'+'"targetFonts: '+targetFonts+'"\t'+'"allChosenHistories: '+$('#allChosenHistories').val()+'"\t'+'"finalTimes: '+finalTimes+'"\t'+'"userInputHistory: '+String(designContainer.data('userInputHistory'))+'"\t'+'"studyInterfaceType: '+$('#studyInterfaceType').val()+'"\t';
		$('#finalOutput').val(finalOutput);
		$('#finalOutput').css("display", "block");
	}
	
	var endTime= new Date().getTime();
	$('#nextDesignTime').text(endTime-startTime);
	$('#currentDesignIndex').text(1+currentDesignIndex);
	$('#addFavoriteButton').addClass('disabled');
	clearHistory();
}

function sendResultsToServer(finalChoices,finalChosenHistories,finalTimes,userInputHistory){
	//console.log('sending results to server');
	var userID = getUserID();
	sendStatToServer("finalChoices",finalChoices,userID);
	sendStatToServer("finalChosenHistories",finalChosenHistories,userID);
	sendStatToServer("finalTimes",finalTimes,userID);
	sendStatToServer("userInputHistory",userInputHistory,userID);
	//console.log('results sent');
}

function showStartTaskButton(){
	if (getURLParameter('disableTimer')!=='1'){
		$('#studyContainer').hide();
		$('#startTask').show();	
	}
	else{
		$('#startTask').hide();	
	}
}

function hideStartTaskButton(){
	if (getURLParameter('disableTimer')!=='1'){
		$('#startTask').hide();
		$('#studyContainer').show();
		assignTimer();
	}
}

function assignTimer(){
	$('#timerTime').countdown('destroy');
	var now=new Date();
	var secondsForDesign = 120; //set timer to 3 minutes (180 seconds)
	now.setSeconds(now.getSeconds()+secondsForDesign);
	var callback = function(periods){
		var secondsLeft = $.countdown.periodsToSeconds(periods);
		if (secondsLeft <= 30){ // turn timer RED when less than 30 seconds remain
			$('#timer').addClass('urgentTimer');
		}
		else{
			$('#timer').removeClass('urgentTimer');	
		}
	};
	var finished = function(){
		$('#nextDesignButton').click();
	};
	$('#timerTime').countdown({until:now,format:'MS',onTick:callback,onExpiry:finished});
	return now;
}

function hideInterface(){
	$('#studyContainer').hide();
}

function logFontChoice(fontSize,fontName){
	var designContainer = $('#designContainer');
	designContainer.data('chosenHistory').push([fontSize,fontName]);
}

function resetDesignCache(){
	$('#designContainer').removeData('fontName');
	$('#designContainer').removeData('fontSize');
}

function removeNextDesignButton(){
	$('#nextDesignButton').remove();
}

function setupNextDesignButton(){
	$('#nextDesignButton').click(
		function(){
			if (! $(this).hasClass('disabled')){
				if (! isLoading()){
					moveToNextDesign();
					$('#scrollToHere')[0].scrollIntoView(true);
				}
			}
		}
	);
}

function disableNextDesignButton(){
	$('#nextDesignButton').addClass('disabled');
	$('#nextDesignButton').removeClass('btn-success');
}

function enableNextDesignButton(){
	$('#nextDesignButton').removeClass('disabled');
	$('#nextDesignButton').addClass('btn-success');
}

function enableTimingView(){
	var showTiming = getURLParameter('showTiming');
	if (showTiming=='true')
	{
		$('#timingView').show();
		$('#debugText').show();
	}
}

function setupDesignFromURL(){
	enableTimingView();

	var studyName = getURLParameter('studyName');
	if (studyName !== "") {
		parseAndStartStudy(studyName);
	}
	else{
		var designName = getURLParameter('designName');
		$('#designCountElement').hide();
		setupDesignBox(designName);
	}
}

function getUserID(){
	return $('input[name=fontQueryUserID]').val();
}


function validateDemographicInfo(){
	if ($('select[name="country"]').val() === ""){
		alert('Please select a country');
		return false;
	}
	else if(!parseInt($('input[name="age"]').val(),10)){
		alert('Enter a valid age (in years)');
		return false;
	}
	else if($('input[name="sex"]:checked').val() === undefined){
		alert('Enter your gender.');
		return false;
	}
	else if($('input[name="language"]:checked').val() === undefined){
		alert('Enter your English proficiency.');
		return false;
	}
	else if($('input[name="typexp"]:checked').val() === undefined){
		alert('Enter your familiarity with typography.');
		return false;
	}
	return true;
}

function validateFormResults(){
	var designContainer = $('#designContainer');
	var nDesigns = designContainer.data('designSequence').length;
	
	var nRemainingDesigns = nDesigns - parseInt($('#currentDesignIndex').text(),10);
	var finalChoiceList = designContainer.data('finalChoices');
	//if (nRemainingDesigns === 0 && (finalChoiceList.length === nDesigns)){
	if (nRemainingDesigns < 0 ){
		if (validateDemographicInfo()){
			$('#mturk_form').submit();
		}
		else{
			return false;
		}
	}
	else{
		alert('Study not finished. Please finish.');
		return false;
	}
}

function packageAndSendWindowError(errorMsg,url,lineNumber){
	var error = {'type':errorMsg,'message':url,'stack':lineNumber};
	packageAndSendError(error);
}

function packageAndSendError(error){
	var errorMessage = error. type +";"+ error.message + ";" + error.stack + ";" + navigator.userAgent;
	var userID = getUserID();
	sendStatToServer("clientError",errorMessage,userID);
	$('body').empty();
	$('body').append("There was an error. We apologize for the inconvenience. We are working to fix the issue.");
}

function updateWindowDimensionStats(){
	var width = $(window).width();
	var height = $(window).height();
	var sizeStr = width + 'x' + height;
	$('input[name=windowDimensions]').val(sizeStr);
	var userID = getUserID();
	sendStatToServer("windowSize",sizeStr,userID);
}