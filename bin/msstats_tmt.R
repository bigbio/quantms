#!/usr/bin/env Rscript

# This file is part of MSstats.
# License: Apache 2.0
# Author: Dai Chengxin, Julianus Pfeuffer, Yasset Perez-Riverol

require(MSstatsTMT)
require(stats)
require(gplots)
require(ggrepel)
require(marray)
require(data.table)
require(ggplot2)

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

#' Check groupComparisonPlots parameters
#' @param type type of a plot: HEATMAP/VOLCANOPLOT/COMPARISONPLOT
#' @param log_base 2 or 10
#' @param selected_labels character vector of contrast labels
#' @param all_labels character vector of all contrast labels
#' @keywords internal
.checkGCPlotsInput = function(type, log_base, selected_labels, all_labels) {
    checkmate::assertChoice(type, c("HEATMAP", "VOLCANOPLOT", "COMPARISONPLOT"))
    checkmate::assertChoice(log_base, c(2, 10))
    if (selected_labels != "all") {
        if (is.character(selected_labels)) {
            chosen_labels = selected_labels
            wrong_labels = setdiff(chosen_labels, all_labels)
            if (length(wrong_labels) > 0) {
                msg_1 = paste("Please check labels of comparisons.",
                                "Result does not have the following comparisons:")
                msg_2 = paste(wrong_labels, sep = ", ", collapse = ", ")
                msg = paste(msg_1, msg_2)
                stop(msg)
            }
        }
        if (is.numeric(selected_labels)) {
            n_labels = length(all_labels)
            if (n_labels < max(selected_labels)) {
                msg = paste("Please check your selection of comparisons. There are",
                            n_labels, "comparisons in this result.")
                stop(msg)
            } else {
                chosen_labels = all_labels[selected_labels]
            }
        }
    } else {
        chosen_labels = all_labels
    }
    chosen_labels
}


#' @importFrom stats quantile dist
#' @keywords internal
.getOrderedMatrix = function(input, type) {
    input_tmp = input
    input_tmp[is.na(input)] = 50
    if (toupper(type) == "PROTEIN") {
        input = input[hclust(dist(input_tmp), method = "ward.D")$order, ]
    } else if (toupper(type) == "COMPARISON") {
        input = input[, hclust(dist(t(input_tmp)), method = "ward.D")$order]
    } else if (toupper(type) == "BOTH") {
        input = input[hclust(dist(input_tmp), method = "ward.D")$order,
                        hclust(dist(t(input)), method = "ward.D")$order]
    }
    input
}


#' Create heatmap
#' @param input data.table
#' @inheritParams groupComparisonPlots
#' @keywords internal
.makeHeatmap = function(input, my.colors, my.breaks, x.axis.size, y.axis.size) {
    par(oma = c(3, 0, 0, 4))
    heatmap.2(as.matrix(input),
                col = my.colors,
                Rowv = FALSE, Colv = FALSE,
                dendrogram = "none", breaks = my.breaks,
                trace = "none", na.color = "grey",
                cexCol = (x.axis.size / 10),
                cexRow = (y.axis.size / 10),
                key = FALSE,
                lhei = c(0.1, 0.9), lwid = c(0.1, 0.9))
}


