#!/usr/bin/python
# -*- coding: utf8 -*-
from django.http import HttpResponse
from django.shortcuts import render_to_response
from django.template import RequestContext
from django.utils import simplejson
from django.utils.datetime_safe import datetime
from django.utils.timezone import utc
from webSettings import Settings
from design.models import User
from design.requestUtils import RequestUtils
from design.webUtils import WebUtils
import os
import time
import shutil
import urllib
import sys



#@csrf_protect
def main(request):
	viewType='main'
	return render_to_response('pages/main.html',locals(),
							context_instance=RequestContext(request,processors=[myContext]))

def createLayout(request):
	viewType='createLayout'
	return render_to_response('pages/createLayout.html',locals(),
                              context_instance=RequestContext(request,processors=[myContext]))

def importDesign(request):
	viewType='importDesign'
	return render_to_response('pages/importDesign.html',locals(),
                              context_instance=RequestContext(request,processors=[myContext]))

def createDesign(request):
	viewType='createDesign'
	return render_to_response('pages/createDesign.html',locals(),
                              context_instance=RequestContext(request,processors=[myContext]))

def playbackDesign(request):
	viewType='playbackDesign'
	return render_to_response('pages/playbackDesign.html',locals(),
                              context_instance=RequestContext(request,processors=[myContext]))

def selectDesign(request):
	viewType='selectDesign'
	return render_to_response('pages/selectDesign.html',locals(),
                              context_instance=RequestContext(request,processors=[myContext]))

def viewLayouts(request):
	viewType='viewLayouts'
	return render_to_response('pages/viewLayouts.html',locals(),
                              context_instance=RequestContext(request,processors=[myContext]))

def mturkABStudy(request):
	viewType='mturkABStudy'
	return render_to_response('pages/mturkABStudy.html',locals(),
                              context_instance=RequestContext(request,processors=[myContext]))

def viewABResults(request):
	viewType='viewABResults'
	return render_to_response('pages/viewABResults.html',locals(),
                              context_instance=RequestContext(request,processors=[myContext]))


def mturkStudy(request):
	viewType='mturkStudy'
	suggestions =checkSuggestions(request) 
	print 'suggestions:'+str(suggestions)
	return render_to_response('pages/mturkStudy.html',locals(),
                              context_instance=RequestContext(request,processors=[myContext]))


def mturkAbstractStudy(request):
	viewType='mturkAbstractStudy'
	suggestions =checkSuggestions(request) 
	print 'suggestions:'+str(suggestions)
	return render_to_response('pages/mturkAbstractStudy.html',locals(),
                              context_instance=RequestContext(request,processors=[myContext]))


def retargetStudy(request):
	viewType='retargetStudy'
	suggestions =checkSuggestions(request) 
	
	return render_to_response('pages/retargetStudy.html',locals(),
                              context_instance=RequestContext(request,processors=[myContext]))
	
	
def matchStudy(request):
	viewType='matchStudy'
	suggestions =checkSuggestions(request) 
	return render_to_response('pages/matchStudy.html',locals(),
                              context_instance=RequestContext(request,processors=[myContext]))
                              
                              
                              
                              
	
def checkSuggestions(request):
	
	print("path:"+request.path)
	sugg_str="noSuggestions="
	idx= request.path.find(sugg_str)
	if idx>-1:
		print 'idx:'+str(idx)
		idx+=len(sugg_str)
		return 1-int(str(request.path[idx:idx+1]))

	return 1	
	
	
def saveABStudyData(request):
	import json
	data = request.POST['json']
	data = json.loads(data)
	assignmentID = data['assignmentId']
	studyName = data['studyName']
	timestamp = time.time()
	filename = 'designEvaluation-%s-%s-%s.json'%(studyName,assignmentID,timestamp)
	with open(os.path.join(Settings.djangoPath+"json/designABResults/",filename),'w') as f:
		json.dump(data,f,indent=4)
	return HttpResponse(filename)


def pairedStudy(request):
	viewType='pairedStudy'
	suggestions=1
	return render_to_response('pages/pairedStudy.html',locals(),
                              context_instance=RequestContext(request,processors=[myContext]))



def setCurrentDesign(request):
	requestSource = request.GET
	runID = getRunID(request) 
	design = requestSource.get('design')

	
	
	print("Received design from client:"+design)
	try:
		fname=os.path.join(Settings.layoutDirPath,'r'+str(runID)+'_design.data')
		f=open(fname,'w')
		f.write(design)
		f.close();
		
		print("Finished writing design")
		return HttpResponse('1')
	except  IOError  as e:
		return HttpResponse(e.strerror)
	



