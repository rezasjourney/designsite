function getHistXLabels(minVal,maxVal,nBins){
	var arr = Array(nBins);
	//binWidth = (maxVal-minVal)/nBins;
	/*for (var i=0,len=nBins;i<len;i++){
		val = sprintf('%.0f-%.0f',i*binWidth,(i+1)*binWidth);
		arr.push(val);
	}*/
	arr[0]=minVal;
	arr[nBins-1]=maxVal;
	return arr;

}

function binHists(valList,minVal,maxVal,nBins){
	// given a list of values in between minVal and maxVal, return the counts of values in nBins equally-spaced bins
	// binHists([0,0.5,0.75,5.5,10],0,10,10)
	var arr = Array(nBins),i=nBins;
	while (i--) {
		arr[i] = 0;
	} //arr is initialized to zeroes, as necessary
	binWidth = (maxVal-minVal)/nBins;
	for (i=0,len=valList.length;i<len;i++){
		val = valList[i];
		//console.log(val);
		if (val >= minVal && val <= maxVal){
			binIndex = Math.floor(val/binWidth);
			if (binIndex==nBins){
				binIndex = nBins-1;
			}
			arr[binIndex]+=1;
			//console.log(binIndex);
		}
	}
	return arr;
  }

displayPercentage = function(){return this.value+"%";};

function histogram(containerName,seriesList,titleName,yAxisName,xAxisName,nBins,minVal,maxVal,formatFunction){
	/* to be tested on this line:
		histogram('container',[{'seriesName':name,'data':[0,2,4]}],'title','yaxis','xaxis',15)
		* minVal and maxVal are the left and right edge of these histograms
		* formatFunction prepares values of xAxis display. If ignored, does nothing. Use this for percentage display.
	*/
	var chart;
	var allVals;
	if (seriesList.length>1){
		allVals = [].concat.apply([], seriesList.map(function(d){return d.values;}));
	}
	else{
		allVals = seriesList[0].values;
	}
	//console.log(allVals);
	if (typeof minVal == 'undefined' || typeof maxVal == 'undefined'){
		minVal = Math.min.apply(null, allVals),
		maxVal = Math.max.apply(null, allVals);
	}

	if (typeof formatFunction == 'undefined'){
		formatFunction = function(d){return this.value;};
	}

	//console.log(minVal);
	//console.log(maxVal);

	xLabelNames = getHistXLabels(minVal,maxVal,nBins);
	var histDataList = Array();
	for (var i=0,len=seriesList.length;i<len;i++){
		series = seriesList[i];
		thisSeriesName = series.seriesName;
		thisSeriesList = series.values;
		bHist = binHists(thisSeriesList,minVal,maxVal,nBins);
		bHist.push(0);
		//console.log(bHist);
		histDataList.push({name:thisSeriesName,data:bHist,step:true});
	}
	//console.log(histDataList);

	chart = new Highcharts.Chart({
			credits: {enabled: false},
			chart: {renderTo: containerName,type: 'area'},
			title: {text: titleName},
			xAxis: {categories: xLabelNames,labels:{step:nBins-1,formatter:formatFunction},title:{text:xAxisName},endOnTick:true},
			yAxis: {
				min: 0,
				title: {text: yAxisName},
				stackLabels: {enabled: true,style: {fontWeight: 'bold',color: (Highcharts.theme && Highcharts.theme.textColor) || 'gray'}}
			},
			legend: {
				align: 'right',
				x: -100,
				verticalAlign: 'top',
				y: 20,
				floating: true,
				backgroundColor: (Highcharts.theme && Highcharts.theme.legendBackgroundColorSolid) || 'white',
				borderColor: '#CCC',
				borderWidth: 1,
				shadow: false
			},
			tooltip: {
				formatter: function() {
					return this.series.name +': '+ this.y;
				}
			},
			plotOptions: {
				area: {
					stacking: null,
					dataLabels: {enabled: false,color: (Highcharts.theme && Highcharts.theme.dataLabelsColor) || 'white'},
					fillOpacity: 0.5,
					marker:{enabled:false}
				}
			},
			series: histDataList
		});
	return chart;
}