#' Create a volcano plot
#' @inheritParams groupComparisonPlots
#' @param input data.table
#' @param label_name contrast label
#' @param log_base_FC 2 or 10
#' @param log_base_pval 2 or 10
#' @keywords internal
.makeVolcano = function(
    input, label_name, log_base_FC, log_base_pval, x.lim, ProteinName, dot.size,
    y.limdown, y.limup, text.size, FCcutoff, sig, x.axis.size, y.axis.size,
    legend.size, log_adjp
) {
    Protein = NULL

    plot = ggplot(aes_string(x = "logFC",
                            y = log_adjp,
                            color = "colgroup",
                            label = "Protein"),
                    data = input) +
        geom_point(size = dot.size) +
        scale_colour_manual(values = c("gray65", "blue", "red"),
                            limits = c("black", "blue", "red"),
                            breaks = c("black", "blue", "red"),
                            labels = c("No regulation", "Down-regulated", "Up-regulated")) +
        scale_y_continuous(paste0("-Log", log_base_pval, " (adjusted p-value)"),
                            limits = c(y.limdown, y.limup)) +
        labs(title = unique(label_name))
    plot = plot +
        scale_x_continuous(paste0("Log", log_base_pval, " fold change"),
                            limits = c(-x.lim, x.lim))
    if (ProteinName) {
        if (!(length(unique(input$colgroup)) == 1 & any(unique(input$colgroup) == "black"))) {
            plot = plot +
                geom_text_repel(data = input[input$colgroup != "black", ],
                                aes(label = Protein),
                                size = text.size,
                                col = "black")
        }
    }
    if (!FCcutoff | is.numeric(FCcutoff)) {
        l = ifelse(!FCcutoff, 20, 10)
        sigcut = data.table::setnames(
            data.table::data.table("sigline",
                                    seq(-x.lim, x.lim, length.out = l),
                                    (-log(sig, base = log_base_pval)),
                                    "twodash"),
            c("Protein", "logFC", log_adjp, "line"))
    }
    if (!FCcutoff) {
        plot = plot +
            geom_line(data = sigcut,
                        aes_string(x = "logFC", y = log_adjp, linetype = "line"),
                        colour = "darkgrey",
                        size = 0.6,
                        show.legend = TRUE) +
            scale_linetype_manual(values = c("twodash" = 6),
                                    labels = c(paste0("Adj p-value cutoff (", sig, ")"))) +
            guides(colour = guide_legend(override.aes = list(linetype = 0)),
                    linetype = guide_legend())
    }
    if (is.numeric(FCcutoff)) {
        FCcutpos = data.table::setnames(data.table("sigline",
                                                    log(FCcutoff, log_base_pval),
                                                    seq(y.limdown, y.limup, length.out = 10),
                                                    "dotted"),
                                        c("Protein", "logFC", log_adjp, "line"))
        FCcutneg = data.table::setnames(data.table("sigline",
                                                    (-log(FCcutoff, log_base_pval)),
                                                    seq(y.limdown, y.limup, length.out = 10),
                                                    "dotted"),
                                        c("Protein", "logFC", log_adjp, "line"))
        plot = plot +
            geom_line(data = sigcut,
                        aes_string(x = "logFC", y = log_adjp, linetype = "line"),
                        colour = "darkgrey",
                        size = 0.6,
                        show.legend = TRUE) +
            geom_line(data = FCcutpos,
                        aes_string(x = "logFC", y = log_adjp, linetype = "line"),
                        colour = "darkgrey",
                        size = 0.6,
                        show.legend = TRUE) +
            geom_line(data = FCcutneg,
                        aes_string(x = "logFC", y = log_adjp, linetype = "line"),
                        colour = "darkgrey",
                        size = 0.6) +
            scale_linetype_manual(values = c("dotted" = 3, "twodash" = 6),
                                    labels = c(paste0("Fold change cutoff (", FCcutoff, ")"),
                                                paste0("Adj p-value cutoff (", sig, ")"))) +
            guides(colour = guide_legend(override.aes = list(linetype = 0)),
                    linetype = guide_legend())
    }
    plot = plot +
        theme_msstats("VOLCANOPLOT", x.axis.size, y.axis.size,
                        legend.size, strip_background = element_rect(),
                        strip_text_x = element_text(),
                        legend_position = "bottom", legend.title = element_blank())
    plot
}


#' Create comparison plot
#' @param input data.table
#' @param log_base 2 or 10
#' @inheritParams groupComparisonPlots
#' @keywords internal
.makeComparison = function(
    input, log_base, dot.size, x.axis.size, y.axis.size,
    text.angle, hjust, vjust, y.limdown, y.limup
) {
    logFC = ciw = NULL

    protein = unique(input$Protein)
    plot = ggplot(input, aes_string(x = 'Label', y = 'logFC')) +
        geom_errorbar(aes(ymax = logFC + ciw, ymin = logFC - ciw),
                        data = input,
                        width = 0.1,
                        colour = "red") +
        geom_point(size = dot.size,
                        colour = "darkred") +
        scale_x_discrete('Comparison') +
        geom_hline(yintercept = 0,
                    linetype = "twodash",
                    colour = "darkgrey",
                    size = 0.6) +
        labs(title = protein) +
        theme_msstats("COMPARISONPLOT", x.axis.size, y.axis.size,
                        text_angle = text.angle, text_hjust = hjust,
                        text_vjust = vjust)
    plot = plot +
        scale_y_continuous(paste0("Log", log_base, "-Fold Change"),
                                limits = c(y.limdown, y.limup))
    plot
}

