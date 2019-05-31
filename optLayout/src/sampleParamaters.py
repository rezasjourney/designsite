
import numpy as np
import os



homedir='/Users/podonova/school/design/web/optLayout/data/'


input_styles_dir=homedir+'input_styles/'

output_styles_dir=homedir+'style_samples0/'


param_lists=[]



for file in os.listdir(input_styles_dir):
	if file.endswith(".data"):
		print file
		
		f=open(input_styles_dir+file,'r')
		lines=f.readlines()
		f.close()
		
		print lines
		names=[]
		
		p=[]
		
		for i in range(1,len(lines)):
			l=lines[i]
			l=l.replace("\n","")
			splt=l.split(",")
			
			print l
			names.append(splt[0])
			p.append(float(splt[1]))
			p.append(float(splt[2]))
			p.append(float(splt[3]))
			
		param_lists.append(p)


for i in names:
	print i

num_input_styles=len(param_lists)
num_params=len(param_lists[0])

params=np.zeros((num_input_styles,num_params))

for p in range(num_input_styles):
	for i in range(num_params):
		params[p,i]=param_lists[p][i]



mean_param=np.mean(params.T,axis=1)
A=params
M = (A-mean_param).T # subtract the mean (along columns)
[latent,coeff] = np.linalg.eig(np.cov(M))

numpc=num_input_styles-1
p = np.size(coeff,axis=1)
print p

idx = np.argsort(latent) # sorting the eigenvalues
idx = idx[::-1]       # in ascending order
# sorting eigenvectors according to the sorted eigenvalues
coeff = coeff[:,idx]
latent = latent[idx] # sorting eigenvalues
if numpc < p and numpc >= 0:
	coeff = coeff[:,range(numpc)] # cutting some PCs if needed

score = np.dot(coeff.T,M) # projection of the data in the new space



rlatent=np.real(latent)
rcoeff=np.real(coeff)

num_gen_styles = 1


for p in range(num_gen_styles):
	
	r=np.random.normal(size=numpc)
	
	scale=r*np.sqrt(rlatent[range(numpc)])
	scale = 0
	
	new_params=mean_param+(rcoeff*scale).sum(axis=1)
	new_params[new_params<0]=0
	
	f=open(output_styles_dir+'gen_style'+str(p)+'.data','w')
	f.write("Weights,,,\n")
	
	for j in range(0,num_params/3):
		if ((names[j]!='Previous Layout')):
			f.write("%s,%.3f,%.3f,%.3f\n"%(names[j],new_params[j*3],max(new_params[j*3+1],0.1),new_params[j*3+2]))
	
	f.close()

