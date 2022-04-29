#' Inizialize the TMT and LFQ parameters
#'
#' @param usage message to exit the script analysis
#'
#' @return

initialize_msstats <- function(usage) {
    args <- commandArgs(trailingOnly = TRUE)
    if (length(args) < 1) {
        print(usage)
        stop("At least the first argument must be supplied (input csv).n", call. = FALSE)
    }
    if (length(args) < 2) {
        args[2] <- "pairwise"
    }

    if (length(args) < 3) {
        # default control condition
        args[3] <- ""
    }

    if (length(args) < 4) {
        # removeOneFeatProts
        args[4] <- FALSE
    }
    return(args)
}

#' Handle the number of contrasts in the differential expression analysis.
#' It returns a matrix of the contrasts to be analyzed.
#'
#' @param l
#' @param contrast_str
#' @param lvls number of doncitions

#' @return
#'
parse_contrasts <- function(l, contrast_str, lvls) {
    if (contrast_str == "pairwise") {
        if (control_str == "") {
            contrast_mat <- matrix(nrow = l * (l - 1) / 2, ncol = l, dimnames = list(Contrasts = rep(NA, l * (l - 1) / 2), Levels = lvls))
            c <- 1
            for (i in 1:(l - 1)) {
                for (j in (i + 1):l) {
                    comparison <- rep(0, l)
                    comparison[i] <- 1
                    comparison[j] <- -1
                    contrast_mat[c,] <- comparison
                    rownames(contrast_mat)[c] <- paste0(lvls[i], "-", lvls[j])
                    c <- c + 1
                }
            }
        } else {
            control <- which(as.character(lvls) == control_str)
            if (length(control) == 0) {
                stop("Control condition not part of found levels.n", call. = FALSE)
            }
            contrast_mat <- matrix(nrow = l - 1, ncol = l, dimnames = list(Contrasts = rep(NA, l - 1), Levels = lvls))
            c <- 1
            for (j in setdiff(1:l, control)) {
                comparison <- rep(0, l)
                comparison[i] <- -1
                comparison[j] <- 1
                contrast_mat[c,] <- comparison
                rownames(contrast_mat)[c] <- paste0(lvls[i], "-", lvls[j])
                c <- c + 1
            }
        }
    } else {
        contrast_lst <- unlist(strsplit(contrast_str, ";"))
        contrast_mat <- make_contrasts(contrast_lst, lvls)
    }
    print("Contrasts to be tested:")
    print(contrast_mat)
    return(contrast_mat)
}