groupComparisonPlots = function(
    data, type, sig = 0.05, FCcutoff = FALSE, logBase.pvalue = 10, ylimUp = FALSE,
    ylimDown = FALSE, xlimUp = FALSE, x.axis.size = 10, y.axis.size = 10,
    dot.size = 3, text.size = 4, text.angle = 0, legend.size = 13,
    ProteinName = TRUE, colorkey = TRUE, numProtein = 100, clustering = "both",
    width = 10, height = 10, which.Comparison = "all", which.Protein = "all",
    address = ""
) {
    Label = Protein = NULL

    type = toupper(type)
    input = data.table::as.data.table(data)
    all_labels = as.character(unique(data$Label))
    log_base_FC = ifelse(is.element("log2FC", colnames(data)), 2, 10)

    chosen_labels = .checkGCPlotsInput(type, logBase.pvalue, which.Comparison,
                                        all_labels)
    input = input[Label %in% chosen_labels]
    input[, Protein := factor(Protein)]
    input[, Label := factor(Label)]

    if (type == "HEATMAP") {
        .plotHeatmap(input, logBase.pvalue, ylimUp, FCcutoff, sig, clustering,
                    numProtein, colorkey, width, height, log_base_FC,
                    x.axis.size, y.axis.size, address)
    }
    if (type == "VOLCANOPLOT") {
        .plotVolcano(input, which.Comparison, address, width, height, logBase.pvalue,
                    ylimUp, ylimDown, FCcutoff, sig, xlimUp, ProteinName, dot.size,
                    text.size, legend.size, x.axis.size, y.axis.size, log_base_FC)
    }
    if (type == "COMPARISONPLOT") {
        .plotComparison(input, which.Protein, address, width, height, sig, ylimUp,
                        ylimDown, text.angle, dot.size, x.axis.size, y.axis.size,
                        log_base_FC)
    }
}


