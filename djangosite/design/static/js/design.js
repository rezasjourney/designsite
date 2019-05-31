String.prototype.replaceAll = function(find, replace) {
	var str = this;
	return str.replace(new RegExp(find, 'g'), replace);
};

if ( typeof (String.prototype.trim) === "undefined") {
	String.prototype.trim = function() {
		return String(this).replace(/^\s+|\s+$/g, '');
	};
}

function isiPhonePad() {
	return ((navigator.platform.indexOf("iPhone") != -1) || (navigator.platform.indexOf("iPod") != -1) || (navigator.userAgent.match(/iPad/i) != null)
	);
}


function cutHex(h) {return (h.charAt(0)=="#") ? h.substring(1,7):h}
function hexToV(h) {
	var r= parseInt((cutHex(h)).substring(0,2),16)
	var g= parseInt((cutHex(h)).substring(2,4),16)
	var b= parseInt((cutHex(h)).substring(4,6),16)
	return (r+g+b)/3.0
}

function setupCanvas() {

	var design = $('#canvas').data("design");
	var images = $('#canvas').data("images");

	$('#canvas').data("sendLayoutToServerTimes", [])

	design.region_proposals = false;

	if ($('#canvas').data("stage") != undefined)
		$('#canvas').data("stage").destroy();

	if ($('#canvas').data("latencyTimes") == undefined)
		$('#canvas').data("latencyTimes",[]);

	$('#canvas').hide(); 

	$('#canvas').data("mousePos", 0)

	$('#canvas').data("dragging", false)

	$('#canvas').data("lastDist", 1);

	$('#canvas').data("show_lock_icons", true);
	$('#canvas').data("show_fixed_opacity", false);

	$('#canvas').data("align_lines", [])

	$('#canvas').data("energy", 9999)
	$('#canvas').data("energy_lists", {})
	$('#canvas').data("plot_energy_list", [])

	$('#canvas').data("layout_stack", [])
	$('#canvas').data("layout_stack_idx", -1)
	
	$('#canvas').data("user_layout_stack", [])
	$('#canvas').data("user_layout_stack_idx", -1)

	if ($('#canvas').data("user_input_log")==undefined)
		$('#canvas').data("user_input_log", [])
	
	if ($('#canvas').data("status_log")==undefined)
		$('#canvas').data("status_log", ['Setup'])
	
	
	if ($('#canvas').data("layout_log")==undefined)
		$('#canvas').data("layout_log", [])

	//$('#canvas').data("paused", false)
	$('#canvas').data('killed', false)
	$('#canvas').data("overlap_mode", false)
	$('#canvas').data("region_mode", false)
	$('#canvas').data("text_mode", false)
	
	$('#canvas').data("suggestion", [])
	$('#canvas').data("previous_suggestions", [])

	if (!("saved_layouts" in design))
		design.saved_layouts = []

	if (!("overlap_regions" in design))
		design.overlap_regions = []

	if (!("regions" in design))
		design.regions = []
		
	if (!("element_alts" in design))
		design.element_alts = {}
		
	if (!("rules" in design)) 
		design.rules=[]
		
	if (!("directory" in design)) 
		design.directory=''
		
		
	$('#design_width').val(design.width)
	$('#design_height').val(design.height)


	var stage = new Kinetic.Stage({
		container : 'canvas',
		width : design.width,
		height : design.height
	});
	var layer = new Kinetic.Layer({
		id : 'layer',
	});
	stage.add(layer);
	
	$('#canvas').data("mousedown",false)
	$(document).mousedown(function(evt){$('#canvas').data("mousedown",true)})
	$(document).mouseup( function(evt){
		//console.log("stage mouseup")
		$('#canvas').data("mousedown",false)
		$('#canvas').data("select_rect").hide()
		$('#canvas').data("select_rect").getLayer().draw()
		$('#canvas').data("select_start", false)	
		})


	var previewRect = new Kinetic.Rect({
		x : 0,
		y : 0,
		width : design.width,
		height : design.height,
		name : 'preview',
		fillPatternImage : images.background
	});
	layer.add(previewRect);
	previewRect.hide();
	$('#canvas').data("preview_image", previewRect);
	$('#canvas').data("preview", -1);

	var col = design.background_color

	if ((col != undefined) && (col.indexOf('#') == -1))
		col = '#' + col;

	if (!("background_elem"  in design))
	{
		back_elem = {}
		back_elem.id = '0';
		back_elem.type = "background";
		back_elem.text = '';
		back_elem.font = 'Garamond';
		back_elem.color = design.background_color;
		back_elem.group_id = 0;
		back_elem.importance = 0;
		back_elem.anchors = [];
		back_elem.loaded = false;
		back_elem.resizing = false;
		back_elem.selected = false;
		back_elem.bold = false;
		back_elem.italic = false;
		back_elem.shadow = false;
		back_elem.align = "center"
		back_elem.x = 0
		back_elem.y = 0
		back_elem.fname=design.background_fname	
	
		
		back_elem.offset_x=0
		back_elem.offset_y=0
		design.background_elem=back_elem
	}
	else
	{
		$('#background_offset_x').val(design.background_elem.offset_x)
		$('#background_offset_y').val(design.background_elem.offset_y)
	}



	var backgroundRect = new Kinetic.Rect({
		x : 0,
		y : 0,
		width : design.width,
		height : design.height,
		fill : col,
		name : 'background',
		stroke : 'Red',
		strokeWidth : 4,
		strokeEnabled: false,
		fillPatternImage : images.background
		//fillPatternOffset: {x:design.background_elem.offset_x, y:design.background_elem.offset_y}
	});
	layer.add(backgroundRect);
	backgroundRect.moveToBottom()

	design.background = backgroundRect;


	console.log('design.background_color:'+design.background_color)
	console.log('design.background_fname:'+design.background_fname)
	
	
	design.background_elem.img = backgroundRect
	

	setupSelectRectangle(design,layer)
	


	$('#canvas').data("selected", design.background_elem)
	setupElementCallbacks(backgroundRect, design.background_elem);

	var sugg_stage = new Kinetic.Stage({
		container : 'suggestion_canvas',
		width : design.width,
		height : design.height
	});

	var sugg_layer = new Kinetic.Layer({
		id : 'sugg_layer',
	});

	var backgroundRect2 = new Kinetic.Rect({
		x : 0,
		y : 0,
		width : design.width,
		height : design.height,
		fill : col,
		fillPatternImage : images.background
	});
	sugg_layer.add(backgroundRect2);
	design.sugg_background = backgroundRect2;

	//console.log("background color: "+design.background_color)

	sugg_stage.add(sugg_layer);

	var overlap_layer = new Kinetic.Layer();
	stage.add(overlap_layer);
	$('#canvas').data("overlap_layer", overlap_layer);

	var region_layer = new Kinetic.Layer();
	stage.add(region_layer);
	$('#canvas').data("region_layer", region_layer);

	$('#canvas').data("stage", stage);
	$('#canvas').data("sugg_stage", sugg_stage);

	console.log("stage:" + stage)

	var max_group_id = 0;
	var max_id = 0;
	$.each(design.elements, function(i, elem) {
		if ("group_id" in elem)
			max_group_id = Math.max(max_group_id, elem.group_id);
		if (("id" in elem))
			max_id = Math.max(max_id, elem.id)
	});


	$('#canvas').data("images_rendering",0)

	$.each(design.elements, function(i, elem) {

		elem.loaded = false;
		elem.resizing = false;
		elem.fixed = false;
		elem.align_type = -1;
		elem.num_lines = 0;
		//elem.num_align=-1;
		elem.selected = false;
		elem.old_text = '';
		if ('orig_text' in elem)
		{
			elem.orig_text=elem.orig_text.trim()
			elem.text=elem.text.trim()
		}
		
		if (elem.color=='black')
			elem.color='000'

		elem.fixed_amount = 0.0;
		if ($('#canvas').data("init_fixed_amount")!=undefined)
			elem.fixed_amount =$('#canvas').data("init_fixed_amount");
			
		elem.hidden_img = 0;
		elem.hidden = false;
		delete elem["img"];
		delete elem["sugg_img"];

		if (!("group_id" in elem)) {
			max_group_id = max_group_id + 1;
			elem.group_id = max_group_id;
		}

		if (!("id" in elem)) {
			max_id = max_id + 1;
			elem.id = max_id;
		}
		
		//if (!("constraints" in elem)) {
			elem.constraints = {'size':[],'alignment':[]}
		//}
		
		if (!("shadow" in elem)) {			
			elem.shadow =false
		}

		if (!("allow_overlap" in elem))
			elem.allow_overlap = false;

		if (!("fix_alignment" in elem))
			elem.fix_alignment = false;

		if (!("fix_alternate" in elem))
			elem.fix_alternate = false;

		if (!("optional" in elem))
			elem.optional = false;

		if (elem.type == 'graphic')
			elem.type_id = 2;
		if (elem.type == 'text')
			elem.type_id = 1;

		if (elem.id in design.element_alts) {
			var alt_id = 0;
			$.each(design.element_alts[elem.id], function(i, e) {
				e.alternate_id = alt_id;
				alt_id += 1;
			});
		}
		
		if ($('#canvas').data("randomizeInit"))	{
			
			$.each(design.elements, function(i, e) {
				var new_height = 0
			
				console.log("num lines:"+e.num_lines)
				if (e.type == 'graphic') {
					new_height = Math.round(Math.random()*100+50)	
				} else if (e.type == 'text') {
					
					if (e.num_lines==0)
						e.num_lines=e.text.split("\n").length
					new_height = Math.round((Math.random()*20+15) * Math.min(e.num_lines,3))
				}
		
				console.log("design height " + design.height + ", e height " + e.height)
		
				e.height = new_height
				e.width = e.height * e.aspect_ratio
		
				var new_x = Math.random() * (design.width - e.width)
				var new_y = Math.random() * (design.height - e.height)
		
				e.x = new_x
				e.y = new_y
			});
			
		}
		
		
		
		//if ($('#canvas').data("suggestionsEnabled"))
		setupLockingCallbacks(elem, layer)

		if ("fname" in elem) {
			elem.alternate_id = 0;
			setupImageElement(elem, images[elem.fname], layer, sugg_layer, false)

			var missing_or = true;
			$.each(design.overlap_regions, function(j, or) {
				if (or.elem_id == elem.id)
					missing_or = false;
			});
			if ((missing_or) && (!elem.allow_overlap)) {
				overlap = {}
				overlap.elem_id = elem.id
				overlap.x_min = 0
				overlap.y_min = 0
				overlap.x_max = 1
				overlap.y_max = 1
				design.overlap_regions.push(overlap)
			}

		} else if (elem.type == 'text') {
			if (elem.color == undefined)
				elem.color = '#000'
			if (elem.color.indexOf('#') == -1)
				elem.color = '#' + elem.color;

			elem.text = elem.text.trim()
			elem.sugg_align = elem.align;
			renderTextAlts(elem, false)
		}

		elem.last_x = elem.x;
		elem.last_y = elem.y;

	});

	window.addEventListener('keydown', keyPressed);

	layer.draw();
	sugg_layer.draw();
	//$('#suggestion_canvas').data("stage",sugg_stage);

	//setTimeout(sendDesign,500);
	//sendCurrentDesign();

	$.each(design.elements, function(i, elem) {

		var found_other = false;
		$.each(design.elements, function(j, elem2) {
			if ((i != j) && (elem.group_id == elem2.group_id))
				found_other = true;
		});
		if (!found_other)
			elem.group_id = -1;
	});

	setupStageCallbacks(stage);

	var curr_layout=getCurrentLayout()
	addLayoutToStack(curr_layout)

	$('#canvas').data("runs", {})


	if ($('#canvas').data("suggestionsEnabled")) {
		startSuggestions()
	}
	//design.elements.sort(function(e1,e2){return e1.importance-e2.importance})


	console.log("text to render: "+$('#canvas').data("images_rendering"))


	if ((design.saved_layouts.length>0) && ($('#canvas').data("sequence_index")==undefined))
	{
		var func = function(){
			renderSavedLayouts(design.saved_layouts,curr_layout)
		}
		executeAfterTextRendering(func)
	}
	else
		$('#canvas').show()

	
	allowUpdates()
	
	$('#canvas').data("started", !($('#canvas').data("automaticUpdate")))

}

function executeAfterTextRendering(func)
{
	var images_remaining = $('#canvas').data("images_rendering")
	if ((images_remaining != undefined) && (images_remaining==0))
	{
		console.log("executing function")
		func()
	}
	else
	{
		setTimeout(function (){
			executeAfterTextRendering(func)			
		},100)
	}
		
	
}



function renderSavedLayouts(layouts,curr_layout)
{
	
	//console.log("rendering saved layouts: "+layouts)
	
	if (layouts.length==0)
	{
		setCurrentLayout(curr_layout)
		$('#canvas').show()
		return
		
	}
		
	if (layouts[0]==null)
	{
		renderSavedLayouts(layouts.slice(1),curr_layout)
		return	
	}
		
		
	console.log("rendering saved layout: "+layouts[0])
	
	setCurrentLayout(layouts[0],true,true)

	
	$('#canvas').data("stage").toDataURL({
			callback : function(data_url) {
				var img = new Image();
	
				img.onload = function() {
														
					var sugg_id = Math.round(Math.random() * 100000)	
					addSavedLayout(img,data_url,layouts[0],sugg_id,false)					
					renderSavedLayouts(layouts.slice(1),curr_layout)
					
				}
				img.src=data_url
			}
	});
	
}


function setupSelectRectangle(design,layer)
{
	
	console.log("setupSelectRectangle\n, background col:"+design.background_color)
	
	$('#canvas').data("invert", false)
	var select_color = 'black'
	var select_opacity = 0.1
	
	var background_val;
	if (design.background_color!=undefined)
	 	background_val=hexToV(design.background_color)
	
	if ((design.background_fname.indexOf("black") > -1) || ((design.background_fname=='') && (background_val<50)))
	{
		console.log('inverting selector')
		$('#canvas').data("invert", true)
		$("#invert_select").prop("checked", true)
		select_color = 'white'
		select_opacity = 0.2
	}


	var select_rect = new Kinetic.Rect({
		x : 0,
		y : 0,
		width : 100,
		height : 100,
		fill : 'blue',
		stroke : select_color,
		opacity : select_opacity,
		strokeWidth : 1,
		visible : false
	});

	layer.add(select_rect);

	$('#canvas').data("select_rect", select_rect)
	$('#canvas').data("select_start", false)
	
	
	
}


function allowUpdates() {
	
	if (!$('#canvas').data("suggestionsEnabled"))
		return

	$('#canvas').data("started", true)
	$('#canvas').data("energy_lists", {})

	if ($('#canvas').data("layoutStartTime") == undefined)
		$('#canvas').data("layoutStartTime", new Date())
		
	$.each($('#canvas').data("runs"), function(i, run) {
		run.converged=false
	});
	
	$('#checkingImage').css("visibility",'visible');
	
	
	var sug_check=$('#canvas').data("suggestion_check");
	if ((sug_check==undefined) || (sug_check==-1))
	{
		console.log("adding checkForSuggestions"+$('#canvas').data("suggestion_check"))
		
		if ($('#canvas').data("automaticUpdate"))
			suggestion_check=setInterval(checkForSuggestions, 100);
		else
			suggestion_check=setInterval(checkForSuggestions, 200);	
		
		$('#canvas').data("suggestion_check",suggestion_check)
	}

}

function setupLockingCallbacks(elem, layer) {

	//console.log("background color:"+$('#canvas').data("design").background_color)

	//var filt=Kinetic.Filters.Invert;
	var filt = 0;

	//if ($('#canvas').data("invert"))
	//	filt=Kinetic.Filters.Invert

	var images = $('#canvas').data("images");

	var size = 15
	if (!$('#canvas').data("suggestionsEnabled"))
		size =0.1
		
	if ($('#canvas').data("playback"))
		size = 15

	elem.unlock_img = new Kinetic.Image({
		x : elem.x + elem.width,
		y : elem.y,
		image : images['unlocked'],
		height : size,
		width : size,
		draggable : false,
		visible : false,
		filter : filt,
		opacity : 0.75
	});

	elem.tweakable_img = new Kinetic.Image({
		x : elem.x + elem.width,
		y : elem.y,
		image : images['tweakable'],
		height : size,
		width : size,
		draggable : false,
		visible : false,
		filter : filt,
		opacity : 0.75
	});

	elem.lock_img = new Kinetic.Image({
		x : elem.x + elem.width,
		y : elem.y,
		image : images['locked'],
		height : size,
		width : size,
		draggable : false,
		visible : false,
		filter : filt,
		opacity : 0.75
	});

	layer.add(elem.unlock_img)
	layer.add(elem.tweakable_img)
	layer.add(elem.lock_img)

	if (elem.fixed_amount<0.5)
		elem.state_img = elem.unlock_img;
	else if (elem.fixed_amount<1)
		elem.state_img = elem.tweakable_img;
	else
		elem.state_img = elem.lock_img;

	elem.unlock_img.on("click tap", function(evt) {
		
		var new_state='locked'
		//if ($('#canvas').data("automaticUpdate"))
		//	new_state='tweakable'
			
		setElementState(elem.id, new_state)
		$('#canvas').data("user_input_log").push("St-"+String(elem.id)+"-"+new_state )
		$('#canvas').data("status_log").push("St-"+String(elem.id)+"-"+new_state )
		sendCurrentLayout('State Change')
		
		allowUpdates()
		
	});
	
	elem.tweakable_img.on("click tap", function(evt) {
		
		setElementState(elem.id, 'locked')
		$('#canvas').data("user_input_log").push("St-"+String(elem.id)+"-locked" )
		$('#canvas').data("status_log").push("St-"+String(elem.id)+"-locked" )
		sendCurrentLayout('State Change')
		
		allowUpdates()
	});
	elem.lock_img.on("click tap", function(evt) {
		
		setElementState(elem.id, 'unlocked')
		$('#canvas').data("user_input_log").push("St-"+String(elem.id)+"-unlocked" )
		$('#canvas').data("status_log").push("St-"+String(elem.id)+"-unlocked" )
		sendCurrentLayout('State Change')
		allowUpdates()
	});

}

function setElementState(elem_id, new_state,fix_amount) {
	$.each($('#canvas').data("design").elements, function(i, elem) {

		if (elem.id == elem_id) {

			var old_state_img = elem.state_img;
			elem.unlock_img.hide()
			elem.tweakable_img.hide()
			elem.lock_img.hide()

			if (new_state == 'unlocked') {
				elem.fix_alignment=false
				elem.state_img = elem.unlock_img
				elem.fixed_amount = 0
			}
			if (new_state == 'tweakable') {
				elem.state_img = elem.tweakable_img
				elem.fixed_amount = 0.5
			}
			if (new_state == 'locked') {
				elem.state_img = elem.lock_img
				elem.fixed_amount = 1
			}
			
			if (fix_amount !=undefined)
				elem.fixed_amount=fix_amount

			console.log("elem " + elem.id + " is " + new_state + " with fixed amount " + elem.fixed_amount)

			elem.state_img.setPosition(old_state_img.getPosition())
			elem.state_img.show()
			elem.state_img.getLayer().draw()
		}

	});


}

function changeElementStates(new_state) {
	$('#canvas').data("user_input_log").push("State-" + new_state)
	$('#canvas').data("status_log").push("State-" + new_state)

	$.each($('#canvas').data("design").elements, function(i, e) {
		if (e.selected) {
			setElementState(e.id, new_state)
		}
	});
	
	sendCurrentLayout('State Change')
	allowUpdates()

}

function designSizeChanged() {

	var design = $('#canvas').data("design")

	var new_width = parseInt($('#design_width').val())
	var new_height = parseInt($('#design_height').val())
	if ((new_width > 0) && (new_height > 0)) {

		console.log("designSizeChanged")


		deselectAll()

		retargetElements(new_height,new_width)
		

		design.width = new_width
		design.height = new_height
		
		$('#canvas').data("stage").setWidth(new_width)
		$('#canvas').data("stage").setHeight(new_height)
		
		
		design.background_elem.img.attrs.width=new_width
		design.background_elem.img.attrs.height=new_height
		
		$('#canvas').data("sugg_stage").attrs.width=new_width
		$('#canvas').data("sugg_stage").attrs.height=new_height
		
		design.sugg_background.attrs.width=new_width
		design.sugg_background.attrs.height=new_height
		
		$('#canvas').data("preview_image").attrs.width=new_width
		$('#canvas').data("preview_image").attrs.height=new_height
		
		design.background_elem.img.getLayer().draw()
		
		
		$.each(design.elements, function(i, elem) {
			setElementState(elem.id, 'unlocked',0.05)
			elem.state_img.hide()
		})
			
		$("#suggestion_layout0").hide()
		$("#suggestion_layout1").hide()
		$("#suggestion_layout2").hide()
			
		$('#suggestion_table').parent().css("height",new_height+30)	
		$('#gallery_table').parent().css("height",new_height+30)
		deleteGallery()
		
		
		if ($('#canvas').data("suggestionsEnabled")) 
			startSuggestions()
		
		allowUpdates()
	}
}


function retargetElements(new_height, new_width)
{
	var design = $('#canvas').data("design")
	var new_diag =Math.sqrt(new_height*new_height + new_width*new_width)
	var curr_diag=Math.sqrt(design.height*design.height + design.width*design.width )
	
	var scale = (new_diag/ curr_diag);
	
	$.each(design.elements, function(i, elem) {

		elem.aspect_ratio=elem.img.getWidth()/elem.img.getHeight()
		var width = elem.height * elem.aspect_ratio
		var mid_x = (elem.x + width / 2) / design.width;
		var mid_y = (elem.y + elem.height / 2) / design.height;

		elem.height = elem.height * scale
		elem.width = elem.height * elem.aspect_ratio

		elem.x = Math.max(0, mid_x * new_width - elem.width / 2);
		elem.y = Math.max(0, mid_y * new_height - elem.height / 2);
		
		//console.log("elem.text: "+elem.text)
		//console.log("element "+elem.id +" exceed by "+(elem.x+elem.width-design.width))
		//console.log("elem.x: "+elem.x)
		
		
		elem.x = elem.x - Math.max(0,(elem.x+elem.width)-new_width)			
		elem.y = elem.y - Math.max(0,(elem.y+elem.height)-new_height)
		
		elem.img.setPosition(elem.x, elem.y)
					
	});
	
}

function setupImageElement(elem, image, layer, sugg_layer, selected) {
	var design = $('#canvas').data("design");

	var scale = 1;
	while (Math.max(image.height * scale, image.height * scale) > Math.max(design.width, design.height) * 0.5) {
		scale = scale * 0.9;
	}

	if (gup('hideContent') != '1') {
		img = new Kinetic.Image({
			x : elem.x,
			y : elem.y,
			image : image,
			height : Math.round(image.height * scale),
			width : Math.round(image.width * scale),
			name : elem.id,
			strokeEnabled : selected,
			stroke : 'Red',
			strokeWidth : 2,
			lineJoin : 'round',
			dashArray : [7, 5],
			name : elem.id,
			draggable : true
		});

		layer.add(img);
		img.moveToBottom()
		img.moveUp()

		elem.img = img;
		elem.aspect_ratio = image.width / image.height;

		elem.img.setHeight(elem.height);
		elem.img.setWidth(elem.height * elem.aspect_ratio);

		//console.log("setting up image with height "+elem.height)

		var img2 = img.clone();
		img2.attrs.strokeEnabled = false;
		sugg_layer.add(img2);
		elem.sugg_img = img2;

		setupElementCallbacks(img, elem);

		elem.anchors = createAnchors(elem, layer, selected)
		moveAnchors(elem)

		elem.loaded = true;
	} else {
		var text = new Kinetic.Text({
			x : 0,
			y : 0,
			text : 'Image',
			fill : 'black',
			height : Math.round(image.height * scale),
			width : Math.round(image.width * scale),
			fontSize : 30,
			fontFamily : 'Calibri',
			align : 'center'
		});

		text.toImage({
			x : 0,
			y : 0,
			width : (text.getWidth()),
			height : (text.getHeight()),
			callback : function(text_img) {

				var add_background = function(pixels) {
					var d = pixels.data;
					for (var i = 0; i < d.length; i += 4) {

						var alpha = (d[i + 3] / 255)

						d[i] += alpha * d[i] + (1 - alpha) * 135;
						d[i + 1] += alpha * d[i + 1] + (1 - alpha) * 206;
						d[i + 2] += alpha * d[i + 2] + (1 - alpha) * 235;
						d[i + 3] = 255;
					}
					return pixels;
				};

				img = new Kinetic.Image({
					x : elem.x,
					y : elem.y,
					image : text_img,
					height : Math.round(image.height * scale),
					width : Math.round(image.width * scale),
					name : elem.id,
					strokeEnabled : selected,
					stroke : 'Red',
					strokeWidth : 2,
					lineJoin : 'round',
					dashArray : [7, 5],
					name : elem.id,
					draggable : true,
					filter : add_background
				});

				layer.add(img);

				elem.img = img;
				elem.aspect_ratio = image.width / image.height;

				elem.img.setHeight(elem.height);
				elem.img.setWidth(elem.height * elem.aspect_ratio);

				//console.log("setting up image with height "+elem.height)

				var img2 = img.clone();
				img2.attrs.strokeEnabled = false;
				sugg_layer.add(img2);
				elem.sugg_img = img2;

				setupElementCallbacks(img, elem);

				elem.anchors = createAnchors(elem, layer, selected)
				moveAnchors(elem)

				elem.loaded = true;

			}
		});
	}

}

