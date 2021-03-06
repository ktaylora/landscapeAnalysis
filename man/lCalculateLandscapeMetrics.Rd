% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/landscapeMetrics.R
\name{lCalculateLandscapeMetrics}
\alias{lCalculateLandscapeMetrics}
\title{a wrapper function that accepts a raster list and applies landscape metrics across the list.  Code for landscape
metrics is implemented using an approach coded by Jeremy VanDerWal (jjvanderwal@gmail.com), using the 'SDMTools' package.}
\usage{
lCalculateLandscapeMetrics(x = NULL, metric = NULL, DEBUG = F,
  class = 1)
}
\arguments{
\item{x}{list object containing raster(s) that will be passed to 'SDMTools' to calculate class/patch statistics.}

\item{metric}{a vector containing the target class/patch metrics calculated for each raster object in 'x'.}

\item{class}{raster cell values (usually binary) indicating the focal class.  Default value is 1.}
}
\description{
a wrapper function that accepts a raster list and applies landscape metrics across the list.  Code for landscape
metrics is implemented using an approach coded by Jeremy VanDerWal (jjvanderwal@gmail.com), using the 'SDMTools' package.
}

