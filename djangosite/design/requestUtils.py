#!/usr/bin/python
# -*- coding: utf8 -*-
from models import User, Request,OptimizationRequest, StatsLog,Layout
from webUtils import WebUtils
from webSettings import Settings as WebSettings

class RequestUtils():
	@staticmethod
	def logSQLQuery(queryStr):
		with open("%s../cache/queries.data"%WebSettings.djangoPath,'a') as f:
			f.write("%s\n"%(queryStr))
	
	@staticmethod
	def getIPAddress(request):
		ip = '1.1.1.1' 
		if 'HTTP_X_REAL_IP' in request.META:
			ip = request.META['HTTP_X_REAL_IP']
		elif 'HTTP_X_FORWARDED_FOR' in request.META:
			ip = request.META['HTTP_X_FORWARDED_FOR']
		elif 'REMOTE_ADDR' in request.META:
			ip = request.META['REMOTE_ADDR']
		return ip
	
	@staticmethod
	def registerRequest(request,user):
		assert user is not None
		ip = RequestUtils.getIPAddress(request)
		url = request.get_full_path()
		req = Request(ip=ip,url=url,request_user = user)
		req.save()
		
	@staticmethod
	def registerOptimizationRequest(request,user):
		assert user is not None
		ip = RequestUtils.getIPAddress(request)
		url = request.get_full_path()
		
		req = Request(ip=ip,url=url,request_user = user)
		req.save()
		
		optreq = OptimizationRequest(ip=ip,url=url,request=req, request_user = user)
		#req = Request(ip=ip,url=url,request_user = user)
		optreq.save()
		
		return optreq.id
	
	@staticmethod
	def fetchUserByIP(ip):
		assert ip is not None
		#usersByMostRequests = sorted(User.objects.all(),key=lambda n:(n.nQueries()),reverse=True)
		query = User.objects.filter(request__ip=ip)[:1]
		#print query.query
		RequestUtils.logSQLQuery(query.query)
		#for user in usersByMostRequests:
		#	ipList = user.ipList()
		#	if ip in ipList:
		#		return user
		#return None
		try:
			user = query.get()
		except User.DoesNotExist:
			return None
		return user
	
	@staticmethod
	def newUser():
		user = User(userID=WebUtils.randomString())
		user.save()
		return user
	
	@staticmethod
	def getUser(userID):
		try:
			user = User.objects.get(userID=userID)
		except User.DoesNotExist:
			return None
		#print user.query
		#RequestUtils.logSQLQuery(user.query)
		assert user is not None
		return user
	
	@staticmethod
	def setOrGetUser(request):
		userID = None
		requestSource = request.GET
		if 'userID' in requestSource:
			userID = requestSource['userID']
			#print "has User ID: %s"%(userID)
		user = None
		if userID is not None:
			#user = RequestUtils.getUser(userID)
			user = RequestUtils.getUser(userID)
		if user is None:
			ip = RequestUtils.getIPAddress(request)
			user = RequestUtils.fetchUserByIP(ip)
			#print "had to use ip address"
		if user is None:
			user = RequestUtils.newUser()
			userID = user.userID
		return user
	
	
	
	@staticmethod
	def newLayout(request,run_id,layout,client_to_server):
		
		user = RequestUtils.setOrGetUser(request)
		ip = RequestUtils.getIPAddress(request)
		
		l = Layout(request_user = user,ip=ip,run_id=run_id,layout=layout,client_to_server=client_to_server)
		l.save()
		return l
	
	
	@staticmethod
	def getOrSetLayout(request,run_id,client_to_server):
		
		
		l = RequestUtils.getLayout(run_id,client_to_server)
		
		if l is None:
			
			user = RequestUtils.setOrGetUser(request)
			ip = RequestUtils.getIPAddress(request)
			
			l = Layout(request_user = user,ip=ip,run_id=run_id,client_to_server=client_to_server)
			l.save()
			
		return l
	
	
	@staticmethod
	def getLayout(run_id,client_to_server):
		try:
			l = Layout.objects.get(run_id=run_id,client_to_server=client_to_server)
		except Layout.DoesNotExist:
			return None
		
		assert l is not None
		return l
	
	
	@staticmethod
	def registerStat(request,statType,statInfo):
		#assert 'userID' in request.GET
		#print "userID:%s"%(request.GET.get('userID'))
		#user = RequestUtils.getUser(request.GET.get('userID'))
		user = RequestUtils.setOrGetUser(request)
		req = StatsLog(request_user = user,statType = statType,statPiece = statInfo)
		req.save()