function createAnchors(elem, layer, visible) {
	var anchors = {}
	anchors["topLeft"] = createScaleAnchor(0, 0, "topLeft", layer, elem, visible)
	anchors["topRight"] = createScaleAnchor(0, 0, "topRight", layer, elem, visible)
	anchors["bottomLeft"] = createScaleAnchor(0, 0, "bottomLeft", layer, elem, visible)
	anchors["bottomRight"] = createScaleAnchor(0, 0, "bottomRight", layer, elem, visible)

	//
	if ((elem.type == 'text') && ((elem.text.indexOf(" ") > -1) || (elem.text.indexOf("\n") > -1))) {
		anchors["midRight"] = createAspectRatioAnchor(0, 0, "midRight", layer, elem, visible)
		anchors["midLeft"] = createAspectRatioAnchor(0, 0, "midLeft", layer, elem, visible)
	}
	return anchors;

}

function createAspectRatioAnchor(x, y, name, layer, elem, selected) {

	var anchor = new Kinetic.Rect({
		x : x,
		y : y,
		width : 8,
		height : 8,
		fill : 'red',
		opacity : 1,
		name : name,
		draggable : true,
		visible : selected
	});
	anchor.rotate(150)
	layer.add(anchor);

	anchor.on('dragstart', function() {
		elem.anchor_pos = layer.getStage().getPointerPosition()
		$('#canvas').data("user_input_log").push("AR")
		$('#canvas').data("status_log").push("AR")
		console.log("ar dragstart")
	});
	anchor.on('dragmove', function() {

		$('#canvas').data("select_start", false)
		
		//console.log("ar dragmove")

		if ((elem.anchor_pos == 0) || (elem.fix_alternate))
			return;


		

		elem.resizing = true;
		//anchorImageUpdate(this,element);
		//console.log("layer "+anchor.getLayer())

		var alts = $('#canvas').data("design").element_alts[elem.id];

		var next_pos = layer.getStage().getPointerPosition()
		
		var pos_diff=elem.anchor_pos.x - next_pos.x
		//console.log("pos_diff:"+pos_diff)

		var flip = 1;
		if (name == 'midLeft')
			flip = -1;
		if (flip * (pos_diff) > 5) {

			console.log("checking")
			if ((elem.num_lines + 1) in alts) {
				console.log("setting "+(elem.num_lines + 1))
				selectAlternateElement(elem, elem.num_lines + 1)
				elem.anchor_pos = 0;
			}

			moveAnchors(elem)
			layer.draw();
		} else if (flip * (-1*pos_diff) > 5) {

			console.log("checking")
			
			if ((elem.num_lines - 1) in alts) {
				selectAlternateElement(elem, elem.num_lines - 1)
				elem.anchor_pos = 0;
			}

			moveAnchors(elem)
			layer.draw();
		}



	});

	anchor.on('dragend', function() {

		
		elem.resizing = false
		moveAnchors(elem)
		
		drawAlignmentLines(elem, 'dragging')
		layer.draw();
	});

	return anchor;
}

function createScaleAnchor(x, y, name, layer, element, selected) {

	var anchor = new Kinetic.Circle({
		x : x,
		y : y,
		fill : 'red',
		opacity : 1,
		radius : 6,
		name : name,
		draggable : true,
		visible : selected
	});
	layer.add(anchor);

	anchor.on('dragstart', function() {
		$('#canvas').data("user_input_log").push("S")
		$('#canvas').data("status_log").push("S")
	});

	anchor.on('dragmove', function() {

		console.log("dragmove scale")
		$('#canvas').data("select_start", false)
		
		

		element.resizing = true;
		//allowUpdates()

		var shift = anchorImageUpdate(this, element);
		
		
		if ((!$('#canvas').data("suggestionsEnabled")) ||(!$('#canvas').data("automaticUpdate")))
		{
			$.each($('#canvas').data("design").elements, function(i, e) {
				
				
				if (element.constraints['size'].indexOf(e.id)!=-1)
				{
					var new_height=shift.new_height;
					if 	(element.type=='text')
						new_height=(shift.new_height/Math.max(1,element.num_lines))*e.num_lines
					
					console.log("new height: "+new_height)
					e.x=e.img.getX()+shift.x_offset
					e.y=e.img.getY()+shift.y_offset
					
					console.log(e.x)
					
					e.img.setX(e.x)
					e.img.setY(e.y)
					
		
					e.img.setWidth(e.aspect_ratio*new_height)
					e.img.setHeight(new_height)
				
					e.width=e.img.getWidth()
					e.height=e.img.getHeight()	
					
					
					e.state_img.setPosition(e.x + e.width, e.y)
				}
			})
		}
		else
			$('#canvas').data("started",false)
			
		
		
		console.log("shift:")
		console.log(shift)

		drawAlignmentLines(element, name)

		//if ($("#infer_locking_select").prop("checked") && (element.fixed_amount == 0))
		//	setElementState(element.id, 'tweakable')



		//
		layer.draw();

	});

	anchor.on('dragend', function() {

		
		$.each($('#canvas').data("design").elements, function(i, e) {
			if ((e != element)) {
				if ($("#infer_locking_select").prop("checked")) {
					var overlap = getOverlap(e.img, element.img)
					if ((overlap > 0.1) && (e.fixed_amount != 1)&& (!e.allow_overlap)&& (!element.allow_overlap)) {
						
						setElementState(e.id, 'unlocked')
					

						/*
						 if (e.fix_alignment)
						 {
						 e.fix_alignment=false
						 sendCurrentDesign()
						 }
						 */
					}
				}
			}
		});

		element.resizing = false
		

		sendCurrentLayout('Scale')
	});

	return anchor;

}

function anchorImageAspectRatioUpdate(anchor, elem) {
	var anchor_pos = anchor.getAbsolutePosition()
	//console.log("element "+ elem.id+" anchor "+ anchor.attrs.name+" has position: "+anchor_pos.x + " "+ anchor_pos.y )

	var new_height = 1;
	var new_width = 1;
	if (anchor.attrs.name == "topLeft") {
		new_height = elem.anchors["topLeft"].getAbsolutePosition().y - elem.anchors["bottomLeft"].getAbsolutePosition().y
		new_width = elem.anchors["topRight"].getAbsolutePosition().x - elem.anchors["topLeft"].getAbsolutePosition().x
	}
	if (anchor.attrs.name == "bottomLeft") {
		new_height = elem.anchors["topLeft"].getAbsolutePosition().y - elem.anchors["bottomLeft"].getAbsolutePosition().y
		new_width = elem.anchors["bottomRight"].getAbsolutePosition().x - elem.anchors["bottomLeft"].getAbsolutePosition().x
	}
	if (anchor.attrs.name == "bottomRight") {
		new_height = elem.anchors["topRight"].getAbsolutePosition().y - elem.anchors["bottomRight"].getAbsolutePosition().y
		new_width = elem.anchors["bottomRight"].getAbsolutePosition().x - elem.anchors["bottomLeft"].getAbsolutePosition().x
	}
	if (anchor.attrs.name == "topRight") {
		new_height = elem.anchors["topRight"].getAbsolutePosition().y - elem.anchors["bottomRight"].getAbsolutePosition().y
		new_width = elem.anchors["topRight"].getAbsolutePosition().x - elem.anchors["topLeft"].getAbsolutePosition().x
	}

	var aspect_ratio = new_width / new_height;

	var nearest_elem = elem;
	var min_dist = 999;
	$.each($('#canvas').data("design").element_alts[elem.id], function(i, e) {
		var dist = Math.abs(aspect_ratio - e.aspect_ratio)
		if (dist < min_dist) {
			nearest_elem = e
			min_dist = dist
		}
	});

	if (elem != nearest_elem) {
		setAlternate(elem, nearest_elem);


		if (anchor.attrs.name.indexOf("Left") > -1) {
			nearest_elem.img.setX(anchor_pos.x)
		}

		return true
	}
	/*
	new_height=Math.max(new_height,10);
	elem.img.setHeight(new_height)
	elem.height=new_height

	if ("aspect_ratio" in elem)
	elem.img.setWidth(new_height*elem.aspect_ratio)
	else
	{
	new_width=Math.max(new_width,10)
	elem.img.setWidth(new_width)
	elem.width=new_width
	}

	if ((anchor.attrs.name=="topLeft") ||  (anchor.attrs.name=="bottomLeft") )
	{
	var right_pos=elem.anchors["bottomRight"].getAbsolutePosition().x;
	elem.img.setX(right_pos-elem.img.getWidth())
	}
	*/

	//moveAnchors(elem)
}

function setAlternate(elem, alt_elem) {
	console.log("setAlternate for element " + elem.id)

	var layer = $('#canvas').data("stage").get('#layer')[0];

	var design = $('#canvas').data("design")

	var scale = alt_elem.num_lines / elem.num_lines
	console.log("setting alternate text :" + alt_elem.text)

	console.log("orig element selected? " + elem.selected)

	console.log("alternate id :" + alt_elem.alternate_id)

	alt_elem.x = elem.x
	alt_elem.y = elem.y
	alt_elem.height = elem.height * scale
	alt_elem.align_type = elem.align_type
	alt_elem.align = elem.align
	alt_elem.group_id = elem.group_id
	alt_elem.importance = elem.importance
	alt_elem.selected = elem.selected
	alt_elem.fix_alignment = elem.fix_alignment
	alt_elem.fixed_amount = elem.fixed_amount



	//alt_elem.unlock_img=elem.unlock_img
	//alt_elem.tweakable_img=elem.tweakable_img
	//alt_elem.lock_img=elem.lock_img

	alt_elem.optional = elem.optional

	elem.img.remove()
	elem.sugg_img.remove();

	$.each(design.element_alts[elem.id], function(i, e) {
		e.img.remove()
		$.each(e.alignment_imgs, function(j, ai) {
			ai.remove()
		});
		$.each(e.anchors, function(i, a) {
			a.hide()
		});
	});

	if (alt_elem.num_lines > 1) {
		if (alt_elem.img != alt_elem.alignment_imgs[alt_elem.align]) {
			alt_elem.img = alt_elem.alignment_imgs[alt_elem.align];
		}
	}

	alt_elem.img.setPosition(elem.img.attrs.x, elem.img.attrs.y)
	alt_elem.img.attrs.strokeEnabled = elem.selected
	alt_elem.img.setHeight(elem.img.getHeight() * scale)
	alt_elem.img.setWidth(alt_elem.img.getHeight() * alt_elem.aspect_ratio)
	alt_elem.img.setOpacity(1)

	alt_elem.width=alt_elem.img.getWidth()
	alt_elem.height=alt_elem.img.getHeight()

	alt_elem.state_img = elem.state_img
	alt_elem.state_img.setPosition(alt_elem.x + alt_elem.width, alt_elem.y)

	layer.add(alt_elem.img)
	alt_elem.img.show()

	setHidden(alt_elem, elem.hidden)

	
	
	$.each(alt_elem.anchors, function(i, a) {
		//layer.add(a)
		
		a.moveToTop()
		if (elem.selected)
			a.show();
	});
	

	moveAnchors(alt_elem)

	layer.draw()

	var idx = design.elements.indexOf(elem);

	design.elements[idx] = alt_elem;

	if ($('#canvas').data("selected") == elem) {
		console.log("element was selected already")
		$("#num_lines_select").val(alt_elem.num_lines).attr('selected', true);
		$("#user_text").val(alt_elem.text);

		$('#canvas').data("selected", alt_elem)
	}

	if (alt_elem.fixed_amount < 0.5)
		setElementState(alt_elem.id, 'unlocked')
	else if ((alt_elem.fixed_amount >0.1) && (alt_elem.fixed_amount <0.9))
		setElementState(alt_elem.id, 'tweakable')
	else
		setElementState(alt_elem.id, 'locked')
		
	sendCurrentLayout('Aspect Ratio')

}

function anchorImageUpdate(anchor, elem) {
	var anchor_pos = anchor.getAbsolutePosition()
	//console.log("element "+ elem.id+" anchor "+ anchor.attrs.name+" has position: "+anchor_pos.x + " "+ anchor_pos.y )

	var old_x=elem.x
	var old_y=elem.y
	var old_width=elem.width


	console.log(anchor.attrs.name )
	
	
	var new_height = 1;
	var new_width = 1;
	if (anchor.attrs.name == "topLeft") {
		new_height = elem.anchors["topLeft"].getAbsolutePosition().y - elem.anchors["bottomLeft"].getAbsolutePosition().y
		new_width = elem.anchors["topRight"].getAbsolutePosition().x - elem.anchors["topLeft"].getAbsolutePosition().x
		
	}
	if (anchor.attrs.name == "bottomLeft") {
		
		new_height = elem.anchors["topLeft"].getAbsolutePosition().y - elem.anchors["bottomLeft"].getAbsolutePosition().y
		new_width = elem.anchors["bottomRight"].getAbsolutePosition().x - elem.anchors["bottomLeft"].getAbsolutePosition().x
		elem.img.setY(anchor_pos.y)
	}
	if (anchor.attrs.name == "bottomRight") {
		new_height = elem.anchors["topRight"].getAbsolutePosition().y - elem.anchors["bottomRight"].getAbsolutePosition().y
		new_width = elem.anchors["bottomRight"].getAbsolutePosition().x - elem.anchors["bottomLeft"].getAbsolutePosition().x
		elem.img.setY(anchor_pos.y)
	}
	if (anchor.attrs.name == "topRight") {
		new_height = elem.anchors["topRight"].getAbsolutePosition().y - elem.anchors["bottomRight"].getAbsolutePosition().y
		new_width = elem.anchors["topRight"].getAbsolutePosition().x - elem.anchors["topLeft"].getAbsolutePosition().x
	}

	var right_pos = elem.anchors["bottomRight"].getAbsolutePosition().x;

	new_height = Math.max(new_height, 10);
	elem.img.setHeight(new_height)
	elem.height = new_height

	if ("aspect_ratio" in elem)
		elem.img.setWidth(new_height * elem.aspect_ratio)
	else {
		new_width = Math.max(new_width, 10)
		elem.img.setWidth(new_width)
		elem.width = new_width
	}

	if ((anchor.attrs.name == "topLeft") || (anchor.attrs.name == "bottomLeft")) {
		
		elem.img.setX(right_pos - elem.img.getWidth())
	}
	elem.x = elem.img.attrs.x
	elem.y = elem.img.attrs.y
	elem.width = elem.img.getWidth()
	elem.height = elem.img.getHeight()

	elem.state_img.setPosition(elem.x + elem.width, elem.y)

	moveAnchors(elem)
	

	var shift={}
	shift.x_offset=elem.x-old_x
	shift.y_offset=elem.y-old_y
	shift.new_height=elem.height
	
	if (elem.type=='text')
		 $("#fontSizeInput").val((elem.height/elem.init_height)*elem.init_font_size)
		 
	return shift
}

function keyPressed(evt) {
	console.log("Key pressed: " + evt.keyCode)

	var input_focused = $("*:focus").length > 0;

	if (input_focused)
	{
		console.log("input focused")
		return;
	}

	if (evt.keyCode == 49)
		saveCurrentLayout()

	if (evt.keyCode == 67) {
		if ($('#canvas').data("overlap_mode")) {
			$('#canvas').data("design").overlap_regions = [];
			toggleOverlapMode();
			toggleOverlapMode();
			sendCurrentDesign();

		}
	}

	if (evt.keyCode == 65 && evt.shiftKey)
		selectAllElements()

	if (evt.keyCode == 189 && evt.shiftKey)
		scaleCurrentElement(0.9)
	if (evt.keyCode == 187 && evt.shiftKey)
		scaleCurrentElement(1.1)

	//if ((evt.keyCode == 68) || (evt.keyCode == 46))
	//	deleteCurrentElement()

	//if (evt.keyCode == 80)
	//	toggleOverlapMode()

	//if (evt.keyCode == 82)
	//	toggleRegionMode()

	/*
	if (evt.keyCode == 32) {
		switchPauseState();
		evt.preventDefault();
	}

	 if (evt.keyCode==70)
	 {
	 $.each($('#canvas').data("design").elements, function(i, elem){

	 if (elem.selected)
	 {
	 if (elem.fixed_amount<1)
	 elem.fixed_amount=1
	 else
	 elem.fixed_amount=0.25

	 //setStroke(elem.img,true, 1.5,elem.fixed_amount );
	 //elem.img.attrs.opacity=elem.fixed_amount
	 }

	 });
	 $('#canvas').data("design").elements[0].img.getLayer().draw();
	 sendCurrentLayout();

	 }
	 */
}

function toggleRegionMode() {
	var stage = $('#canvas').data("stage");
	var design = $('#canvas').data("design");
	var region_layer = $('#canvas').data("region_layer");

	var layer = stage.get('#layer')[0];

	if ($('#canvas').data("region_mode")) {
		//layer.show();
		console.log("disabling region mode")
		region_layer.removeChildren();
		region_layer.draw()

		$('#canvas').data("region_mode", false)
		$('#region_controls').hide()
	} else {
		console.log("enabling region mode")

		deselectAll(design.background_elem)
		design.background_elem.img.getLayer().draw();

		var backgroundRect = new Kinetic.Rect({
			x : 0,
			y : 0,
			fill : 'black',
			opacity : 0.25,
			width : design.width,
			height : design.height
		});

		region_layer.add(backgroundRect)
		backgroundRect.moveToTop()

		$.each(design.regions, function(i, reg) {
			var fill_color = getRegionColor(reg)

			var rect = new Kinetic.Rect({
				x : reg.x,
				y : reg.y,
				fill : fill_color,
				opacity : 0.25,
				width : reg.width,
				height : reg.height,
				draggable : true,
				stroke : 'Red',
				strokeWidth : 2,
				lineJoin : 'round',
				dashArray : [7, 5],
				strokeEnabled : false
			});
			reg.img = rect
			region_layer.add(rect)

			reg.anchors = createAnchors(reg, region_layer, false)
			moveAnchors(reg)
			setupElementCallbacks(rect, reg)

		});

		region_layer.draw()

		$('#canvas').data("region_mode", true)

		$('#region_controls').show()
		hideBackgroundControls()
		$('#element_controls').hide()

	}
}

function getRegionColor(reg) {
	if (reg.allow_text && (!reg.allow_graphic))
		return '#5F5'
	else if (reg.allow_graphic && (!reg.allow_text))
		return '#55F'
	else if (reg.allow_graphic && (reg.allow_text))
		return '#5FF'
	else
		return 'white'
}

function toggleOverlapMode() {
	var stage = $('#canvas').data("stage");
	var design = $('#canvas').data("design");
	var overlap_layer = $('#canvas').data("overlap_layer");

	var layer = stage.get('#layer')[0];

	if ($('#canvas').data("overlap_mode")) {
		//layer.show();
		console.log("disabling overlap mode")
		overlap_layer.removeChildren();
		overlap_layer.draw()

		$('#canvas').data("overlap_mode", false)
	} else {
		//layer.hide();
		console.log("enabling overlap mode")

		var backgroundRect = new Kinetic.Rect({
			x : 0,
			y : 0,
			fill : 'black',
			opacity : 0.25,
			width : design.width,
			height : design.height
		});

		overlap_layer.add(backgroundRect)
		backgroundRect.moveToTop()

		//var elem_list=design.elements
		//elem_list.push(design.back_elem)

		$.each(design.elements, function(i, elem) {
			var x = elem.x
			var y = elem.y
			var w = elem.img.getWidth()
			var h = elem.img.getHeight()

			var draw_overlap = false;
			if (elem.type == 'text')
				draw_overlap = true
			else
				$.each(design.overlap_regions, function(i, or) {
					if (or.elem_id == elem.id) {
						draw_overlap = true;
						x = x + w * or.x_min;
						y = y + h * or.y_min;
						w = w * (or.x_max - or.x_min);
						h = h * (or.y_max - or.y_min);
					}
				});
			if (draw_overlap) {
				var rect = new Kinetic.Rect({
					x : x,
					y : y,
					fill : 'white',
					opacity : 0.25,
					width : w,
					height : h
				});
				overlap_layer.add(rect)
			}

		});

		for (var i = 0; i < design.overlap_regions.length; i++) {
			var or = design.overlap_regions[i]
			console.log("or.elem_id " + or.elem_id)
			if (or.elem_id == 0) {
				var rect = new Kinetic.Rect({
					x : or.x_min * design.width,
					y : or.y_min * design.height,
					fill : 'white',
					opacity : 0.25,
					width : design.width * (or.x_max - or.x_min),
					height : design.height * (or.y_max - or.y_min)
				});
				overlap_layer.add(rect)
				console.log("adding rectangle " + rect.attrs.x + " " + rect.attrs.y + " ")
			}
		}

		overlap_layer.draw()

		overlap_layer.on("mousedown", function(evt) {

			console.log("mouse down")
			var mousePos = stage.getPointerPosition();
			var overlapRect = new Kinetic.Rect({
				x : mousePos.x,
				y : mousePos.y,
				fill : 'white',
				opacity : 0.25,
				width : 0,
				height : 0,
				id : "current_overlap"
			});
			overlap_layer.add(overlapRect)
			overlap_layer.draw()
			$('#canvas').data("mousePos", mousePos)

			console.log("down")
			console.log($('#canvas').data("mousePos"))
		});

		overlap_layer.on("mousemove", function() {
			var mousePos0 = $('#canvas').data("mousePos")

			if (mousePos0 == 0)
				return;
			var mousePos = stage.getPointerPosition();

			var overlapRect = stage.get('#current_overlap')[0];
			//if (overlapRect!=undefined)
			//{

			if (mousePos.y < mousePos0.y)
				overlapRect.setY(mousePos.y)

			if (mousePos.x < mousePos0.x)
				overlapRect.setX(mousePos.x)

			overlapRect.setHeight(Math.abs(mousePos.y - mousePos0.y))
			overlapRect.setWidth(Math.abs(mousePos.x - mousePos0.x))

			//console.log(overlapRect.getWidth()+" "+overlapRect.getHeight())
			//overlap_layer.draw()
			//}

		});

		overlap_layer.on("mouseup", function() {
			console.log("mouse up (overlap)")

			if (($('#canvas').data("mousePos") == 0))
				return;

			$('#canvas').data("mousePos", 0)

			console.log($('#canvas').data("mousePos"))

			var overlapRect = stage.get('#current_overlap')[0];
			//var elem=findElement(overlapRect.attrs.x,overlapRect.attrs.y,overlapRect.getWidth(),overlapRect.getHeight())
			var elem = design.background_elem;
			overlap = {}
			overlap.elem_id = elem.id
			console.log("Creating new OR with elem id " + elem.id)

			overlap.x_min = (overlapRect.attrs.x - elem.x) / elem.img.getWidth()
			overlap.y_min = (overlapRect.attrs.y - elem.y) / elem.img.getHeight()

			overlap.x_max = overlap.x_min + overlapRect.getWidth() / elem.img.getWidth()
			overlap.y_max = overlap.y_min + overlapRect.getHeight() / elem.img.getHeight()

			if ((overlap.x_max - overlap.x_min > 0.01) && (overlap.y_max - overlap.y_min > 0.01)) {
				console.log("")
				design.overlap_regions.push(overlap)
				overlap_layer.draw()
				sendCurrentDesign()
			}
		});

		$('#canvas').data("overlap_mode", true)
	}
}

