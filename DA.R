library(limma)
library(data.table)

#################RNA###########################################
subtype=read.table("subtype.tsv",header=T,sep='\t')
expre=fread("RNAseqnormalized.tsv")
expre=as.matrix(expre[,2:ncol(expre)],rownames=expre$V1)

#set comparisons
#~0 gives a model where each coefficient corresponds to a group mean
design=model.matrix(~0+subtype$subtype)
#fix names
colnames(design)=gsub("subtype.subtype","",colnames(design))
contr.mtrx=makeContrasts(
	basal_normal=Basal-Normal,
	her2_normal=Her2-Normal,
	luma_normal=LumA-Normal,
	lumb_normal=LumB-Normal,
levels=design)

#check if count&variance are indi
#if counts are more variable at lower expression, voom makes the 
#data “normal enough”
v=voom(expre,design,plot=T,save.plot=T)#no need if fitted curve is smooth
#https://ucdavis-bioinformatics-training.github.io/2018-June-RNA-Seq-Workshop/thursday/DE.html

#fit a linear model using weighted least squares for each gene
fit=lmFit(v,design)
fitSubtype = contrasts.fit(fit, contr.mtrx)
#treat is better than fc+p.val thresholds, that increase FP
tfitSubtype=treat(fitSubtype, lfc = log2(1.5))
#log2(1.2 or 1.5) will usually give DE genes with fc => 2
#depending on the sample size and precision of the experiment
DE.genes=lapply(1:4,function(x) 
	topTreat(tfitSubtype,coef=x,n=nrow(expre)))
names(DE.genes)=c("Basal_Normal","Her2_Normal",
	"LumA_Normal","LumB_Normal")
sapply(1:4,function(x) sum(DE.genes[[x]]$adj.P.Val<0.01))
#[1] 5279 4370 4051 4867
#pdf("DEgenes.pdf")
#par(mfrow=c(2,2))
#sapply(1:4,function(x) plotMA(fitSubtype,coef=x))
#sapply(1:4,function(x) {
#	volcanoplot(tfitSubtype,coef=x)
#	abline(h=-log2(1.2),col="red")
#})
#dev.off()
temp=do.call(rbind,lapply(1:4,function(x) 
	cbind(names(DE.genes)[x],DE.genes[[x]])))
png("logFC.png")
ggplot(temp,aes(y=logFC,x=contrast,color=contrast))+
	geom_boxplot()+theme(legend.position="none")
dev.off()
#write.table(temp,"DE.genes.tsv",sep='\t',quote=F)
#next:GSEA
#################miRNA###########################################
mir=fread("Downloads/miRNAseqNormi.tsv")
mir=as.matrix(mir[,2:ncol(mir)],rownames=mir$V1)

v=voom(mir,design,plot=T,save.plot=T)#no need if fitted curve is smooth
fit=lmFit(v,design)
fitSubtype = contrasts.fit(fit, contr.mtrx)
tfitSubtype=treat(fitSubtype, lfc = log2(1.5))
DE.miR=lapply(1:4,function(x) 
	topTreat(tfitSubtype,coef=x,n=nrow(mir)))
names(DE.miR)=c("Basal_Normal","Her2_Normal",
	"LumA_Normal","LumB_Normal")
sapply(1:4,function(x) sum(DE.miR[[x]]$adj.P.Val<0.01))
#[1] 329 185 132 220
#################methylation###########################################
##por ARSYN no hace falta este modelo tan complejo salvo para methy
design=model.matrix(~0+subtype$subtype+subtype$tumor_stage+
	subtype$treatment_or_therapy+subtype$race+
	subtype$ajcc_pathologic_t+subtype$primary_diagnosis+
	subtype$age_at_index+subtype$ajcc_pathologic_m)

#library(sva)
library(missMethyl)
load("porSubti.RData")
#https://ucdavis-bioinformatics-training.github.io/2018-June-RNA-Seq-Workshop/thursday/DE.html
#https://f1000research.com/articles/5-1408/v1

methy=do.call(cbind,sapply(concatenadas,function(x) x[[2]]))
design=methyDesign[methyDesign$barcode%in%colnames(methy),]
#add gender factor, to control for it on DM, nor on DE coz ARSyN is expected to have wiped all unwanted signal
table(methyDesign[,c(4,10)])
#        gender
#subtype  female male
#  Basal     135    0
#  Her2       74    1
#  LumA      331    0
#  LumB      170    7
#  normal     96    0
load("subtiTMMArsyn.RData")
gender=sapply(as.character(design$patient),function(x) unique(subtipos$gender[as.character(subtipos$patient)==x]))
design=cbind(design,gender)


#mRNA DE
rna=do.call(cbind,sapply(concatenadas,function(x) x[[3]]))
v=voom(rna,DE.design,plot=T,save.plot=T)
#rna variance~[0.1,0.3]


#esta bien usar t-test? no sabes si la expresión tiene distro normal, pero seguro no
#tampoco esperas homogeneity no?


