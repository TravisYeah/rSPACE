##### Subfunctions #############################################################
readInput<-function(filename){                                                 #
  DF<-read.delim(filename, header=F, sep=c(' ', '*'),                          #
    colClasses=c("character"))[,c(2,4)]                                        #
  names(DF)<-c('GridID', 'ch')                                                 #
  DF$GridID<-as.numeric(DF$GridID)                                             #
  return(DF)                                                                   #
  }                                                                            #
                                                                               #
switcheroo<-function(x,detP) {                                                 #
  for(i in 1:length(x)){                                                       #
    if(x[i]=="1"){if(rbinom(1,1,prob=detP)==0) {x[i]="0"}}                     #
    }                                                                          #
    return(x)                                                                  #
  }                                                                            #
                                                                               #
time_int<-function(n_visit, n_yrs){                                            #
  tmp<-rep(0,n_visit)                                                          #
  tmp[n_visit] = 1                                                             #
  tmp<-rep(tmp,n_yrs)                                                          #
  return(tmp[-n_yrs*n_visit])                                                  #
  }                                                                            #
                                                                               #
drop_visits<-function(ch, n_visits, n_yrs, n_visit){                           #
  tmp<-rep(F,n_visits)                                                         #
  tmp[1:n_visit]=T                                                             #
  tmp<-rep(tmp,n_yrs)                                                          #
  unlist(lapply(strsplit(ch,split=""),function(x) paste(x[tmp], collapse=""))) #
  }                                                                            #
                                                                               #
drop_years <- function(ch, n_visits, dropvec=rep(c(F,T),                       #
                length.out=nchar(ch[1])/n_visits), samples=NULL){              #
  dropvec<-matrix(dropvec, ncol=length(dropvec),nrow=length(ch), byrow=T)      #
  if(!is.null(samples)){                                                       #
    smple<-sample(nrow(samples), length(ch), replace=T)                        #
    dropvec<-matrix(as.logical(as.matrix(samples[smple,])),nrow=nrow(dropvec)) #
  }                                                                            #
#    ch <- unlist(lapply(strsplit(ch, split=""), function(x) {                 #
#      x[rep(dropvec,each=n_visits)]="."                                       #
#      paste(x,collapse="")} ))                                                #
    ch_split<-strsplit(ch, split='')                                           #
    ch <- unlist(sapply(1:length(ch), function(x) {                            #
      ch_split[[x]][rep(dropvec[x,],each=n_visits)]="."                        #
      paste(ch_split[[x]],collapse="")} ))                                     #
  if(is.null(samples)) {ch<-substr(ch,1,nchar(ch)-n_visits)}                   #
  return(ch)}                                                                  #
                                                                               #
drop_detP <-function(ch, detP) {                                               #
  unlist(lapply(strsplit(ch,split=""),                                         #
    function(x) paste(switcheroo(x,detP), collapse="")))}                      #
                                                                               #
FPC <- function(n, N, use=T) {if(use==T) return((N-n)/N) else return(1)}       #
                                                                               #
                                                                               #
variance.components<-function(est, Trend_DM, vcv.est, REML=T){                 #
   if(REML==T) {                                                               #
     return(var.components.reml(est,design=Trend_DM,vcv.est))                  #
     } else {                                                                  #
     return(var.components(est,design=Trend_DM,vcv.est))                       #
     }                                                                         #
}                                                                              #
                                                                               # 
set_grid<-function(filetest, SubPop=NULL){                                     #
 # Filter out cells that shouldn't be included.                                #
 # SubPop should be a raster with the previous grid layer                      #
 #  filtered to a subregion.                                                   #
  if(!is.null(SubPop)){                                                        #
    map<-raster(SubPop,band=2)                                                 #
    GRDuse <- unique(getValues(map))                                           #
    GRDuse <- GRDuse[which(GRDuse>0)] #drops NAs and 0s.                       #
  } else {                                                                     #
    test = readInput(filetest)                                                 #
    GRDuse = test$GridID                                                       #
  }                                                                            #
  return(GRDuse)                                                               #
  }                                                                            #
                                                                               #
adjust_detP<-function(detP_test,detP1=1){                                      #
  n<-length(detP_test)                                                         #
  detP_test<-detP_test/c(detP1,detP_test)[-(n+1)]                              #
  return(detP_test)                                                            #
  }                                                                            #
                                                                               #
                                                                               #