function selectAllElements() {
	console.log("select all")
	var elements = $('#canvas').data("design").elements;
	$.each(elements, function(i, e) {
		e.img.attrs.strokeEnabled = true;
		$.each(e.anchors, function(i, a) {
			a.hide();
		});
		e.selected = true;
	});
	elements[0].img.getLayer().draw();
}

/*
function switchPauseState() {
	if ($('#canvas').data("paused") == false)
		pauseSuggestions()
	else
		resumeSuggestions()
}

function pauseSuggestions() {
	//$('#pauseButton').text("Resume")
	//$('#pauseButton').removeClass("btn-warning")
	//$('#pauseButton').addClass("btn-success")
	$('#pauseButton').hide()
	$('#startButton').show()
	$('#canvas').data("paused", true)

}
*/

function resumeSuggestions() {

	if (!$('#canvas').data("suggestionsEnabled"))
		return

	if ($('#canvas').data("design").elements.length <= 1) {
		console.log("not enough elements to start suggestions")
		//return
	}
	if (($('#suggestion_status').text() == "Inactive"))
		startSuggestions()

	$('#canvas').data("status_log").push("Resume")

	sendCurrentLayout('Resume')

	/*
	$('#pauseButton').show()
	$('#startButton').hide()
	$('#canvas').data("paused", false)
	*/

}

function deleteCurrentElement() {


	
	$('#element_controls').hide()
	document.body.style.cursor = "default";
	$('#canvas').data("text_mode", false)

	$('#canvas').data("user_input_log").push("Remove")
	$('#canvas').data("status_log").push("Remove")


	var layer = $('#canvas').data("stage").get('#layer')[0];
	var sugg_layer = $('#canvas').data("sugg_stage").get('#sugg_layer')[0];

	var elements;

	if ($('#canvas').data("region_mode"))
		elements = $('#canvas').data("design").regions
	else
		elements = $('#canvas').data("design").elements

	if ($('#canvas').data("selected").type == 'background')
		return;

	var rem = elements.indexOf($('#canvas').data("selected"));

	console.log("removing element " + rem)
	elements[rem].img.destroy();
	if ("sugg_img" in elements[rem]) {
		elements[rem].sugg_img.destroy();
	}
	console.log(elements)

	$.each(elements[rem].anchors, function(i, a) {
		a.destroy();
	});

	elements[rem].lock_img.destroy()
	elements[rem].unlock_img.destroy()
	elements[rem].tweakable_img.destroy()

	$.each($('#canvas').data("align_lines"), function(i, al) {
		al[0].destroy()
	});
	$('#canvas').data("align_lines", [])

	elements.splice(rem, 1);
	sendCurrentDesign();
	sendCurrentLayout('Delete');

	layer.draw()
	sugg_layer.draw()

	$('#canvas').data("selected", $('#canvas').data("design").background_elem)
	
	deleteGallery()


}

function scaleCurrentElement(scale_factor) {
	var elem = $('#canvas').data("selected");

	if ((elem != undefined) && (elem.type != "background")) {

		var curr_height = elem.img.getHeight()
		var new_height = Math.max(curr_height * scale_factor, 5);
		elem.height = new_height;
		elem.img.setHeight(new_height)

		if (elem.type == 'region') {
			elem.img.setWidth(elem.img.getWidth() * scale_factor)
			elem.width = elem.img.getWidth();
		} else
			elem.img.setWidth(new_height * elem.aspect_ratio)

		elem.width = elem.img.getWidth();

		moveAnchors(elem)
		elem.img.getLayer().draw()
	}
}

/*
 function setCurrentSuggestion(evt)
 {

 setCurrentLayout($('#suggestion_canvas').data("layout"))
 elements[0].img.getLayer().draw();

 }
 */

function copyCurrentDesign() {
	var design = $('#canvas').data("design");

	var design_copy = jQuery.extend(true, {}, design);

	//$.each(design_copy, function (i, elem){

	//});

	return design_copy;
}


function addSavedLayout(img,data_url,curr_layout,sugg_id,save_to_server){
	console.log("addSavedLayout")

	




	var new_layout_elem = $('#saved_layout0').clone()
	new_layout_elem.data("preview_image", img);
	new_layout_elem.data("layout", curr_layout);
	new_layout_elem.data("time", new Date());
	new_layout_elem.data("sugg_id", sugg_id);

	new_layout_elem.attr("id", "saved_layout" + sugg_id)
	new_layout_elem.mouseover(function() {
		viewLayout('saved', sugg_id)
	})
	new_layout_elem.click(function() {
		setFixedLayout('saved', sugg_id)
	})
	//new_layout_elem.dblclick(function() {setFixedLayout('saved',count)})

	var stage = $('#canvas').data("stage");
	var canvas = new_layout_elem[0];
	var ctx = canvas.getContext("2d")
	ctx.drawImage(img, 0, 0, stage.attrs.width / 3, stage.attrs.height / 3);

	var remove_layout_elem = $('#remove_saved_layout0').clone()
	remove_layout_elem.click(function() {
		removeSavedLayout(sugg_id)
	})
	

	
	$('#saved_table').append($('<tr>').append($('<td>').append(new_layout_elem), $('<td>').append(remove_layout_elem)))
	
	
	if (save_to_server)
	{
		var hit_id = gup('hitId')
		var fname = 'layouts/' + $('#canvas').data("design").name + '-' + gup('workerId') + "-" + hit_id + "-" + String(sugg_id) + '.png'
		saveImageOnServer(fname, data_url)
	}
	
	
	
	var retarget=gup('retarget')
	if (retarget!='')
	{
		var splt=retarget.split("_")
		var new_width=parseInt(splt[0])
		var new_height=parseInt(splt[1])		
		retargetElements(new_height,new_width)	
		var retarget_layout	=getCurrentLayout()
		
		setCurrentLayout(curr_layout)
		
		new_layout_elem.data("retarget_layout", retarget_layout);
		
		console.log("retarget_layout:"+retarget_layout)
	}
	
	
	
	
}





function saveCurrentLayout() {
	var stage = $('#canvas').data("stage");
	var curr_layout = getCurrentLayout()
	
	
	$('#saved_text').show()
	$('#gallery_text').hide()
	
	$('#saved_lk').click()
	$('#showGalleryButton').show()
	

	var num_saved = $('#saved_table').find("tr").length - 1;
	var max_saved = 100;
	if (gup("maxSaved") != undefined)
		max_saved = parseInt(gup("maxSaved"))

	if (num_saved >= max_saved) {
		alert("You have reached the maximum number of saved layouts: " + max_saved + ". Remove other layouts before saving.")
		return;
	}

	$('#canvas').data("user_input_log").push("Save")
	$('#canvas').data("status_log").push("Save")


	$.each($('#canvas').data("design").elements, function(i, e) {
		e.state_img.show()
	});


	

	
	stage.toDataURL({
		
      callback: function(data_url2) {
      	
      	var sugg_id = Math.round(Math.random() * 100000)
      	
      	
      	console.log("rendering first time")
		var fname='layouts/states/'+$('#canvas').data("design").name+'-'+gup('workerId')+"-"+gup('hitId')+"-"+String(sugg_id)
		saveDesignOnServer(data_url2,'',fname)
		
		$.each($('#canvas').data("design").elements, function(i, e) {
			e.img.attrs.strokeEnabled = false;
			e.state_img.hide()
			$.each(e.anchors, function(i, a) {
				a.hide();
			});
		});
	
		$.each($('#canvas').data("align_lines"), function(i, al) {
			al[0].hide()
		});		
		

		stage.toDataURL({
			callback : function(data_url) {
				var img = new Image();
	
				img.onload = function() {
					
					console.log("rendering second time")
					//$('#canvas').data("saved_images").push(img);
					//$('#canvas').data("saved_layouts").push(curr_layout);
					//$('#canvas').data("saved_designs").push(copyCurrentDesign());
	
					//var count = $("#saved_table").children().children().length;
	
					//$("#saved_row").parent().css("padding",1)
	
					addSavedLayout(img,data_url,curr_layout,sugg_id,true)
	
					/*
					 for (var i=0;i < Math.min(saved_layouts.length,9);i++)
					 {
	
					 $('#saved_layout'+i).data("preview_image",saved_images[i]);
					 $('#saved_layout'+i).data("layout",saved_layouts[i]);
					 var canvas=$('#saved_layout'+i)[0];
					 var ctx=canvas.getContext("2d")
					 ctx.drawImage(saved_images[i],0,0,stage.attrs.width/3,stage.attrs.height/3);
	
					 }
					 */
	
					$.each($('#canvas').data("design").elements, function(i, e) {
						if (e.selected) {
							e.img.attrs.strokeEnabled = true;
							e.state_img.show()
							$.each(e.anchors, function(i, a) {
								a.show();
							});
						}
					});
					$.each($('#canvas').data("align_lines"), function(i, al) {
						al[0].show()
					});
					
					//resetLayout() 
	
				}
				img.src = data_url;
	
			}
		});
		
          
      }
    });
	
	
	
}

function removeSavedLayout(id) {
	console.log("id to remove:" + id)
	$("#saved_layout" + id).parent().parent().remove()
	$('#canvas').data("user_input_log").push("Rm Layout")
	$('#canvas').data("status_log").push("Rm Layout")
}

function saveDesign() {
	
	console.log("saveDesign")
	var stage = $('#canvas').data("stage");
	var design = $('#canvas').data("design");

	$.each(design.elements, function(i, e) {
		e.img.attrs.strokeEnabled = false;
		e.state_img.hide()
		$.each(e.anchors, function(i, a) {
			a.hide();
		});
	});

	$.each($('#canvas').data("align_lines"), function(i, al) {
		al[0].hide()
	});

	console.log("height " + design.elements[0].height)
	
	
	
	var saved_canvases = $("#saved_table").find("canvas")
	console.log("saved_canvases.length:" + saved_canvases.length)


	design.saved_layouts=[]
	$.each(saved_canvases, function(i, saved_img) {
		design.saved_layouts.push($(saved_img).data("layout"))
	});
	
	

	stage.toDataURL({
		callback : function(data_url) {

			saveDesignOnServer(data_url, design)

			$.each(design.elements, function(i, e) {
				if (e.selected) {
					e.img.attrs.strokeEnabled = true;
					e.state_img.show()
					$.each(e.anchors, function(i, a) {
						a.show();
					});
				}
			});
			$.each($('#canvas').data("align_lines"), function(i, al) {
				al[0].show()
			});

		}
	});
}

function setFixedLayout(layout_type, layout_num) {

	viewLayout('interactive', -1);

	deselectAll()
	console.log("setting " + layout_type + " layout: " + layout_num)
	//setCurrentLayout($('#canvas').data("saved_layouts")[i],true)
	
	setCurrentLayout($('#' + layout_type + '_layout' + layout_num).data("layout"), true);
	//pauseSuggestions();
	sendCurrentLayout('set-'+layout_type);


	$.each($('#canvas').data("design").elements, function(i,e){
		
		if (e.selected)
			console.log("ERROR: element "+i+" is selected")
	})

	$('#canvas').data("user_input_log").push("Load-" + layout_type+"-"+layout_num)
	$('#canvas').data("status_log").push("Load-" + layout_type+"-"+layout_num)

	if (layout_type=='gallery')
		removeAllConstraints()
	//if (!$('#canvas').data("noSuggestions"))
	//	$('#suggestion_lk').click()

	if ($('#canvas').data("overlap_mode")) {
		toggleOverlapMode();
		toggleOverlapMode();
	}

	if ($('#canvas').data("region_mode")) {
		toggleRegionMode();
		toggleRegionMode();
	}

}


function resetLayout(reset_canvas) {

	if (reset_canvas==undefined)
		reset_canvas=true

	
	deselectAll()

	var design = $('#canvas').data("design");

	var run_offset = $('#canvas').data("run_offset");
	if (run_offset == undefined)
		run_offset = 0;

	run_offset = 0;
	$('#canvas').data("run_offset", run_offset)

	$('#canvas').data("user_input_log").push("Reset")
	$('#canvas').data("status_log").push("Reset")

	var curr_layout = getCurrentLayout()

	removeAllConstraints();

	//$.each($('#canvas').data("design").elements,function (i,e){e.fixed_amount=0.01})
	//return

	$.each(design.elements, function(i, e) {

	
		var new_height = 0
		

		if (e.type == 'graphic') {
			new_height = Math.round(Math.random()*50+50)

		} else if (e.type == 'text') {
			
			if (e.num_lines<=3)
			{
				var num_lines=Math.round(Math.random()*2+1)
				console.log(num_lines)
				selectAlternateElement(e,num_lines)
				
			}
			new_height = Math.round((Math.random()*10+10) * e.num_lines)
		}

		console.log("design height " + design.height + ", e height " + e.height)

		e.height = new_height
		e.width = e.height * e.aspect_ratio

		var new_x = Math.random() * (design.width - e.width)
		var new_y = Math.random() * (design.height - e.height)

		e.x = new_x
		e.y = new_y
		e.last_x = new_x
		e.last_y = new_y

		e.img.setPosition(new_x, new_y)
		e.img.setWidth(e.width)
		e.img.setHeight(e.height)

				
		e.state_img.setPosition(e.x + e.width, e.y)
		e.state_img.hide()

	});


	
	sendCurrentLayout('Reset',true)

	if (reset_canvas)
	{
		addLayoutToStack(getCurrentLayout())

	}
	else
	{
		setCurrentLayout(curr_layout)
	}


	design.elements[0].img.getLayer().draw()

	

	$('#canvas').data("energy_lists", {})
	$('#checkingImage').css("visibility","hidden");
	$('#canvas').data("started", true)

	//stopSuggestions()
	allowUpdates()
	//startSuggestions(run_offset)


}




function resetRuns() {
	
	//console.log("reset run "+run_id);
	deselectAll()
	
	
	
	
	var design = $('#canvas').data("design");
	
	
	$.each(design.elements, function(i, e) {
		setElementState(e.id, 'unlocked')
	})
	

	var curr_layout = getCurrentLayout()
	
	
	$('#canvas').data("layout_log").push(['user-More Designs',new Date().getTime(),curr_layout,";"])
	$('#canvas').data("user_input_log").push("More Designs")
	$('#canvas').data("status_log").push("More Designs")
	
	$.each($('#canvas').data("runs"), function(i, run) {
			if (run.id > -1) {
				run.converged=false
				
				console.log("reset run: "+run.id)
				
				$.each(design.elements, function(i, e) {
			
					var new_height = 0
			
					if (e.type == 'graphic') {
			
						new_height = Math.round(Math.random()*100+50)
			
					} else if (e.type == 'text') {
						
						//if (e.num_lines<=3)
						//{
						//	var num_lines=Math.round(Math.random()*2+1)
						//	console.log(num_lines)
						//	selectAlternateElement(e,num_lines)	
						//}
						new_height = Math.round((Math.random()*20+10) * e.num_lines)
					}
			
					console.log("design height " + design.height + ", e height " + e.height)
			
					e.height = new_height
					e.width = e.height * e.aspect_ratio
			
					var new_x = Math.random() * (design.width - e.width)
					var new_y = Math.random() * (design.height - e.height)
			
					e.x = new_x
					e.y = new_y
			
					e.fixed_amount = 0.0
					e.state_img.hide()
		
				});

			console.log("calling with run id"+run.id)
			sendCurrentLayout(undefined,true,run.id)
			$('#canvas').data("energy_lists")[run.id]=[]
			}
	});

	

	setCurrentLayout(curr_layout)
	
	$('#canvas').data("started", true)
	allowUpdates()

}




function viewLayout(layout_type, layout_num) {

	console.log("view " + layout_type + " layout " + layout_num)


	if (layout_type!='interactive')
	{
		$('#canvas').data("user_input_log").push("View-" + layout_type+"-"+layout_num)
		$('#canvas').data("status_log").push("View-" + layout_type+"-"+layout_num)
	}
	
	if ((layout_num < 0) && $('#canvas').data("preview") > -1) {
		
		
		
		$('#canvas').data("preview", -1)
		$('#canvas').data("preview_image").hide()
		$('#canvas').data("preview_image").getLayer().draw()
		$('#canvas').data("overlap_layer").show()

		
		var selected=$('.selectedPreview')
		
		var canvas = selected[0];
		var ctx = canvas.getContext("2d")

		var image = selected.data("preview_image")
		var sugg_stage= $('#canvas').data("sugg_stage")
		
		ctx.drawImage(image, 0, 0, sugg_stage.attrs.width / 3, sugg_stage.attrs.height / 3);
		
		selected.removeClass("selectedPreview")
		
		
		

	} else if ($('#' + layout_type + '_layout' + layout_num).data("layout") != undefined) {

		$('#' + layout_type + '_layout' + layout_num).addClass("selectedPreview")

		$('#canvas').data("overlap_layer").hide()
		$('#canvas').data("preview", layout_num)
		$('#canvas').data("preview_image").show()
		$('#canvas').data("preview_image").attrs.fillPatternImage = $('#' + layout_type + '_layout' + layout_num).data("preview_image")
		
		$('#canvas').data("preview_image").attrs.stroke='#0F0'
		$('#canvas').data("preview_image").attrs.strokeEnabled=true
		$('#canvas').data("preview_image").attrs.strokeWidth=4
		
		$('#canvas').data("preview_image").moveToTop()
		$('#canvas').data("preview_image").getLayer().draw()
		

		var canvas = $('#' + layout_type + '_layout' + layout_num)[0];
		var ctx = canvas.getContext("2d")
		var image = $('#canvas').data("images")['accept_suggestion'];	
		
		var sugg_stage= $('#canvas').data("sugg_stage")
		if (sugg_stage.attrs.width>sugg_stage.attrs.height)
			ctx.drawImage(image, 30, 0);
		else	
			ctx.drawImage(image, 0, 30);	
		
		
		
	}

}

function sendDesign() {
	var elements = $('#canvas').data("design").elements;

	console.log('sendInitialDesign');
	for (var j = 0; j < elements.length; j++) {

		if (elements[j].loaded == false) {
			setTimeout(sendDesign, 500);
			return;
		}
	}
	sendCurrentLayout();
	sendCurrentDesign();

}

function updateTextElement(elem) {

	var old_text_chars = elem.old_text.replaceAll('\n', '').replaceAll(',', '').replaceAll(' ', '');
	var new_text_chars = elem.text.replaceAll('\n', '').replaceAll(',', '').replaceAll(' ', '');

	var old_num_lines = elem.old_text.split("\n").length;
	var new_num_lines = elem.text.split("\n").length;

	//var old_text_lines = elem.old_text.replaceAll(',', '').replaceAll(' ', '');
	//var new_text_lines = elem.text.replaceAll(',', '').replaceAll(' ', '');

	console.log("old_text: " + old_text_chars)
	console.log("new_text: " + new_text_chars)

	/*
	Cases:
	1) The new text is identical to the old text
	- re-render alternates, but use the current texts
	2) The new text is significantly different than the old text (new words, etc)
	- get text alternates and re-render everything from scratch
	3) The new text differs from the old text by the number of lines
	- render the new text, set that as a new alternate, and update the selection
	4) The new text only differs from the old text by commas or spaces (tweaking the current)
	- re-render only this element
	*/

	// Case 1
	if (elem.old_text == elem.text) {
		console.log("updateTextElement: Re-rendering existing alternates")
		renderTextAlts(elem, false)

	}
	//Case 2
	else if (old_text_chars != new_text_chars) {
		console.log("updateTextElement: Completely re-rendering & finding new alternates")
		renderTextAlts(elem, true)
	}
	//Case 3
	else if ((old_num_lines != new_num_lines)) {
		console.log("updateTextElement: Setting a new alternate with different #s of lines")

		var alts = $('#canvas').data("design").element_alts[elem.id];

		if ( new_num_lines in alts) {

			//selectAlternateElement(new_num_lines)
			//renderTextElement(elem,true)

			alts[new_num_lines].text = elem.text
			elem.text = elem.old_text;
			renderTextElement(alts[new_num_lines], false)

			setTimeout(function() {
				setAlternate(elem, alts[new_num_lines])
			}, 100)

			$("#num_lines_select").val(new_num_lines).attr('selected', true);

		} else {

			var new_elem = jQuery.extend(true, {}, elem)
			new_elem.text = elem.text
			new_elem.num_lines = new_num_lines
			new_elem.fixed_amount = 1
			elem.text = elem.old_text

			elem.img.remove()
			new_elem.loaded = false
			delete new_elem["img"]
			renderTextElement(new_elem, true)

			var max_cnt = 0;
			$.each(alts, function(i, alt) {
				max_cnt = Math.max(max_cnt, alt.alternate_id);
			});
			new_elem.alternate_id = max_cnt + 1

			alts[new_num_lines] = new_elem

			//selectElement(new_elem)
			$("#num_lines_select").val(new_num_lines).attr('selected', true);
			//return;

		}

	}
	//Case 4: tweaking
	else {
		console.log("updateTextElement: Tweaking current")
		renderTextElement(elem, true)
	}

	selectElement(elem)

}

function updateTextElementOld(elem) {

	var old_text = elem.old_text.replaceAll('\n', '').replaceAll(',', '').replaceAll(' ', '');
	var new_text = elem.text.replaceAll('\n', '').replaceAll(',', '').replaceAll(' ', '');

	console.log("old_text: " + old_text)
	console.log("new_text: " + new_text)

	//only update the current alternate, don't replace everything...
	if (old_text == new_text) {
		var alts = $('#canvas').data("design").element_alts[elem.id];

		var old_num_lines = elem.old_text.split("\n").length;
		var new_num_lines = elem.text.split("\n").length;

		if (old_num_lines == new_num_lines) {

			renderTextElement(elem, true)

		} else {

			if ( new_num_lines in alts) {
				alts[new_num_lines].text = elem.text
				elem.text = elem.old_text;
				renderTextElement(alts[new_num_lines], true)
				setAlternate(elem, alts[new_num_lines])

			} else {

				var new_elem = jQuery.extend(true, {}, elem)
				new_elem.text = elem.text
				new_elem.num_lines = new_num_lines
				new_elem.fixed_amount = 1
				elem.text = elem.old_text

				elem.img.remove()
				new_elem.loaded = false
				delete new_elem["img"]
				renderTextElement(new_elem, true)
				//renderTextElement(elem,false)

				var max_cnt = 0;
				$.each(alts, function(i, alt) {
					max_cnt = Math.max(max_cnt, alt.alternate_id);
				});
				new_elem.alternate_id = max_cnt + 1

				alts[new_num_lines] = new_elem

				setTimeout(function() {
					selectElement(new_elem)
				}, 500)

			}

			$("#num_lines_select").val(new_num_lines).attr('selected', true);

		}
	} else {
		delete $('#canvas').data("design").element_alts[String(elem.id)]

		renderTextAlts(elem, true)
		//selectElement(elem)

	}

}

function fixElementImages() {
	

	
	var design=$('#canvas').data("design");
	var layer = $('#canvas').data("stage").get('#layer')[0];
	
	
	$.each(design.elements, function (i, elem){
		
		
		elem.img.remove()
	
		console.log(design.element_alts[elem.id])
		
		if (design.element_alts[elem.id]!= undefined)
		{
			$.each(design.element_alts[elem.id], function(i, e) {
				e.img.remove()
		
				console.log(e.alignment_imgs)
				$.each(e.alignment_imgs, function(j, ai) {
					ai.remove()
				});
				$.each(e.anchors, function(i, a) {
					a.hide()
				});
			});
		}
	
		if ((elem.num_lines > 1) && (elem.img != elem.alignment_imgs[elem.align])) {
			elem.img = elem.alignment_imgs[elem.align];
		}
	
		elem.img.setPosition(elem.x, elem.y)
		elem.img.attrs.strokeEnabled = elem.selected
		elem.img.setHeight(elem.height)
		elem.img.setWidth(elem.height * elem.aspect_ratio)
		elem.img.setOpacity(1)
	
		layer.add(elem.img)
		elem.img.show()
	
	});

}

