#' @title Cast array to data frame
#' @param object \code{array} class object
#' @param value_to column header for array value
#' @param dim.names list of dimension names
#' @importFrom tibble as_tibble
#' @export
array2dfr <- function(object, value_to = "value", dim.names = list()) {
    
    # check and correct length of dim.names vectors
    invisible(lapply(1:length(dim.names), function(i) dim.names[[i]] <<- dim.names[[i]][1:dim(object)[i]]))
    
    # assign
    dimnames(object) <- dim.names
    
    # melt to data frame
    object <- array2DF(object, responseName = value_to)
    
    # coerce iterations and time to integer values
    class(object[,which(grepl("^iter", colnames(object)))]) <- "integer"
    class(object[,which(grepl("_iter", colnames(object)))]) <- "integer"
    class(object[,which(grepl("time", colnames(object)))])  <- "integer"
    
    # return
    return(as_tibble(object))
}
