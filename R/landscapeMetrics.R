require(raster)
require(rgdal)

# sampling addons and other goodies
# source("~/Cloud/Code/ktaylor_essentialSpatialAddons.R")


#
# spatialPolygonsToHexagonalGrid()
# Quick wrapper funtion for HexPoints2SpatialPolygons(), because I can never remember the name of 
# the HexPoints2SpatialPolygons function when I need it.
#
# Author: Kyle Taylor (kyle.taylor@pljv.org)
#

spatialPolygonsToHexagonalGrid <- function(s=NULL,n=NULL){
  # default includes
  require(raster)
  require(rgdal)
  # sanity checks
  if(is.null(s) | is.null(n)) { cat(" -- error: no values specified for s= and n=\n"); stop(); }
  sLocations <- spsample(s, n=n, type="hexagonal")
    return(HexPoints2SpatialPolygons(sLocations))
}

#
# subsampleSurface()
# accepts a RasterLayer (and optional input pts=SpatialPoints object) and either generates a 
# buffered point pattern process across its surface or buffers the pts= data and performs an extraction
# across the raster surface using those data.  Returns a list containing the extractions.
#
# Author: Kyle Taylor (kyle.taylor@pljv.org)
#

subsampleSurface <- function(x=NULL, pts=NULL, n=100, type='random', width=NULL, DEBUG=T){
  if(DEBUG){ t1 <- Sys.time(); }
  # default includes
  require(rgeos)
  # sanity checks
  if(is.null(x)) { 
    cat(" -- error: x= parameter is undefined.\n");
    stop()
  } else if(is.null(width)){
    cat(" -- error: width= parameter is undefined. Buffer distance should be in meters.\n")
    stop()
  }
  # create a series of points covering the raster surface, x
  if(is.null(pts)){
    s <- as(extent(x), 'SpatialPolygons') 
      s <- spsample(s, n=n, type=type)
        s <- split(s,f=rep(1:length(s))) # convert to a list
  } else if(class(pts) == "SpatialPoints") { 
    # if the user specified spatial points at runtime, let's use them
    if(!is.na(crs(pts))){
      require(rgdal)
      pts <- spTransform(pts, CRS(raster::projection(x)))
    } else {
      cat(" -- error: NA coordinate reference system for pts= data.\n")
      stop()
    }
    s <- split(pts,f=rep(1:length(pts)))
  } else {
    cat(" -- error: unknown input. pts= argument should be SpatialPoints\n"); 
    stop();
  }
  # convert points to buffers and mask as needed across each buffered point      
  s <- lapply(s, FUN=rgeos::gBuffer, width=width)
    r_s <- lapply(s, FUN=raster::crop, x=x) 
        s <- mapply(FUN=raster::mask, x=r_s, mask=s); 

  rm(r_s); gc(verbose=F)

  if(DEBUG){ cat(" -- debug (elapsed time): ", Sys.time()-t1, "\n"); } 
  return(s)
}

#
# lReclass()
# accepts a list of rasters and reclasses each raster to a binary surface where 1=focal cover value and 
# 0=everything else
#
# Author: Kyle Taylor (kyle.taylor@pljv.org)
#

lReclass <- function(x=NULL, inValues=NULL){
  for(i in 1:length(x)){ # figure out how to do this with lapply
    x[[i]] <- x[[i]] %in% inValues
      x[[i]][x[[i]] == 0] <- NA
  }
  return(x)
}

#
# calcPatchIssolation()
# Calculate the KNN distance between patches in a binary raster specified by r=RasterLayer. You can either return the KNN index or some 
# statistic (e.g., mean) specified by fun=.  The default action is to return the full index.
#
# Author: Kyle Taylor (kyle.taylor@pljv.org) [2015]
#

calcPatchIssolation <- function(r, fun=NA, k=1){
  require(raster)
  require(sp)
  require(rgeos)
  require(FNN)
  
  o <- raster::clump(r)
    o <- raster::rasterToPolygons(o, dissolve=T, na.rm=T) 
      o <- sp::getSpPPolygonsLabptSlots(o)
  
  if(nrow(o) > k){ # return NA if there are not more than k patches available  
    o <- as.vector(FNN::knn.dist(data=o,k=k));
  } else {
    return(NA);
  }
  
  if(suppressWarnings(!is.na(fun))) o <- match.fun(fun)(o)
 
  return(o)
}

#
# calculateLandscapeMetric()
# quick wrapper function that accepts a raster list and applies landscape metrics across the list.  Code for landscape 
# metrics is implemented using an approach coded by Jeremy VanDerWal (jjvanderwal@gmail.com), using the SDMTools package.
#
# Author: Kyle Taylor (kyle.taylor@pljv.org)
#

