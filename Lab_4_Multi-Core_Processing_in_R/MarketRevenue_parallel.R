##################################################################
## Preliminaries
rm(list=ls())

## This function will check if a package is installed, and if not, install it
pkgTest <- function(x) {
  if (!require(x, character.only = TRUE))
  {
    install.packages(x, dep = TRUE)
    if(!require(x, character.only = TRUE)) stop("Package not found")
  }
}

## These lines load the required packages
packages <- c("readxl", "ggmap", "ggplot2", "foreach", "doParallel")
lapply(packages, pkgTest)


##################################################################
## Process

US_P <- readRDS("/projects/hackonomics/snowproject/United_States_Property.rds")
US_D <- readRDS("/projects/hackonomics/snowproject/United_States_Daily.rds")

US_P$City_State <- paste(US_P$City,"_", US_P$State, sep="")
  
Markets  <- unique(US_P$City_State, incomparables=FALSE)
#Markets1 <- Markets(1:1)

#print(Markets)

library("ggplot2")

findModel <- function(y, US_P, US_D){  

  print(paste0(y, " beginning"))

  ## Choose market
  TH_P <- subset(US_P, City_State==y)
  
  ## Subset Daily Data by Market
  TH_ID <- as.vector(TH_P$Property.ID)
  TH_D <- US_D[which(US_D$Property.ID %in% TH_ID),]
  
  if(nrow(TH_D) == 0){
    print(paste0(y," had 0 terms"))
  } else {

  # Define Market Characteristics
  City <- TH_P$City[1]
  State <- TH_P$State[1]
  
  ## Modify date format
  TH_D$date <- as.Date(as.character(TH_D$Date), format="%Y-%m-%d")
  TH_D$datepos <- as.POSIXlt(TH_D$date)
  
  ## Compute Property Level Potential Revenue
  TH_D$PotentialRevenue <- 0
  TH_D$PotentialRevenue[which(TH_D$Status=="A" | TH_D$Status=="R")] <- TH_D$Price[which(TH_D$Status=="A" | TH_D$Status=="R")]
  
  ## Compute Property Level Revenue
  TH_D$Revenue <- 0
  TH_D$Revenue[which(TH_D$Status=="R")] <- TH_D$Price[which(TH_D$Status=="R")]
  
  ## Compute Market Level Potential Revenue
  PotentialRevenue <- aggregate(PotentialRevenue ~ date, data=TH_D, FUN=sum, na.rm=TRUE)
  
  ## Compute Market Level Revenue
  Revenue <- aggregate(Revenue ~ date, data=TH_D, FUN=sum, na.rm=TRUE)
  
  ## Merge Revenue Data
  TH_Daily <- merge(PotentialRevenue,Revenue, by = c("date"))
  TH_Daily$RevenueFraction <- as.numeric(TH_Daily$Revenue/TH_Daily$PotentialRevenue)
  TH_Daily$City <- City
  TH_Daily$State <- State
  
  ## SaveRDS
  data_name = paste("/projects/hackonomics/snowproject/intermediate_parallel/", y, ".rds", sep="")
  saveRDS(TH_Daily, data_name)
  
  # Plot Potential and Actual Revenue by Date
  ggplot() +
    geom_line(aes(TH_Daily$date, TH_Daily$PotentialRevenue), colour='black') +
    geom_line(aes(TH_Daily$date, TH_Daily$Revenue), colour='red')
  
  # print file
  graph_name = paste("/projects/hackonomics/snowproject/intermediate_parallel/DailyRevenue/Revenue_", y, ".png", sep="")
  ggsave(graph_name, width = 8, height = 5)
  }
  # print finished city
  print(y)

}


Sys.time()
print("starting parallel")

np <- detectCores()
cl <- makeForkCluster(np-1)
clusterExport(cl, c())
registerDoParallel(cores=(np-1))

print(length(Markets))

foreach(i=1:length(Markets), .combine='c') %dopar% {
  findModel(Markets[i], US_P, US_D)
}

stopCluster(cl)
Sys.time()
print("ended parallel")







