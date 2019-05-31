
import inspect, os
import sys


if __name__ == "__main__":

	
	#print inspect.getfile(inspect.currentframe()) # script filename (usually with path)
	path= os.path.dirname(os.path.abspath(inspect.getfile(inspect.currentframe())))+"/" # script directory
	print 'Setting install path to '+path
	
	
	print 'Writing optLayout settings file'
	f=open(path+"optLayout/src/settings.cuh",'w')
	f.write('char *home_dir="'+path+'optLayout/";')
	f.close()
	
	
	print 'Writing django settings'
	f=open(path+"djangosite/design/webSettings.py",'w')
	f.write('class Settings:\n')
	f.write('\t layoutDirPath = "'+path+'optLayout/data/runs/" \n')
	f.write('\t djangoPath = "'+path+'djangosite/design/static/" \n')
	f.write('\t optimizerPath = "'+path+'optLayout/" \n')
	f.close()
	
	
	f=open(path+"djangosite/djangosite/settings.py",'r')
	settings=f.read()
	f.close()
	#settings=settings.replace('/Users/donovan/Documents/work/design/web/',path)
	
	idx=settings.find("'NAME':")
	idx2=settings.find(",",idx)
	settings=settings[0:idx]+"'NAME': '"+path+"djangosite/djangosite/fontQuery.db'"+settings[idx2:]
	
	
	#print settings	
	f=open(path+"djangosite/djangosite/settings.py",'w')
	f.write(settings)
	f.close()