file_label<-function(filename){                                                #
  filename<-unlist(lapply(strsplit(filename,'/'),function(x) rev(x)[1]))       #
  filename<-gsub('.txt','',filename)                                           #
  return(filename)                                                             #
}                                                                              #
                                                                               #
                                                                               #
################################################################################

## Main loop function 
test_samples<-function(folder, Parameters, ... ){
  additional.args<-list(...)
    function_name<-default.value(additional.args$function_name,"wolverine_analysis")
    SubPop       <-additional.args$SubPop
    sample_matrix<-additional.args$sample_matrix
    xxx          <-default.value(additional.args$xxx,1)
    max_xxx      <-default.value(additional.args$max_xxx,1)
    min_xxx      <-default.value(additional.args$min_xxx,1)
    base.name    <-default.value(additional.args$base.name, "rSPACEx")
    n_runs       <-additional.args$n_runs
    FPCind       <-default.value(additional.args$FPC, TRUE)
    skipConfirm  <-default.value(additional.args$skipConfirm, F)


   if(!skipConfirm){
      askConfirm<-("" ==readline(prompt="\n rSPACE creates text files.
        If you're ok with this, press ENTER to continue.
        Typing anything else will exit.\n"))
      if(!askConfirm)
      { message('Exiting function')
        return(0)
      }
   }

  cat('\nSetting up...\n')
  time1 = proc.time()[3] 
  
  n_visits<-Parameters$n_visits
  n_yrs<-Parameters$n_yrs
  RunAnalysis<-get(function_name)
  
  # All encounter history files to test
  output_files = dir(folder, pattern=paste0('^',base.name),full.names=T)  

  # Set up output folder/file for results
  folder<-paste0(folder,'/output')
  if(!file.exists(folder)) 
    dir.create(folder)  
  results_file<-paste(folder,"/sim_results", xxx, ".txt",sep="")
  
  sim_results<-RunAnalysis(n_yrs)
  cat(c(names(sim_results),"n_grid","n_visits","detP","gap_yr","rn","\n"), 
    file=results_file)
  
  
  # Parameters to vary
  if(is.null(Parameters$n_visit_test)) Parameters$n_visit_test=2:Parameters$n_visits
  if(is.null(Parameters$detP_test))    Parameters$detP_test = c(1,0.8,0.2) 
  if(is.null(Parameters$grid_sample))  Parameters$grid_sample=c(0.05,0.15,0.25,0.35,0.45,0.55,0.75,0.95)
  if(is.null(Parameters$sample_yrs))   Parameters$sample_yrs<-c(0,1)
  
  GRDuse<-set_grid(output_files[1], SubPop)
  gridTotal<-length(GRDuse)
    
  n_grid_sample = round(Parameters$grid_sample*gridTotal)
  detP_test = adjust_detP(Parameters$detP_test,Parameters$detP)

  
  #Main loop
  if(is.null(n_runs)) n_runs<-length(output_files)
  index<-rep(min_xxx:max_xxx,length.out=n_runs)
  for(rn in (1:n_runs)[index==xxx]){ 
   cat('\n', rn, ' ');flush.console()
   test<-readInput(output_files[rn])
    GRD<-test$GridID
    test<-test$ch
   use = sample(match(GRDuse, GRD), gridTotal)

   detPhold = Parameters$detP
  
  for(detPt in detP_test){
  test<-drop_detP(test, detPt)  # cumulatively reduces the number of detections
  detPhold = detPhold * detPt

  for(n_grid in n_grid_sample){
    suppressWarnings(rm("ch1"))
    ch1<-test[use[1:n_grid]]    # only include data from grids in sample
    fpc<-ifelse(FPCind, FPC(n_grid, gridTotal) ,1)  

    for(n_visit in Parameters$n_visit_test){
      suppressWarnings(rm("ch"))
      ch<-drop_visits(ch1, n_visits, n_yrs, n_visit) # drop data from extra visits

      for(gap_yr in Parameters$sample_yrs){
        cat('.'); flush.console()
        sim_results<-RunAnalysis(n_yrs, ch, n_visit, gap_yr, fpc, ...)
        for(i in 1:nrow(sim_results)){
          cat(c(unlist(sim_results[i,]),
            n_grid,n_visit,detPhold,gap_yr,file_label(output_files[rn]),'\n'), 
            file=results_file,append=T)
        }}}}}}
  cat('/n')      
  return(proc.time()[3]-time1)
}
                
  