def getLayoutFromClient(request):
	requestSource = request.GET
	runID = getRunID(request) 
	layout = requestSource.get('layout')
	
	
	layoutDB=RequestUtils.getLayout(runID,True)
	if layoutDB is not None:
		layoutDB.layout=layout
		layoutDB.send_time=datetime.utcnow().replace(tzinfo=utc)
		layoutDB.save()
		return HttpResponse('1')
	else:
		return HttpResponse('ERROR. No layout for run '+str(runID))
	'''
	fname=os.path.join(Settings.layoutDirPath,'r'+str(runID)+'_check_layout.data')
	
	try:
		
		f=open(fname+'.tmp','w')
		f.write(layout)
		f.close()
		
		os.rename(fname+'.tmp',fname)
		print("Finished writing layout:"+layout)
		
		return HttpResponse('1')
	except IOError  as e:
		print "I/O error({0}): {1}, {2}".format(e.errno, e.strerror,fname)
		return HttpResponse(e.strerror)
	'''
	
	
def updateParameters(request):
	requestSource = request.GET
	runID = getRunID(request) 
	parameterType = requestSource.get('parameterType')
	parameterValue = requestSource.get('parameterValue')
	print("Updating model parameters");
	

			
	fname=os.path.join(Settings.layoutDirPath,'r'+str(runID)+'_parameter_change.data')
	try:
		
		f=open(fname,'w')
		f.write(parameterType+"\n"+parameterValue)
		f.close();
		return HttpResponse('1')
	except IOError  as e:
		print "I/O error({0}): {1}, {2}".format(e.errno, e.strerror,fname)
		return HttpResponse(e.strerror)
	
	
	
def stopRun(request):
	requestSource = request.GET
	runID = getRunID(request) 
	runType = requestSource.get('runType')
	debugMode = requestSource.get('debugMode')
	print("Stopping run ");

	
	command= 'pkill -f "'+Settings.optimizerPath+'optLayout -i -r '+str(runID)+' -t '+runType+' -b '+debugMode+'"'
		
	print('command: '+command)
	sendCommand(command)
	


	
	return HttpResponse('1')




def sendCommand(filename,dir=''):
	command=dir+filename
	if '/home/donovan' in Settings.layoutDirPath:
		command="ssh donovan@medusa.dgp.toronto.edu '"+dir+filename+"' &"
	print command
	os.system(command)
	

def sendLayoutToClient(request):

	requestSource = request.GET
	runID = getRunID(request) 

	retObj={};
	retObj['runID']=runID
	retObj['galleryIdx']=-1

	runType=request.GET.get('runType')
	dirName=Settings.layoutDirPath+"../gallery/"+request.GET.get('dirName')+"/"
	galleryIdx=int(request.GET.get('galleryIdx'))
	
	retObj['dirName']=dirName
	#retObj['galleryIdx']=galleryIdx
	
	if ((runType=='gallery') and (os.path.isdir(dirName)) and (galleryIdx>-1)):
		
		idx=galleryIdx
		
		for i in range(0,1000):
			if idx>=999:
				idx=0
			else:
				idx+=1
			try:
				fname=dirName+"style"+str(idx)+".data"
				f=open(os.path.join(dirName,fname),'r')
				retObj['layout']=f.read()
				f.close()	
				
				retObj['optimizationActive']=True;
				retObj['userLayoutFeatures']=''
				retObj['layoutFeatures']=''
				retObj['galleryIdx']=idx
				
				retJSON = simplejson.dumps(retObj,default=default_action)
				return HttpResponse(retJSON)
			except:
				pass
		
	layoutDB=RequestUtils.getLayout(runID,False)
	if layoutDB is not None:
		

		retObj['layout']=layoutDB.layout
		
		
		time_diff=datetime.utcnow().replace(tzinfo=utc)-layoutDB.send_time
		#print 'time since last modification: '+str(time_diff.seconds)

		retObj['optimizationActive']=time_diff.seconds<15;
		retObj['userLayoutFeatures']=''
		retObj['layoutFeatures']=''
		
		try:

			fname='r'+str(runID)+'_user_layout_features.txt'
			f=open(os.path.join(Settings.layoutDirPath,fname),'r')
			retObj['userLayoutFeatures']=f.read()
			f.close()	
		except:
			pass
		
		try:
			fname='r'+str(runID)+'_opt_layout_features.txt'
			f=open(os.path.join(Settings.layoutDirPath,fname),'r')
			retObj['layoutFeatures']=f.read()
			f.close()	
		except:
			pass
		
		retJSON = simplejson.dumps(retObj,default=default_action)
		return HttpResponse(retJSON)
	else:
		return HttpResponse('ERROR. No layout for run '+str(runID))
	
	

	
	'''
	#check_layout=''
	layout=''
	#layoutFeatures=''
	#userLayoutFeatures=''
	
	fname='r'+str(runID)+'_opt_layout.data'
	
	try:
		
		mod_time=os.path.getmtime(os.path.join(Settings.layoutDirPath,fname))
		
		curr_time=time.time()
		diff=curr_time-mod_time
		
		if (diff<7.0):
			retObj['optimizationActive']=True;
		
		
		f=open(os.path.join(Settings.layoutDirPath,fname),'r')
		layout=f.read()
		f.close()
		
	
		fname=os.path.join(Settings.layoutDirPath,'r'+str(runID)+'_check_layout.data')
		f=open(fname,'r')
		check_layout=f.read()
		f.close()
		
		
		fname='r'+str(runID)+'_opt_layout_features.txt'
		f=open(os.path.join(Settings.layoutDirPath,fname),'r')
		layoutFeatures=f.read()
		f.close()
				
		fname='r'+str(runID)+'_user_layout_features.txt'
		f=open(os.path.join(Settings.layoutDirPath,fname),'r')
		userLayoutFeatures=f.read()
		f.close()
	
		
	except IOError  as e:
		print "I/O error({0}): {1}, {2}".format(e.errno, e.strerror,fname)
		#return HttpResponse(e.strerror)
  
    
    
	retObj['layout']=layout;
	

	retObj['layoutFeatures']=layoutFeatures;
	retObj['userLayoutFeatures']=userLayoutFeatures;
	retObj['userLayout']=check_layout;
	
	
	retJSON = simplejson.dumps(retObj,default=default_action)
	return HttpResponse(retJSON)
	'''