function renderTextAlts(elem, createAlternates) {
	console.log("rendering text alts for element text: " + elem.text)
	elem.orig_text = elem.text.trim()

	var idx = $('#canvas').data("design").elements.indexOf(elem);

	var text_alts = {};

	if (elem.id in $('#canvas').data("design").element_alts) {
		var elem_alts = $('#canvas').data("design").element_alts[elem.id];
		$.each(elem_alts, function(i, alt) {
			var num_lines = alt.text.split("\n").length
			text_alts[num_lines] = alt.text

			if ((alt.img != undefined) && ( typeof (alt.img) != 'string')) {
				console.log("typeof(alt.img) " + typeof (alt.img))

				alt.img.remove()
				alt.sugg_img.remove()

				$.each(alt.anchors, function(i, a) {
					a.destroy();
				});
			}
		})
	}

	if ((!(elem.id in $('#canvas').data("design").element_alts)) || (createAlternates))
		text_alts = findTextAlternates(elem.text)

	var alts = {}
	var cnt = 0;
	$.each(text_alts, function(i, text) {

		//console.log("rendering text with num_lines "+elem.num_lines+" \n"+)
		text_trim=text.trim()

		console.log("text alt "+i+" has text "+text_trim)

		var new_elem;
		if (text_trim == elem.orig_text) {
			console.log("matching orig")
			new_elem = elem
			$('#canvas').data("design").elements[idx] = new_elem
		} else {
			new_elem = jQuery.extend(true, {}, elem)
			new_elem.text = text_trim
			new_elem.num_lines = text_trim.split("\n").length
		}

		new_elem.state_img = elem.state_img;
		new_elem.unlock_img = elem.unlock_img;
		new_elem.tweakable_img = elem.tweakable_img;
		new_elem.lock_img = elem.lock_img;
		delete new_elem["img"];
		delete new_elem["sugg_img"];

		renderTextElement(new_elem, false)

		alts[new_elem.num_lines] = new_elem
		new_elem.alternate_id = cnt
		cnt = cnt + 1

	});

	$('#canvas').data("design").element_alts[elem.id] = alts;

}

function selectAlternateElement(elem, num_lines) {

	console.log("setting element " + elem.id + " with num lines " + num_lines)

	var alts = $('#canvas').data("design").element_alts[elem.id]

	if ( num_lines in alts) {
		setAlternate(elem, alts[num_lines])
	}

	//design.elements[idx].style=elem.style

}

function renderTextElement(elem, is_visible) {

	var layer = $('#canvas').data("stage").get('#layer')[0];
	var sugg_layer = $('#canvas').data("sugg_stage").get('#sugg_layer')[0];

	//var layer=elem.img.getLayer();
	//var sugg_layer=elem.sugg_img.getLayer();

	console.log("rendering text for element " + elem.text)

	fontStyle = ''
	if (elem.bold)
		fontStyle = fontStyle + " bold";
	if (elem.italic)
		fontStyle = fontStyle + " italic";

	var sugg_pos={}
	sugg_pos.x=elem.x;
	sugg_pos.y=elem.y;
	sugg_pos.height=elem.height;
	
	
	if ("img" in elem) {
		console.log("removing img from element")

		sugg_pos.x = elem.sugg_img.getAbsolutePosition().x
		sugg_pos.y = elem.sugg_img.getAbsolutePosition().y
		sugg_pos.height = elem.sugg_img.getHeight()

		elem.x = elem.img.getAbsolutePosition().x
		elem.y = elem.img.getAbsolutePosition().y
		elem.height = elem.img.getHeight()
		elem.width = elem.img.getWidth()
		elem.img.destroy()
		elem.sugg_img.destroy()

		$.each(elem.alignment_imgs, function(i, ai) {
			ai.destroy()
		});

		$.each(elem.anchors, function(i, a) {
			a.destroy()
		});
	}

	var alignments;

	elem.num_lines = elem.text.split("\n").length;

	// wierd...look into this fixed_alignment
	if ((elem.num_lines > 1) && ((!("fixed_alignment" in elem)) || (elem.fixed_alignment == false)))
		alignments = ["left", "center", "right"];
	else
		alignments = [elem.align]

	console.log("alignments: " + (alignments))

	elem.max_line_length = 0;
	$.each(elem.text.split("\n"), function(i, t) {
		elem.max_line_length = Math.max(elem.max_line_length, t.length)
	});
	console.log("max line length: " + elem.max_line_length)

	//elem.num_align=alignments.length

	elem.alignment_imgs = {}
	elem.alignment_sugg_imgs = {}

	console.log("font: " + elem.font)
	console.log("fontStyle: " + fontStyle)
	
	
	$('#canvas').data("images_rendering",$('#canvas').data("images_rendering")+alignments.length)

	$.each(alignments, function(index, curr_alignment) {

		elem.init_font_size= (60 / elem.num_lines + 10);

		var text
		if (elem.shadow)
			text = new Kinetic.Text({
				x : 0,
				y : 0,
				text : elem.text,
				fill : elem.color,
				fontSize : (60 / elem.num_lines + 10),
				fontStyle : fontStyle,
				fontFamily : elem.font,
				align : curr_alignment,
		        shadowColor: 'black',
		        shadowBlur: 10,
		        shadowOffset: {x:5,y:5},
		        shadowOpacity: 0.5
			});
		else
			text = new Kinetic.Text({
				x : 0,
				y : 0,
				text : elem.text,
				fill : elem.color,
				fontSize : (60 / elem.num_lines + 10),
				fontStyle : fontStyle,
				fontFamily : elem.font,
				align : curr_alignment
			});
		
		/*
		var sans_serif_width=text.getWidth()
		console.log("sans serif width:"+sans_serif_width)
		
		text.attrs.fontFamily=elem.font
		var font_width=text.getWidth()
		console.log("font width:"+font_width)
		
		if ((elem.font!= 'sans-serif') && (font_width==sans_serif_width))
		{
			console.log("ERROR. Font not loaded. Rendering as sans-serif. Wait till loaded")	
			
			
			var callback = function (){textToImage(text,curr_alignment, sugg_pos,elem,layer,is_visible)};
			
			var interval;
			var cnt=0;
			
			var checkFontWidth=function()
			{
				text.attrs.fontFamily=elem.font
				var width=text.getWidth()
				console.log("checkFontWidth "+width+ ", sans_serif_width "+sans_serif_width+", cnt "+cnt)
				console.log(interval)
				if (width!=sans_serif_width)
				{
					console.log("clearing interval and textToImage ")
					clearInterval(interval)
					callback()
				}	
				cnt+=1;
			}
			
			//interval= setInterval(checkFontWidth,1000)
			
		}
		//else
		*/
		textToImage(text,curr_alignment, sugg_pos,elem,layer,sugg_layer,is_visible)
		

		/*
		if (gup('hideContent') == '1')
			text = new Kinetic.Text({
				x : 0,
				y : 0,
				text : 'Text',
				fill : 'black',
				height : text.getHeight(),
				width : text.getWidth(),
				fontSize : 30,
				fontFamily : 'Calibri',
				align : 'center'
			});
		*/
		
	});

}






function textToImage(text, curr_alignment,sugg_pos, elem, layer,sugg_layer,is_visible)
{

	elem.anchors = createAnchors(elem, layer, false)

	elem.aspect_ratio = text.getWidth() / text.getHeight()

	//elem.aspect_ratio=img.width/img.height
	console.log("text: " + elem.text + " \n aspect ratio " + elem.aspect_ratio)
	
	if (elem.text.trim().split("\n").length!=elem.num_lines)
	{
		console.log("ERROR. doesnt match num lines"+elem.num_lines)
	}

	text.toImage({
		x : 0,
		y : 0,
		width : (text.getWidth()+5),
		height : (text.getHeight()+5),
		callback : function(img) {
			
			$('#canvas').data("images_rendering",$('#canvas').data("images_rendering")-1)

			/*
			 var canvas = document.createElement('canvas');
			 canvas.width=img.width
			 canvas.height=img.height
			 var context = canvas.getContext('2d');

			 context.drawImage(img, 0, 0 );
			 var data = context.getImageData(0, 0, img.width, img.height).data;
			 //console.log(data)

			 var min_x=img.width, max_x=-1;
			 var min_y=img.height, max_y=-1;
			 for(var y = 0; y < img.height; y++)
			 for(var x = 0; x < img.width; x++)
			 {

			 if (data[((img.width * y) + x) * 4 + 3]!=0)
			 {
			 min_x=Math.min(min_x,x)
			 min_y=Math.min(min_y,y)

			 max_x=Math.max(max_x,x)
			 max_y=Math.max(max_y,y)
			 }
			 }

			 */

			var add_background = ''
			if (gup('hideContent') == '1') {
				add_background = function(pixels) {
					var d = pixels.data;
					for (var i = 0; i < d.length; i += 4) {

						var alpha = (d[i + 3] / 255)

						//d[i] += alpha*d[i]+(1-alpha)*135;
						// d[i+1] += alpha*d[i+1]+(1-alpha)*206;
						//d[i+2] += alpha*d[i+2]+(1-alpha)*235;
						d[i] += alpha * d[i] + (1 - alpha) * 0;
						d[i + 1] += alpha * d[i + 1] + (1 - alpha) * 255;
						d[i + 2] += alpha * d[i + 2] + (1 - alpha) * 127;
						d[i + 3] = 255;
					}
					return pixels;
				};
			}

			var text_img = new Kinetic.Image({
				image : img,
				x : elem.x,
				y : elem.y,
				width : img.width, //max_x-min_x,
				height : img.height, //max_y-min_y,
				strokeEnabled : is_visible,
				stroke : 'Red',
				strokeWidth : 2,
				lineJoin : 'round',
				dashArray : [7, 5],
				name : String(elem.id),
				draggable : true,
				visible : false,
				filter : add_background
				//crop: {
				//x: min_x,
				//y: min_y,
				//width: max_x-min_x,
				// height: max_y-min_y
				//}
			});
			
			elem.init_height= img.height;

			var scale = 1.0;
			if (elem.old_text.length > 0) {
				var old_num_lines = elem.old_text.split("\n").length;
				scale = elem.num_lines / old_num_lines;
			}

			elem.alignment_imgs[curr_alignment] = text_img

			text_img.setHeight(elem.height * scale);
			text_img.setWidth(elem.height * scale * elem.aspect_ratio);

			var sugg_text_img = text_img.clone();
			sugg_text_img.setX(sugg_pos.x);
			sugg_text_img.setY(sugg_pos.x);
			sugg_text_img.setHeight(sugg_pos.height)
			sugg_text_img.setWidth(sugg_pos.height * elem.aspect_ratio)
			sugg_text_img.attrs.strokeEnabled = false;

			elem.alignment_imgs[curr_alignment] = text_img
			elem.alignment_sugg_imgs[curr_alignment] = sugg_text_img

			console.log("create text with num_lines " + elem.num_lines + " with alignment:" + curr_alignment + " " + elem.align)
			if ((elem.num_lines == 1) || (elem.align == curr_alignment)) {

				//console.log("\nadding image to element\n "+elem.text)
				
				//console.log("\norig text\n"+elem.orig_text)
				elem.img = text_img;
				layer.add(text_img);

				if ((is_visible) || (elem.text.trim() == elem.orig_text.trim())) {

					console.log('matched elem text\n: ' + elem.orig_text)
					//$.each(elem.anchors, function(i,a){
					//	layer.add(a)
					//a.moveToTop()
					//});
					//moveAnchors(elem)

					elem.img.show()

					layer.draw()
				}
			}

			if ((elem.num_lines == 1) || (elem.sugg_align == curr_alignment)) {
				elem.sugg_img = sugg_text_img;
				sugg_layer.add(sugg_text_img);

				if ((is_visible) || (elem.text == elem.orig_text)) {
					sugg_layer.draw()
					elem.sugg_img.show()
				}
			}

			setupElementCallbacks(text_img, elem);

			elem.loaded = true;

		}
	});

}



function findTextAlternates(text) {
	var alts = {};

	var one_line = text.split("\n").join(" ");
	var num_words = one_line.split(" ").length;

	alts[1] = one_line;

	var init_num_lines = text.split("\n").length;

	console.log("one line: " + one_line);
	console.log("num words:" + num_words);

	//console.log("init_num_lines "+init_num_lines)

	for (var n = 2; n <= Math.min(num_words, 7); n++) {

		var line_size = one_line.length / n;
		console.log('line size' + line_size)

		var new_text = ''
		var curr_idx = 0;
		var check_idx = curr_idx + line_size;
		for (var i = 0; i < n - 1; i++) {
			var idx1 = one_line.indexOf(' ', check_idx);

			var idx2 = one_line.substring(0, check_idx).lastIndexOf(' ');

			if ((idx1 == -1) && (idx2 == -1)) {
				console.log("index ==-1 ")
				continue

			}

			var idx = 0
			if ((((idx1 - check_idx) < (check_idx - idx2)) || (idx2 >= one_line.length - 1) || (idx2 == -1)) && (idx1 != -1))
				idx = idx1;
			else
				idx = idx2;

			console.log('n' + n + ' i ' + i + " curr idx " + curr_idx + " idx " + idx)
			console.log(" idx1 " + idx1 + " " + " idx2 " + idx2)
			new_text += one_line.substring(curr_idx, idx + 1) + "\n"
			curr_idx = idx;
			check_idx += line_size;

		}
		new_text += one_line.substring(curr_idx, one_line.length)

		console.log('new_text: ' + new_text)
		var lines = new_text.split("\n")
		var text2 = ''
		var max_len = 0;
		for (var j = 0; j < lines.length; j++) {
			if (lines[j].length > 0) {
				var trimmed = lines[j].trim()
				text2 += trimmed + "\n"
				max_len = Math.max(max_len, trimmed.length)
			}
		}

		text2 = text2.substring(0, text2.length - 1)

		var num_lines = text2.split("\n").length;

		var ratio = (max_len) / (num_lines)
		console.log('Creating text alt ' + n + ' with num_lines ' + num_lines + ", ratio: " + ratio + "\n" + text2)

		//if ((num_lines>2) && (ratio<5))
		//	continue;

		alts[num_lines] = text2;
	}

	alts[init_num_lines] = text;

	return alts;

}

function deselectAll(elem) {
	var other;

	if ((elem != undefined) && (elem.type == 'region'))
		other = $('#canvas').data("design").regions
	else
		other = $('#canvas').data("design").elements

	
	$('#canvas').data("selected", elem);
	if (elem==undefined)
		$('#canvas').data("selected", 0);
		
	console.log('selected: '+$('#canvas').data("selected"))

	$.each($('#canvas').data("align_lines"), function(i, al) {
		al[0].destroy()
	});
	$('#canvas').data("align_lines", [])

	$.each(other, function(i, e) {
		if ((e != elem)) {

			e.state_img.hide()

			//if (e.selected) {
			e.img.attrs.strokeEnabled = false;

			$.each(e.anchors, function(i, a) {
				a.hide();
			});
			e.selected = false;
			
		}
	});
}

function selectMultipleElements(p1, p2) {

	console.log('p1:' + p1.x + ' ' + p1.y)
	console.log('p2: ' + p2.x + ' ' + p2.y)
	var x = Math.min(p1.x, p2.x)
	var y = Math.min(p1.y, p2.y)
	var width = Math.max(p1.x, p2.x) - x
	var height = Math.max(p1.y, p2.y) - y

	var selected = []
	$.each($('#canvas').data("design").elements, function(i, e) {

		if (!((x + width < e.x) || (e.x + e.width < x) || (y + height < e.y) || (e.y + e.height < y)))
			selected.push(e)

	});
	if (selected.length > 0) {
		deselectAll()
		$.each(selected, function(i, e) {
			console.log('e:' + e.x + ' ' + e.y + " w/h: " + e.width + ' ' + e.height)
			console.log("selected element " + e.id)
			selectElement(e, true)
		});

	}

}

function selectElement(elem, multiple) {

	multiple = typeof multiple !== 'undefined' ? multiple : false;

	console.log("setting selected to " + elem.id + " with type " + elem.type + " and multiple " + multiple)

	//if (elem.selected)
	//	return;

	if (elem.img == undefined) {
		console.log("no image. try again in 200 ms")
		setTimeout(function() {
			selectElement(elem, multiple);
		}, 200)
		return

	}
	
	removeSuggestions()
	
	
	$("#canvas").data("last_selected", $('#canvas').data("selected"))	

	if (!multiple) {
		deselectAll(elem)

		//if ($('#canvas').data("selected")!=elem)
		setControls(elem)

		if (elem.type != 'background')
			drawAlignmentLines(elem, 'dragging')
			
			
		console.log("setting anchors")
		$.each(elem.anchors, function(i, a) {

			//if ($('#canvas').data("region_mode"))
			a.moveToTop()
			//layer.add(a)
			a.show()
		});
		moveAnchors(elem);
		
		///$('#size_constraint').prop("checked",false)
		//$('#alignment_constraint').prop("checked",false)
		
		$('#group_constraints').css("visibility",'hidden')
			
	} 
	
	else {

		if (elem.selected) {
			elem.selected = false;
			elem.img.attrs.strokeEnabled = false;
			elem.img.getLayer().draw();
			return;

		}
		if ($('#canvas').data("selected")!=0)
		{
			$.each($('#canvas').data("selected").anchors, function(i, a) {
				a.hide();
			});
		}
		
		var size_constraint=true;
		var alignment_constraint=true;
		
		var selected_others=0;
		
		$.each($('#canvas').data("design").elements, function(i, e) {
			if ((e.selected) && (e.id!=elem.id))
			{
				selected_others++;
				
				if (e.constraints['size'].indexOf(elem.id)==-1)
					size_constraint=false
					
				if (e.constraints['alignment'].indexOf(elem.id)==-1)
					alignment_constraint=false					
					
				
			}
			
		});
		
		if (selected_others==0){
			size_constraint=false;
			alignment_constraint=false;
		}
		else
			$('#group_constraints').css("visibility",'visible')
		
		$('#size_constraint').prop("checked",size_constraint)
		$('#alignment_constraint').prop("checked",alignment_constraint)
		
		
	}

	if ($('#canvas').data("region_mode"))
		elem.img.moveToTop();

	var layer = elem.img.getLayer()


	$.each($('#canvas').data("design").elements, function(i, e) {

		if (elem.type != 'background') {
			e.state_img.show()
			e.state_img.setPosition(e.x + e.width, e.y)
		} else
			e.state_img.hide()
	});

	//elem.curr_pos=elem.img.getStage().getPointerPosition()
	elem.last_x = elem.img.getPosition().x;
	elem_last_y = elem.img.getPosition().y;

	elem.selected = true;
	
	if (elem.type!='background')
		elem.img.attrs.strokeEnabled = true;


	$('#canvas').data("selected", elem);

	console.log("finished selecting")


	//setCurrentRules()

	layer.draw();

}

function getDistance(p1, p2) {
	return Math.sqrt(Math.pow((p2.x - p1.x), 2) + Math.pow((p2.y - p1.y), 2));
}

function setupStageCallbacks(stage) {
	stage.getContent().addEventListener('touchmove', function(evt) {
		var touch1 = evt.touches[0];
		var touch2 = evt.touches[1];

		if (touch1 && touch2) {
			var dist = getDistance({
				x : touch1.clientX,
				y : touch1.clientY
			}, {
				x : touch2.clientX,
				y : touch2.clientY
			});

			var lastDist = $('#canvas').data("lastDist");
			var lastScale = $('#canvas').data("lastScale");
			$('#canvas').data("lastDist", dist);

			var scale = ((dist + 50 ) / (lastDist + 50));
			scale = Math.min(Math.max(scale, 0.95), 1.05)

			if ((lastScale != undefined) && (((lastScale > 1) && (scale > 1)) || ((lastScale < 1) && (scale < 1))))
				scale = scale * 0.25 + lastScale * 0.75;
			$('#canvas').data("lastScale", scale);

			scaleCurrentElement(scale)
		}
	}, false);

	stage.getContent().addEventListener('touchend', function() {
		$('#canvas').data("lastDist", 0);
	}, false);

}

function setupElementCallbacks(elem_img, elem) {

	

	

	elem_img.on('mouseover', function(evt) {
		if ($("#mouseover_alignment_select").prop("checked"))
			drawAlignmentLines(elem, 'mouseover')

	});
	
	elem_img.on('dragstart',function(evt) {dragStartEvent(evt, elem, elem_img)});
	elem_img.on('dragmove',function(evt) {dragMoveEvent(evt, elem, elem_img)});
	elem_img.on('dragend',function(evt) {dragEndEvent(evt, elem, elem_img)});

	elem_img.on('dblclick dbltap', function(evt) {
		console.log("double click");

		if (elem.type != 'background')
			showElementControls();
		else
			showBackgroundControls();
	});

	 elem_img.on("click tap",function(evt) {clickEvent(evt, elem, elem_img)});
	
	 elem_img.on("mousedown",function(evt) {mouseDownEvent(evt, elem, elem_img)});
	 elem_img.on("mousemove",function(evt) {mouseMoveEvent(evt, elem, elem_img)}); 
	 elem_img.on("mouseup",function(evt) {mouseUpEvent(evt, elem, elem_img)});

}


function dragStartEvent(evt,elem,elem_img)
{
	$('#canvas').data("dragging", true)
	console.log("dragstart")
	evt.preventDefault();

	if (elem.type != 'background')
		$('#canvas').data("select_start", false)


	$.each($('#canvas').data("design").elements, function(i, e) {
		e.last_x=e.x;
		e.last_y=e.y;	
	});
	if (elem.type=='background')
		console.log("background drag")
	if (!elem.selected)
		selectElement(elem, evt.shiftKey == 1)

	elem.curr_pos = elem_img.getStage().getPointerPosition();

	$('#canvas').data("user_input_log").push("M")
	$('#canvas').data("status_log").push("M")
	
	
	stopSuggestionsUntilUserInput()
	
}

function dragMoveEvent(evt,elem,elem_img)
{
	
	console.log("dragmove")
	//$('#canvas').data("select_start",undefined)
	evt.preventDefault();

	if ((elem.resizing))
		return;

	//elem.selected=true;

	$('#canvas').data("select_start", false)
	//allowUpdates()

	var stage = elem_img.getStage()

	//console.log("stage:"+stage)
	if (stage == undefined) {
		console.log("layer:")
		console.log(elem_img.getLayer())
		$('#suggestion_status').text("stage undefined");
		return;

	}

	moveAnchors(elem)

	elem.x = elem_img.getPosition().x
	elem.y = elem_img.getPosition().y

	elem.state_img.setPosition(elem.x + elem.width, elem.y)

	drawAlignmentLines(elem, 'dragging')

	//var curr_pos=stage.getPointerPosition()

	var diff_x = elem.x - elem.last_x;
	var diff_y = elem.y - elem.last_y;

	console.log("x:"+elem.x)
	console.log("y:"+elem.y)
	console.log("last_x:"+elem.last_x)
	console.log("last_y:"+elem.last_y)
	console.log("diff_x:"+diff_x)
	console.log("diff_y:"+diff_y)

	elem.last_x = elem.x
	elem.last_y = elem.y

	var num_other_selected = 0

	$.each($('#canvas').data("design").elements, function(i, e) {
		if ((e != elem) && (e.selected)) {

			if (e.img.attrs.strokeEnabled == false) {
				$('#error_message').text("Element selected by mistake")
				e.selected = false
				return

			}

			e.curr_pos += diff_x
			e.curr_pos += diff_y

			e.x += diff_x
			e.y += diff_y

			e.img.setPosition(e.x, e.y)
			e.state_img.setPosition(e.x + e.width, e.y)

			e.fixed_amount = elem.fixed_amount
			num_other_selected += 1
		}
	});

	//console.log("setting state")

	//if ($("#infer_locking_select").prop("checked") && (elem.fixed_amount !=1) && (elem.fixed_amount != 0.5) && (num_other_selected == 0))
	//	setElementState(elem.id, 'tweakable')
	//else
	elem.state_img.show()

	$.each($('#canvas').data("design").elements, function(i, e) {
		if ((e != elem) && (!(e.selected))) {
			var new_opacity = 0;

			if ($("#fixed_opacity_select").prop("checked")) {
				console.log("fixed opacity")
				new_opacity = 0.6;
			} else if (e.fixed_amount == 0)
				new_opacity = 0.3;
			else
				new_opacity = 0.6;

			e.img.attrs.opacity = new_opacity
			e.state_img.attrs.opacity = new_opacity

			if ($("#lock_icon_select").prop("checked"))
				e.state_img.show()
			else
				e.state_img.hide()
		} else
			e.img.attrs.opacity = 1.0;

	});
	//sendCurrentLayout();
	//console.log("end dragmove")

	elem_img.getLayer().draw();


}