lCalculateLandscapeMetrics <- function(x=NULL, metric=NULL, DEBUG=F){
  if(DEBUG){ t1 <- Sys.time(); }
  # default includes
  require(SDMTools)
  # sanity checks
  if(class(x) != "list") { cat(" -- error: x= object should be a list() of rasters, as returned by subsampleSurface().\n"); stop(); }

  # sanity check our buffer raster surfaces for valid data before passing to PatchStats and ClassStats
  naCheck <- function(x){ sum(values(is.na(x))) == ncell(x) }  
    allNa <- unlist(lapply(x, naCheck))

  if(sum(allNa)/length(allNa) == 1){
      if(DEBUG) warning("100% of buffered samples are NA.  Returning zero for all patch stats.")
      vClass <- vPatch <- rep(0, length(x))
      return(list(vClass, vPatch))
  } else if(sum(allNa)>0){ 
      if(DEBUG) warning((sum(allNa)/length(allNa))*100, "% of the sample buffers are completely NA.  Removing offenders, but it will lower your sample size.") 
      x <- x[!allNa]
  }

  # calculate patch and class statistics
  t <- lapply(x, ClassStat)
    t <- list(t,lapply(x, PatchStat)) # make a list of lists containing class stats and patch stats
  # parse out the requested metrics as vectors and return to user, if requested
  if(!is.null(metric)){
    classStats <- names(t[[1]][[1]])
    patchStats <- names(t[[2]][[1]])
    vClass <- vPatch <- vector()
    
    whichMetric <- classStats %in% metric
    if(sum(whichMetric) > 0){
      for(i in 1:length(t[[1]])){ focal <- t[[1]][[i]][1,whichMetric]; names(focal) <- classStats[whichMetric]; vClass<-append(vClass,focal) }
    }
    whichMetric <- patchStats %in% metric
    if(sum(whichMetric) > 0){
      for(i in 1:length(t[[2]])){ focal <- t[[2]][[i]][1,whichMetric]; names(focal) <- patchStats[whichMetric]; vPatch<-append(vPatch,focal) }
    }
    # lastly, are there statistics that were requested which are not a part of SDMTOOLS?
    if("patch.issolation" %in% metric){
      focal <- unlist(lapply(x, FUN=calcPatchIssolation, fun=median));
        names(focal) <- rep("patch.issolation", length(focal))
      vClass<-append(vClass,focal);
    }
    if(DEBUG){ cat(" -- debug (elapsed time): ", Sys.time()-t1, "\n"); }
    return(list(vClass,vPatch))
  }
  # return the full table of stats offered, by default
  if(DEBUG){ cat(" -- debug (elapsed time): ", Sys.time()-t1, "\n"); }
   return(t)
}

#
# Lextract()
# takes spatial features (e.g., SpatialPoints) from y= and extracts across a list of raster scenes specified by X=
# handy for extracting data across the spatial extent of scenes without having to mosaic the rasters into a single surface.
#

Lextract <- function(X=NULL, y=NULL, fun=mean){
  output <- NULL    # we don't know how many points will actually overlap our surface -- will assign output values dynamically
  y$id <- 1:nrow(y) # order our initial point sample by id, so that we can sort effectively later
  cat(" -- extracting across raster scenes: ")
  for(x in X){
    if(nrow(y)>0){ # sanity-check : prevent an attempted extraction with no points
      y <- spTransform(y, CRS(projection(x)))
      # extract overlapping features and add to our merged output
      if(gIntersects(as(extent(x), 'SpatialPolygons'), as(extent(y), 'SpatialPolygons'))){
         vals <- raster::extract(x, y, sp=F, fun=fun)
        # keep non-NA values and add them to output spatial feature -- place NA values back in y for the next iteration of the raster list
        focal <- y[!is.na(vals),]
          focal@data <- cbind(focal@data,data.frame(val=vals[!is.na(vals)]))
        y <- y[is.na(vals),]
        if(is.null(output)){ 
          output <- focal 
        } else {
          output <- rbind(output, spTransform(focal, CRS(projection(output))))
        }
      }
    }; cat(".")
  }; cat("\n")
  # merge in the remaining points (with NA extracted values)
  if(nrow(y)>1){
    y$val <- rep(NA,nrow(y))
    output <- rbind(output,y)
  }
  # return out output points, sorted by initial $id
  return(output[order(output$id),])
}

#
# metricsListToVector()
# parses the list output from lCalculateLandscapeMetrics() by metric name, returning the results as a vector.
#
metricsListToVector <- function(x,metric="total.area"){
  out <- vector();
  out <- append(out, as.vector(unlist(x[[1]][which(names(x[[1]]) == metric)])));
  out <- append(out, as.vector(unlist(x[[2]][which(names(x[[2]]) == metric)])));
  return(out);
}