def getRunID(request):
	runID=int(request.GET.get('runID'))
	if runID<10:
		
		user = RequestUtils.setOrGetUser(request)
		#userID = user.userID
		#runID= RequestUtils.registerOptimizationRequest(request,user)
		
		return runID+user.id*10;
	else:
		return runID
		
		
def startNewRun(request):



	requestSource = request.GET
	
	runID = getRunID(request) 
	runType = requestSource.get('runType')
	design = requestSource.get('design')
	
	debugMode = requestSource.get('debugMode')
	
	userID = RequestUtils.setOrGetUser(request).userID
	
	
	#create DB entries for layouts between gpu server and client
	layoutDB=RequestUtils.getOrSetLayout(request,runID,True)
	layoutDB.layout=''
	layoutDB.save()
	layoutDB=RequestUtils.getOrSetLayout(request,runID,False)
	layoutDB.layout=''
	layoutDB.save()	
		
	command=''
	print 'runID:'+str(runID)

	
	retObj={}
	print("starting new run for userID: "+userID)
	
	'''
	try:
		#removeFile('r'+str(runID)+'_check_layout.data')
		
		fname=os.path.join(Settings.layoutDirPath,'r'+str(runID)+'_check_layout.data')
		f=open(fname,'w')
		f.write('quit')
		f.close()
		time.sleep(0.1)
		#os.remove(os.path.join(Settings.layoutDirPath,'r'+str(runID)+'_check_layout.data'))
	except Exception, e:
	    print 'Failed to write: '+ str(e)
	'''
	
	try:
		
		if ('Users' in Settings.layoutDirPath):
			sendCommand("killall -9 optLayout")
	
		fname=os.path.join(Settings.layoutDirPath,'r'+str(runID)+'_design.data')
		f=open(fname+'.tmp','w')
		f.write(design)
		f.close();
		
		os.rename(fname+'.tmp',fname)
		
			
		command= Settings.optimizerPath+"optLayout -i -r "+str(runID)+" -t "+runType+" -b "+debugMode+" &"
		print('command: '+command)
		sendCommand(command)
		
		if ('Users' in Settings.layoutDirPath):
			time.sleep(0.1)
			sendCommand('cpulimit -p `pgrep optLayout` -l 25 &')
	except IOError as e:
		return HttpResponse("Error({0}): {1}".format(e.errno, e.strerror))
	
		
	print("Trying to start new run. id "+str(runID))
	


	
	retObj['runID']=runID
	retObj['commandOutput']=command
	retObj['userID']=userID
	print 'command output: '+command
	
	retJSON = simplejson.dumps(retObj,default=default_action)
	return HttpResponse(retJSON)


