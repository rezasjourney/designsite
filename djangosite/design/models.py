from django.db import models
#from datetime import datetime
from webUtils import WebUtils
from webClasses import UserDisplay
import urlparse
# Create your models here.


class User(models.Model):
	userID = models.CharField(max_length=30,db_index=True)
	created = models.DateTimeField(auto_now_add=True)
	modified = models.DateTimeField(auto_now=True)
	
	def getOldestCreatedRequest(self):
		if self.nQueries()>0:
			return self.request_set.order_by('created')[0].getSinceCreatedDate()
		else:
			return ''
	
	def getNewestCreatedRequest(self):
		count = self.nQueries()
		if count>0:
			return self.request_set.order_by('created')[count-1].getSinceCreatedDate()
		else:
			return ''
	
	def getNewestCreatedDelta(self):
		count = self.nQueries()
		if count>0:
			return self.request_set.order_by('created')[count-1].getSinceCreatedDelta()
		else:
			return 0
	
	def nQueries(self):
		return self.request_set.count()
	
	def nStats(self):
		return self.statslog_set.count()
	
	def getAllStats(self):
		return [stat.forDisplay() for stat in self.statslog_set.order_by('-created')]
	
	def ipList(self):
		ipList = self.request_set.values_list('ip',flat=True).distinct()
		#print ipList
		return ipList
	
	def getUserDisplay(self):
		return UserDisplay(self.userID,
                           self.ipList(),
                           self.nQueries(),
                           self.nStats(),
                           self.getOldestCreatedRequest(),
                           self.getNewestCreatedRequest())
	
	def getAllQueries(self):
		return [request.forDisplay() for request in self.request_set.order_by('-created')]
	
	def __str__(self):
		return "User :%s"%(self.userID)

class Request(models.Model):
	ip = models.IPAddressField(db_index=True)
	request_user = models.ForeignKey(User)
	url = models.URLField(max_length=2000)
	created = models.DateTimeField(auto_now_add=True)
	modified = models.DateTimeField(auto_now=True)
	
	def getSinceCreatedDate(self):
		return WebUtils.timeSinceDateTimeToString(self.created)
	
	def getSinceCreatedDelta(self):
		return WebUtils.timeSinceDateTimeToDelta(self.created)
    
	
	def forDisplay(self):
		path,query = self.prettyUpUrl()
		return {'urlPath':path,'query':query,'created':self.created}
	
	def prettyUpUrl(self):
		o = urlparse.urlparse(self.url)
		path = o.path
		query = o.query
		queryDict = urlparse.parse_qs(query)
		if 'userID' in queryDict:
			del queryDict['userID']
		if 'probList' in queryDict:
			del queryDict['probList']
		for key,value in queryDict.items():
			if len(value)==1:
				value = value[0]
				queryDict[key]=value
		return path,queryDict.items()

	def __str__(self):
		return "Request: %s %s %s"%(self.request_user,self.ip,self.url)



class Layout(models.Model):
	run_id = models.IntegerField(db_index=True)
	layout = models.CharField(max_length=500)
	#url = models.URLField(max_length=2000)
	ip = models.IPAddressField()
	request_user = models.ForeignKey(User)
	created = models.DateTimeField(auto_now_add=True)
	modified = models.DateTimeField(auto_now=True)
	send_time = models.DateTimeField(auto_now=True)
	client_to_server=models.BooleanField()
	def __str__(self):
		return "Layout. User %s. Run id %d, layout: %s"%(self.request_user,self.run_id,self.layout)
	def getSinceCreatedDate(self):
		return WebUtils.timeSinceDateTimeToString(self.created)
	def getSinceCreatedDelta(self):
		return WebUtils.timeSinceDateTimeToDelta(self.created)


class OptimizationRequest(models.Model):
	ip = models.IPAddressField(db_index=True)
	url = models.URLField(max_length=2000)
	request_user = models.ForeignKey(User)
	request = models.ForeignKey(Request)
	
	def __str__(self):
		return "Optimization Request: %s %s %s"%(self.request_user,self.ip,self.url)

class StatsLog(models.Model):
	request_user = models.ForeignKey(User)
	statType = models.TextField()
	statPiece = models.TextField()
	created = models.DateTimeField(auto_now_add=True)
	
	def getSinceCreatedDate(self):
		return WebUtils.timeSinceDateTimeToString(self.created)
	
	def forDisplay(self):
		return {'statType':self.statType,'statPiece':self.statPiece,'created':self.created}



