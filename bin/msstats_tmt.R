#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)
char_to_boolean = c("true"=TRUE, "false"=FALSE)

usage <- "Rscript msstats_tmt.R input.csv [list of contrasts or 'pairwise'] [default control condition or '']... [normalization based reference channel]"
if (length(args)<1) {
    print(usage)
    stop("At least the first one argument must be supplied (input csv).n", call.=FALSE)
}
if (length(args)<2) {
    # contrasts
    args[2] = "pairwise"
}
if (length(args)<3) {
    # default control condition
    args[3] = ""
}

if (length(args)<4) {
    # removeOneFeatProts
    args[4] = FALSE
}
rmProtein_with1Feature = args[4]
if(typeof(rmProtein_with1Feature) == 'character'){
    rmProtein_with1Feature = char_to_boolean[rmProtein_with1Feature]
}

if (length(args)<5) {
    # use unique peptide
    args[5] = TRUE
}
useUniquePeptide = args[5]
if(typeof(useUniquePeptide) == 'character'){
    useUniquePeptide = char_to_boolean[useUniquePeptide]
}

if (length(args)<6) {
    # remove the features that have 1 or 2 measurements within each Run.
    args[6] = TRUE
}
rmPSM_withfewMea_withinRun = args[6]
if(typeof(rmPSM_withfewMea_withinRun) == 'character'){
    rmPSM_withfewMea_withinRun = char_to_boolean[rmPSM_withfewMea_withinRun]
}

if (length(args)<7) {
    # sum or max - when there are multiple measurements for certain feature in certain Run.
    args[7] = 'sum'
}

if (length(args)<8) {
    # summarization methods to protein-level can be performed: "msstats(default)"
    args[8] = "msstats"
}

if (length(args)<9) {
    # Global median normalization on peptide level data
    args[9] = TRUE
}
global_norm = args[9]
if(typeof(global_norm) == 'character'){
    global_norm = char_to_boolean[global_norm]
}

if (length(args)<10) {
    # Remove norm channel
    args[10] = TRUE
}
remove_norm_channel = args[10]
if(typeof(remove_norm_channel) == 'character'){
    remove_norm_channel = char_to_boolean[remove_norm_channel]
}

if (length(args)<11) {
    # default Reference channel based normalization between MS runs on protein level data.
    # Reference Channel annotated by 'Norm' in Condition.
    args[11] = TRUE
}
reference_norm = args[11]
if(typeof(reference_norm) == 'character'){
    reference_norm = char_to_boolean[reference_norm]
}

csv_input <- args[1]
contrast_str <- args[2]
control_str <- args[3]

require(MSstatsTMT)
# read dataframe into MSstatsTMT
data <- read.csv(csv_input)
quant <- OpenMStoMSstatsTMTFormat(data, useUniquePeptide=useUniquePeptide, rmPSM_withfewMea_withinRun=rmPSM_withfewMea_withinRun,
    rmProtein_with1Feature=rmProtein_with1Feature
)

# protein summarization
processed.quant <- proteinSummarization(quant, method=args[8],remove_empty_channel=TRUE, global_norm=global_norm,
    reference_norm=reference_norm, remove_norm_channel=remove_norm_channel
)

dataProcessPlotsTMT(processed.quant, "ProfilePlot", width=12, height=12, which.Protein="all")
dataProcessPlotsTMT(processed.quant, "QCPlot", width=12, height=12, which.Protein="allonly")

lvls <- levels(as.factor(processed.quant$ProteinLevelData$Condition))
l <- length(lvls)
if (l == 1)
{
    print("Only one condition found. No contrasts to be tested. If this is not the case, please check your experimental design.")
} else {
    if (contrast_str == "pairwise")
    {
        if (control_str == "")
        {
            contrast_mat <- matrix(nrow = l * (l-1) / 2, ncol = l, dimnames=list(Contrasts=rep(NA, l * (l-1) / 2), Levels=lvls))
            c <- 1
            for (i in 1:(l-1))
            {
                for (j in (i+1):l)
                {
                    comparison <- rep(0,l)
                    comparison[i] <- 1
                    comparison[j] <- -1
                    contrast_mat[c,] <- comparison
                    rownames(contrast_mat)[c] <- paste0(lvls[i],"-",lvls[j])
                    c <- c+1
                }
            }
        } else {
            control <- which(as.character(lvls) == control_str)
            if (length(control) == 0)
            {
                stop("Control condition not part of found levels.n", call.=FALSE)
            }

            contrast_mat <- matrix(nrow = l-1, ncol = l, dimnames=list(Contrasts=rep(NA, l-1),Levels=lvls))
            c <- 1
            for (j in setdiff(1:l,control))
            {
                comparison <- rep(0,l)
                comparison[i] <- -1
                comparison[j] <- 1
                contrast_mat[c,] <- comparison
                rownames(contrast_mat)[c] <- paste0(lvls[i],"-",lvls[j])
                c <- c+1
            }
        }
    } else {
        contrast_lst <- unlist(strsplit(contrast_str,";"))
        contrast_mat <- make_contrasts(contrast_lst, lvls)
    }
    print ("Contrasts to be tested:")
    print (contrast_mat)
    #TODO allow for user specified contrasts
    test.MSstatsTMT <- groupComparisonTMT(contrast.matrix=contrast_mat, data=processed.quant)

    #TODO allow manual input (e.g. proteins of interest)
    write.table(test.MSstatsTMT$ComparisonResult, file=paste0("msstatsiso_results.csv"), quote=FALSE, sep='\t', row.names = FALSE)

    #write comparison to CSV (one CSV per contrast)
    # writeComparisonToCSV <- function(DF)
    # {
    #     write.table(DF, file=paste0("comparison_",unique(DF$Label),".csv"), quote=FALSE, sep='\t', row.names = FALSE)
    #     return(DF)
    # }
    # ComparisonResultSplit <- split(test.MSstatsTMT$ComparisonResult, test.MSstatsTMT$ComparisonResult$Label)
    # for(i in 1:length(ComparisonResultSplit)){
    #     writeComparisonToCSV(ComparisonResultSplit[[i]])
    # }
}
