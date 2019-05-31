
function toggleRules()
{
	
	if ($('#rules').is(":visible"))
	{
		$('#rules').hide()
		$('#rulesButton').text("Show Rules")
	}
	else
	{
		$('#rules').show()
		$('#rulesButton').text("Hide Rules")
		
		
		setCurrentRules()
	}
	
}



function setCurrentRules()
{
	
	if (!$('#rules').is(":visible"))
		return
	
	$('#appliedRuleMenu').find('.rule').hide()
	$('#addRuleMenu').find('.rule').hide()
	
	console.log("setting current rules")
	
	var selected_types=[]
	var selected_ids=[]
	
	var design = $('#canvas').data("design")
	
	$.each(design.elements, function (i,e){
		
		if (e.selected)
		{
			selected_types.push(e.type)
			selected_ids.push(e.id)
		}
	});
	
	selected_types.sort()
	
	console.log("selected types: "+selected_types)
	
	
	var applied_rules=[]
	$.each(design.rules, function (i,r){
		
		var rule_ids=r[1]
		
		if (rule_ids.length!=selected_ids.length)
			return
		for (var i=0;i<rule_ids.length;i++)
			if (rule_ids[i]!=selected_ids[i])
				return
				
		applied_rules.push(r[0])
		
	});
	
	console.log("applied rules: "+applied_rules)
	
	
	
	if (selected_types.length==0)
	{
		$('.rule').hide()
		return;
	}
	

	var unique_types = [];
	$.each(selected_types, function(i, el){
	    if($.inArray(el, unique_types) === -1) unique_types.push(el);
	});
	

	var rules=$('#canvas').data("rules")
	
	$.each(rules,function (i,r) {
		
		
		
		var name=r[0]
		var number_constraints=r[1]
		var type_constraints=r[2]
		
		console.log("trying rule "+name + " "+number_constraints+ " "+type_constraints)
		
		if ((number_constraints=="2"))
		{
			
			if  (selected_types.length!=2)
				return;
				
			var type_string=selected_types.join(" ")
			console.log("type string: "+type_string)
			
			if (selected_types.join(" ")!=type_constraints)
				return
			
		}	
			
		else if ((number_constraints==">1") && (selected_types.length<=1))
			return;	
			
		else if ((number_constraints==">2") && (selected_types.length<=2))
			return;	
			
		if ((type_constraints=='same') && (unique_types.length!=1))
			return
		
		if ((type_constraints=='text') && (unique_types.join(" ")!="text"))
			return
		
		
		if (applied_rules.indexOf(name)!=-1)
		{
			$('#appliedRuleMenu').find('.'+name+"Rule").show()
			$('#addRuleMenu').find('.'+name+"Rule").hide()
		}
		else
		{
			$('#addRuleMenu').find('.'+name+"Rule").show()
			$('#appliedRuleMenu').find('.'+name+"Rule").hide()
		}
		
	})
	
	$('#addRuleMenu').find(".initRule").hide()
	


	
}



function createRules()
{
	
	var all_rules=[]
	
	console.log("loading rules ")
	$.get('/design/static/rules.txt', function(data) {
		console.log("rules: "+data)
		
		var splt=data.split("\n")
		
	    for (var i=0 ; i < splt.length; i++)  
	    {
	    	var r=splt[i].split(",")
			all_rules.push(splt[i].split(","))			
			addRuleToLists(i,r)
		}

		$('#canvas').data("rules",all_rules)
		

	})
	
	
}





function addRuleToLists(id,rule){

	var rule_name=rule[0]
	var add_rule=$('#addRuleMenu').find(".initRule").clone()
	
	add_rule.removeClass('initRule')
	add_rule.addClass('rule')
	add_rule.addClass(rule_name+'Rule')
	add_rule.data("rule_name",rule_name)
	
	add_rule.find('.ruleText').text(rule[3])
	
	var applied_rule=add_rule.clone()
	
	applied_rule.data("sibling",add_rule)
	add_rule.data("sibling",applied_rule)
	
	var addButtonFunction = function(e){
		
		var list_elem=$(this)
		list_elem.hide()
		console.log(list_elem)
		list_elem.data("sibling").show()
		e.preventDefault()
		var rule_name=list_elem.data("rule_name")
		
		var selected_ids=[]
		$.each($('#canvas').data("design").elements, function (i, e){
			if (e.selected)
				selected_ids.push(e.id)
		})
		
		var r=[rule_name, selected_ids]
		
		$('#canvas').data("design").rules.push(r)	
		
		list_elem.data("sibling").data("rule",r)	
	};


	add_rule.click(addButtonFunction);
	$('#addRuleMenu').append(add_rule);
	
	
	var removeButtonFunction = function(e){
		
		var list_elem=$(this)
		list_elem.hide()
		
		console.log(list_elem)
		list_elem.data("sibling").show()
		
		//update element
		e.preventDefault()
		
		
		var rule_name=list_elem.data("rule_name")
		
		var selected_ids=[]
		$.each($('#canvas').data("design").elements, function (i, e){
			if (e.selected)
				selected_ids.push(e.id)
		})
	
	
		var rules=$('#canvas').data("design").rules
		
		var idx=rules.idx(list_elem.data("rule"));
		
		if (idx>-1)
			rules.splice(idx, 1);
		
			
		
		
	};
	
	applied_rule.hide()
	//applied_rule.find(".removeRuleButton").show()
	applied_rule.click(removeButtonFunction)
	
	$('#appliedRuleMenu').append(applied_rule);
	
	
}