function dragEndEvent(evt,elem,elem_img)
{
	
	evt.preventDefault();
	
	allowUpdates()

	//if (elem.type != 'region') {
	
	$.each($('#canvas').data("design").elements, function(i, e) {
		if ((e != elem)) {
			//setStroke(e.img, false, 1.5, e.fixed_amount)

			if ($("#infer_locking_select").prop("checked")) {
				var overlap = getOverlap(e.img, elem.img)
				if ((overlap > 0.1) && (e.fixed_amount != 1)&& (!e.allow_overlap)&& (!elem.allow_overlap)) {
					setElementState(e.id, 'unlocked')
					e.img.attrs.strokeEnabled=false
					if (e.fix_alignment)
					{
					 	e.fix_alignment=false
					 	
					 	sendCurrentDesign()
					}
					 
				}

			}

			//console.log('overlap: '+overlap)

			e.state_img.attrs.opacity = 1

			//if (!e.selected)
			//	e.state_img.hide()
		}
		e.img.attrs.opacity = 1

	});

	//$.each($('#canvas').data("align_lines"), function(i, al){
	//	al.destroy()
	//});

	elem_img.getLayer().draw();

	sendCurrentLayout('Move');
	

	$('#canvas').data("dragging", false)

	
}



function clickEvent(evt,elem,elem_img)
{
	console.log("click, text mode " + $('#canvas').data("text_mode")+", "+$('#canvas').data("dragging"))


	
	if ($('#canvas').data("text_mode")) {

		console.log("create text element")
		createNewElement('text')
		document.body.style.cursor = "default";
		$('#canvas').data("text_mode", false)
		return
	}
	
	if ($('#canvas').data("dragging"))
		return;
	

	selectElement(elem, evt.shiftKey == 1)

	if (elem.type == 'background') {

		$('#element_controls').hide()

		var last_selected = $("#canvas").data("last_selected")

		if ($('#background_controls').is(":visible"))
			hideBackgroundControls()
		else if (("type" in last_selected) && (last_selected.type == "background") && ($('#canvas').data("modificationsEnabled")))
		{
			showBackgroundControls()
		}
	
	} else {
		hideBackgroundControls()

		sendCurrentLayout('Select')
	}
	
}


function mouseMoveEvent(evt,elem,elem_img)
{
	var start_pos = $('#canvas').data("select_start")
	
	console.log("mouse move")
	var stage = elem_img.getStage();
	var curr_pos = stage.getPointerPosition()
	
	console.log("curr_pos")
	console.log(curr_pos)
	
	console.log(elem_img.getHeight())
	//evt.preventDefault();
	if ((start_pos != false)&& $('#canvas').data("mousedown")) {
		

		
		var select_rect = $('#canvas').data("select_rect")

		
		var dist = getDistance(start_pos, curr_pos)

		if (dist > 10) {
			selectMultipleElements($('#canvas').data("select_start"), stage.getPointerPosition())

			select_rect.setWidth(curr_pos.x - start_pos.x)
			select_rect.setHeight(curr_pos.y - start_pos.y)
			select_rect.show()
			select_rect.getLayer().draw()
		}
	}
}

function mouseUpEvent(evt,elem,elem_img)
{

	$('#canvas').data("mousedown",false)
	//evt.preventDefault();
	$('#canvas').data("select_rect").hide()
	$('#canvas').data("select_rect").getLayer().draw()
	
	var stage = elem_img.getStage();

	console.log("mouse up: " + $('#canvas').data("select_start"))
	//console.log(elem_img)
	//console.log(elem)


	if ($('#canvas').data("select_start") != false) {
		console.log("mouse up")
		var curr_pos = stage.getPointerPosition()
		var dist = getDistance($('#canvas').data("select_start"), curr_pos)

		if (dist > 10) {

			selectMultipleElements($('#canvas').data("select_start"), stage.getPointerPosition())
		}
	}
	$('#canvas').data("select_start", false)
	
}

function mouseDownEvent(evt,elem,elem_img)
{

	var stage = elem_img.getStage();
	
	$('#canvas').data("mousedown",true)
	
	console.log("mouse down: " + $('#canvas').data("select_start"))
	console.log(elem_img)
	console.log(elem)	
	if (elem.type=='background')
	{
		$('#canvas').data("select_start", stage.getPointerPosition())
		$('#canvas').data("select_rect").setPosition($('#canvas').data("select_start"));
	}
}



function drawAlignmentLines(elem, call_type) {

	$.each($('#canvas').data("align_lines"), function(i, al) {
		al[0].destroy()
	});
	$('#canvas').data("align_lines", [])

	if (elem.type == 'background') {
		elem.img.getLayer().draw()
		return;
	}

	elem.width = elem.img.getWidth()
	elem.height = elem.img.getHeight()
	//console.log("drawAlignmentLines")

	elem.mid_x = elem.x + elem.width / 2.0
	elem.mid_y = elem.y + elem.height / 2.0

	var min_x_amount = 9999
	var min_y_amount = 9999
	var x_line = [min_x_amount, 0, 0, 0, 0, 0, -99, []]
	var y_line = [0, min_y_amount, 0, 0, 0, 0, -99, []]

	var align_thresh = 10

	var design_x_center = $('#canvas').data("design").width / 2.0
	var design_y_center = $('#canvas').data("design").height / 2.0
	var align_x_center = Math.abs(elem.mid_x - design_x_center)
	var align_y_center = Math.abs(elem.mid_y - design_y_center)

	//var global_x_align=false;
	if (align_x_center < align_thresh) {
		//global_x_align=true;
		min_x_amount = align_x_center
		x_line = ([design_x_center - elem.mid_x, 0, design_x_center, 0, design_x_center, design_y_center * 2, 10, []])
	}

	//var global_y_align=false;
	if (align_y_center < align_thresh) {
		//global_y_align=true;
		min_y_amount = align_y_center
		y_line = ([0, design_y_center - elem.mid_y, 0, design_y_center, design_x_center * 2, design_y_center, 11, []])
	}

	$.each($('#canvas').data("design").elements, function(i, e) {

		if ((e != elem) && (!(e.selected))) {
			e.width = e.img.getWidth()
			e.height = e.img.getHeight()

			var mid_x = e.x + e.width / 2.0;
			var mid_y = e.y + e.height / 2.0;

			var align_left = Math.abs(elem.x - e.x)
			var align_right = Math.abs(elem.x + elem.width - (e.x + e.width))
			var align_x_center = Math.abs(elem.mid_x - mid_x)
			var align_x_min = Math.min(align_left, Math.min(align_x_center, align_right))

			var align_bottom = Math.abs(elem.y - e.y)
			var align_top = Math.abs(elem.y + elem.height - (e.y + e.height))
			var align_y_center = Math.abs(elem.mid_y - mid_y)
			var align_y_min = Math.min(align_top, Math.min(align_y_center, align_bottom))

			if (call_type.indexOf('Left') > -1) {
				align_x_center = align_thresh + 1
				align_right = align_thresh + 1
			}
			if (call_type.indexOf('Right') > -1) {
				align_x_center = align_thresh + 1
				align_left = align_thresh + 1
			}
			if (call_type.indexOf('top') > -1) {
				align_y_center = align_thresh + 1
				align_bottom = align_thresh + 1
			}
			if (call_type.indexOf('bottom') > -1) {
				align_y_center = align_thresh + 1
				align_top = align_thresh + 1
			}

			var y_start = Math.min(e.y, elem.y)
			var y_end = Math.max(e.y + e.height, elem.y + elem.height)

			var x_start = Math.min(e.x, elem.x)
			var x_end = Math.max(e.x + e.width, elem.x + elem.width)
			//&& (y_end-y_start >x_line[5]-x_line[3])
			if ((align_x_min < align_thresh)) {

				var prev_line = x_line;

				//global_x_align=false;

				var new_x_line = -1;
				if ((align_left < align_thresh) && (align_left == align_x_min)) {
					x_line = ([e.x - elem.x, 0, e.x, y_start, e.x, y_end, 0, [e.id]])
				} else if ((align_x_center < align_thresh) && (align_x_center == align_x_min)) {
					x_line = ([mid_x - elem.mid_x, 0, mid_x, y_start, mid_x, y_end, 1, [e.id]])
				} else if ((align_right < align_thresh) && (align_right == align_x_min)) {
					x_line = ([(e.x + e.width) - (elem.x + elem.width), 0, e.x + e.width, y_start, e.x + e.width, y_end, 2, [e.id]])
				}

				//if they are the same type, then concatente the other elements
				if (prev_line[6] == x_line[6]) {
					//console.log("same type")
					if (align_x_min > min_x_amount) {

						//var prev_align=prev_line[7]
						var temp = jQuery.extend(true, {}, prev_line);
						prev_line = x_line
						x_line = temp
						//x_line[7]=prev_align
						//console.log("prev_line:"+prev_line)
						//console.log("x_line:"+x_line)
					}

					x_line[3] = Math.min(x_line[3], prev_line[3])
					x_line[5] = Math.max(x_line[5], prev_line[5])
					x_line[7] = x_line[7].concat(prev_line[7])
				} else {
					if (align_x_min > min_x_amount)
						x_line = prev_line
				}
				min_x_amount = Math.min(align_x_min, min_x_amount);

			}

			//(x_end-x_start >x_line[4]-x_line[2]) &&
			if ((align_y_min < align_thresh)) {

				//console.log("matched element: "+e.id)
				var prev_line = y_line;
				//console.log("prev_line"+prev_line)

				//global_y_align=false;

				if ((align_bottom < align_thresh) && (align_bottom == align_y_min)) {
					y_line = ([0, e.y - elem.y, x_start, e.y, x_end, e.y, 3, [e.id]])
				} else if ((align_y_center < align_thresh) && (align_y_center == align_y_min)) {
					y_line = ([0, mid_y - elem.mid_y, x_start, mid_y, x_end, mid_y, 4, [e.id]])
				} else if ((align_top < align_thresh) && (align_top == align_y_min)) {
					y_line = ([0, (e.y + e.height) - (elem.y + elem.height), x_start, e.y + e.height, x_end, e.y + e.height, 5, [e.id]])
				}

				//if they are the same type, then concatente the other elements
				if (prev_line[6] == y_line[6]) {
					//console.log("same type")
					if (align_y_min > min_y_amount) {
						//var prev_align=prev_line[7]
						var temp = jQuery.extend(true, {}, prev_line);
						prev_line = y_line
						y_line = temp
						//y_line[7]=prev_align
						//console.log("prev_line:"+prev_line)
						//console.log("y_line:"+y_line)
					}

					y_line[7] = y_line[7].concat(prev_line[7])
					y_line[2] = Math.min(y_line[2], prev_line[2])
					y_line[4] = Math.max(y_line[4], prev_line[4])
				} else {
					if (align_y_min > min_y_amount)
						y_line = prev_line
				}
				min_y_amount = Math.min(align_y_min, min_y_amount);

			}

		}

	});
	//}

	var lines = [];
	if (x_line[0] < 9999)
		lines.push(x_line)
	if (y_line[1] < 9999)
		lines.push(y_line)

	if ((lines.length > 0) && ($("#alignment_select").prop("checked"))) {
		$.each(lines, function(i, line) {

			var stroke_color = 'black'
			var stroke_opacity = 0.35
			if ($('#canvas').data("invert")) {
				stroke_color = 'white'
				stroke_opacity = 0.5
			}
		
			
			//console.log("creating line "+line)
			var draw_line = new Kinetic.Line({
				points : [line[2], line[3], line[4], line[5]],
				stroke : stroke_color,
				strokeWidth : 1,
				lineJoin : 'round',
				dashArray : [3, 2],
				opacity : stroke_opacity
			});

			//var global_align= Number(((line[2]==line[4]) && global_x_align) || ((line[2]!=line[4]) && global_y_align))

			$('#canvas').data("align_lines").push([draw_line, elem.id, line[6], line[7]])
			elem.img.getLayer().add(draw_line)

			if ((line[0] != 0) || (line[1] != 0)) {

				/*
				 $.each($('#canvas').data("design").elements, function(i, e) {
				 if (e.selected)
				 {

				 if (call_type=='dragging')
				 {
				 e.x+=line[0];
				 e.y+=line[1];
				 }

				 e.img.setPosition(e.x,e.y)
				 //elem.img.setWidth(elem.width,elem.height)
				 e.state_img.setPosition(e.x+e.width,e.y)
				 moveAnchors(e)

				 }
				 });
				 */

				if ((call_type == 'dragging')) {
					elem.x += line[0];
					elem.y += line[1];
				} 
				/*
				else if (call_type == 'topLeft') {
					elem.x += line[0];
					elem.y += line[1];

					elem.height += Math.max(line[1], line[0] / elem.aspect_ratio)
					elem.width += Math.max(line[0], line[1] * elem.aspect_ratio)
				}
				*/

				elem.img.setPosition(elem.x, elem.y)
				//elem.img.setWidth(elem.width,elem.height)
				elem.state_img.setPosition(elem.x + elem.width, elem.y)
				moveAnchors(elem)

			}

		});


		$.each(elem.anchors, function(i, a) {
			a.moveToTop()
		});
		
		elem.img.getLayer().draw()

	}

}

function setStroke(shape, enabled, width, color_blend) {
	shape.attrs.strokeEnabled = enabled
	shape.setStrokeWidth(width)

	shape.setStrokeR(Math.round(255 * (1 - color_blend)))
	shape.setStrokeG(0)
	shape.setStrokeB(Math.round(255 * (color_blend)))

}

function getOverlap(shape1, shape2) {
	var p1 = shape1.getPosition()
	var p2 = shape2.getPosition()
	var x11 = p1.x, y11 = p1.y, x12 = p1.x + shape1.getWidth(), y12 = p1.y + shape1.getHeight(), x21 = p2.x, y21 = p2.y, x22 = p2.x + shape2.getWidth(), y22 = p2.y + shape2.getHeight()

	x_overlap = Math.max(0, Math.min(x12, x22) - Math.max(x11, x21))
	y_overlap = Math.max(0, Math.min(y12, y22) - Math.max(y11, y21));
	var ol1 = (x_overlap * y_overlap) / (shape1.getWidth() * shape1.getHeight())
	var ol2 = (x_overlap * y_overlap) / (shape2.getWidth() * shape2.getHeight())

	return Math.max(ol1, ol2)

}

function showBackgroundControls() {
	if ($('#canvas').data("modificationsEnabled")) {
		$('#background_controls').show()
		//$('#canvas').data("design").background_elem.img.attrs.draggable=true
		//$('#canvas').data("design").background_elem.img.attrs.strokeEnabled=true
		$('#element_controls').hide()
		
		//if ($('#canvas').data("design").background_fname=='')
		//	$('#offset_controls').hide()
		
		$('#canvas').data("design").background_elem.img.getLayer().draw()
	}

}

function hideBackgroundControls() {
	if ($('#canvas').data("modificationsEnabled")) {
		console.log("hideBackgroundControls")
		//$('#canvas').data("design").background_elem.img.attrs.strokeEnabled=false
		$('#background_controls').hide()
		//$('#canvas').data("design").background_elem.img.attrs.draggable=false
		
		$('#canvas').data("design").background_elem.img.getLayer().draw()
		
	}

}


function showElementControls() {
	if ($('#canvas').data("modificationsEnabled")) {
		hideBackgroundControls() 
		$('#element_controls').show()
	}
}

function moveAnchors(elem) {

	$.each(elem.anchors, function(i, a) {
		if (a.attrs.name == 'bottomLeft') {
			a.setX(elem.img.getAbsolutePosition().x)
			a.setY(elem.img.getAbsolutePosition().y)
		}
		if (a.attrs.name == 'bottomRight') {
			a.setX(elem.img.getAbsolutePosition().x + elem.img.getWidth())
			a.setY(elem.img.getAbsolutePosition().y)
		}
		if (a.attrs.name == 'topLeft') {
			a.setX(elem.img.getAbsolutePosition().x)
			a.setY(elem.img.getAbsolutePosition().y + elem.img.getHeight())
		}
		if (a.attrs.name == 'topRight') {
			a.setX(elem.img.getAbsolutePosition().x + elem.img.getWidth())
			a.setY(elem.img.getAbsolutePosition().y + elem.img.getHeight())
		}

		if (a.attrs.name == 'midRight') {
			a.setX(elem.img.getAbsolutePosition().x + elem.img.getWidth() - 6)
			a.setY(elem.img.getAbsolutePosition().y + elem.img.getHeight() / 2)
		}
		if (a.attrs.name == 'midLeft') {
			a.setX(elem.img.getAbsolutePosition().x - 6)
			a.setY(elem.img.getAbsolutePosition().y + elem.img.getHeight() / 2)
		}

	});

}

function createNewElement(type, img, fname) {

	if ((type == 'text') && $('#user_text').val() == '') {
		alert("Please enter the text before clicking to position")
		return
	}

	console.log("Creating new element")

	var mousePos = $('#canvas').data("stage").getPointerPosition()

	var elem = {}

	elem.loaded = false
	elem.resizing = false
	elem.fixed = false
	elem.align_type = -1
	elem.num_lines = 0
	//elem.num_align=-1
	elem.selected = true
	elem.old_text = ''
	elem.type = type
	elem.id = -1
	elem.fixed_amount = 0.5
	elem.alternate_id = 0
	elem.optional = false

	if (mousePos == undefined) {
		elem.x = 0
		elem.y = 0
	} else {
		elem.x = mousePos.x
		elem.y = mousePos.y
	}

	if (fname != undefined)
		elem.fname = fname

	elem.group_id = $("#group_select").val()
	elem.importance = $("#importance_select").val()

	var max_id = 0;
	$.each($('#canvas').data("design").elements, function(i, e) {
		max_id = Math.max(max_id, parseInt(e.id))
	});
	elem.id = max_id + 1

	$('#canvas').data("design").elements.push(elem)

	//design.elements.sort(function(e1,e2){return e1.importance-e2.importance})
	//var max_id=-1;
	//$.each($('#canvas').data("design").elements, function(i,e){
	//	max_id
	//});

	var layer = $('#canvas').data("stage").get('#layer')[0];
	var sugg_layer = $('#canvas').data("sugg_stage").get('#sugg_layer')[0];

	//if ($('#canvas').data("suggestionsEnabled"))
	setupLockingCallbacks(elem, layer)

	if (elem.type == 'graphic') {

		$('#canvas').data("user_input_log").push("Add Graphic")
		$('#canvas').data("status_log").push("Add Graphic")

		elem.type_id = 2;
		elem.height = 100;
		setupImageElement(elem, img, layer, sugg_layer, false);

		overlap = {}
		overlap.elem_id = elem.id
		overlap.x_min = 0
		overlap.y_min = 0
		overlap.x_max = 1
		overlap.y_max = 1

		$('#canvas').data("design").overlap_regions.push(overlap)

		sendCurrentDesign();

	}
	if (elem.type == 'text') {
		$('#canvas').data("user_input_log").push("Add Text")
		$('#canvas').data("status_log").push("Add Text")

		elem.type_id = 1;
		elem.font = $('#font_select').data("font");
		elem.bold = $("#bold_select").attr("checked") == 'checked';
		elem.italic = $("#italic_select").attr("checked") == 'checked';
		elem.shadow = $("#shadow_select").attr("checked") == 'checked';
		elem.fix_alignment = $("#fix_select").attr("checked") == 'checked';
		elem.fix_alternate = $("#num_lines_fix_select").attr("checked") == 'checked';
		elem.color = $('#color_select').val();
		elem.text = $('#user_text').val();

		if (elem.text == '')
			return;

		elem.align = ""

		$(".align_select.active").each(function() {
			console.log(this);
			elem.align = this.value
		});

		elem.sugg_align = elem.align;

		console.log("Creating with alignment: " + elem.align)

		elem.num_lines = elem.text.split("\n").length;
		console.log('num_lines ' + elem.num_lines)
		elem.height = 25 * (elem.num_lines);

		//renderTextElement(elem,true,true);
		renderTextAlts(elem, true)

		setTimeout(function() {
			sendCurrentDesign();
			resumeSuggestions();
		}, 500)

	}

	console.log("setting element id to " + elem.id)

	deleteGallery()

	//deselectAll(elem)
	//$('#canvas').data("selected",elem)

	layer.draw();
	sugg_layer.draw();

	//$('#canvas').data("selected",elem);
	//elem.img.attrs.strokeEnabled=true;
	selectElement(elem, false);

}

function setControls(elem) {

	$('#canvas').data("settingControls", true);

	if (elem.type == 'region') {
		console.log("Setting controls for region: " + elem.id);
		$("#region_text_select").prop("checked", elem.allow_text)
		$("#region_graphic_select").prop("checked", elem.allow_graphic)
		$("#region_overlap_select").prop("checked", elem.allow_overlap)
	} else {
		console.log("Setting controls for element: " + elem.id + " with type " + elem.type);

		//$("#font_select").val(elem.font);
		$("#font_select").data("font", elem.font)

		$("#font_select").find('span').html(elem.font);
		$("#font_select").css('font-family', elem.font);

		console.log("setting font:" + elem.font)

		$("#group_select").val(elem.group_id).attr('selected', true);
		$("#importance_select").val(elem.importance).attr('selected', true);
		$("#bold_select").prop("checked", elem.bold)
		$("#italic_select").prop("checked", elem.italic)
		$("#shadow_select").prop("checked", elem.shadow)
		$("#fix_select").prop("checked", elem.fix_alignment)
		$("#num_lines_fix_select").prop("checked", elem.fix_alternate)
		
		
		if (elem.color!=undefined)
		{
			$('#color_select').val(cutHex(elem.color));
			$('#color_select').css("background-color",'#'+cutHex(elem.color))
			
			
			if (hexToV(elem.color)<100)
				$('#color_select').css("color",'#FFF')
			else
				$('#color_select').css("color",'#000')
		}
		
		$("#optional_select").prop("checked", elem.optional)
		$("#hidden_select").prop("checked", elem.hidden)
		$('#user_text').val(elem.text);

		$("#overlap_select").prop("checked", elem.allow_overlap)

		if (elem.type=='text')
			$("#overlap_mod").hide()
		else
			$("#overlap_mod").show()
		/*
		 if (elem.type=='graphic')
		 $('#user_text').hide()
		 else
		 $('#user_text').show()
		 */
		if (elem.type=='text')
			 $("#fontSizeInput").val((elem.height/elem.init_height)*elem.init_font_size)
		

		$("#num_lines_select").val(elem.num_lines).attr('selected', true);

		$(".align_select").each(function() {
			//console.log(this);
			if (this.value == elem.align)
				this.click()
		});
	}
	console.log("Finished setting controls for element: " + elem.id);

	$('#canvas').data("settingControls", false);
}

function regionControlsChanged() {
	console.log("region controls changed")

	if ($('#canvas').data("settingControls"))
		return;

	var elem = $('#canvas').data("selected")

	elem.allow_text = $("#region_text_select").attr("checked") == 'checked'
	elem.allow_graphic = $("#region_graphic_select").attr("checked") == 'checked'
	elem.allow_overlap = $("#region_overlap_select").attr("checked") == 'checked'

	elem.img.setFill(getRegionColor(elem))
	elem.img.getLayer().draw()

	sendCurrentDesign();

}