function barGraph(containerName,seriesObj,titleName,yAxisName,xAxisName,seriesName){
	/* to be tested on this line:
		histogram('container',{"data":[{'columnName':name,'data':0,2,4},{}],'dataName':'dataName'},'title','yaxis','xaxis',15)
	*/
	var chart;
	var allVals;
	
	var data = seriesObj.data;

	xLabelNames = data.map(function (d){return d.columnName;});
	xData = data.map(function (d){return d.data;});
	dataName = seriesObj.dataName;
	dataContainer = [{name:dataName,data:xData,step:true}];
	//console.log(xData);
	//console.log(xLabelNames);
	//console.log(dataContainer);

	chart = new Highcharts.Chart({
			credits: {enabled: false},
			chart: {renderTo: containerName,type: 'column'},
			title: {text: titleName},
			xAxis: {categories: xLabelNames,title:{text:xAxisName},endOnTick:true},
			yAxis: {
				min: 0,
				title: {text: yAxisName},
				stackLabels: {enabled: true,style: {fontWeight: 'bold',color: (Highcharts.theme && Highcharts.theme.textColor) || 'gray'}}
			},
			legend: {
				align: 'right',
				x: -100,
				verticalAlign: 'top',
				y: 20,
				floating: true,
				backgroundColor: (Highcharts.theme && Highcharts.theme.legendBackgroundColorSolid) || 'white',
				borderColor: '#CCC',
				borderWidth: 1,
				shadow: false
			},
			tooltip: {
				formatter: function() {return this.x+': '+ this.y;}
			},
			plotOptions: {
				area: {
					stacking: null,
					fillOpacity: 0.5,
					marker:{enabled:false}
				}
			},
			series: dataContainer //[{name:dataName,data:xData,step:true}]
		});
	return chart;
}

function scatterPlot(containerName,seriesObj,titleName,seriesName){
	// {attrib1:'a',attrib2:'b',data:[[0,0],[0.5,0.25],[1.0,1.0]]}
	attrib1 = seriesObj.attrib1;
	attrib2 = seriesObj.attrib2;
	data = seriesObj.data;
	var dataContainer = [{name:seriesName,data:data}];
	var chart;

	chart = new Highcharts.Chart({
			credits: {enabled: false},
			chart: {renderTo: containerName,type: 'scatter'},
			title: {text: titleName},
			xAxis: {title:{text:attrib1},startOnTick:true,endOnTick:true,showLastLabel:true,min:0,max:100},
			yAxis: {
				min: 0,
				max:100,
				title: {text: attrib2},
				stackLabels: {enabled: true,style: {fontWeight: 'bold',color: (Highcharts.theme && Highcharts.theme.textColor) || 'gray'},
					startOnTick: true, endOnTick: true, showLastLabel: true}
			},
			legend: {
				align: 'right',
				x: -100,
				verticalAlign: 'top',
				y: 20,
				floating: true,
				backgroundColor: (Highcharts.theme && Highcharts.theme.legendBackgroundColorSolid) || 'white',
				borderColor: '#CCC',
				borderWidth: 1,
				shadow: false
			},
			tooltip: {
				formatter: function() {return sprintf("<b>%s</b><br>%s: %.1f%%<br>%s: %.1f%%",this.point.name,attrib1, this.x, attrib2, this.y);}
			},
			plotOptions: {
				scatter: {
					fillOpacity: 0.5,
					marker: {
						radius: 2,states: {hover: {enabled: true,lineColor: 'rgb(100,100,100)'}}
					},
					states: {
						hover: {marker: {enabled: false}}
					}
				}
			},
			series: dataContainer // [{name:dataName,data:xData,step:true}]
		});
}