#' Prepare data for heatmaps and plot them
#' @inheritParams groupComparisonPlots
#' @param input data.table
#' @param log_base_pval log base for p-values
#' @param log_base_FC log base for log-fold changes - 2 or 10
#' @keywords internal
.plotHeatmap = function(
    input, log_base_pval, ylimUp, FCcutoff, sig, clustering, numProtein, colorkey,
    width, height, log_base_FC, x.axis.size, y.axis.size, address
) {
    adj.pvalue = heat_val = NULL

    if (length(unique(input$Protein)) <= 1) {
        stop("At least two proteins are needed for heatmaps.")
    }
    if (length(unique(input$Label)) <= 1) {
        stop("At least two comparisons are needed for heatmaps.")
    }

    if (is.numeric(ylimUp)) {
        y.limUp = ylimUp
    } else {
        y.limUp = ifelse(log_base_pval == 2, 30, 10)
        input[adj.pvalue < log_base_pval ^ (-y.limUp), adj.pvalue := log_base_pval ^ (-y.limUp)]
    }

    if (is.numeric(FCcutoff)) {
        input$adj.pvalue = ifelse(input[, 3] < log(FCcutoff, log_base_FC) & input[, 3] > -log(FCcutoff, log_base_FC),
                                    1, input$adj.pvalue)
    }

    input[, heat_val := -log(adj.pvalue, log_base_pval) * sign(input[, 3])]
    wide = data.table::dcast(input, Protein ~ Label,
                                value.var = "heat_val")
    proteins = wide$Protein
    wide = as.matrix(wide[, -1])
    rownames(wide) = proteins
    wide = wide[rowSums(!is.na(wide)) != 0, colSums(!is.na(wide)) != 0]
    wide = .getOrderedMatrix(wide, clustering)

    blue.red.18 = maPalette(low = "blue", high = "red", mid = "black", k = 12)
    my.colors = blue.red.18
    my.colors = c(my.colors, "grey") # for NA
    up = 10
    temp = 10 ^ (-sort(ceiling(seq(2, up, length = 10)[c(1, 2, 3, 5, 10)]), decreasing = TRUE))
    breaks = c(temp, sig)
    neg.breaks = log(breaks, log_base_pval)
    my.breaks = c(neg.breaks, 0, -neg.breaks[6:1], 101)
    blocks = c(-breaks, 1, breaks[6:1])
    x.at = seq(-0.05, 1.05, length.out = 13)
    namepro = rownames(wide)
    totalpro = length(namepro)
    numheatmap = totalpro %/% numProtein + 1
    if (colorkey) {
        par(mar = c(3, 3, 3, 3), mfrow = c(3, 1), oma = c(3, 0, 3, 0))
        plot.new()
        image(z = matrix(seq(seq_len(length(my.colors) - 1)), ncol = 1),
                col = my.colors[-length(my.colors)],
                xaxt = "n",
                yaxt = "n")
        mtext("Color Key", side = 3,line = 1, cex = 3)
        mtext("(sign) Adjusted p-value", side = 1, line = 3, at = 0.5, cex = 1.7)
        mtext(blocks, side = 1, line = 1, at = x.at, cex = 1)
    }

    savePlot(address, "Heatmap", width, height)
    for (j in seq_len(numheatmap)) {
        if (j != numheatmap) {
            partial_wide = wide[((j - 1) * numProtein + 1):(j * numProtein), ]
        } else {
            partial_wide = wide[((j - 1) * numProtein + 1):nrow(wide), ]
        }
        heatmap  = .makeHeatmap(partial_wide, my.colors, my.breaks, x.axis.size, y.axis.size)
    }
    if (address != FALSE) {
        dev.off()
    }
}


#' Save a plot to pdf file
#'
#' @inheritParams .saveTable
#' @param width width of a plot
#' @param height height of a plot
#'
#' @return NULL
#'
#' @export
#'
savePlot = function(name_base, file_name, width, height) {
    if (name_base != FALSE) {
        all_files = list.files(".")
        if(file_name == 'ProfilePlot'){
            num_same_name = sum(grepl(paste0("^", name_base, file_name, "_[0-9]?"), all_files))
        } else {
            num_same_name = sum(grepl(paste0("^", name_base, file_name, "[0-9]?"), all_files))
        }
        if (num_same_name > 0) {
            file_name = paste(file_name, num_same_name + 1, sep = "_")
        }
        file_path = paste0(name_base, file_name, ".pdf")
        pdf(file_path, width = width, height = height)
    }
    NULL
}