function numLinesChanged() {
	selectAlternateElement($('#canvas').data("selected"), $("#num_lines_select").val())

}

function fontSelected(font) {

	var splt = font.split(",")
	var fontName = splt[0]
	fontName = fontName.split("'").join('');
	console.log("clicked: " + fontName)
	$('#font_select').data("font", fontName)
	controlsChanged()

}

function controlsChanged(new_val) {

	console.log("controls changed")

	if ($('#canvas').data("settingControls"))
		return;

	var elem = $('#canvas').data("selected")

	if ((elem == undefined) || (elem.type == "background"))
		return;

	if (new_val != undefined) {
		$('#canvas').data("user_input_log").push("Align-" + new_val)
		$('#canvas').data("status_log").push("Align-" + new_val)
	}

	console.log("selected " + elem.id)

	var changed_design = false;
	var changed_text = false;
	var changed_alignment = false;
	var alignments = ["left", "center", "right"];

	elem.old_text = elem.text;

	if (elem.type == 'text') {
		var bold = $("#bold_select").attr("checked") == 'checked'
		var italic = $("#italic_select").attr("checked") == 'checked'
		var shadow = $("#shadow_select").attr("checked") == 'checked'
		var fix_alignment = $("#fix_select").attr("checked") == 'checked'
		var fix_alternate = $("#num_lines_fix_select").attr("checked") == 'checked'
		var optional = $("#optional_select").attr("checked") == 'checked'
		var hidden = $("#hidden_select").attr("checked") == 'checked'

		if (bold != elem.bold) {
			console.log("bold changed from " + elem.bold + " to " + bold)

			elem.bold = bold;
			changed_text = true;
			changed_design = true;
		}

		if (shadow != elem.shadow) {
			console.log("shadow changed from " + elem.shadow + " to " + shadow)
			elem.shadow = shadow;
			changed_text = true;

		}

		if (fix_alternate != elem.fix_alternate) {
			console.log("fix_alternate changed from " + elem.fix_alternate + " to " + fix_alternate)
			elem.fix_alternate = fix_alternate;
			changed_design = true;
		}
		if (optional != elem.optional) {
			console.log("optional changed from " + elem.optional + " to " + optional)
			elem.optional = optional;
			changed_design = true;
		}
		if (hidden != elem.hidden) {
			console.log("hidden changed from " + elem.hidden + " to " + hidden)
			elem.hidden = hidden;
			//changed_design=true;

			if (elem.hidden) {

				elem.hidden_img = elem.img.getImage()
				elem.img.setImage(0)
				//elem.img.setFillEnabled(false)
				//elem.img.hide()
			} else {
				//console.log(elem.hidden_img)
				elem.img.setImage(elem.hidden_img)
				elem.hidden_img = 0
				//elem.img.show()
				//elem.img.setFillEnabled(true)

			}

			elem.img.getLayer().draw();
			changed_design = true;
		}

		if ($("#color_select").val() != elem.color) {
			console.log("color changed from " + elem.color + " to " + $("#color_select").val())
			elem.color = $("#color_select").val();
			changed_text = true;
		}

		if ($('#font_select').data("font") != elem.font) {
			console.log("font changed from " + elem.font + " to " + $('#font_select').data("font"))
			elem.font = $('#font_select').data("font");
			changed_text = true;
		}

		if ($("#user_text").val() != elem.text) {
			console.log("text changed from " + elem.text + " to " + $("#user_text").val())

			elem.text = $("#user_text").val();
			changed_text = true;
		}

		if (fix_alignment != elem.fix_alignment) {
			console.log("fix_alignment changed from " + elem.fix_alignment + " to " + fix_alignment)
			elem.fix_alignment = fix_alignment;

			$(".align_select.active").each(function() {
				//console.log(this);
				elem.align_type = alignments.indexOf(this.value)
				elem.align=this.value
				//console.log("setting alternate to "+elem.alternate)
			});

			changed_design = true;
		}

		if ((elem.num_lines > 1) && (new_val != undefined) && (new_val != elem.align)) {
			elem.align = new_val
			console.log("Setting new alignment: " + elem.align);

			var layer = elem.img.getLayer();
			var orig_img = elem.img;
			elem.img.remove();
			elem.img = elem.alignment_imgs[new_val];
			elem.img.show();
			//elem.alternate=alignments.indexOf(new_val)

			elem.align_type = alignments.indexOf(new_val)

			elem.img.setX(orig_img.getAbsolutePosition().x)
			elem.img.setY(orig_img.getAbsolutePosition().y)
			elem.img.setHeight(orig_img.getHeight())
			elem.img.setWidth(orig_img.getWidth())
			elem.img.attrs.strokeEnabled = orig_img.attrs.strokeEnabled

			layer.add(elem.img);

			$.each(elem.anchors, function(i, a) {
				a.moveToTop();
			});

			layer.draw();

			//changed_text=true;
			changed_alignment = true;

			elem.fix_alignment = true;

			changed_design = true;

			$("#fix_select").prop("checked", true)

		}

		if (changed_text) {
			updateTextElement(elem)
		}

	}
	//graphical elements
	else
	{
		console.log("allow_overlap for element "+elem.id)
		
		var allow_overlap = $("#overlap_select").attr("checked") == 'checked'
		if (allow_overlap != elem.allow_overlap) 
		{
			elem.allow_overlap = allow_overlap;
			
			var design=$('#canvas').data("design")
			var or_idx=-1;
			$.each(design.overlap_regions , function (i,or) {

				if (or.elem_id==elem.id)
				{
					or_idx=i;
					console.log("matched "+or.elem_id+ " at index "+or_idx)	
				}
		
			});
			
			if (or_idx>-1)
			{
				console.log(design.overlap_regions[or_idx])	
				design.overlap_regions.splice(or_idx,1)
				
			}
			
			if (!allow_overlap)
			{
				console.log("!allow_overlap")
				overlap = {}
				overlap.elem_id = elem.id
				overlap.x_min = 0
				overlap.y_min = 0
				overlap.x_max = 1
				overlap.y_max = 1
				design.overlap_regions.push(overlap)
				
				console.log(design.overlap_regions)
			}
			
		
				//overlap = overlap + or.elem_id + "," + Math.round(or.x_min * 1000) / 1000 + "," + Math.round(or.x_max * 1000) / 1000 + "," + Math.round(or.y_min * 1000) / 1000 + "," + Math.round(or.y_max * 1000) / 1000 + "\n"
		
			sendCurrentDesign();
		}
			
			
		
	}

	if ($("#group_select").val() != elem.group_id) {
		elem.group_id = $("#group_select").val();
		sendCurrentDesign();
	}
	if ($("#importance_select").val() != elem.importance) {
		elem.importance = $("#importance_select").val();
		sendCurrentDesign();
	}
	
	
	
	

	if ((changed_design) || (changed_text))
		setTimeout(function() {
			sendCurrentDesign();
		}, 200)

	if (changed_alignment)
		sendCurrentLayout('Align');

}

function checkForSuggestions() {

	var runs = $('#canvas').data("runs")

	var design=$('#canvas').data("design")
	var dir_name=design.name+"_"+design.width+"_"+design.height


	$.each(runs, function(i, run) {
		if (run.id > -1)
		{
			
			if (run.type=='gallery')
			{
				var last_gallery_check=$('#canvas').data("last_gallery_check")
				var curr_time=new Date().getTime()
				
				if ((last_gallery_check!=undefined) && (curr_time-last_gallery_check<2000))
					return
					
				$('#canvas').data("last_gallery_check",curr_time)
				
			}
			
			getLayoutFromServer(run.id, run.type,dir_name);
			
		}
	});
	/*
	 if ($('#suggLayout').data('runID')>=0)
	 {
	 getLayoutFromServer($('#canvas').data("design").name,$('input[name=userID]').val());
	 }
	 */

}

function getCurrentLayout(reset) {
	var design = $('#canvas').data("design")

	var layout = design.name+'\n';
	
	var scale = 1.0;
	layout += Math.round(design.width / scale) + "," + Math.round(design.height / scale) +'\n'+ (design.elements.length) + "\n";

	
	var constraints={}
	
	var type_map={'size':10,'alignment':11}
	
	var cons_str=''

	for (var i = 0; i < design.elements.length; i++) {
		var elem = design.elements[i];

		//var fixed=(elem.fixed);
		//var fixed=(elem.fixed || elem.selected);
		if (elem.alternate_id == -1)
			elem.alternate_id = 0

		var fix_amount = (Math.round((elem.fixed_amount) * 1000) / 1000)
		
		if (elem.hidden)
			fix_amount = -1;

		
		// && $('#canvas').data("automaticUpdate")
		if ((elem.selected))
			if (fix_amount==1)
				fix_amount = 1.05;
			else
				fix_amount = 0.95;
				
		//if ((!reset) &&(fix_amount==0) &&($('#canvas').data("automaticUpdate")))
		//	fix_amount=0.01
			
		if ((!reset) &&(fix_amount==0))
			fix_amount=0.5
				
		
		$.each(elem.constraints,function(type,cons){

			if (cons.length>0)
			{
				console.log("constraint ")
				console.log(cons)
				
				cons_str+=elem.id+","+type_map[type]+","+cons.length+","
				for (var j=0;j<cons.length;j++)
					cons_str+=cons[j]+","
				cons_str=cons_str.substring(0,cons_str.length-1)+"\n"
			}
		
		});
		
			
		//if ((fix_amount<0.05) &&(!$('#canvas').data("automaticUpdate")))
		//	fix_amount=0.0

		layout += Math.round(elem.x / scale) + "," + Math.round(elem.y / scale) + "," + Math.round(elem.height / scale) + "," + elem.align_type + "," + fix_amount + ",-1," + (elem.hidden ? -1 : elem.alternate_id) + "\n"
	}

	var lines = $('#canvas').data("align_lines");

	if (lines.length >= 1) {
		var selected_element = false;
		for (var i = 0; i < design.elements.length; i++) {
			if ((design.elements[i].id == lines[0][1]) && (design.elements[i].selected))
				selected_element = true;
		}

		if (selected_element) {
			//layout += lines.length + ' lines\n'

			$.each(lines, function(i, al) {
				var aligned_elem = al[3];
				//console.log("al:"+al)
				cons_str += al[1] + "," + al[2] + "," + aligned_elem.length + ","
				for (var i = 0; i < aligned_elem.length; i++)
					cons_str += aligned_elem[i] + ","
				cons_str = cons_str.slice(0, -1) + "\n"
			});
		} //else
		//	layout += '0 lines\n'
	} //else
	//	layout += '0 lines\n'

	//console.log("constraints:\n"+cons_str)

	var num_constraints=cons_str.split("\n").length-1
	layout += num_constraints+' constraints\n'
	layout += cons_str
	
	
	if (reset==true)
		layout += '-2 regions\n'
	else
		layout += '-1 regions\n'
	return layout
	//console.log("layout:\n"+layout);

}

function sendCurrentLayout(user_input, reset,run_id) {

	console.log("sendCurrentLayout "+user_input)

	var layout = getCurrentLayout(reset)
	
	if (user_input!=undefined)
	{
		$('#canvas').data("layout_log").push(['user-'+user_input,new Date().getTime(),layout,";"])
		makeSuggestions()
	}
	
	
	console.log("curr_layout: "+layout) 

	$('#report').hide()
	$('#reportStatus').text("")
	
	//addLayoutToStack(layout,'user')
	addLayoutToStack(layout)
	//console.log("curr layout:" + layout)


	var layout_counter=$('#canvas').data("layout_counter")
	if (layout_counter==undefined)
		layout_counter=0;
	$('#canvas').data("layout_counter",layout_counter+1)
 	
 	layout=layout_counter+"\n"+layout
 	
 	
 	console.log("new counter: "+layout_counter)
 	
 	$('#userLayout').val(layout)

	

	if (run_id==undefined){
		console.log("sending to all");
		$.each($('#canvas').data("runs"), function(i, run) {
			if (run.id > -1) {
				sendLayoutToServer(run.id, layout);
			}
		});
		
		$('#canvas').data("energy", 9999)
		$('#canvas_energy').text(9999)
	}
	else
		sendLayoutToServer(run_id, layout);
		
	allowUpdates()


	
}

function sendCurrentDesign() {
	console.log("sendCurrentDesign")
	var design = getCurrentDesign();
	$.each($('#canvas').data("runs"), function(i, run) {
		updateDesignOnServer(run.id, design)
		run.energy = 99999;
	});

}

function getCurrentDesign() {
	//console.log('getCurrentDesign')

	var design = $('#canvas').data("design")


	var dstring = design.name+'\n';
	
	
	var scale = 1.0;
	dstring += Math.round(design.width / scale) + "," + Math.round(design.height / scale) +'\n'+ (design.elements.length) + "\n";


	dstring = dstring + "0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,1,background\n";

	var graphic_ids=[]

	for (var i = 0; i < design.elements.length; i++) {

		var elem = design.elements[i];
		
		if (elem.type=='graphic')
		 	graphic_ids.push(elem.id)

		if (elem.alternate_id == -1)
			elem.alternate_id = 0

		/*
		var fix_amount = (Math.round((elem.fixed_amount) * 100) / 100)
		if (elem.hidden)
			fix_amount = -1;

		if ((elem.anchors["topLeft"].attrs != undefined) && (elem.anchors["topLeft"].attrs.visible))
			fix_amount = 1;
		*/
		fix_amount = 0;
			
		var alignments = ["left", "center", "right"];
		var a_type=	alignments.indexOf(elem.align)

		dstring = dstring + (elem.id) + ",";
		dstring = dstring + elem.type_id + ",";
		dstring = dstring + elem.importance + ",";
		dstring = dstring + elem.num_lines + ",";
		dstring = dstring + elem.group_id + ",";
		dstring = dstring + (Math.round((1 / elem.aspect_ratio) * 1000) / 1000) + ',';
		dstring = dstring + Math.round(elem.x / scale) + ',';
		dstring = dstring + Math.round(elem.y / scale) + ',';
		dstring = dstring + Math.round(elem.height / scale) + ',';
		dstring = dstring + a_type + ",";
		dstring = dstring + fix_amount + ",";
		dstring = dstring + (elem.fix_alternate ? 0 : elem.alternate_id ) + ",";
		dstring = dstring + (elem.fix_alignment ? 1 : 0 ) + ",";
		dstring = dstring + (elem.optional ? 1 : 0 ) + ",";
		dstring = dstring + "0,1,0,1," + elem.fname + "\n";

		//console.log("aspect ratio "+(Math.round((1/elem.aspect_ratio)*1000)/1000))

		//if (elem.img)
		//	console.log('element +'+i+' x: '+elem.img.getPosition().x+ ' y: '+elem.img.getPosition().y)
	}

	var overlap = '';
	var overlap_cnt=0;

	for (var i = 0; i < design.overlap_regions.length; i++) {
		var or = design.overlap_regions[i];

		if ($.inArray(or.elem_id,graphic_ids)>-1)
		{
			overlap = overlap + or.elem_id + "," + Math.round(or.x_min * 1000) / 1000 + "," + Math.round(or.x_max * 1000) / 1000 + "," + Math.round(or.y_min * 1000) / 1000 + "," + Math.round(or.y_max * 1000) / 1000 + "\n"
			overlap_cnt++;
		}
	}

	dstring += (overlap_cnt) + " overlap regions\n" + overlap;

	var num_alts = 0;
	var alt_string = ''
	$.each(design.element_alts, function(id, alts) {

		var alt_str = id + "," + Object.keys(alts).length + ","

		$.each(design.elements, function(i, elem) {
			if ((id == elem.id) && (!elem.fix_alternate)) {
				num_alts++
				$.each(alts, function(num_lines, alt_elem) {
					alt_str += alt_elem.num_lines + "," + (Math.round((1 / alt_elem.aspect_ratio) * 1000) / 1000) + "," + alt_elem.max_line_length + ","
				});
				alt_string += alt_str + "\n"
			}
		});

	});

	dstring += num_alts + " alternates\n"
	dstring += alt_string;

	//console.log("sending current design:\n "+dstring);

	return dstring

}

function setSuggestionLayout(run_id, new_layout, new_energy) {
	var design = $('#canvas').data("design");


	var run = $('#canvas').data("runs")[run_id]


	//var gallery_layouts=$('#canvas').data("gallery_layouts");
	//var gallery_images=$('#canvas').data("gallery_images");
	//var gallery_designs=$('#canvas').data("gallery_designs");
	
	var sequence=((run.type.search("gallery") > -1) ||(run.type.search("nio") > -1))

	if ((run.layout != new_layout) && (new_energy<9999) &&((run.energy != new_energy ) ||sequence )) {

		//console.log("setting new layout for run_id "+run_id)//+" new_layout: "+new_layout)
		//console.log("old energy "+run.energy+" new energy "+new_energy)

		
		//console.log("canvas id:"+run.canvas_id )

		if (run.canvas_id < 0)
		{
			return;
			
		}

		var alignments = ["left", "center", "right"];

		var elements = new_layout.split("\n");
		var elem_cnt = parseInt(elements[3])
		if (elem_cnt != design.elements.length)
		{
			console.log("count mismatch")
			return;
		}
		
		var design_sizes = elements[2].split(",")
		var layout_width=parseInt(design_sizes[0])
		var layout_height=parseInt(design_sizes[1])
		
		if ((layout_width!= design.width) || (layout_height!=design.height))
		{
			console.log("layout_width:"+ layout_width)
			console.log("layout_height:"+ layout_height)
			console.log("design.width:"+ design.width)
			console.log("design.height:"+ design.height)
			return;
		}



	
		var curr_time=new Date().getTime()
		var start_time=$('#canvas').data("startRenderTime")
		
		if ((curr_time!=undefined)&& (curr_time!=0) && (curr_time-start_time<5000))
		{
			console.log("still rendering. check back later...")
			setTimeout(function(){setSuggestionLayout(run_id,new_layout,new_energy);}, 500);
			return
		}
		else
			$('#canvas').data("startRenderTime",curr_time)
		
	
	
	
		console.log("setting new layout for run "+run_id)
	
		run.layout = new_layout
		run.energy = new_energy

		if (run.type != 'gallery')
			$('#suggestion_layout' + String(run.canvas_id)).data("layout", new_layout)
		
		
		
		var sugg_layer = $('#canvas').data("sugg_stage").get('#sugg_layer')[0];

		for (var i = 4; i < design.elements.length + 4; i++) {

			var elem = design.elements[i - 4];

			var elem_split = elements[i].split(',');

			var alt_id = parseInt(elem_split[6]);

			var alt_elem = elem;
			
			if ("sugg_img" in alt_elem)
				alt_elem.sugg_img.remove();

			if ((!elem.fix_alternate) && (elem.id in design.element_alts)) {
				$.each(design.element_alts[elem.id], function(num_lines, ae) {
					if (alt_id == ae.alternate_id) {
						alt_elem = ae;
						//console.log("found "+(i)+" num_lines "+num_lines+ " alt id "+ae.alternate_id)
					}

					ae.sugg_img.remove();
				});
			}

			if (alt_elem.num_lines > 1) {
				var a = parseInt(elem_split[3])

				var align;
				if (a > -1)
					align = alignments[a]
				else
					align = elem.align

				alt_elem.sugg_align = align;
				alt_elem.sugg_img = alt_elem.alignment_sugg_imgs[align];
			}

			if (alt_id < 0) {
				continue;
			}

			//console.log("added "+(i))
			sugg_layer.add(alt_elem.sugg_img);

			var height = parseInt(elem_split[2]);
			var width = height * alt_elem.aspect_ratio;

			alt_elem.sugg_img.setX(parseInt(elem_split[0]));
			alt_elem.sugg_img.setY(parseInt(elem_split[1]));
			alt_elem.sugg_img.setHeight(height);
			alt_elem.sugg_img.setWidth(width);

			//if (alt_id!=-1)
			alt_elem.sugg_img.show()
			//else
			//	alt_elem.sugg_img.hide()

			//console.log("setting "+i+ " "+parseInt(elem_split[0])*4.0+ " "+ parseInt(elem_split[1])*4.0+" "+height+" "+width+" "+elem.aspect_ratio);
		}

		sugg_layer.draw();

		//console.log("draw")

		var sugg_stage = sugg_layer.getStage();
		sugg_stage.toDataURL({
			callback : function(dataUrl) {
				var img = new Image();

				img.onload = function() {

					run.image = img;

					if ($("#canvas").data("preview") == run.canvas_id) {
						$('#canvas').data("preview_image").attrs.fillPatternImage = img
						$('#canvas').data("preview_image").getLayer().draw()
					}

					if ((run.type == 'gallery')|| (run.type == 'nio')) {
						
						
						
						var count = $("#gallery_table").children().children().length;

						var new_layout_elem = $('#gallery_layout0').clone()
						new_layout_elem.show()
						new_layout_elem.data("preview_image", img);
						new_layout_elem.data("layout", new_layout);
						new_layout_elem.attr("id", "gallery_layout" + count)
						
						new_layout_elem.attr("width",sugg_stage.attrs.width / 3)
						new_layout_elem.attr("height",sugg_stage.attrs.height / 3)
						
						new_layout_elem.mouseover(function() {
							viewLayout('gallery', count)
						})
						new_layout_elem.click(function() {
							setFixedLayout('gallery', count)
						})
						//new_layout_elem.dblclick(function() {setFixedLayout('gallery',count)})

						var canvas = new_layout_elem[0];
						var ctx = canvas.getContext("2d")
						ctx.drawImage(img, 0, 0, sugg_stage.attrs.width / 3, sugg_stage.attrs.height / 3);
						$('#gallery_table').append($('<tr>').append($('<td>').append(new_layout_elem)))
						new_layout_elem.parent().addClass("suggestion")

					} else {

						
						$('#suggestion_layout' + run.canvas_id).data("preview_image", img)
						
						var canvas = $('#suggestion_layout'+(run.canvas_id));
						canvas.attr("width",sugg_stage.attrs.width/3)
						canvas.attr("height",sugg_stage.attrs.height/3)
						canvas.show()
						
						var ctx = canvas[0].getContext("2d")

						ctx.clearRect(0, 0, sugg_stage.attrs.width / 3, sugg_stage.attrs.height / 3);
						ctx.drawImage(img, 0, 0, sugg_stage.attrs.width / 3, sugg_stage.attrs.height / 3);
						
						
						if ($('#suggestion_layout' + run.canvas_id).hasClass("selectedPreview"))	
						{		
							if (sugg_stage.attrs.width>sugg_stage.attrs.height)
								ctx.drawImage($('#canvas').data("images")['accept_suggestion'], 30,0);
							else	
								ctx.drawImage($('#canvas').data("images")['accept_suggestion'], 0, 30);
						}
						
					}
					
					$('#canvas').data("startRenderTime",0)	

				}

				img.src = dataUrl
			}
		});

	}

}

function createNewRegion(x, y, w, h, graphic, text, overlap) {
	region = {}
	region.type = 'region'
	region.id = 'region'
	region.x = x
	region.y = y
	region.width = w
	region.height = h
	region.allow_graphic = graphic
	region.allow_text = text
	region.allow_overlap = overlap
	region.selected = false
	region.fixed_amount = 0

	return region
}

function getLayoutDiff(layout1, layout2) {
	if ((layout1 == undefined) || (layout2 == undefined) || (layout1 == '') || (layout2 == ''))
		return 10000;
		
	var idx1=layout1.indexOf("design_")
	var idx2=layout2.indexOf("design_")
	
	layout1=layout1.slice(idx1,layout1.length)
	layout2=layout2.slice(idx2,layout2.length)
	
	var elements1 = layout1.split("\n");
	var elements2 = layout2.split("\n");

	var num_elements = parseInt(elements1[2])

	if (num_elements != parseInt(elements2[2]))
		return 10000;
	//console.log("layout1:"+layout1)
	//console.log("layout2:"+layout2)
	
	
	var diff_sum = 0;

	for (var i = 3; i < num_elements + 3; i++) {
		
		var elem1_split = elements1[i].split(',');
		var elem2_split = elements2[i].split(',');

		//console.log(elem1_split)
		//console.log(elem2_split)

		for (var j = 0; j < 3; j++)
			diff_sum += Math.abs(elem1_split[j] - elem2_split[j])

		//diff_sum+=5*Math.abs(elem1_split[3]-elem2_split[3])

	}

	//console.log("diff_sum:"+diff_sum)

	return diff_sum;

}