def saveReport(request):
	
	context=myContext(request)
	userID = context['userID']
	requestSource = request.POST
	
	reportString = requestSource.get('report')
	reportName= userID+"-"+requestSource.get('reportName')
	image1 = requestSource.get('image1')
	image2 = requestSource.get('image2')
	image3 = requestSource.get('image3')
	
	dirName="reports/"	
	
	try:
		fname=Settings.djangoPath+dirName+reportName+".json"
		f = open(fname,"w")
		f.write(reportString)
		f.close()		
		
		image_fname=Settings.djangoPath+dirName+reportName+"-before.png"
		im = urllib.urlopen(image1)
		output = open(image_fname,"wb")
		output.write(im.read())
		output.close()
		
		image_fname=Settings.djangoPath+dirName+reportName+"-after.png"
		im = urllib.urlopen(image2)
		output = open(image_fname,"wb")
		output.write(im.read())
		output.close()
		
		image_fname=Settings.djangoPath+dirName+reportName+"-opt.png"
		im = urllib.urlopen(image3)
		output = open(image_fname,"wb")
		output.write(im.read())
		output.close()
	
	except IOError  as e:
		print "I/O error({0}): {1}, {2}".format(e.errno, e.strerror,fname)
		return HttpResponse(e.strerror)
		
	return HttpResponse('1')

def saveDesign(request):
	
	requestSource = request.POST
	userID = requestSource.get('userID')
	designString = requestSource.get('design')
	image = requestSource.get('image')
	designName=requestSource.get('designName')
	
	print("saveDesign")
	
	try:
		
		designString = designString.encode('ascii', 'ignore')
		design = simplejson.loads(designString)
		
		
		print("design name:"+designName)
		
		
		if 'layouts' in designName:
			dirName='images/'
		else:
			
			designDir=design[u'directory']
			dirName="designs/"+designDir
			print("design dir:"+designDir)
			
		
		fname=Settings.djangoPath+dirName+designName+".json"

		
		if (len(designString)>5):
			f = open(fname,"w")
			f.write(designString)
			f.close()
			
		
		
		image_fname=Settings.djangoPath+dirName+designName+".png"
		
		im = urllib.urlopen(image)
		output = open(image_fname,"wb")
		output.write(im.read())
		output.close()
		
		
		
		
	except IOError  as e:
		print "I/O error({0}): {1}, {2}".format(e.errno, e.strerror,fname)
		return HttpResponse(e.strerror)
		
		
		
	return HttpResponse('1')


def saveImage(request):
	
	requestSource = request.POST
	imgName= requestSource.get('imageName')
	image = requestSource.get('image')

	image_fname=Settings.djangoPath+"images/"+imgName
	
	im = urllib.urlopen(image)
	output = open(image_fname,"wb")
	output.write(im.read())
	output.close()
	
	return HttpResponse('1')



def deleteDesign(request):
	
	requestSource = request.GET
	designName= requestSource.get('designName')
	print("Trying to delete "+designName)
	
	stripName=designName
	if "/" in designName:
		
		stripName=designName[designName.rfind("/")+1:]
	
	try:
		shutil.move(Settings.djangoPath+"designs/"+designName+".json", Settings.djangoPath+"designs/"+"deleted/"+stripName+".json")
		shutil.move(Settings.djangoPath+"designs/"+designName+".png", Settings.djangoPath+"designs/"+"deleted/img/"+stripName+".png")
	except IOError  as e:
		print "I/O error({0}): {1}".format(e.errno, e.strerror)
		return HttpResponse(e.strerror)
		
	return HttpResponse('1')



def listDesigns(request):
	
	requestSource = request.GET
	userID = requestSource.get('userID')
	
	dir = requestSource.get('dir')
	if dir!='':
		if dir[-1]!='/':
			dir+='/'
		print("dir: "+dir)
	designs=[]

	for filename in os.listdir(Settings.djangoPath+"designs/"+dir):
	    print  filename
	    if '.json' in filename:
			#f=open(os.path.join(Settings.djangoPath+"designs/",filename),'r')
			designs.append(dir+filename)
	
	print designs
	retObj={}
	retObj['designs']=designs
	retJSON = simplejson.dumps(retObj,default=default_action)
	return HttpResponse(retJSON)



