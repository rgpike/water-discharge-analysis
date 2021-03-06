
# Compare the computed percentile longterm statistics with those from the Excel spreadsheet
# Change Log
#     2017-01-30 CJS First Edition

compare.percentile.longterm.stat <- function(Station.Code,
                                             Q.filename, E.filename,
                                             write.comparison.csv=FALSE,
                                             write.plots.pdf=FALSE,
                                             report.dir=".",
                                             csv.nddigits=3,  # number of decimal digits to write out
                                             debug=FALSE){
#  Input
#    Station.Code - prefix for file names
#    Q.filename - file name of csv file containing the annual statistics
#    E.filename - Excel workbook with the statistics
#    save.comparison - save the csv file of comparisons
#    save.plots      - save the plots
#
#  Output: List with the following objects
#    stats.in.Q.not.in.E  - statistics in Q but not in E
#    stats.in.E.not.in.Q  - statistics in E but not in Q
#    diff.stat - data frame showing for each statistics the value in Q, the value in E and the
#                proportional difference
#    plot.list - list of plots visualizing the diff.stat
#    stat.not.plotted - list of variables not in any of the plots (should be empty)
#############################################################
#  Some basic error checking on the input parameters
#
   Version <- "2017-02-15"
   if( !is.character(Station.Code))  {stop("Station Code must be a character string.")}
   if(length(Station.Code)>1)        {stop("Station.Code cannot have length > 1")}
   if( !is.character(Q.filename))    {stop("Q.filename  muste be a character string.")}
   if( !is.character(E.filename))    {stop("E.filename  muste be a character string.")}
   if( !file.exists(Q.filename))     {stop('Q.filename does not exist')}
   if( !file.exists(E.filename))     {stop('E.filename does not exist')}
   if(length(Q.filename)>1)          {stop("Q.filename cannot have length > 1")}
   if(length(E.filename)>1)          {stop("E.filename cannot have length > 1")}

   if(! is.logical(write.comparison.csv)) {stop("write.comparison.csv should be logical")}
   if(! is.logical(write.plots.pdf))      {stop("write.plots.pdf should be logical")}
   if( !dir.exists(as.character(report.dir)))      {stop("directory for saved files does not exits")}

   if(!is.numeric(csv.nddigits)){ stop("csv.nddigits must be numeric")}
   csv.nddigits <- round(csv.nddigits)[1]
   #  Load the packages used 
   library(ggplot2)
   library(openxlsx)
   library(plyr)

   # Get the computed summary statistics created in another file
   Q.stat <- read.csv(file=Q.filename, header=TRUE, as.is=TRUE, strip.white=TRUE)

   # Get the data from the Excel spreadsheet
   E.stat.in <- openxlsx::readWorkbook(E.filename, sheet='HydroDataSummary',  rows=7:29)
   if(debug)browser()
   E.stat.in <- E.stat.in[, (ncol(E.stat.in)-12):ncol(E.stat.in)]  # CG1: CT5 but readWorkBook skips blank columns in the first 5 rows

   # Transpose the Excel sheet 
   E.stat.in[,1] <- paste("P",formatC(100-as.numeric(E.stat.in[,1]), width=2, format="d", flag="0"), sep="")
   E.stat <-as.data.frame(t(E.stat.in[,-1]), stringsAsFactors=FALSE)
   names(E.stat) <- E.stat.in[,1]
   E.stat$Month <- row.names(E.stat)
   E.stat$Month <- substr(E.stat$Month,1,3)
   
   # check the names in the two data frames
   names(Q.stat)
   names(E.stat)

   # which statistics are in Q.stat, but not in E.stat
   stats.in.Q.not.in.E <- names(Q.stat)[ !names(Q.stat) %in% names(E.stat)]

   # which statistics are in E.stat but not in Q.stat
   stats.in.E.not.in.Q <- names(E.stat)[ !names(E.stat) %in% names(Q.stat)]
   #browser()
   # Now to compare the results from Q.stat to those in E.stat
   diff.stat <- ldply( names(Q.stat)[ names(Q.stat) != "Month" & !(names(Q.stat) %in% stats.in.Q.not.in.E)], 
                      function (stat, Q.stat, E.stat){
      # stat has the name of the column to compare
      Q.values <- Q.stat[, c("Month",stat)]
      E.values <- E.stat[, c("Month",stat)]
      both.values <- merge(Q.values, E.values, by="Month", suffixes=c(".Q",".E"))
      both.values$diff <-  both.values[,paste(stat,".Q",sep="")] - both.values[,paste(stat,".E",sep="")]  
      both.values$mean <- (both.values[,paste(stat,".Q",sep="")] + both.values[,paste(stat,".E",sep="")])/2
      both.values$pdiff  <- abs(both.values$diff)/ both.values$mean 
      both.values$stat <- stat
      names(both.values)[names(both.values) == paste(stat,".Q",sep="")] <- "Value.Q"
      names(both.values)[names(both.values) == paste(stat,".E",sep="")] <- "Value.E"
      both.values[ !(is.na(both.values$Value.Q) & is.na(both.values$Value.E)),]
    }, Q.stat=Q.stat, E.stat=E.stat)

   # Visualize where any difference lie
   diff.stat[ is.na(diff.stat$pdiff),]
   max(diff.stat$pdiff, na.rm=TRUE)
   min(diff.stat$pdiff, na.rm=TRUE)

   
   makediffplot <- function (plotdata){
     myplot <- ggplot2::ggplot(data=plotdata, aes(x=Month, y=stat, size=pdiff))+
       ggtitle(paste(Station.Code, " - Standardized differences between Q.stat and E.Stat",sep=""))+
       theme(plot.title = element_text(hjust = 0.5))+
       geom_point()+
       scale_size_area(limits=c(0,.01), name="Proportional\ndifference")+
       ylab("Variables showing \nProportion of abs(diff) to mean")
     # indicate missing values using X
     if(sum(is.na(plotdata$pdiff))){
        myplot <- myplot + geom_label(data=plotdata[is.na(plotdata$pdiff),], aes(label="X", size=NULL),size=4, fill='red',alpha=0.2)
     }
     myplot
  }

   plotdata <- diff.stat
   plotdata$Month <- factor(plotdata$Month, levels=month.abb, order=TRUE)
   plotdata$pdiff <- pmin(.01, plotdata$pdiff)

   plot.allstat <- makediffplot(plotdata)  # all variables

   # are there any variables not plotted?
   stat.not.plotted <- NA

   plot.list <- list(plot.allstat=plot.allstat)

   file.comparison <- NA
   if(write.comparison.csv){
      file.comparison.csv <- file.path(report.dir, paste(Station.Code,"-comparison-percentile-longterm-R-vs-Excel.csv",sep=""))
      write.csv(diff.stat, file.comparison.csv, row.names=FALSE)
   }
   
   file.plots.pdf <- NA
   if(write.plots.pdf){
      file.plots.pdf <- file.path(report.dir, paste(Station.Code,"-comparison-percentile-longterm-R-vs-Excel.pdf",sep=""))
      pdf(file=file.plots.pdf)
      l_ply(plot.list, function(x){plot(x)})
      dev.off()
   }
   
   list(stats.in.Q.not.in.E=stats.in.Q.not.in.E,
        stats.in.E.not.in.Q=stats.in.E.not.in.Q,
        diff.stat=diff.stat,
        plot.list=plot.list,
        stat.not.plotted=stat.not.plotted,
        file.cmparsion.csv=file.comparison.csv,
        file.plots.pdf=file.plots.pdf,
        Version=Version,
        Date=Sys.time())
}