
#' Inizialize the TMT and LFQ parameters
#'
#' @param usage message to exit the script analysis
#'
#' @return

initialize_msstats <- function (usage){
    args <- commandArgs(trailingOnly=TRUE)
    if (length(args)<1) {
        print(usage)
        stop("At least the first argument must be supplied (input csv).n", call.=FALSE)
    }
    if (length(args)<2) {
        args[2] <- "pairwise"
    }

    if (length(args)<3) {
        # default control condition
        args[3] <- ""
    }

    if (length(args)<4) {
        # removeOneFeatProts
        args[4] <- FALSE
    }
    return(args)
}




