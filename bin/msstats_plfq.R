#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)

usage <- "Rscript msstats_plfq.R input.csv input.mztab [list of contrasts or 'pairwise'] [default control condition or ''] [output prefix]"

#TODO Waiting DIA mzTab
if (length(args)<2) {
    print(usage)
    stop("At least the first two arguments must be supplied (input csv and input mzTab).n", call.=FALSE)
}
if (length(args)<=2) {
    # contrasts
    args[3] = "pairwise"
}
if (length(args)<=3) {
    # default control condition
    args[4] = ""
}
if (length(args)<=4) {
    # default output prefix
    args[5] = "msstats"
}

csv_input <- args[1]
mzTab_input <- args[2]
contrast_str <- args[3]
control_str <- args[4]
out_prefix <- args[5]
folder <- dirname(mzTab_input)
filename <- basename(mzTab_input)
mzTab_output <- paste0(folder,'/',out_prefix,filename)

# load the MSstats library
require(MSstats)
require(tibble)
require(data.table)

# read dataframe into MSstats
data <- read.csv(csv_input)
quant <- OpenMStoMSstatsFormat(data, removeProtein_with1Feature = FALSE)

# process data
processed.quant <- dataProcess(quant, censoredInt = 'NA')

lvls <- levels(as.factor(data$Condition))
if (length(lvls) == 1)
{
    print("Only one condition found. No contrasts to be tested. If this is not the case, please check your experimental design.")
} else {
    if (contrast_str == "pairwise")
    {
        if (control_str == "")
        {
            l <- length(lvls)
            contrast_mat <- matrix(nrow = l * (l-1) / 2, ncol = l)
            rownames(contrast_mat) <- rep(NA, l * (l-1) / 2)
            colnames(contrast_mat) <- lvls
            c <- 1
            for (i in 1:(l-1))
            {
                for (j in (i+1):l)
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
            control <- which(as.character(lvls) == control_str)
            if (length(control) == 0)
            {
                stop("Control condition not part of found levels.n", call.=FALSE)
            }

            l <- length(lvls)
            contrast_mat <- matrix(nrow = l-1, ncol = l)
            rownames(contrast_mat) <- rep(NA, l-1)
            colnames(contrast_mat) <- lvls
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
        print("Specific contrasts not supported yet.")
        exit(1)
    }

    print ("Contrasts to be tested:")
    print (contrast_mat)
    #TODO allow for user specified contrasts
    test.MSstats <- groupComparison(contrast.matrix=contrast_mat, data=processed.quant)

    #TODO allow manual input (e.g. proteins of interest)
    write.csv(test.MSstats$ComparisonResult, "msstats_results.csv", row.names=FALSE, sep=",")

    groupComparisonPlots(data=test.MSstats$ComparisonResult, type="ComparisonPlot",
                        width=12, height=12,dot.size = 2)

    test.MSstats$Volcano = test.MSstats$ComparisonResult[!is.na(test.MSstats$ComparisonResult$pvalue),]
    groupComparisonPlots(data=test.MSstats$Volcano, type="VolcanoPlot",
                        width=12, height=12,dot.size = 2)

    # Otherwise it fails since the behaviour is undefined
    if (nrow(contrast_mat) > 1)
    {
        groupComparisonPlots(data=test.MSstats$ComparisonResult, type="Heatmap",
                            width=12, height=12,dot.size = 2)
    }

    #for (comp in rownames(contrast_mat))
    #{
    #  groupComparisonPlots(data=test.MSstats$ComparisonResult, type="ComparisonPlot",
    #                       width=12, height=12,dot.size = 2, sig=1)#,
    #                       which.Comparison = comp,
    #                       address=F)
    #  # try to plot all comparisons
    #}


    # annotate how often the protein was quantified in each condition (NA values introduced by merge of completely missing are set to 1.0)
    ############ also calculate missingness on condition level

    # input: ProcessedData matrix of MSstats
    # output:
    #   calculate fraction of na in condition (per protein)
    # Groups:   PROTEIN [762]
    #   PROTEIN                 `1`   `2`
    #   <fct>                 <dbl> <dbl>
    # 1 sp|A1ANS1|HTPG_PELPD   0    0.5
    # 2 sp|A2I7N3|SPA37_BOVIN  0    0.5
    # 3 sp|A2VDF0|FUCM_HUMAN   0    0.5
    # 4 sp|A6ND91|ASPD_HUMAN   0.5  0.5
    # 5 sp|A7E3W2|LG3BP_BOVIN  0.5  0.5
    # 6 sp|B8FGT4|ATPB_DESAA   0    0.5

    getMissingInCondition <- function(processedData) {
        p <- processedData
        n_samples <- aggregate(p$SUBJECT, by = list(p$GROUP), FUN = function(x) {return(length(unique(as.numeric(x))))})
        colnames(n_samples) <- c("GROUP", "n_samples")
        p <- p[complete.cases(p["LogIntensities"]),][,c("Protein", "GROUP", "SUBJECT")]
        p_dup <- p[!duplicated(p),]
        p_dup_agg <- aggregate(p_dup$SUBJECT, by = list(p_dup$Protein, p_dup$GROUP), length)
        colnames(p_dup_agg) <- c("Protein", "GROUP", "non_na")
        agg_join <- merge(p_dup_agg, n_samples, by = "GROUP")
        agg_join$missingInCondition = 1 - agg_join$non_na / agg_join$n_samples

        p <- dcast(setDT(agg_join), Protein~GROUP, value.var = "missingInCondition")
        return(p)
    }

    mic <- getMissingInCondition(processed.quant$ProteinLevelData)
    test.MSstats$ComparisonResult <- merge(x=test.MSstats$ComparisonResult, y=mic, by="Protein")
    commoncols <- intersect(colnames(mic), colnames(test.MSstats$ComparisonResult))
    test.MSstats$ComparisonResult[, commoncols] <- apply(test.MSstats$Comparison[, commoncols], 2, function(x) {x[is.na(x)] <- 1; return(x)})

    #write comparison to CSV (one CSV per contrast)
    writeComparisonToCSV <- function(DF)
    {
        write.table(DF, file=paste0("comparison_",unique(DF$Label),".csv"), quote=FALSE, sep='\t', row.names = FALSE)
        return(DF)
    }
    ComparisonResultSplit <- split(test.MSstats$ComparisonResult, test.MSstats$ComparisonResult$Label)
    for(i in 1:length(ComparisonResultSplit)){
        writeComparisonToCSV(ComparisonResultSplit[[i]])
    }


    #replace quants in mzTab
    ################# MzTab
    # find start of the section
    startSection <- function(file, section.identifier) {
        data <- file(file, "r")
        row = 0
        while (TRUE) {
            row = row + 1
            line = readLines(data, n=1)
            if (substr(line, 1, 3)==section.identifier) {
                break
            }
        }
        close(data)
        return (row)
    }

    # find start of the mzTab section tables
    MTD.first_row <- startSection(mzTab_input, "MTD")
    PRT.first_row <- startSection(mzTab_input, "PRH")
    PEP.first_row <- startSection(mzTab_input, "PEH")
    PSM.first_row <- startSection(mzTab_input, "PSH")

    # read entire mzTab and extract protein data
    MTD <- read.table(mzTab_input, sep="\t",
    skip=MTD.first_row-1,
    nrows=PRT.first_row - MTD.first_row - 1 -1, # one extra empty line
    fill=TRUE,
    header=TRUE,
    quote="",
    na.strings=c("null","NA"),
    stringsAsFactors=FALSE,
    check.names=FALSE)


    PRT <- read.table(mzTab_input, sep="\t",
    skip=PRT.first_row-1,
    nrows=PEP.first_row - PRT.first_row - 1 -1, # one extra empty line
    fill=TRUE,
    header=TRUE,
    quote="",
    na.strings=c("null","NA"),
    stringsAsFactors=FALSE,
    check.names=FALSE)

    noquant <- as.logical(PRT[,"opt_global_result_type"] == 'protein_details')
    PRT_skipped <- PRT[noquant,]
    PRT <- PRT[!noquant,]

    PEP <- read.table(mzTab_input, sep="\t",
    skip=PEP.first_row-1,
    nrows=PSM.first_row - PEP.first_row - 1 - 1, # one extra empty line
    fill=TRUE,
    header=TRUE,
    quote="",
    na.strings=c("null","NA"),
    stringsAsFactors=FALSE,
    check.names=FALSE)

    PSM <- read.table(mzTab_input, sep="\t",
    skip=PSM.first_row-1,
    fill=TRUE,
    header=TRUE,
    quote="",
    na.strings=c("null","NA"),
    stringsAsFactors=FALSE,
    check.names=FALSE)

    #### Insert quantification data from MSstats into PRT section
    # first we create a run level protein table form MSstats output
    # then we merge the values into the mzTab PRT table


    # Input: MSstats RunLevelData
    # Output: Run level quantification
    # Create a run level protein table
    #   PROTEIN                 `1`   `2`   `3`   `4`   `5`   `6`   `7`   `8`   `9`  `10`  `11`  `12`  `13`  `14`  `15`  `16`  `17`  `18`  `19`  `20`
    #   <fct>                 <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl> <dbl>
    # 1 sp|A1ANS1|HTPG_PELPD   24.2  24.9  22.8  25.3  24.7  22.9  24.6  25.1  24.0  22.1  25.0  24.3  23.6  NA    NA    NA    NA    NA    NA    NA
    # 2 sp|A2I7N1|SPA35_BOVIN  22.9  23.6  22.4  23.8  23.4  NA    23.6  23.9  22.5  NA    23.7  23.5  22.5  22.5  23.0  23.0  22.6  22.2  22.1  22.8
    getRunLevelQuant <- function(runLevelData)
    {
        runlevel.long <- data.frame()
        for (name in names(runLevelData)) {
            singleProtein.long <- sapply(runLevelData[[name]], rbind)
            singleProtein.long <- data.frame(singleProtein.long)
            singleProtein.long$Protein <- name
            runlevel.long <- rbind(runlevel.long, singleProtein.long)
        }
        runlevel.wide <- dcast(setDT(runlevel.long), Protein~RUN, value.var = "LogIntensities")
        runlevel.wide <- as.data.frame(runlevel.wide)
        return(runlevel.wide)
    }

    quant.runLevel <- MSstatsPrepareForGroupComparison(processed.quant)
    quant.runLevel <- getRunLevelQuant(quant.runLevel)
    colnames(quant.runLevel)[1] = "accession"

    quant.runLevel$accession<-as.character(quant.runLevel$accession)

    for (col_nr in seq(from=2, to=length(colnames(quant.runLevel))))
    {
        colnames(quant.runLevel)[col_nr]=(paste0("protein_abundance_assay[", colnames(quant.runLevel)[col_nr] , "]"))
    }

    # TODO: check if assays in MzTab match to runs. Also true for fractionated data?

    # clear old quant values from ProteinQuantifier
    PRT[,grepl( "protein_abundance_assay" , names(PRT))] = NA
    PRT[,grepl( "protein_abundance_study_variable" , names(PRT))] = NA

    # merge in quant.runLevel values into PRT
    PRT_assay_cols <- grepl("protein_abundance_assay", names(PRT))
    PRT_stdv_cols <- grepl("protein_abundance_study_variable", names(PRT))
    RL_assay_cols <- grepl("protein_abundance_assay", names(quant.runLevel))

    for (acc in quant.runLevel$accession)
    {
        q<-which(quant.runLevel$accession==acc)

        # acc from MSstats might be a group e.g., "A;B" so
        # we check the single leader protein in mzTab PRT$accession against both A and B
        w<-which(PRT$accession %in% strsplit(acc, ";", fixed=TRUE)[[1]])

        if (length(w) == 0)
        {
            # TODO: check why not all summarized protein accessions are in the mzTab. Minimum number of peptides/features different?
            print(paste("Warning: ", acc, " not in mzTab but reported by MSstats"))
        }
        else
        {
            PRT[w, PRT_assay_cols] <- quant.runLevel[q, RL_assay_cols]
            PRT[w, PRT_stdv_cols] <- quant.runLevel[q, RL_assay_cols] # we currently store same data in stdv and assay column
        }
    }

    write.table(MTD, mzTab_output, sep = "\t", quote=FALSE, row.names = FALSE, na = "null")
    write("",file=mzTab_output,append=TRUE)
    suppressWarnings(write.table(PRT_skipped, mzTab_output, sep = "\t", quote=FALSE, row.names = FALSE, append=TRUE, na = "null"))
    suppressWarnings(write.table(PRT, mzTab_output, sep = "\t", col.names=FALSE, quote=FALSE, row.names = FALSE, append=TRUE, na = "null"))
    write("",file=mzTab_output,append=TRUE)
    suppressWarnings(write.table(PEP, mzTab_output, sep = "\t", quote=FALSE, row.names = FALSE, append=TRUE, na = "null"))
    write("",file=mzTab_output,append=TRUE)
    suppressWarnings(write.table(PSM, mzTab_output, sep = "\t", quote=FALSE, row.names = FALSE, append=TRUE, na = "null"))

}
