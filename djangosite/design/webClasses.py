
class SimpleFont(object):
	def __init__(self,name):
		self.name = name
		
	def to_dict(self):
		return {
			#'__type__':'simple_font',
			'name':self.name
			#'fontNameURL':'/~libeks/fontQuery/static/fontNames/fontName-%s.gif'%(self.name)
			}

class Font(object):
	def __init__(self,name,imageURL,queryAttributes=[],otherAttributes=[],hiddenAttributes=[],score=None):
		self.name = name
		self.imageURL = imageURL
		self.score = score
		self.queryAttributes = queryAttributes
		self.otherAttributes = otherAttributes
		self.resultOrder = None
		#self.hiddenAttributes = hiddenAttributes #deprecated
	
	def to_dict(self):
		#print "inside to_dict: font score: %s"%(self.score)
		return {'__type__':'font',
			'name':self.name,
			'imageURL':self.imageURL,
			'score':self.score,
			#'queryAttributes':[attr.to_dict() for attr in self.queryAttributes],
			'queryAttributes':self.queryAttributes,
			#'otherAttributes':[attr.to_dict() for attr in self.otherAttributes],
			'otherAttributes':self.otherAttributes,
			'resultOrder': self.resultOrder,
			'fontNameURL':'/~libeks/fontQuery/static/fontNames/fontName-%s.gif'%(self.name)
			#'hiddenAttributes':[attr.to_dict() for attr in self.hiddenAttributes] 
			#'hiddenAttributes':self.hiddenAttributes #deprecated
			}
		
class Attribute(object):
	def __init__(self,name,score=None,inQuery=True):
		self.name = name
		assert score is not None
		self.score = score
		self.relativeScore = None
		#self.quality = quality # deprecated?
		self.inQuery = inQuery
	
	def nameWithPresence(self,negated=False):
		# adds a minus in front if the negation of attribute is needed
		presenceTranslator = {True: "",False: "-"}
		requestPresence = negated != self.presence #XOR of negated and self.presence
		return "%s%s"%(presenceTranslator[requestPresence],self.name)
	
	def to_dict(self):
		#print 'inside to_dict: attribute score: %s'%(self.score)
		return {'__type__':'attribute',
			'name':self.name,
			'score':self.score, # deprecated?
			'relativeScore':self.relativeScore,
			#'quality':self.presence, #deprecated
			'inQuery':self.inQuery
			}
	
class UserDisplay(object):
	def __init__(self,userID,IPs,nQueries,nStats,sinceFirst,sinceLast,locations=[]):
		self.userID = userID
		self.IPs = IPs
		self.nQueries = nQueries
		self.nStats = nStats
		self.sinceFirst = sinceFirst
		self.sinceLast = sinceLast
		self.locations = locations
		
	def to_dict(self):
		pass