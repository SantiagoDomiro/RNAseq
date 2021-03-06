files=list.files()
files=files[grep("pval",files)]
readHDIout=function(file){
	data=fread(file,verbose=F)
	data=data[which(rowSums(data[,2:101])!=0|data[,102]<1),]
	stability=rowSums(data[,2:101])/100
	data=cbind(data[,c(1,102)],stability)
	colnames(data)=c("predictor","pval","stability")
	return(data)
}
hdi=lapply(files,readHDIout)
names(hdi)=gsub(".pvals","",files)
hdi=hdi[sapply(hdi,nrow)>0]
pvals=lapply(hdi,function(x) sapply(x$stability,function(y) 
	binom.test(y*100,100,1/401482,"greater",conf.level=0.99)$p.val))
pvals=do.call(rbind,lapply(1:length(pvals),function(x) 
	cbind(names(hdi)[x],as.matrix(hdi[[x]]),pvals[[x]])))
pvals=cbind(pvals,p.adjust(as.numeric(lala[,5])))
colnames(pvals)[c(1,5,6)]=c("model","binom.pval","fdr.q")