#miR DE
mirna=do.call(cbind,sapply(concatenadas,function(x) x[[1]]))
v.miR=voom(mirna,DE.design,plot=T,save.plot=T)#mirna variance~[0.3,1.6]
fit=lmFit(v.miR,DE.design)
fitSubtype.miR = contrasts.fit(fit, contr.mtrx)
tfitSubtype.miR=treat(fitSubtype.miR, lfc = log2(1.1))
DE.miR=lapply(1:4,function(x) topTreat(tfitSubtype.miR,coef=x,n=nrow(mirna)))
names(DE.miR)=c("basal_normal","her2_normal","luma_normal","lumb_normal")
sapply(1:4,function(x) sum(DE.miR[[x]]$adj.P.Val<0.01))
#[1] 328 278 259 291
#no voom gives
#[1] 298 259 248 282
fiTemp=lmFit(mirna,DE.design) 
fiTemp=contrasts.fit(fiTemp, contr.mtrx)
pdf("DEmiRs.pdf")
par(mfrow=c(2,2))
sapply(1:4,function(x) plotMA(fiTemp,coef=x))
sapply(1:4,function(x) plotMA(fitSubtype.miR,coef=x))
sapply(1:4,function(x) {
	volcanoplot(tfitSubtype.miR,coef=x)
	abline(h=-log2(0.01),col="red")
})
dev.off()
save(DE.genes,DE.miR,file="DA.RData")

svg("voom.svg")
par(mfrow=c(2,1))
plot(v$voom.xy,xlab="log2(count size + 0.5)",ylab="Sqrt(standard deviation)",main="RNA")
lines(v$voom.line,col="red")
plot(v.miR$voom.xy,xlab="log2(count size + 0.5)",ylab="Sqrt(standard deviation)",main="miRNA")
lines(v.miR$voom.line,col="red")
dev.off()

#CpG DM reccomended method: RUV-inverse outperforms existing methods in DA of 450k data
M=lapply(1:4,function(x) cbind(concatenadas[[x]][[2]],concatenadas$normal[[2]]))
i=sapply(M,ncol)-75
DE.design=lapply(1:4,function(x) 
	model.matrix(~1+as.factor(c(rep(names(i)[x],i[x]),rep("normal",75)))))
#stage 1: find empirical controls not associated with subtypes 
fit = lapply(1:4,function(x) lmFit(M[[x]],DE.design[[x]]))
#unadjusted limma is the worst method coz it has lots of false positive [Maksimovic2015]
efit=lapply(fit,eBayes)
topr=lapply(efit,function(x) topTable(x,num=Inf))## Removing intercept from test coefficients
sapply(topr,function(x) sum(x$logFC[x$adj.P.Val<0.01]<0))#most DMs possible
#[1] 118260  82020 113250 109812
sapply(topr,function(x) sum(x$logFC[x$adj.P.Val<0.01]>0))
#[1] 113345 131402 103097 102783
ctl=lapply(topr,function(x) x$adj.P.Val>0.5) 
# performance is consistent when controls are selected based on FDR cut-off
sapply(ctl,table)#Maksimovic uses  2051 ‘true’ positives and 170 629 ‘true’ negatives
#        [,1]   [,2]   [,3]   [,4]
#FALSE 342764 336375 330017 332717
#TRUE   41811  48200  54558  51858
# Stage 2 analysis
rfit <- sapply(1:4,function(x) RUVfit(data=M[[x]], design=DE.design[[x]], coef=2, ctl=ctl[[x]])) 
rfit <- lapply(rfit,RUVadj)
DM.cpg=lapply(rfit,function(x) topRUV(x,num=Inf))
names(DM.cpg1)=c("luma_normal","basal_normal","lumb_normal","her2_normal")
sapply(DM.cpg,function(x) sum(x[x$p.ebayes.BH<0.01,1]<0))
#[1]    8 1146 1710 3620
sapply(DM.cpg,function(x) sum(x[x$p.ebayes.BH<0.01,2]>0))
#[1]   48 1312 1664 2877
#lumA may have less DM coz it has more samples, so the same threshold doesn't work for all subtypes 

#Alternative method
#given the large N(>>5) and cancer effect (gives the 1st PC), all methods are expected to work similarly
#though this only controls for KNOWN batches
DE.design=model.matrix(~0+design$subtype+design$plate+design$sample+design$vial+design$portion,design$gender)
colnames(DE.design)=gsub("design.","",colnames(DE.design))
fit1 = lmFit(methy,DE.design)
contr.mtrx=rbind(contr.mtrx,matrix(rep(0,(ncol(DE.design)-nrow(contr.mtrx))*ncol(contr.mtrx)),ncol=ncol(contr.mtrx)))
#0 for covariates, we're only after subtype signal 
fitSubtype.M1 = contrasts.fit(fit1, contr.mtrx)
tfitSubtype.M1 = treat(fitSubtype.M1,lfc=log2(1.5))
DM.cpg1=lapply(1:4,function(x) topTreat(tfitSubtype.M1,coef=x,n=nrow(methy)))
names(DM.cpg1)=colnames(contr.mtrx)
sapply(DM.cpg1,function(x) sum(x$logFC[x$adj.P.Val<0.01]<0))
#[1] 11266 11289  6882 25298
sapply(DM.cpg1,function(x) sum(x$logFC[x$adj.P.Val<0.01]>0))
#[1] 18367 27116 10847 39200
png("DM.png")
par(mfrow=c(3,4))
sapply(efit,limma::plotMA)
sapply(DM.cpg,function(x) plot(x[,c(1,5)],log="y",ylim=c(1,1e-13),ylab="log(p.ebayes)",xlab="lfc",pch='.'))
sapply(1:4,function(x) limma::volcanoplot(tfitSubtype.M1,coef=x,main=names(DM.cpg1)[x]))
dev.off()

save(DE.genes,DE.miR,DM.cpg,DM.cpg1,file="DA.RData")
