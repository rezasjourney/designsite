from webSettings import Settings
from datetime import datetime
import pytz
import random
import string
import os

class WebUtils():

	@staticmethod
	def loadAttributePreview():
		filepath = os.path.join(Settings.dataDirPath,'attributeExamples.data')
		filecontents =  WebUtils.getFileLines(filepath)
		return filecontents[0]

	@staticmethod
	def stringToBoolean(text,default=None):
		"""
		Given a string, return a boolean
		'True','true','1' -> True
		'False','false','0','' -> False
		if text is None, return default
		"""
		trueValues = ['True','true','1']
		falseValues = ['False','false','0','']
		if text in trueValues:
			return True
		elif text in falseValues:
			return False
		elif text is None:
			return default
		else:
			print text
			raise

	@staticmethod
	def getFileLines(path):
		f=open(path,'rU')
		lines = [line.rstrip('\n') for line in f]
		f.close()
		if lines and lines[-1]=='':
			lines = lines[:-1]
		return lines

	@staticmethod
	def fontImagePathRelative(fontName,depth=1):
		return "%s%s.png"%(Settings.absPathToImages,fontName)
	
	@staticmethod
	def timeSinceDateTimeToString(dt):
		pluralTrans = {False:'',True:'s'}
		delta = WebUtils.timeSinceDateTimeToDelta(dt)
		deltaseconds = delta.seconds
		deltadays = delta.days
		minutes,_seconds = divmod(deltaseconds,60)
		hours,minutes = divmod(minutes,60)
		weeks,days = divmod(deltadays,7)
		if weeks>0:
			return "%d week%s ago"%(weeks,pluralTrans[weeks>1])
		elif days>0:
			return "%d day%s ago"%(days,pluralTrans[days>1])
		elif hours>0:
			return "%d hour%s ago" %(hours,pluralTrans[hours>1])
		elif minutes>0:
			return "%d minute%s ago"%(minutes,pluralTrans[minutes>1])
		else:
			return "mere seconds ago"
		
	@staticmethod
	def timeSinceDateTimeToDelta(dt):
		now = datetime.now(pytz.utc)
		delta = now-dt
		return delta
	
	@staticmethod
	def randomString(N=30):
		return ''.join(random.choice(string.ascii_uppercase + string.digits) for _x in range(N))
	
	@staticmethod
	def getMinMaxXY(data):
		# given a list of 2d coordinates, return the min and max of each dimension
		# data is a list of two-tuples
		minx = min([coord1 for (coord1,_coord2) in data])
		miny = min([coord2 for (_coord1,coord2) in data])
		maxx = max([coord1 for (coord1,_coord2) in data])
		maxy = max([coord2 for (_coord1,coord2) in data])
		return (minx,maxx),(miny,maxy)
	

	@staticmethod
	def scale(points,uLeft=(0,0),lRight=(100,100),padding=5):
		# given a list of 2-tuples (points), the coordinates of the upper left (uLeft) and lower right (lRight) coordinates of the box
		# as well as optional padding, returned a list of scaled points so that they fit into the box and that angles are preserved
		uLeft = tuple([val+padding for val in uLeft])
		lRight = tuple([val-padding for val in lRight])
		xWidth,yWidth = [(high-low) for low,high in zip(uLeft,lRight)]
		assert xWidth>0
		assert yWidth>0
		(minx,maxx),(miny,maxy) = WebUtils.getMinMaxXY(points)
		xRange,yRange = float(maxx-minx),float(maxy-miny)
		xScale,yScale = xRange/xWidth,yRange/yWidth
		scale = max(xScale,yScale)
		xOffset,yOffset = (xWidth-xRange/scale)/2,(yWidth-yRange/scale)/2
		retPoints = []
		for x,y in points:
			nx,ny = xOffset + padding + (x-minx)/scale,yOffset + padding + (y-miny)/scale
			retPoints.append((nx,ny))
		return retPoints
	
	@staticmethod
	def softMins(distList,sigma=1.0):
		import math
		#input is a list of distances. Distances should be normalized so that the smallest one is 1, so then sigma=1
		exps = [math.exp(-dist)/sigma for dist in distList]
		sumExp = sum(exps)
		return [exp/sumExp for exp in exps]
	
	
	
	@staticmethod	
	def multisampleFromDiscrete(distribution,nSamples):
		# takes nSamples from the probability distribution without replacement
		# distribution = [(prob,eltName)]
		# where prob's don't have to sum to 1
		assert len(distribution)>nSamples
		retList = []
		for _iSample in range(nSamples):
			choiceName = WebUtils.sampleOneFromDiscrete(distribution)
			retList.append(choiceName)
			distribution = [(weight,eltName) for (weight,eltName) in distribution if not eltName==choiceName]
		assert len(retList)==nSamples
		return retList
	
	@staticmethod
	def getCachedIPLocation(ip):
		#print "checking ip: %s"%(ip)
		lines = WebUtils.getFileLines("%sips.data"%(Settings.cacheDirPath))
		for line in lines:
			lineIP,location = line.split('\t')
			if lineIP==ip:
				return location
		return None
	
	@staticmethod
	def setCacheIPLocation(ip,location):
		#print "setting ip: %s, location: %s"%(ip,location)
		with open("%sips.data"%(Settings.cacheDirPath),'a') as f:
			f.write('%s\t%s\n'%(ip,location))
	
	@staticmethod
	def getIPLocation(ip):
		assert len(ip)>0
		location =  WebUtils.getCachedIPLocation(ip)
		if location is None:
			import json
			import urllib
			url = "http://api.hostip.info/get_json.php?ip=%s"
			response = urllib.urlopen(url%(ip)).read()
			#print response
			jsDict = json.loads(response)
			location = "%s, %s"%(jsDict['city'],jsDict['country_name'])
			WebUtils.setCacheIPLocation(ip, location) 
		return location
	