def getJSONFiles(request):
	
	dir = request.GET.get('dir')
	if dir!='':
		if dir[-1]!='/':
			dir+='/'
		print("dir: "+dir)
	json_files=[]
	for filename in os.listdir(Settings.djangoPath+"json/"+dir):
	    print  filename
	    if '.json' in filename:
	    

	    	f=open(os.path.join(Settings.djangoPath+"json/",dir+filename),'r')
	    	
	    	json=simplejson.loads(f.read())
	    	json['filename']=filename
	    	
	    	json_files.append(simplejson.dumps(json,default=default_action))
	    	f.close()
			
	
	retObj={}
	retObj['files']=json_files
	retJSON = simplejson.dumps(retObj,default=default_action)
	return HttpResponse(retJSON)



def getSortedFiles(dirpath):
    a = [s for s in os.listdir(dirpath)
         if os.path.isfile(os.path.join(dirpath, s))]
    a.sort(key=lambda s: os.path.getmtime(os.path.join(dirpath, s)))
    return a[::-1]


def listLayouts(request):
	
	requestSource = request.GET
	userID = requestSource.get('userID')
	
	interface= str(requestSource.get('interface'))
	print 'interface:'+(interface)
	
	workerID= str(requestSource.get('workerID'))
	print 'workerID:'+(workerID)
	
	design= str(requestSource.get('design'))
	print 'design:'+(design)
	
	
	if ((design =='') and (workerID=='')):
		return HttpResponse('Please specify a design')
	
	if ((design =='') and (workerID!='')):
		design='all'
	
	layouts=[]

	for filename in getSortedFiles(Settings.djangoPath+"json/"):
	    print  filename
	    if '.json' in filename:
	    	
	    	if 'layoutStudyResults' in filename:
	    		continue
	    	
	    	if ((design != 'all') and (design not in filename)):
	    		print 'design:'+design
	    		continue
	    	if ((workerID != '') and (workerID not in filename)):
	    		print 'workerID does match:'+(workerID)
	    		continue
	    	
	    	
	    	f=open(os.path.join(Settings.djangoPath+"json/",filename),'r')
	    	print  'added :'+filename
	    	#designs.append(filename)
	    	layout=f.read()
	    	
	    	json=simplejson.loads(layout)
	    	json['filename']=filename
	    	
	    	if (("interface" in json) and (interface!= '') and (json['interface']!=interface)):
	    		continue
	    	
	    	layouts.append(simplejson.dumps(json,default=default_action))
	    	f.close()
	
	retObj={}
	retObj['layouts']=layouts
	retJSON = simplejson.dumps(retObj,default=default_action)
	return HttpResponse(retJSON)




def layoutStudyResults(request):
	import json
	data = request.POST['json']
	data = json.loads(data)
	timestamp = time.time()
	filename = '%s-%s-%s.json'%(data['design'],data['workerID'],timestamp)
	with open(os.path.join(Settings.djangoPath+"json/",filename),'w') as f:
		json.dump(data,f,indent=4)
	return HttpResponse(filename)




def computeGetLayout(request):
	
	runID=int(request.body)

	layoutDB=RequestUtils.getLayout(runID,True)
	if layoutDB is not None:
		
		try:
			fname=os.path.join(Settings.layoutDirPath,'r'+str(runID)+'_check_layout.data')
			f=open(fname,'w')
			f.write(layoutDB.layout)
			f.close()
		except Exception, e:
			print 'Failed to write: '+ str(e)	
		
		
		return HttpResponse(layoutDB.layout)
	else:
		return HttpResponse('ERROR: no layout')



def computeSendLayout(request):
	resp= (request.body)
	runID=int(resp.split('\n')[0])
	idx=resp.index("\n")
	layout=resp[(idx+1):]

	
	try:
		fname=os.path.join(Settings.layoutDirPath,'r'+str(runID)+'_opt_layout.data')
		f=open(fname,'w')
		f.write(layout)
		f.close()
	except Exception, e:
		print 'Failed to write: '+ str(e)
	

	layoutDB=RequestUtils.getLayout(runID,False)
	if layoutDB is not None:
		layoutDB.layout=layout
		layoutDB.save()
		return HttpResponse('1')
	else: 
		return HttpResponse("ERROR. No layout for that run")
	return HttpResponse("1")


def myContext(request):
	'A context processor that provides userID'
	user = RequestUtils.setOrGetUser(request)
	userID = user.userID
	RequestUtils.registerRequest(request,user)
	return {'userID' : userID}

def default_action(obj):
	# this function returns a dictionary for any object that is not JSON-serializable.
	return obj.to_dict()	
	