function addLayoutToStack(new_layout,stack_type) {

	var idx;
	var stack;

	//console.log("addLayoutToStack "+new_layout)

	if (stack_type=='user')
	{
		idx = $('#canvas').data("user_layout_stack_idx");
		stack = $('#canvas').data("user_layout_stack");
		//console.log("user_layout_stack")
	}
	else
	{
		idx = $('#canvas').data("layout_stack_idx");
		stack = $('#canvas').data("layout_stack");
		//console.log("layout_stack")
	}
	

	
	if ((stack.length>0) && (getLayoutDiff(stack[stack.length-1][0],new_layout)<1))
	{
		//console.log("duplicate layout, not added to stack")
		return;	
	}
		
	
	//console.log("pre stack length:"+stack.length)

	//stack.push([new_layout, getCurrentDesign()])
	
	if (idx != stack.length - 1)
	{
		//console.log("slicing stack from 0 to "+(idx+1))
		stack = stack.slice(0, idx+1);
		
	}
	
	
	
	if (stack_type=='user')
	{
		var elem_info=[]
		$.each($('#canvas').data("design").elements, function(i, elem) {
			elem_info.push({'fixed_amount':elem.fixed_amount,'selected':elem.selected })
		});
		stack.push([new_layout, elem_info])
		
		$('#canvas').data("user_layout_stack_idx", stack.length - 1)
		$('#canvas').data("user_layout_stack", stack)
	}
	else
	{
		
		console.log("new idx:"+(stack.length - 1))
		stack.push([new_layout, undefined])
		
		$('#canvas').data("layout_stack_idx", stack.length - 1)
		$('#canvas').data("layout_stack", stack)
	}

	if (stack.length > 1)
	{
		if (stack_type=='user')
			$('#reportUndoButton').fadeTo(0, 1)
		else 
			$('#undoButton').fadeTo(0, 1)
	}
		

}

function setCurrentLayout(new_layout, set_fixed, undoing,render_info,playback) {

	if (undoing==undefined)
		undoing=false
		

	console.log("setCurrentLayout")
	
	if (new_layout==undefined)
	{
		console.log("ERROR. layout undefined.")
		return
	}

	if (((set_fixed == false)) || ($('#canvas').data("dragging")))
		return

	var design = $('#canvas').data("design")
	var layout = $('#canvas').data("layout");

	var alignments = ["left", "center", "right"];

	if (layout != new_layout) {

		if (!undoing) {
			addLayoutToStack(new_layout)
		}
		//console.log("setting new layout")


		console.log("setting current layout:" + new_layout)
		
		var idx=new_layout.indexOf("design_")
		//console.log("idx:"+idx)
		if (idx==0)
			new_layout='0\n'+new_layout

		//console.log("here")
		var elements = new_layout.split("\n");
		var elem_cnt = parseInt(elements[3])

		//console.log("elem_cnt "+elem_cnt+" design.elements.length "+design.elements.length)

		if (elem_cnt != design.elements.length)
			return;
			
			
		var design_sizes = elements[2].split(",")
		var layout_width=parseInt(design_sizes[0])
		var layout_height=parseInt(design_sizes[1])
		
		if ((layout_width!= design.width) || (layout_height!=design.height))
		{
			console.log("layout_width:"+ layout_width)
			console.log("layout_height:"+ layout_height)
			console.log("design.width:"+ design.width)
			console.log("design.height:"+ design.height)
			return;
		}
			
		if (undoing)
			$('#canvas').data("layout_log").push(['user-Undo/Redo',new Date().getTime(),new_layout,";"])
		else
			$('#canvas').data("layout_log").push(['sugg',new Date().getTime(),new_layout,";"])

		var layer = $('#canvas').data("stage").get('#layer')[0];

		//layer.removeChildren()
		
		var fixed_count=0;

		for (var i = 0; i < design.elements.length; i++) {

			//console.log("design.elements.length: "+design.elements.length)

			var elem = design.elements[i];

			//console.log("elem id: "+elem.id+" selected?"+elem.selected)


				
			if (elem.fixed_amount==1)
				fixed_count+=1;
				
				
			//console.log("elem id: "+elem.id+" selected?"+elem.selected+ " fix_amount:"+fixed_count)

			var elem_split = elements[i+4].split(',');

			if (elem.img == undefined)
				console.log("ERROR on element " + i + " with layout " + elements[i])

			
			var new_height = parseInt(elem_split[2]);
			var new_x = parseInt(elem_split[0])
			var new_y = parseInt(elem_split[1])
			var new_alt_id = parseInt(elem_split[6]);
			var new_align_id=parseInt(elem_split[3])
			
			
			elem.img.attrs.strokeEnabled=false
			
			if (elem.selected){
				
				
				fixed_count+=1;
				//continue
				
				var str= sprintf("checking selected %f %f %f %f %f, %f %f %f %f %f",elem.x,elem.y,elem.height,elem.alternate_id, elem.align_type, new_x,new_y, new_height, new_alt_id, new_align_id )
				
				console.log(str)
				
				if ((elem.type=='graphic') || (Math.round(elem.height)!=new_height) || (Math.round(elem.x)!=new_x) || (Math.round(elem.y)!=new_y) || (new_alt_id!= elem.alternate_id) || (new_align_id ==elem.align_type))
				{
					elem.img.attrs.strokeEnabled=true
					continue
				}
			
				//console.log("updating selected to new align type "+String(new_align_id)+" from type "+String(elem.align_type))
			}
			


			if ((!elem.fix_alternate) && (elem.id in design.element_alts)) {
				$.each(design.element_alts[elem.id], function(num_lines, ae) {
					ae.img.remove()
					//fadeOutImage(ae.img)
					if ((new_alt_id == ae.alternate_id)) {
						
						
						var last_img=elem.img;
						last_img.remove()
						//fadeOutImage(last_img)
						
						ae.fixed_amount = elem.fixed_amount
						ae.state_img = elem.state_img
						design.elements[i] = ae
						
						ae.selected=elem.selected
						ae.img.attrs.strokeEnabled = false;
						ae.img.show()
						ae.img.setPosition(last_img.getPosition())
						
						if  (new_alt_id!= elem.alternate_id)
							ae.img.setOpacity(0)
						
						layer.add(ae.img)
						
						elem = ae;

					}
				});
			}
			
	
			
			

			
			
			var new_width = new_height * elem.aspect_ratio;

			elem.height = new_height
			elem.width = new_width
			elem.x = new_x
			elem.y = new_y
			
			//elem.state_img.show()
			

		
	
			if (undoing)
			{
				setElementState(elem.id,'unlocked')
				elem.state_img.hide()
			}
		
		
			if ((render_info!= undefined) || (playback!=undefined)){
				
				
				
				if (render_info!= undefined)
				{
					fix_amount = render_info[i].fixed_amount
					selected = render_info[i].selected
				}
				else
				{
					fix_amount=parseFloat(elem_split[4]);
					selected= ((fix_amount==0.95) || (fix_amount==1.05))
					
					console.log("fix_amount:"+fix_amount)
					console.log("selected:"+selected)
				}
				
				elem.img.attrs.strokeEnabled=selected
				
				elem.state_img.hide()
								
				if (fix_amount<0.5)
					elem.state_img=elem.unlock_img
				else if (fix_amount<1.0)
					elem.state_img=elem.tweakable_img
				else
					elem.state_img=elem.lock_img
				
				elem.state_img.setPosition(elem.x + elem.width, elem.y)	
					
				elem.state_img.show()
				
			}




			if (elem.num_lines > 1) {

				elem.align_type = new_align_id

				var align;
				if (new_align_id > -1)
					align = alignments[new_align_id]
				else
					align = elem.align

				if (elem.img != elem.alignment_imgs[align]) {
					var layer = elem.img.getLayer();
					
					var last_img=elem.img
					
	
					elem.state_img.setPosition(last_img.attrs.x + last_img.getWidth(), last_img.attrs.y)		
	
					elem.align = align;
					elem.img = elem.alignment_imgs[align];
					elem.img.attrs.strokeEnabled=elem.selected
					elem.img.setHeight(last_img.getHeight())
					elem.img.setWidth(last_img.getWidth())
					elem.img.setPosition(last_img.getPosition())
					elem.img.setOpacity(0)
					elem.img.show()
					layer.add(elem.img);
					
					
					fadeOutImage(last_img,undoing)

				}
			}

				

			//else
			if (playback==undefined)
				elem.img.attrs.strokeEnabled=false

			if ((elem.selected) && $('#canvas').data("automaticUpdate"))
			{
				elem.img.attrs.strokeEnabled=true
				console.log("drawing selected")
			}	

			fadeInElement(elem,undoing)

			setHidden(elem, new_alt_id < 0)
			
			elem.region_id = parseInt(elem_split[5])
		
			

		}

		//set regions
		design.regions = []
		for (var i = elem_cnt + 4; i < elements.length; i++) {
			var reg = elements[i].split(",")
			if (reg.length < 6)
				continue;

			$.each(reg, function(i, r) {
				reg[i] = parseInt(r)
			})
			var region = createNewRegion(reg[1], reg[2], reg[3], reg[4], reg[0] == 2, reg[0] == 1, false)
			console.log('region. ' + elements[i] + ' x ' + region.x + ' y ' + region.y + ' w ' + region.width + ' h ' + region.height + ' ' + region.allow_text + ' ')
			design.regions.push(region);
		}

		console.log("finished setting new layout")
		

		
		if (fixed_count<design.elements.length)
			$('#canvas').data("status_log").push("U"+(design.elements.length-fixed_count))

		$('#canvas').data("layout", new_layout);
	}

	design.elements[0].img.getLayer().draw();

	//double check each element is correct
	$.each(design.elements, function(i, e) {
		if ((e.img.getStage() == undefined) || (e.img.getLayer() == undefined)) {
			console.log("error for element " + e.id)
			console.log("stage: ")
			console.log(e.img.getStage())

			console.log("layer: ")
			console.log(e.img.getLayer())
			console.log("new_layout:")
			console.log(new_layout)

			$('#suggestion_status').text("stage undefined");
		}

	});
}


function fadeInElement(elem,undoing)
{
	
	var time=0.3
	if (undoing)
		time=0.2
	//var visible=elem.state_img.isVisible()
	if (elem.state_img.isVisible())
	{
		var tween = new Kinetic.Tween({
	 		node:elem.state_img,
	 		duration:time,	
	 		opacity:1,
	 		x:(elem.x + elem.width),
	 		y:elem.y,
		});
		tween.play()
	}
	else
		elem.state_img.setPosition(elem.x + elem.width, elem.y)
	
	elem.img.attrs.draggable=false
	var tween = new Kinetic.Tween({
 		node:elem.img,
 		duration:time,
 		opacity:1,
 		x:elem.x,
 		y:elem.y,
 		height:elem.height,
 		width:elem.width,
 		easing:Kinetic.Easings.Linear,
 		onFinish: function(element){
			elem.img.attrs.draggable=true
 			moveAnchors(elem)		 	
 			}
 		
 	})
 	tween.play()
}

function fadeOutImage(img,undoing)
{
	/*
	console.log("fadeout img")
	console.log(img)	
	console.log(img.getLayer())
	if ((img==undefined)||(img.getLayer()==undefined))
		return
	*/
	var time=0.3
	if (undoing)
		time=0.2

	var tween = new Kinetic.Tween({
 		node:img,
 		duration:time,	
 		opacity:0,
		onFinish: function(){
			//console.log(img)
			if (img!=undefined)
				img.remove()
		}
	});
	tween.play()
	
	
}


function setHidden(elem, state) {
	elem.hidden = state
	if (state) {
		if (elem.hidden_img == 0) {
			elem.hidden_img = elem.img.getImage()
			elem.img.setImage(0)
		}
	} else {
		if (elem.hidden_img != 0) {
			elem.img.setImage(elem.hidden_img)
			elem.hidden_img = 0
		}
	}

}

function loadImages(sources, callback) {
	
	if ($('#canvas').data("loadedImages"))
		return
	
	$('#canvas').data("loadedImages",true)
	console.log("loading images")
	var images = {};
	var loadedImages = 0;
	var numImages = 0;
	for (var src in sources) {
		numImages++;
	}

	for (var src in sources) {
		console.log("loading image " + sources[src])

		images[src] = new Image();
		images[src].onload = function() {

			if (++loadedImages >= numImages) {

				$('#canvas').data("images", images);
				callback();
			}
		};
		images[src].src = sources[src];
	}
}

function loadDesignFile(designName) {

	$('#canvas').data("images_rendering",-1)
	
	console.log("loading design " + designName)
	var jsonLoad = $.getJSON(sprintf('/design/static/designs/%s.json', designName), function(design) {
		console.log('design.json obtained');

		var idx=designName.indexOf('new')

		if (idx>-1) {
			design.name = "design_" + String(new Date().getTime());
			console.log("Created design " + design.name)
		}
		
		idx=designName.lastIndexOf('/')
		
		if (idx>-1)
		{
			var design_dir=designName.substring(0,idx+1)
			var name=designName.substring(idx+1,designName.length)
			
			
			console.log("design dir: "+design_dir)
			console.log("design name: "+name)
			
			design.directory=design_dir;
			design.name=name;		
			
		}

		design.elements.sort(function(e1, e2) {
			return e2.importance - e1.importance
		})

		$('#canvas').data("design", design);

		sources = {};

		sources['unlocked'] = '/design/static/icons/unlocked.png'
		sources['tweakable'] = '/design/static/icons/tweakable.png'
		sources['locked'] = '/design/static/icons/locked.png'
		
		sources['accept_suggestion'] = '/design/static/img/select_suggestion.png'

		if (design.background_fname.length > 1)
			sources['background'] = sprintf('/design/static/images/%s', design.background_fname);

		font_list=[]

		$.each(design.elements, function(i, elem) {
			if ("fname" in elem) {
				console.log("elem.fname " + elem.fname)
				sources[elem.fname] = sprintf('/design/static/images/%s', elem.fname);
			}
			else{
				if ($.inArray(elem.font,font_list)==-1)
				{
					$('#updateText').css("font-family",elem.font)
					 
					var fdiv=$('#initFont').clone()
					fdiv.css("font-family",elem.font)
					fdiv.attr("id",elem.font)
					$('#initFont').parent().append(fdiv)
					font_list.push(elem.font)
				}
					
			}
			
		});
		
		console.log("loading fonts "+String(font_list))
		
		$('#canvas').data("loadedImages",false)
		
		
		var callback = function(){loadImages(sources, setupCanvas);}
		
		if (font_list.length>0)
			waitForWebfonts(font_list,callback)
		else
			callback()
		//loadImages(sources, setupCanvas);
		

	}).done(function() {
		console.log('success');
	}).fail(function() {
		console.error('JSON load failure.');
	});
}

function selectImage(type) {
	console.log("selectImage")
	deselectAll()
	$('#canvas').data('inputType', type)
	$('#fileInput').click();
}

function handleFiles(files) {
	console.log("handling files " + files);
	var file = files[0];
	var reader = new FileReader();
	reader.onload = onFileReadComplete;
	reader.readAsDataURL(file);
	
	$("#canvas").data("load_filename", file.name)
}

function onFileReadComplete(event) {
	console.log(event.target.result)

	var img = new Image();

	var fname = "graphic_" + String(new Date().getTime()) + ".png";
	var fname = $("#canvas").data("load_filename");

	img.onload = function() {

		if ($('#canvas').data('inputType') == 'graphic')
			createNewElement('graphic', img, fname)
		else {
			var background = $('#canvas').data('design').background;
			background.attrs.fillPatternImage = img
			background.attrs.fill = undefined
			$("#canvas").data("design").background_fname = fname;
			background.getLayer().draw()

			background = $('#canvas').data('design').sugg_background;
			background.attrs.fillPatternImage = img
			background.attrs.fill = undefined
			background.getLayer().draw()
		}
	};
	img.src = event.target.result

	saveImageOnServer(fname, event.target.result)

}




function backgroundOffsetChanged() {
	console.log("backgroundOffsetChanged")

	var design=$('#canvas').data("design");

	if (design.background_fname != ''){
		
		var offset_x=parseInt($('#background_offset_x').val())
		var offset_y=parseInt($('#background_offset_y').val())
		
		var pos = design.background_elem.img.getPosition();
		
		design.background_elem.offset_x=offset_x
		design.background_elem.offset_y=offset_y
		
		design.background_elem.img.attrs.fillPatternOffsetX=offset_x
		design.background_elem.img.attrs.fillPatternOffsetY=offset_y
		
		design.background_elem.img.getLayer().draw()		
	}

}


function backgroundColorChanged() {
	console.log("backgroundColorChanged")

	var background = $('#canvas').data('design').background;
	background.attrs.fillPatternImage = ''
	background.attrs.fill = $('#background_color_select').val();
	$("#canvas").data("design").background_fname = '';
	$('#canvas').data('design').background_color = $('#background_color_select').val();
	background.getLayer().draw()

	background = $('#canvas').data('design').sugg_background;
	background.attrs.fillPatternImage = ''
	background.attrs.fill = $('#background_color_select').val();
	background.getLayer().draw()
	
	
	
	setupSelectRectangle($('#canvas').data('design'),$('#canvas').data("stage").get('#layer')[0])
	
	

}

function setupSliders() {

	$('#whitespace_slider').slider({
		min : 0,
		step : 1,
		max : 100,
		value : 50,
		change : function(event, ui) {
			updateParameters('whitespace', ui.value);
		}
	});

	$('#text_size_slider').slider({
		min : 0,
		step : 1,
		max : 100,
		value : 50,
		change : function(event, ui) {
			updateParameters('text_size', ui.value);
		}
	});

	$('#graphic_size_slider').slider({
		min : 0,
		step : 1,
		max : 100,
		value : 50,
		change : function(event, ui) {
			updateParameters('graphic_size', ui.value);
		}
	});

	$('#symmetry_slider').slider({
		min : 0,
		step : 1,
		max : 100,
		value : 50,
		change : function(event, ui) {
			updateParameters('symmetry', ui.value);
		}
	});

}

function createNewDesign() {
	window.location.replace("/design/create&design=new")
}

function openExistingDesign() {
	window.location.replace("/design/select/"+$('#canvas').data("design").directory)
}

function duplicateDesign() {
	$('#canvas').data("design").name = "design_" + String(new Date().getTime());
	saveDesign()
	alert("Design duplicated")
	startSuggestions()
}

function deleteDesign() {

	if (confirm("Warning! This will permanentely delete this design and send you back to the selection menu. Are you sure you want to delete this design?")) {
		deleteDesignOnServer($('#canvas').data("design"))

	}
}

function startSuggestions(run_offset) {


	if (run_offset == undefined)
	{
		run_offset = 0
		if (gup("run_offset")!='')
			run_offset=parseInt(gup("run_offset"))
	}
		

	console.log("Starting suggestions")

	if ($('#canvas').data("design").elements.length <= 1) {
		console.log("Not enough elements")
		//return
	}

	$('#canvas').data("status_log").push("Start")

	$('#canvas').data('killed', false)
	$('#canvas').data('paused', false)
	$('#restartButton').hide()

	$('#suggestion_status').text("")

	var design_string = getCurrentDesign();


	var layout_counter=$('#canvas').data("layout_counter")
	if (layout_counter==undefined)
		layout_counter=0;
	$('#canvas').data("layout_counter",layout_counter+1)
 	
 	design_string=layout_counter+"\n"+design_string
	


	$('#design_out').val(design_string);

	var runs = [];

	var run_id = -1;
	//var run_types;
	//var run_types=['near','mid','far','gallery']
	
	
	if ($('#canvas').data("automaticUpdate"))
	 	run_types=['autoupdate','gallery']
	else
	 	run_types=['near','gallery']

	//run_types=['autoupdate']
	//var run_types=['near','mid','far','gallery']
	//var run_types=[]

	console.log("run types")
	console.log(run_types)

	if (getURLParameter("nio") == 1)
		run_types=['nio']
		
	var run_dict={}

	for (var i = 0; i < run_types.length; i++) {

		run = {}
		//run.id=Math.floor(Math.random()*65000);
		run.id = i + run_offset
		run.canvas_id = i
		run.image = new Image()
		run.type = run_types[i]
		run.layout = ''
		run.energy = 9999999
		run.converged=false
		//stopRun(run.id, run_types[i]);
		
		runs.push(run)
		
		run_dict[run.id]=run

		if ('gallery' == run_types[i])
			$('#gallery_layout0').data("run_idx", i)
		else
			$('#suggestion_layout' + String(run.canvas_id)).data("run_idx", i)
		
	}
	$('#canvas').data("runs", run_dict)
	
	sendRun(0,runs,design_string)
	

	


}

function sendRun(i,runs,design_string)
{
	if (i>=runs.length)
		return
	startNewRun(runs[i].id, runs[i].type, design_string)
	setTimeout(function(){sendCurrentLayout( 'start', false,runs[i].id); sendRun(i+1,runs, design_string)}, 1000);

}
		


function startText() {
	console.log("adding new text. deselecting")
	deselectAll()
	var layer = $('#canvas').data("stage").get('#layer')[0];
	layer.draw()
	$('#user_text').val('')
	//if ($('#canvas').data("text_mode") == false) {
		document.body.style.cursor = "url('/design/static/img/text_cursor2.png'), auto"
		$('#canvas').data("text_mode", true)
		showElementControls()
	//} else {
	//	document.body.style.cursor = "default";
	//	$('#canvas').data("text_mode", false)
	//}
}

function createRegion() {
	var region = createNewRegion(0, 0, 100, 100, $("#region_graphic_select").attr("checked") == 'checked', $("#region_text_select").attr("checked") == 'checked', $("#region_overlap_select").attr("checked") == 'checked')

	$('#canvas').data("design").regions.push(region)

	toggleRegionMode()
	toggleRegionMode()

	deselectAll(region)

	region.img.getLayer().draw()

}

function regionProposalChanged() {

	var design = $('#canvas').data("design");

	design.region_proposals = $("#region_proposal_select").attr("checked") == 'checked';

	sendCurrentLayout();
}

function testSendLayout(num) {
	$('#canvas').data("sendLayoutToServerTimes", [])
	for (var i = 0; i < num; i++) {
		sendCurrentLayout()
	}

}

function toggleInvert() {

	$('#canvas').data("invert", $("#invert_select").attr("checked") == 'checked')

	/*
	 $.each($('#canvas').data("design").elements, function(i,elem){

	 var filt=0
	 if ($('#canvas').data("invert"))
	 filt=Kinetic.Filters.Invert

	 elem.lock_img.attrs.filter=filt
	 elem.tweakable_img.attrs.filter=filt
	 elem.unlock_img.attrs.filter=filt
	 elem.state_img.attrs.filter=filt
	 });
	 */

	$('#canvas').data("stage").get('#layer')[0].draw()

}

function validateFormResults() {

	var saved_canvases = $("#saved_table").find("canvas")

	console.log("saved_canvases.length:" + saved_canvases.length)

	var min_layouts = gup('numLayouts')

	if ((min_layouts != '') && (saved_canvases.length - 1 < parseInt(min_layouts)))
		alert("You must create (and save) at least " + min_layouts + " layouts.")
	else {
		$("#final_design").val(getCurrentDesign())

		$.each(saved_canvases, function(i, saved_img) {

			var saved_layout = $(saved_img).data("layout")

			var new_inp = $('<input>')
			new_inp.attr("type", "hidden")
			new_inp.attr("id", "saved_layout" + i)
			new_inp.attr("name", "saved_layout" + i)
			new_inp.val(saved_layout)

			$("#final_layouts").append(new_inp)

		});

		//$("#studySubmit").click()
	}
}