#' Theme for MSstats plots
#'
#' @param type type of a plot
#' @param x.axis.size size of text on the x axis
#' @param y.axis.size size of text on the y axis
#' @param legend_size size of the legend
#' @param strip_background background of facet
#' @param strip_text_x size of text on facets
#' @param legend_position position of the legend
#' @param legend_box legend.box
#' @param text_angle angle of text on the x axis (for condition and comparison plots)
#' @param text_hjust hjust parameter for x axis text (for condition and comparison plots)
#' @param text_vjust vjust parameter for x axis text (for condition and comparison plots)
#' @param ... additional parameters passed on to ggplot2::theme()
#'
#' @import ggplot2
#' @export
#'
theme_msstats = function(
    type, x.axis.size = 10, y.axis.size = 10, legend_size = 13,
    strip_background = element_rect(fill = "gray95"),
    strip_text_x = element_text(colour = c("black"), size = 14),
    legend_position = "top", legend_box = "vertical", text_angle = 0, text_hjust = NULL, text_vjust = NULL,
    ...
) {
    if (type %in% c("CONDITIONPLOT", "COMPARISONPLOT")) {
        ggplot2::theme(
            panel.background = element_rect(fill = 'white', colour = "black"),
            axis.title.x = element_text(size = x.axis.size + 5, vjust = -0.4),
            axis.title.y = element_text(size = y.axis.size + 5, vjust = 0.3),
            axis.ticks = element_line(colour = "black"),
            title = element_text(size = x.axis.size + 8, vjust = 1.5),
            panel.grid.major.y = element_line(colour = "grey95"),
            panel.grid.minor.y = element_blank(),
            axis.text.y = element_text(size = y.axis.size, colour = "black"),
            axis.text.x = element_text(size = x.axis.size, colour = "black",
                                        angle = text_angle, hjust = text_hjust,
                                        vjust = text_vjust),
            ...
        )
    } else {
        ggplot2::theme(
            panel.background = element_rect(fill = 'white', colour = "black"),
            legend.key = element_rect(fill = 'white', colour = 'white'),
            panel.grid.minor = element_blank(),
            strip.background = strip_background,
            axis.text.x = element_text(size = x.axis.size, colour = "black"),
            axis.text.y = element_text(size = y.axis.size, colour = "black"),
            axis.title.x = element_text(size = x.axis.size + 5, vjust = -0.4),
            axis.title.y = element_text(size = y.axis.size + 5, vjust = 0.3),
            axis.ticks = element_line(colour = "black"),
            title = element_text(size = x.axis.size + 8, vjust = 1.5),
            strip.text.x = strip_text_x,
            legend.position = legend_position,
            legend.box = legend_box,
            legend.text = element_text(size = legend_size),
            ...
        )
    }
}

#' Get proteins based on names or integer IDs
#'
#' @param chosen_proteins protein names or integers IDs
#' @param all_proteins all unique proteins
#'
#' @return character
#'
#' @export
getSelectedProteins = function(chosen_proteins, all_proteins) {
    if (is.character(chosen_proteins)) {
        selected_proteins = chosen_proteins
        missing_proteins = setdiff(selected_proteins, all_proteins)
        if (length(missing_proteins) > 0) {
            stop(paste("Please check protein name. Dataset does not have this protein. -",
                        toString(missing_proteins), sep = " "))
        }
    }
    if (is.numeric(chosen_proteins)) {
        selected_proteins <- all_proteins[chosen_proteins]
        if (length(all_proteins) < max(chosen_proteins)) {
            stop(paste("Please check your selection of proteins. There are ",
                        length(all_proteins)," proteins in this dataset."))
        }
    }
    selected_proteins
}

