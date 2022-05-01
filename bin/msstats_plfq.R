#!/usr/bin/env Rscript

# load the MSstats library
require(MSstats)
require(tibble)
require(data.table)

# TODO: Functions shared between msstats_plfq and msstats_tmt should be merge in msstats_utils.R
# Please functions syncronized between the three scripts until the code can be merged.

### Begining Functions section

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
#'
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

#' This functions hels to define the contrasts that will be compare.
#'
#' @param contrasts
#' @param levels
#'
#' @return
make_contrasts <- function(contrasts, levels) {
    #helper function
    indicatorRow <- function(pos,len){
        row <- rep(0,len)
        row[pos] <- 1
        return(row)
    }

    if (is.factor(levels)) levels <- levels(levels)
    if (!is.character(levels)) levels <- colnames(levels)

    l <- length(levels)
    if (l < 1){
        stop("No levels given")
    }

    ncontr <- length(contrasts)
    if (ncontr < 1){
        stop("No contrasts given")
    }

    levelsenv <- new.env()
    for (i in 1:l) {
        assign(levels[i], indicatorRow(i,l), pos=levelsenv)
    }

    contrastmat <- matrix(0, l, ncontr, dimnames=list(Levels=levels,Contrasts=contrasts))
    for (j in 1:ncontr) {
        contrastsj <- parse(text=contrasts[j])
        contrastmat[,j] <- eval(contrastsj, envir=levelsenv)
    }
    return(t(contrastmat))
}

#' Get missing samples by condition
#'
#' @param processedData
#'
#' @return
get_missing_in_condition <- function(processedData) {
        p <- processedData
        n_samples <- aggregate(p$SUBJECT, by = list(p$GROUP), FUN = function(x) {return(length(unique(as.numeric(x))))})
        colnames(n_samples) <- c("GROUP", "n_samples")
        p <- p[complete.cases(p["LogIntensities"]),][,c("Protein", "GROUP", "SUBJECT")]
        p_dup <- p[!duplicated(p),]
        p_dup_agg <- aggregate(p_dup$SUBJECT, by = list(p_dup$Protein, p_dup$GROUP), length)
        colnames(p_dup_agg) <- c("Protein", "GROUP", "non_na")
        agg_join <- merge(p_dup_agg, n_samples, by = "GROUP")
        agg_join$missingInCondition <- 1 - agg_join$non_na / agg_join$n_samples

        p <- dcast(setDT(agg_join), Protein~GROUP, value.var = "missingInCondition")
        return(p)
    }

### End Function Sections

char_to_boolean <- c("true"=TRUE, "false"=FALSE)
usage <- "Rscript msstats_plfq.R input.csv [list of contrasts or 'pairwise'] [default control condition or ''] ..."

#TODO rewrite mzTab in next version
args <- initialize_msstats(usage = usage)

removeOneFeatProts <- args[4]
if(typeof(removeOneFeatProts) == 'character'){
    removeOneFeatProts <- char_to_boolean[removeOneFeatProts]
}

if (length(args)<5) {
    # keeps features with only one or two measurements across runs
    args[5] <- TRUE
}
removeFewMeasurements <- args[5]

if(typeof(removeFewMeasurements) == 'character'){
    removeFewMeasurements <- char_to_boolean[removeFewMeasurements]
}

if (length(args)<6) {
    # which features to use for quantification per protein: 'top3' or 'highQuality' which removes outliers only"
    args[6] <- 'top3'
}
if (length(args)<7) {
    # which summary method to use: 'TMP' (Tukey's median polish) or 'linear' (linear mixed model)
    args[7] <- 'TMP'
}
if (length(args)<8) {
    # outputPrefix
    args[8] <- './msstats'
}

csv_input <- args[1]
contrast_str <- args[2]
control_str <- args[3]

# read dataframe into MSstats
data <- read.csv(csv_input)
quant <- OpenMStoMSstatsFormat(data, removeProtein_with1Feature = removeOneFeatProts, removeFewMeasurements=removeFewMeasurements)

# process data
processed.quant <- dataProcess(quant, censoredInt = 'NA', featureSubset = args[6], summaryMethod = args[7])

lvls <- levels(as.factor(data$Condition))
l <- length(lvls)

if (l == 1) {
    print("Only one condition found. No contrasts to be tested. If this is not the case, please check your experimental design.")
} else {
    contrast_mat <- parse_contrasts(l = l, contrast_str = contrast_str, lvls = lvls)
    print ("Contrasts to be tested:")
    print (contrast_mat)
    test.MSstats <- groupComparison(contrast.matrix=contrast_mat, data=processed.quant)

    mic <- get_missing_in_condition(processed.quant$ProteinLevelData)
    test.MSstats$ComparisonResult <- merge(x=test.MSstats$ComparisonResult, y=mic, by="Protein")
    commoncols <- intersect(colnames(mic), colnames(test.MSstats$ComparisonResult))
    test.MSstats$ComparisonResult[, commoncols] <- apply(test.MSstats$Comparison[, commoncols], 2, function(x) {x[is.na(x)] <- 1; return(x)})

    #write all comparisons into one CSV file
    write.table(test.MSstats$ComparisonResult, file=paste0(args[8],"_comparisons.csv"), quote=FALSE, sep='\t', row.names = FALSE)

    groupComparisonPlots(data=test.MSstats$ComparisonResult, type="ComparisonPlot",
                        width=12, height=12,dot.size = 2)

    test.MSstats$Volcano <- test.MSstats$ComparisonResult[!is.na(test.MSstats$ComparisonResult$pvalue),]
    groupComparisonPlots(data=test.MSstats$Volcano, type="VolcanoPlot",
                        width=12, height=12,dot.size = 2)

    # Otherwise it fails since the behaviour is undefined
    if (nrow(contrast_mat) > 1) {
        groupComparisonPlots(data=test.MSstats$ComparisonResult, type="Heatmap",
                            width=12, height=12,dot.size = 2)
    }
}