function setSuggestionIndex(shift) {

	var idx = $('#canvas').data("layout_stack_idx")
	var stack = $('#canvas').data("layout_stack")

	console.log("setSuggestionIndex idx: " + idx + " shift: " + shift + " stack.len: " + stack.length)

	if ((idx + shift < 0) || (idx + shift > stack.length - 1))
		return

	if (shift == -1) {
		$('#canvas').data("user_input_log").push("Undo")
		$('#canvas').data("status_log").push("Undo")
	} else if (shift == 1) {
		$('#canvas').data("user_input_log").push("Redo")
		$('#canvas').data("status_log").push("Redo")
	}

	deselectAll()
	//pauseSuggestions()

	setCurrentLayout(stack[idx+shift][0], true, true)


	if ((idx + shift) == 0)
		$('#undoButton').fadeTo(0, 0.4)
	else
		$('#undoButton').fadeTo(0, 1)

	if ((idx + shift) == stack.length - 1)
		$('#redoButton').fadeTo(0, 0.4)
	else
		$('#redoButton').fadeTo(0, 1)

	$('#canvas').data("layout_stack_idx", idx + shift)

}



function setUserLayoutIndex(shift) {

	var idx = $('#canvas').data("user_layout_stack_idx")
	var stack = $('#canvas').data("user_layout_stack")

	console.log("setUserLayoutIndex idx: " + idx + " shift: " + shift + " stack.len: " + stack.length)

	if ((idx + shift < 0) || (idx + shift > stack.length - 1))
		return

	deselectAll()
	
	setReportBeforeImage(stack[idx+shift])



	if ((idx + shift) == 0)
		$('#reportUndoButton').fadeTo(0, 0.4)
	else
		$('#reportUndoButton').fadeTo(0, 1)

	if ((idx + shift) == stack.length - 1)
		$('#reportRedoButton').fadeTo(0, 0.4)
	else
		$('#reportRedoButton').fadeTo(0, 1)

	$('#canvas').data("user_layout_stack_idx", idx + shift)

}



function plotEnergy(sugg_energy, user_energy) {

	var curr_energy = $('#canvas').data("energy")

	if (curr_energy == 0)
		return;

	var plot_energy = $('#canvas').data("plot_energy_list")

	plot_energy.push([user_energy, sugg_energy])

	var data1 = [];
	var data2 = [];
	for (var i = Math.max(0, plot_energy.length - 25); i < plot_energy.length; i++) {
		data1.push([i, plot_energy[i][0]]);
		data2.push([i, plot_energy[i][1]]);
	}

	$.plot("#energy_plot", [data1, data2], {
		series : {
			shadowSize : 0	// Drawing is faster without shadows
		},
		xaxis : {
			show : false
		}
	});

}


function fontSizeChanged(new_size)
{
	
	var elem=$('#canvas').data("selected")
	if (elem.type=="text")
	{
		
		$('#canvas').data("user_input_log").push("Scale-Dropdown")
		$('#canvas').data("status_log").push("Scale-Dropdown")
		
		
		console.log('user field:'+$('#fontSizeInput'))
		if (new_size==undefined)
			new_size=parseFloat($('#fontSizeInput').val())
		else
			$('#fontSizeInput').val(new_size)
		
		console.log('new size:'+new_size)
		elem.height=(new_size/elem.init_font_size)*elem.init_height
		elem.width=elem.height*elem.aspect_ratio
		
		console.log('setting new height:'+elem.height)
		
		elem.img.setHeight(elem.height)
		elem.img.setWidth(elem.width)
		
		moveAnchors(elem)
		elem.state_img.setPosition(elem.x + elem.width, elem.y)
		drawAlignmentLines(elem, 'dragging')
		elem.img.getLayer().draw()
		
	}
	
	
}




function initializeReport(positive)
{
	
	
	
	if (positive)
		$('#reportInstructions').text("Please describe what you liked about the update (optional)")
	else
		$('#reportInstructions').text("Please describe the problem. What was the expected behaviour? What was wrong with the automatic update?")
	
	
	
	
	
	$('#report').show()
	$('#reportStatus').text("")
	$('#report').data("running",$('#canvas').data("started"))
	$('#report').data("positive",positive)
	
	
	
	$('#report').data("afterLayout",getCurrentLayout())
	
	stopSuggestionsUntilUserInput()
	
	
	var stage=$('#canvas').data("stage")
	
	$.each($('#canvas').data("design").elements, function(i, elem) {
		elem.state_img.show();
	});
	
	
	stage.get('#layer')[0].draw();
	
	stage.toDataURL({
		callback : function(dataUrl) {
			var img = new Image();

			img.onload = function() {
				
				$('#report_after_img').attr("width",stage.attrs.width / 2)
				$('#report_after_img').attr("height",stage.attrs.height / 2)
				$('#report_after_img').attr("src",dataUrl)

			}
			img.src = dataUrl;

		}
	});
	
	var stack = $('#canvas').data("user_layout_stack")
	
	if (stack.length==0)
		return
		
	
	setReportBeforeImage( stack[stack.length-1])
	
	
	
	
	 $('#canvas').data("sugg_stage").toDataURL({
		callback : function(dataUrl) {
			var img = new Image();
			img.onload = function() {
				$('#report_sugg_img').attr("width",stage.attrs.width / 2)
				$('#report_sugg_img').attr("height",stage.attrs.height / 2)
				$('#report_sugg_img').attr("src",dataUrl)
			}
			img.src = dataUrl;

		}
	});
	

	
}


function setReportBeforeImage(layout_info)
{
	
	var layout=layout_info[0]	
	var curr_layout=getCurrentLayout()
	
	$('#report').data("beforeLayout",layout)
	
	
	deselectAll()
		
	setCurrentLayout(layout,true,true,layout_info[1])	
	
	var stage=$('#canvas').data("stage")
	stage.toDataURL({
		callback : function(dataUrl) {
			var img = new Image();
			img.onload = function() {
				$('#report_before_img').attr("width",stage.attrs.width / 2)
				$('#report_before_img').attr("height",stage.attrs.height / 2)
				$('#report_before_img').attr("src",dataUrl)
			}
			img.src = dataUrl;
		}
	});
	
	setCurrentLayout(curr_layout,true,true)	
	
	$.each($('#canvas').data("design").elements, function(i, elem) {
		elem.state_img.hide();
	});
	stage.get('#layer')[0].draw();
	
}


function cancelReport()
{
	
	$('#report').hide()
	
	$('#reportStatus').text("")
	$('#reportText').val('')
}

function submitReport()
{
	
	// 
	if (($('#reportText').val()=='')&& (!$('#report').data("positive")))
	{
		alert("You must provide some explanation for your response")
		return;
	}
	
	
	if ($('#report').data("positive"))
		$('#numLikes').text(parseInt($('#numLikes').text())+1)
	else
		$('#numDislikes').text(parseInt($('#numDislikes').text())+1)
	
	$('#report').hide()
	
	$('#reportStatus').text("Response Submitted")
	
	var report={}
	
	report['text']=$('#reportText').val()
	report['workerId']=gup('workerId')
	report['hitId']=gup('hitId')
	report['assignmentId']=gup('assignmentId')
	report['userId']=$('input[name=userID]').val()
	report['design']=$('#canvas').data("design").name
	report['date']=String(new Date())
	report['errorMessage']=$('#error_message').text()
	report['optimizerRunning']=$('#report').data("running")
	report['afterLayout']=$('#report').data("afterLayout")
	report['beforeLayout']=$('#report').data("beforeLayout")
	report['positive']=$('#report').data("positive")
	
	
	report['userLayoutFeatures']=$('#userLayoutFeatures').val()
	report['suggestionLayoutFeatures']=$('#suggLayoutFeatures').val()
	
	var report_name=report['design']+ "-"+String(new Date().getTime());
	
	saveReportOnServer(report_name, $('#report_before_img').attr("src"), $('#report_after_img').attr("src"), $('#report_sugg_img').attr("src"),report)
	
	
	if ($('#report').data("names")==undefined)
		$('#report').data("names",[])
	
	$('#report').data("names").push([$('#report').data("positive"),report_name])
	
	$('#reportText').val('')
}


function startStudy()
{
	var sequence=$('#canvas').data("design_sequence")
	
	$('#startStudyButton').hide()
	$('#nextDesignButton').show()
	
	$('#canvas').data("sequence_index",0)
	loadDesignFile(design_sequence[0].design)
	
	
	if ($('#canvas').data("suggestionsEnabled"))
		$('.suggestions').show()
		
		
	if($('#canvas').data("automaticUpdate"))
		$('#suggestion_td').hide()
	
		
		
	if ($('#canvas').data("sequence_type")=="retarget")
	{
		executeAfterTextRendering(function(){
			setMatchDesign(design_sequence[0].match_design);
			setupRetargetting();
			resetLayout()})
	}
}





function moveToNextDesign()
{
	
	console.log("moveToNextDesign")
	var curr_design_idx=$('#canvas').data("sequence_index")
	var sequence=$('#canvas').data("design_sequence")
	
	var curr_design=sequence[curr_design_idx].design
	
	if ($('#canvas').data("loading"))
		return
	else
		$('#canvas').data("loading",true)
	
	//$("#layout"+curr_design_idx).val(getCurrentLayout())
	$("#layout"+curr_design_idx).val(getCurrentLayout())
	
	var last_time=$('#canvas').data("designTime")	
	if (last_time==undefined)
		last_time=$('#canvas').data("layoutStartTime") 
	
	var curr_time=new Date()
	
	if ($('#layoutTimes').data('times')==undefined)
		$('#layoutTimes').data('times',[curr_time-last_time])
	else
		$('#layoutTimes').data('times').push(curr_time-last_time)
	
	$('#layoutTimes').val(String($('#layoutTimes').data('times')))
	$('#canvas').data("designTime",curr_time)
	
	$("#layout_input"+curr_design_idx).val($('#canvas').data("user_input_log"))
	$("#layout_log"+curr_design_idx).val($('#canvas').data("layout_log"))
	
	
	$('#studyOrder').val(String(sequence))
	
	
	$.each($('#canvas').data("design").elements, function(i, elem) {
		elem.state_img.hide();
		elem.img.attrs.strokeEnabled=false
		$.each(elem.anchors, function(i, a) {
			a.hide();
		});
	});
	$.each($('#canvas').data("align_lines"), function(i, al) {
		al[0].destroy()
	});
	//$('#canvas').data("stage").get('#layer')[0].draw()
		
	$('#canvas').data("stage").toDataURL({
		callback : function(dataUrl) {
			var img = new Image();

			img.onload = function() {
			
			
				$('#canvas').data("layout_stack", [])
				$('#canvas').data("layout_stack_idx", -1)
				$('#undoButton').fadeTo(0, 0.4)
				$('#redoButton').fadeTo(0, 0.4)
						
				var hit_id = gup('hitId')
				var fname = 'layouts/' + $('#canvas').data("design").name + '-' + gup('workerId') + "-" + hit_id + "-" + String(curr_design_idx) + '.png'
				saveImageOnServer(fname, dataUrl)
			
			
				$('#canvas').data("sequence_index",curr_design_idx+1)	
				
				var next_design=sequence[curr_design_idx+1].design
				
		
				if (next_design!=curr_design)	
				{
					deleteGallery()
				}
				
		
			
				if (next_design.indexOf("direct")>-1)
					$('#canvas').data("suggestionsEnabled",false)

				if (next_design.indexOf("sugg")>-1)
					$('#canvas').data("suggestionsEnabled",true)
			


				var next_str=""
								
				if (next_design.indexOf("tut")>-1)
					next_str+="Tutorial-"
				else
					next_str+="Normal-"
				
	
	
	
				if ($('#canvas').data("suggestionsEnabled"))
				{
					
					next_str+="Suggestions"
					
					$('.suggestions').show()
					
					if($('#canvas').data("automaticUpdate"))
					{
						$('#suggestion_td').hide()
						$('#interface').data("interface").push('adaptive')	
					}
					else
						$('#interface').data("interface").push('suggestions')
				}
				else
				{
					$('#interface').data("interface").push('baseline')
					next_str+="Baseline"	
					
					$('.suggestions').hide()
					stopSuggestionsUntilUserInput()		
				}
	
	
				$('#canvas').data("user_input_log",[next_str])
				$('#canvas').data("status_log").push(next_str)
				$('#canvas').data("layout_log",[next_str,new Date().getTime(),''])
				
				
				
					
				
				loadDesignFile(next_design)
				
				
				if ("match_design" in sequence[curr_design_idx+1])
					setMatchDesign(sequence[curr_design_idx+1].match_design)
				


			
				executeAfterTextRendering(
					function(){
						$('#canvas').data("loading",false)
						
						if (gup("retarget")!='')
							setupRetargetting();
						
						resetLayout();
						
					});
					
					
				
			}
			img.src = dataUrl;

		}
	});		
	
	if (curr_design_idx+1==sequence.length)
	{
		$('#nextDesignButton').hide()
		
		$('.mturkQuestionnaire').show()
		
		$('#canvas').hide()
		
		$('#mainTable').hide()
		
		$('#study_status').text("HIT complete. Please submit after providing suggestions/comments.")
		$('#study_status').css("background-color",'#5F5')
		$('#study_status').show()
		
		return
	}
		
	
	
}


function setMatchDesign(match_design)
{

	var stage=$('#canvas').data("stage")

	console.log("setMatchDesign")

	$('#retarget_img').css("width",stage.attrs.width / 2)
	$('#retarget_img').css("height",stage.attrs.height / 2)
	$('#retarget_img').attr("src","/design/static/designs/"+match_design+".png")

}


function setupRetargetting()
{ 
	

	var retarget=gup('retarget')
	
	
	
	if (retarget!='')
	{
		
		console.log("setupRetargetting. retarget: "+retarget)
		
		$('#canvas').data("started", true)
		
		//var stage=$('#canvas').data("stage")
	
		//stage.toDataURL({
		//	callback : function(dataUrl) {
		//		var img = new Image();
		//		img.onload = function() {
		//			
		//			$('#retarget_img').attr("width",stage.attrs.width / 2)
		//			$('#retarget_img').attr("height",stage.attrs.height / 2)
		//			$('#retarget_img').attr("src",dataUrl)
	
		var splt=retarget.split("_")
		var new_width=parseInt(splt[0])
		var new_height=parseInt(splt[1])		
		
		$('#design_width').val(new_width)
		$('#design_height').val(new_height)
		
		designSizeChanged()
	
		//		}
		//		img.src = dataUrl;
	
		//	}
		//});		
	}
	
}




function waitForWebfonts(fonts, callback) {
    var loadedFonts = 0;
    for(var i = 0, l = fonts.length; i < l; ++i) {
        (function(font) {
            var node = document.createElement('span');
            // Characters that vary significantly among different fonts
            node.innerHTML = 'giItT1WQy@!-/#';
            // Visible - so we can measure it - but not on the screen
            node.style.position      = 'absolute';
            node.style.left          = '-10000px';
            node.style.top           = '-10000px';
            // Large font size makes even subtle changes obvious
            node.style.fontSize      = '300px';
            // Reset any font properties
            
            
            if ((font=='sans-serif') || (font=='Helvetica'))
           		node.style.fontFamily    = 'Eater Caps';
           	else
            	node.style.fontFamily    = 'sans-serif';
            node.style.fontVariant   = 'normal';
            node.style.fontStyle     = 'normal';
            node.style.fontWeight    = 'normal';
            node.style.letterSpacing = '0';
            document.body.appendChild(node);

            // Remember width with no applied web font
            var width = node.offsetWidth;

            node.style.fontFamily = font;
            
            console.log("font "+font+ " start. sans-serif width "+width)

            var interval;
            var cnt=0;
            function checkFont() {
            	
            	if (node)
            	{
            		console.log("font "+font+ " has offset width "+node.offsetWidth+"sans-serif width "+width)
            		
            	}
            	console.log("loaded fonts "+loadedFonts+ " array len "+fonts.length+ " at cnt"+cnt)
                // Compare current width with original width
                if((node!=null) && (node.offsetWidth != width)) {
                    ++loadedFonts;
                    node.parentNode.removeChild(node);
                   
                    node = null;
                }
				
				if (cnt>10)
				{
					clearInterval(interval);
					callback()
					return true
				}
				cnt+=1
				
				
                // If all fonts have been loaded
                if(loadedFonts >= fonts.length) {
                    if(interval) {
                        clearInterval(interval);
                    }
                    if(loadedFonts == fonts.length) {
                        callback();
                        return true;
                    }
                }
            };

	
            if(!checkFont()) {
                interval = setInterval(checkFont, 50);
        
            }
        })(fonts[i]);
    }
};

function toggleSuggestionInterface()
{
	var url=document.URL
	
	if (url.indexOf("?automaticUpdate=1")>-1)
		window.location.replace(url.replace("?automaticUpdate=1",""))
	else
		window.location.replace(url+"?automaticUpdate=1")
	
}

/*
function acceptOrRejectSuggestion(event, layout_num)
{
	console.log(event.clientX)
	console.log(event.clientY)
	
	var offset=$('#suggestion_layout' + layout_num).offset()
	console.log(offset)
	
	var width=$('#suggestion_layout' + layout_num).width()
	
	var mid_pt=offset.left+width/2.0
	if (event.clientX>mid_pt)
		console.log("reject suggestion")
	else
	{
		console.log("accept suggestion")
		setFixedLayout("suggestion",layout_num)
		
	}
		
	
}
*/


function showMoreSimilarLayouts()
{
	$('#suggestion_lk').click()
}
function showMoreDifferentLayouts()
{
	$('#suggestion_lk').click()
	
	
	//if (gup("testing")=="1")
	resetRuns()
	//else
	//	resetLayout(false)
	
	
}



function removeSuggestions()
{
 	$.each($('#canvas').data("suggestion"),function(i,sugg){
 		
 		sugg.img.destroy()
 	})
 	
 	$('#canvas').data("suggestion",[])
}


function acceptSuggestion(s)
{
	
	console.log(s.element)
	console.log("sugg:"+s.element.text)
	
	setElementPosition(s.element,s.x,s.y,s.height)
	s.img.destroy()
	
	//drawAlignmentLines(s.element, 'dragging')
	
}

function setElementPosition(element, x, y,height)
{
	element.img.setPosition(x, y)
	element.img.setHeight(height)
	element.img.setWidth(height*element.aspect_ratio)
	element.x=x
	element.y=y
	element.height=height
	element.width=height*element.aspect_ratio
	
	element.state_img.setPosition(element.x + element.width, element.y)
}



function findSuggestion(selected, elem,type)
{
	
	var shape1=selected.img
	var shape2=elem.img
	var p1 = shape1.getPosition()
	var p2 = shape2.getPosition()
	var x11 = p1.x, y11 = p1.y, x12 = p1.x + shape1.getWidth(), y12 = p1.y + shape1.getHeight(), x21 = p2.x, y21 = p2.y, x22 = p2.x + shape2.getWidth(), y22 = p2.y + shape2.getHeight()

	x_overlap = Math.max(0, Math.min(x12, x22) - Math.max(x11, x21))
	y_overlap = Math.max(0, Math.min(y12, y22) - Math.max(y11, y21));
	
	sugg={}
	
	
	sugg.element=elem
	

	
	console.log("x_overlap: "+x_overlap)
	console.log("y_overlap: "+y_overlap)
	
	var offset_x=0;
	var offset_y=0;
	
	//try to shift horizontally
	if (x_overlap<y_overlap)
	{
		
		//shift left
		if (elem.x+elem.width-selected.x < selected.x+selected.width-(elem.x))
		{
			offset_x=selected.x-(elem.x+elem.width) - 3 
		}
		//shift right
		else
		{
			offset_x=(selected.x+selected.width)-elem.x + 3
		}
		
	}
	//try to shift vertically
	else
	{
		if (elem.y+elem.height-selected.y < selected.y+selected.height-(elem.y))
		{
			offset_y=selected.y-(elem.y+elem.height) - 3
		}
		else
		{
			offset_y=(selected.y+selected.height)-elem.y +3
		}
		
	}
	
	sugg.x=elem.x+offset_x
	sugg.y=elem.y+offset_y
	sugg.height=elem.height
	
	
	return sugg
}


function makeSuggestions()
{
	
	 if ((gup("makeSuggestions")=='1') && (gup("automaticUpdate")=='0'))
	 {
	 	
	 	var design=$('#canvas').data("design")
	 	
	 	var selected=$('#canvas').data("selected")
	 	
	 	
	 	console.log("selected:")
	 	console.log(selected)
	 	
	 	if ((selected==0)||(selected.type=='background'))
	 		return
	 	
	 	removeSuggestions()
	 	
	 	
	 	var suggs=[]
	 	
	 	$.each(design.elements, function(i,e){
	 		
	 		
	 		var overlap = getOverlap(selected.img, e.img)
	 		
			
			if ((e!=selected) && (overlap > 0.02) && (e.fixed_amount != 1)) {
				sugg=findSuggestion(selected, e,'overlap')
				
				suggs.push(sugg)
			}
					
	 		
	 	})
	 	
	 	
	 	$.each(suggs, function (i, sugg)
	 	{
	 		
		 	var img=sugg.element.img
		 	sugg.img=img.clone()
		 	sugg.img.setOpacity(0.5),
		 	img.getLayer().add(sugg.img)
		 	
		 	
		 	var tween = new Kinetic.Tween({
		 		node:sugg.img,
		 		duration:0.3,
		 		opacity:0.15,
		 		x:sugg.x,
		 		y:sugg.y,
		 		scaleX:sugg.element.height/sugg.height,
		 		scaleY:sugg.element.height/sugg.height,
		 		easing:Kinetic.Easings.Linear
		 		
		 	})
		 	tween.play()
		 	
		 	
		 	sugg.img.off("click tap")
		 	
		 	sugg.img.on("click tap", function(){acceptSuggestion(sugg)})
		 	
	 	});
	 	
	 	$('#canvas').data("suggestion",suggs)
	 	
	 	
	 }
	
}

function removeAllConstraints()
{
	$.each($('#canvas').data("design").elements, function (i,e){
		e.constraints = {'size':[],'alignment':[]}

		e.state_img.hide()
		e.fixed_amount = 0.0
		e.state_img = e.unlock_img
		
	});	
	
}


function constraintsChanged(type)
{
	
	console.log("constraintsChanged-"+type)
	
	var selected_ids=[]
	var selected_types=[]
	
	var design = $('#canvas').data('design')
	
	$.each(design.elements, function (i,e){
		
		if (e.selected)
		{
			selected_ids.push(e.id)
			selected_types.push(e.type)
		}
	});
	

	var adding_constraint=$("#size_constraint").prop("checked")
	
	console.log("adding_constraint: "+adding_constraint)
		
	var changed=false;

	var set_height=0;
	if ($('#canvas').data('selected').type=='graphic')
		set_height=$('#canvas').data('selected').height
	else
		set_height=$('#canvas').data('selected').height/$('#canvas').data('selected').num_lines

	
	$.each(design.elements, function (i,e){
		
		if (e.selected)
		{
			
			var cons=e.constraints[type]
			
			for (var i=0;i<selected_ids.length;i++){
				if ((e.id!=selected_ids[i])&&(e.type==selected_types[i])){
					
					var idx=cons.indexOf(selected_ids[i])
					if (idx==-1){						
						cons.push(selected_ids[i])
						changed=true
						
						
						if (type=='size')
						{
							
							var new_height=set_height*Math.max(e.num_lines,1)
							console.log("set new height "+new_height)
							e.height=new_height
							e.width=new_height*e.aspect_ratio
							
							e.img.setHeight(e.height)
							e.img.setWidth(e.width)							
							
						}
							
						
					}
					
					else if (!adding_constraint){
						cons.splice(idx, 1);				
					}
					
				}
			}
			
		}
	});
	
	
	$('#canvas').data("stage").get('#layer')[0].draw()
	
	if (changed)
		sendCurrentLayout(type+" constraint")
	
	
}


function showGalleryLayouts()
{

	$('#gallery_text').show()
	$('#saved_text').hide()
	$('#style_lk').click()
	
	$('#showGalleryButton').hide()
	
	
	//$('#gallery_text').show()
	//$('#style_lk').click()
	

}


function deleteGallery()
{
	var gallery_elem = $('#gallery_layout0')
	$("#gallery_table").empty()
	$('#gallery_table').append($('<tr>').append($('<td>').append(gallery_elem)))
	gallery_elem.hide()
}