#' Preprocess data for volcano plots and create them
#' @inheritParams groupComparisonPlots
#' @keywords internal
.plotVolcano = function(
    input, which.Comparison, address, width, height, log_base_pval,
    ylimUp, ylimDown, FCcutoff, sig, xlimUp, ProteinName, dot.size,
    text.size, legend.size, x.axis.size, y.axis.size, log_base_FC
) {
    adj.pvalue = colgroup = logFC = Protein = issue = Label = newlogFC = NULL

    log_adjp = paste0("log", log_base_pval, "adjp")
    all_labels = unique(input$Label)
    input = input[!is.na(adj.pvalue), ]
    colname_log_fc = intersect(colnames(input), c("log2FC", "log10FC"))
    data.table::setnames(input, colname_log_fc, c("logFC"))

    if (address == FALSE) {
        if (which.Comparison == 'all') {
            if (length(unique(input$Label)) > 1) {
                stop('** Cannnot generate all volcano plots in a screen. Please set one comparison at a time.')
            }
        } else if (length(which.Comparison) > 1) {
            stop( '** Cannnot generate multiple volcano plots in a screen. Please set one comparison at a time.' )
        }
    }

    if (is.numeric(ylimUp)) {
        y.limUp = ylimUp
    } else {
        y.limUp = ifelse(log_base_pval == 2, 30, 10)
    }
    input[, adj.pvalue := ifelse(adj.pvalue < log_base_pval ^ (-y.limUp),
                                    log_base_pval ^ (-y.limUp), adj.pvalue)]

    if (!FCcutoff) {
        logFC_cutoff = 0
    } else {
        logFC_cutoff = log(FCcutoff, log_base_FC)
    }
    input[, colgroup := ifelse(adj.pvalue >= sig, "black",
                            ifelse(logFC > logFC_cutoff,
                                    "red", "blue"))]
    input[, colgroup := factor(colgroup, levels = c("black", "blue", "red"))]
    input[, Protein := as.character(Protein)]
    input[!is.na(issue) & issue == "oneConditionMissing",
            Protein := paste0("*", Protein)]

    savePlot(address, "VolcanoPlot", width, height)
    for (i in seq_along(all_labels)) {
        label_name = all_labels[i]
        single_label = input[Label == label_name, ]

        y.limup = ceiling(max(-log(single_label[!is.na(single_label$adj.pvalue), "adj.pvalue"], log_base_pval)))
        if (y.limup < (-log(sig, log_base_pval))) {
            y.limup = (-log(sig, log_base_pval) + 1) ## for too small y.lim
        }
        y.limdown = ifelse(is.numeric(ylimDown), ylimDown, 0)
        x_ceiling = ceiling(max(abs(single_label[!is.na(single_label$logFC) & is.finite(single_label$logFC), logFC])))
        x.lim = ifelse(is.numeric(xlimUp), xlimUp, ifelse((x_ceiling < 3), 3, x_ceiling))

        single_label[[log_adjp]] = -log(single_label$adj.pvalue, log_base_pval)
        single_label$newlogFC = single_label$logFC
        single_label[!is.na(issue) &
                        issue == "oneConditionMissing" &
                        logFC == Inf, newlogFC := (x.lim - 0.2)]
        single_label[!is.na(issue) &
                        issue == "oneConditionMissing" &
                        logFC == (-Inf), newlogFC := (x.lim - 0.2) * (-1)]
        plot = .makeVolcano(single_label, label_name, log_base_FC, log_base_pval, x.lim, ProteinName, dot.size,
                            y.limdown, y.limup, text.size, FCcutoff, sig, x.axis.size, y.axis.size,
                            legend.size, log_adjp)
        print(plot)
    }
    if (address != FALSE) {
        dev.off()
    }
}


#' Preprocess data for comparison plots and create them
#' @inheritParams groupComparisonPlots
#' @param input data.table
#' @param log_base_FC log base for log-fold changes - 2 or 10
#' @keywords internal
.plotComparison = function(
    input, proteins, address, width, height, sig, ylimUp, ylimDown,
    text.angle, dot.size, x.axis.size, y.axis.size, log_base_FC
) {
    adj.pvalue = Protein = ciw = NULL

    input = input[!is.na(adj.pvalue), ]
    all_proteins = unique(input$Protein)

    if (address == FALSE) {
        if (proteins == "all" | length(proteins) > 1) {
            stop("** Cannnot generate all comparison plots in a screen. Please set one protein at a time.")
        }
    }
    if (proteins != "all") {
        selected_proteins = getSelectedProteins(proteins, all_proteins)
        input = input[Protein %in% selected_proteins, ]
    }

    all_proteins = unique(input$Protein)
    input$Protein = factor(input$Protein)
    savePlot(address, "ComparisonPlot", width, height)
    log_fc_column = intersect(colnames(input), c("log2FC", "log10FC"))
    for (i in seq_along(all_proteins)) {
        single_protein = input[Protein == all_proteins[i], ]
        single_protein[, ciw := qt(1 - sig / (2 * nrow(single_protein)), single_protein$DF) * single_protein$SE]
        data.table::setnames(single_protein, log_fc_column, "logFC")
        y.limup = ifelse(is.numeric(ylimUp), ylimUp, ceiling(max(single_protein$logFC + single_protein$ciw)))
        y.limdown = ifelse(is.numeric(ylimDown), ylimDown, floor(min(single_protein$logFC - single_protein$ciw)))
        hjust = ifelse(text.angle != 0, 1, 0.5)
        vjust = ifelse(text.angle != 0, 1, 0.5)

        plot = .makeComparison(single_protein, log_base_FC, dot.size, x.axis.size,
                                y.axis.size, text.angle, hjust, vjust, y.limdown,
                                y.limup)
        print(plot)
    }
    if (address != FALSE) {
        dev.off()
    }
}

### End Function Sections

char_to_boolean <- c("true"=TRUE, "false"=FALSE)
usage <- "Rscript msstats_tmt.R input.csv [list of contrasts or 'pairwise'] [default control condition or '']... [normalization based reference channel]"

args <- initialize_msstats(usage = usage)

rmProtein_with1Feature <- args[4]
if(typeof(rmProtein_with1Feature) == 'character'){
    rmProtein_with1Feature <- char_to_boolean[rmProtein_with1Feature]
}

if (length(args)<5) {
    # use unique peptide
    args[5] <- TRUE
}
useUniquePeptide <- args[5]
if(typeof(useUniquePeptide) == 'character'){
    useUniquePeptide <- char_to_boolean[useUniquePeptide]
}

if (length(args)<6) {
    # remove the features that have 1 or 2 measurements within each Run.
    args[6] <- TRUE
}
rmPSM_withfewMea_withinRun <- args[6]
if(typeof(rmPSM_withfewMea_withinRun) == 'character'){
    rmPSM_withfewMea_withinRun <- char_to_boolean[rmPSM_withfewMea_withinRun]
}

if (length(args)<7) {
    # sum or max - when there are multiple measurements for certain feature in certain Run.
    args[7] <- 'sum'
}

if (length(args)<8) {
    # summarization methods to protein-level can be performed: "msstats(default)"
    args[8] <- "msstats"
}

if (length(args)<9) {
    # Global median normalization on peptide level data
    args[9] <- TRUE
}
global_norm <- args[9]
if(typeof(global_norm) == 'character'){
    global_norm <- char_to_boolean[global_norm]
}

if (length(args)<10) {
    # Remove norm channel
    args[10] <- TRUE
}
remove_norm_channel <- args[10]
if(typeof(remove_norm_channel) == 'character'){
    remove_norm_channel <- char_to_boolean[remove_norm_channel]
}

if (length(args)<11) {
    # default Reference channel based normalization between MS runs on protein level data.
    # Reference Channel annotated by 'Norm' in Condition.
    args[11] <- TRUE
}
reference_norm <- args[11]
if(typeof(reference_norm) == 'character'){
    reference_norm <- char_to_boolean[reference_norm]
}

if (length(args)<12) {
    # outputPrefix
    args[12] <- './msstats'
}

if (length(args)<13) {
    # adjusted p-value threshold
    args[13] <- 0.05
}

csv_input <- args[1]
contrast_str <- args[2]
control_str <- args[3]

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

if (l == 1) {
    print("Only one condition found. No contrasts to be tested. If this is not the case, please check your experimental design.")
} else {
    contrast_mat <- parse_contrasts(l = l, contrast_str = contrast_str, lvls = lvls)
    print ("Contrasts to be tested:")
    print (contrast_mat)
    #TODO allow for user specified contrasts
    test.MSstatsTMT <- groupComparisonTMT(contrast.matrix=contrast_mat, data=processed.quant)

    #TODO allow manual input (e.g. proteins of interest)
    write.table(test.MSstatsTMT$ComparisonResult, file=paste0(args[12],"_comparisons.csv"), quote=FALSE, sep='\t', row.names = FALSE)

    valid_comp_data <- test.MSstatsTMT$ComparisonResult[!is.na(test.MSstatsTMT$ComparisonResult$pvalue), ]

    if (nrow(valid_comp_data[!duplicated(valid_comp_data$Protein),]) < 2) {
        warning("Warning: Not enough proteins with valid p-values for comparison. Skipping groupComparisonPlots step!")
    } else {

        groupComparisonPlots(data=test.MSstatsTMT$ComparisonResult, type="ComparisonPlot", sig=as.numeric(args[13]), width=12, height=12, dot.size = 2)

        groupComparisonPlots(data=valid_comp_data, type="VolcanoPlot", sig=as.numeric(args[13]),
                            width=12, height=12, dot.size = 2)

        # Otherwise it fails since the behavior is undefined
        if (nrow(contrast_mat) > 1) {
            groupComparisonPlots(data=test.MSstatsTMT$ComparisonResult, type="Heatmap", sig=as.numeric(args[13]),
                                width=12, height=12, dot.size = 2)
        }
    }

}
