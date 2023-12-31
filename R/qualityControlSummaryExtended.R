

# ------------------------------------------------------------------------------
#' @title Quality Control of the MaxQuant summary.txt file
#'
#' @description Performs quality control based on the information available in
#' the MaxQuant summary.txt file.
#' @param summary_file (char or data.frame) The evidence file path and name, or
#' data.frame
#' @param keys_file (char or data.frame) The keys file path and name or
#' data.frame
#' @param output_dir (char) Name for the folder to output the results plots. 
#' Default is "qc_summary".
#' @param output_name (char) prefix output name (no extension).
#' Default: "qcExtended_summary"
#' @param isFractions (logical) `TRUE` if it is a 2D experiment (fractions).
#' Default: `FALSE`
#' @param plotMS1SCANS (logical) `TRUE` generates MS1 scan counts plot: 
#' Page 1 shows the number of MS1 scans in each BioReplicate. 
#' If replicates are present, Page 2 shows the mean number of MS1 scans 
#' per condition with error bar showing the standard error of the mean. 
#' If isFractions `TRUE`, each fraction is a stack on the individual bar graphs. 
#' @param plotMS2 (logical) `TRUE` generates MS2 scan counts plot: 
#' Page 1 shows the number of MSs scans in each BioReplicate. 
#' If replicates are present, Page 2 shows the mean number of MS1 scans per 
#' condition with error bar showing the standard error of the mean. 
#' If isFractions `TRUE`, each fraction is a stack on the individual bar graphs. 
#' @param plotMSMS (logical) `TRUE` generates MS2 identification rate (%) plot: 
#' Page 1 shows the fraction of MS2 scans confidently identified in each 
#' BioReplicate. If replicates are present, Page 2 shows the mean rate of MS2 
#' scans confidently identified per condition with error bar showing the 
#' standard error of the mean. 
#' If isFractions `TRUE`, each fraction is a stack on the individual bar graphs.
#' @param plotISOTOPE (logical) `TRUE` generates Isotope Pattern counts plot: 
#' Page 1 shows the number of Isotope Patterns with charge greater than 1 in 
#' each BioReplicate. If replicates are present, Page 2 shows the mean number 
#' of Isotope Patterns with charge greater than 1 per condition with error bar 
#' showing the standard error of the mean. 
#' If isFractions `TRUE`, each fraction is a stack on the individual bar graphs.
#' @param printPDF If `TRUE` (default) prints out the pdfs. Warning: plot
#' objects are not returned due to the large number of them. 
#' @param verbose (logical) `TRUE` (default) shows function messages
#' @return A number of plots from the summary file
#' @keywords qc, summary, keys
#' @examples
#' # Testing warning if files are not submitted
#' test <- artmsQualityControlSummaryExtended(summary_file = NULL,
#' keys_file = NULL)
#' @export
artmsQualityControlSummaryExtended <- function(summary_file,
                                               keys_file,
                                               output_dir = "qc_summary",
                                               output_name = "qcExtended_summary",
                                               isFractions = FALSE,
                                               plotMS1SCANS = TRUE,
                                               plotMS2 = TRUE,
                                               plotMSMS = TRUE,
                                               plotISOTOPE = TRUE,
                                               printPDF = TRUE,
                                               verbose = TRUE) {
  if(verbose){
    message("---------------------------------------------")
    message("artMS: EXTENDED QUALITY CONTROL (-summary.txt based)")
    message("---------------------------------------------")
  }
  
  if (is.null(summary_file) & is.null(keys_file)) {
    return("You need to provide both evidence and keys")
  }
  
  if(is.null(output_dir)){
    return("The output_dir argument cannot be NULL")
  }
  
  if(any(missing(summary_file) | missing(keys_file)))
    stop("Missed (one or many) required argument(s)
         Please, check the help of this function to find out more")
  
  # Getting data ready
  summarykeys <- artmsMergeEvidenceAndKeys(summary_file, keys_file,
                                           isSummary = TRUE,
                                           verbose = verbose)
    
  colnames(summarykeys) <- tolower(colnames(summarykeys))
  
  if ("fraction" %in% colnames(summarykeys)) {
    summary2fx <- summarykeys
  }
  
  if ("fraction" %in% colnames(summarykeys)) {
    summarykeys <- data.table(summarykeys[, c("condition",
                                              "bioreplicate",
                                              "ms",
                                              "ms.ms",
                                              "ms.ms.identified....",
                                              "isotope.patterns",
                                              "isotope.patterns.sequenced..z.1.")])
    
    summarykeys <- summarykeys[, list(ms = sum(ms),
                                      ms.ms = sum(ms.ms),
                                      ms.ms.identified.... = mean(ms.ms.identified....),
                                      isotope.patterns = sum(isotope.patterns),
                                      isotope.patterns.sequenced..z.1. = sum(isotope.patterns.sequenced..z.1.)),
                               by = list(condition, bioreplicate)]
  } else{
    summarykeys <-
      data.table(summarykeys[, c(
        "condition",
        "bioreplicate",
        "ms",
        "ms.ms",
        "ms.ms.identified....",
        "isotope.patterns",
        "isotope.patterns.sequenced..z.1."
      )])
  }
  
  summary2 <- plyr::ddply(
    summarykeys,
    c("condition"),
    plyr::summarise,
    num.MS1.mean = mean(ms),
    num.MS1.max = max(ms),
    num.MS1.min = min(ms),
    num.MS1.sem = sd(ms) / sqrt(length(ms)),
    num.MS2.mean = mean(ms.ms),
    num.MS2.max = max(ms.ms),
    num.MS2.min = min(ms.ms),
    num.MS2.sem = sd(ms.ms) / sqrt(length(ms.ms)),
    num.IsotopePatterns.mean = mean(isotope.patterns),
    num.IsotopePatterns.max = max(isotope.patterns),
    num.IsotopePatterns.min = min(isotope.patterns),
    num.IsotopePatterns.sem = sd(isotope.patterns) / sqrt(length(isotope.patterns)),
    num.IsotopePatternsSeq.mean = mean(isotope.patterns.sequenced..z.1.),
    num.IsotopePatternsSeq.max = max(isotope.patterns.sequenced..z.1.),
    num.IsotopePatternsSeq.min = min(isotope.patterns.sequenced..z.1.),
    num.IsotopePatternsSeq.sem = sd(isotope.patterns.sequenced..z.1.) /
      sqrt(length(isotope.patterns.sequenced..z.1.)),
    pct.MS2Id.mean = mean(ms.ms.identified....),
    pct.MS2Id.max = max(ms.ms.identified....),
    pct.MS2Id.min = min(ms.ms.identified....),
    pct.MS2Id.sem = sd(ms.ms.identified....) / sqrt(length(ms.ms.identified....))
  )
  
  # PLOTS-----
  if(verbose) message(">> GENERATING QC PLOTS ")
  
  # create output directory if it doesn't exist
  if(printPDF){
    if (!dir.exists(output_dir)) {
      if(verbose) message("-- Output folder created: ", output_dir)
      dir.create(output_dir, recursive = TRUE)
    }
  }
  
  ## NUMBER OF MS1 SCANS
  if (plotMS1SCANS) {
    if(verbose) message("--- Plot Number of MS1 scans", appendLF = FALSE)
    if(printPDF){
      pdf(paste0(output_dir, "/", output_name,'.qcplot.MS1scans.pdf'),
          width = 10, #nsamples * 3
          height = 6,
          onefile = TRUE)
    } 
    aa <- ggplot(summarykeys, aes(x = bioreplicate, y = ms, fill = condition)) +
      geom_bar(stat = "identity", alpha = 0.7, na.rm = TRUE) +
      geom_text(aes(label = round(ms, digits = 0)), vjust = 1 , size = 2) +
      xlab("Experiment") + ylab("Counts") +
      ggtitle("Number of MS1 scans") +
      theme_linedraw() +
      theme(legend.text = element_text(size = 8)) +
      theme(axis.text.x = element_text(
        angle = 90,
        hjust = 1,
        size = 10
      )) +
      theme(axis.text.y = element_text(size = 10)) +
            theme(axis.text.x = element_text(angle = 90,
                                             size = 8)) +
      theme(axis.title.y = element_text(size = 10)) +
      theme(plot.title = element_text(size = 12)) +
      scale_fill_brewer(palette = "Spectral")
      
    print(aa)
    
    ab <- ggplot(summary2, aes(
      x = condition,
      y = num.MS1.mean,
      fill = factor(condition)
    )) +
      geom_bar(stat = "identity",
               position = position_dodge(width = 1),
               alpha = 0.7, na.rm = TRUE) +
      geom_errorbar(
        aes(
          ymin = num.MS1.mean - num.MS1.sem,
          ymax = num.MS1.mean + num.MS1.sem
        ),
        width = .2,
        position = position_dodge(.9)
      ) +
      geom_text(
        aes(label = round(num.MS1.mean, digits = 0)),
        hjust = 0.5,
        vjust = -0.5,
        size = 2,
        position = position_dodge(width = 1)
      ) +
      xlab("Condition") + ylab("Counts") +
      ggtitle("Mean number of MS1 scans per condition, error bar= std error of the mean") +
      theme_linedraw() +
      theme(legend.text = element_text(size = 8)) +
      theme(axis.text.x = element_text(
        angle = 0,
        hjust = 1,
        size = 10
      )) +
      theme(axis.text.y = element_text(size = 10)) +
            theme(axis.text.x = element_text(angle = 90,
                                             size = 8)) +
      theme(axis.title.y = element_text(size = 10)) +
      theme(plot.title = element_text(size = 12)) +
      scale_fill_brewer(palette = "Spectral")
      
    print(ab)
    
    if (isFractions) {
      ac <- ggplot(summary2fx, aes(
        x = bioreplicate,
        y = ms,
        fill = factor(fraction)
      )) +
        geom_bar(stat = "identity", alpha = 0.7, na.rm = TRUE) +
        geom_text(
          aes(label = round(ms, digits = 0)),
          hjust = 0.5,
          vjust = 1.5,
          size = 2,
          position = position_stack()
        ) +
        xlab("Experiment") + ylab("Counts") +
        ggtitle("Number of MS1 scans per Fraction") +
        theme_linedraw() +
        theme(legend.text = element_text(size = 8)) +
        theme(axis.text.x = element_text(
          angle = 90,
          hjust = 0,
          size = 10
        )) +
        theme(axis.text.y = element_text(size = 10)) +
              theme(axis.text.x = element_text(angle = 90,
                                               size = 8)) +
        theme(axis.title.y = element_text(size = 10)) +
        theme(plot.title = element_text(size = 12))
        
      print(ac)
    }
    if(printPDF) garbage <- dev.off()
    if(verbose) message(" done ")
  }
  
  
  ## Number of MS2 scans
  if (plotMS2) {
    if(verbose) message("--- Plot Number of MS2 scans", appendLF = FALSE)
    
    if(printPDF){
      pdf(paste0(output_dir, "/", output_name,'.qcplot.MS2scans.pdf'),
          width = 10, #nsamples * 3
          height = 6,
          onefile = TRUE)
    } 
    
    ba <- ggplot(summarykeys, aes(x = bioreplicate, y = ms.ms, fill = condition)) +
      geom_bar(stat = "identity", alpha = 0.7, na.rm = TRUE) +
      geom_text(aes(label = round(ms.ms, digits = 0)), vjust = 1 , size = 2) +
      xlab("Experiment") + ylab("Counts") +
      ggtitle("Number of MS2 scans") +
      theme_linedraw() +
      theme(legend.text = element_text(size = 8)) +
      theme(axis.text.x = element_text(
        angle = 90,
        hjust = 1,
        size = 2
      )) +
      theme(axis.text.y = element_text(size = 10)) +
            theme(axis.text.x = element_text(angle = 90,
                                             size = 8)) +
      theme(axis.title.y = element_text(size = 10)) +
      theme(plot.title = element_text(size = 12)) +
      scale_fill_brewer(palette = "Spectral")
      
    print(ba)
    
    bb <- ggplot(summary2, aes(
      x = condition,
      y = num.MS2.mean,
      fill = factor(condition)
    )) +
      geom_bar(stat = "identity",
               position = position_dodge(width = 1),
               alpha = 0.7, na.rm = TRUE) +
      geom_errorbar(
        aes(
          ymin = num.MS2.mean - num.MS2.sem,
          ymax = num.MS2.mean + num.MS2.sem
        ),
        width = .2,
        position = position_dodge(.9)
      ) +
      geom_text(
        aes(label = round(num.MS2.mean, digits = 0)),
        hjust = 0.5,
        vjust = -0.5,
        size = 2,
        position = position_dodge(width = 1)
      ) +
      xlab("Condition") + ylab("Counts") +
      ggtitle("Mean number of MS2 scans per condition, error bar= std error of the mean") +
      theme_linedraw() +
      theme(legend.text = element_text(size = 8)) +
      theme(axis.text.x = element_text(
        angle = 0,
        hjust = 1,
        size = 10
      )) +
      theme(axis.text.y = element_text(size = 10)) +
            theme(axis.text.x = element_text(angle = 90,
                                             size = 8)) +
      theme(axis.title.y = element_text(size = 10)) +
      theme(plot.title = element_text(size = 12)) +
      scale_fill_brewer(palette = "Spectral")
      
    print(bb)
    
    if (isFractions) {
      bc <- ggplot(summary2fx, aes(
        x = bioreplicate,
        y = ms.ms,
        fill = factor(fraction)
      )) +
        geom_bar(stat = "identity", alpha = 0.7, na.rm = TRUE) +
        geom_text(
          aes(label = round(ms.ms, digits = 0)),
          hjust = 0.5,
          vjust = 1.5,
          size = 2,
          position = position_stack()
        ) +
        xlab("Experiment") + ylab("Counts") +
        ggtitle("Number of MS2 per Fraction") +
        theme_linedraw() +
        theme(legend.text = element_text(size = 8)) +
        theme(axis.text.x = element_text(
          angle = 90,
          hjust = 0,
          size = 10
        )) +
        theme(axis.text.y = element_text(size = 10)) +
              theme(axis.text.x = element_text(angle = 90,
                                               size = 8)) +
        theme(axis.title.y = element_text(size = 10)) +
        theme(plot.title = element_text(size = 12))
        
      print(bc)
    }
    
    summarykeys.reduced <- summarykeys[, 1:4]
    
    ## LEGACY
    # summarykeys.scans1 <- data.table::melt(summarykeys.reduced, 
    #                                       id.vars = seq_len(2))
    
    summarykeys.scans <- summarykeys.reduced %>%
      tidyr::pivot_longer(cols = -c(condition, bioreplicate), 
                          names_to = "variable", values_to = "value")
    
    bd <-ggplot(summarykeys.scans,
                aes(
                  x = interaction(variable, bioreplicate),
                  y = value,
                  fill = condition
                )) +
      geom_bar(stat = "identity", alpha = 0.7, na.rm = TRUE) +
      geom_text(
        aes(label = round(value, digits = 0)),
        angle = 90,
        vjust = 0.5 ,
        size = 2
      ) +
      xlab("Experiment") + ylab("Counts") +
      ggtitle("Number of MS1 and MS2 scans") +
      theme_linedraw() +
      theme(legend.text = element_text(size = 8)) +
      theme(axis.text.x = element_text(
        angle = 90,
        hjust = 1,
        size = 10
      )) +
      theme(axis.text.y = element_text(size = 10)) +
            theme(axis.text.x = element_text(angle = 90,
                                             size = 8)) +
      theme(axis.title.y = element_text(size = 10)) +
      theme(plot.title = element_text(size = 12)) +
      scale_fill_brewer(palette = "Spectral")
    print(bd)
    if(printPDF) garbage <- dev.off()
    if(verbose) message(" done ")
  }
  
  
  # Number of msms.identification rate
  if (plotMSMS) {
    if(verbose) message("--- Plot Number of msms.identification rate", appendLF = FALSE)
    
    if(printPDF){
      pdf(paste0(output_dir, "/", output_name,'.qcplot.MSMS.pdf'),
          width = 10, #nsamples * 3
          height = 6,
          onefile = TRUE)
    } 

    ca <- ggplot(summarykeys,
                 aes(x = bioreplicate, y = ms.ms.identified...., fill = condition)) +
      geom_bar(stat = "identity", alpha = 0.7, na.rm = TRUE) +
      geom_text(aes(label = round(ms.ms.identified...., digits = 2)), vjust = 1 , size = 2) +
      xlab("Experiment") + ylab("Rate") +
      ggtitle("MS2 Identification rate") +
      theme_linedraw() +
      theme(legend.text = element_text(size = 8)) +
      theme(axis.text.x = element_text(
        angle = 90,
        hjust = 1,
        size = 10
      )) +
      theme(axis.text.y = element_text(size = 10)) +
            theme(axis.text.x = element_text(angle = 90,
                                             size = 8)) +
      theme(axis.title.y = element_text(size = 10)) +
      theme(plot.title = element_text(size = 12)) +
      scale_fill_brewer(palette = "Spectral")
      
    print(ca)
    
    cb <- ggplot(summary2,
                 aes(
                   x = condition,
                   y = pct.MS2Id.mean,
                   fill = factor(condition)
                 )) +
      geom_bar(stat = "identity",
               position = position_dodge(width = 1),
               alpha = 0.7, na.rm = TRUE) +
      geom_errorbar(
        aes(
          ymin = pct.MS2Id.mean - pct.MS2Id.sem,
          ymax = pct.MS2Id.mean + pct.MS2Id.sem
        ),
        width = .2,
        position = position_dodge(.9)
      ) +
      geom_text(
        aes(label = round(pct.MS2Id.mean, digits = 2)),
        hjust = 0.5,
        vjust = -0.5,
        size = 2,
        position = position_dodge(width = 1)
      ) +
      xlab("Condition") + ylab("Rate") +
      ggtitle("Mean MS2 Identification rate across bioreplicates and fractions") +
      theme_linedraw() +
      theme(legend.text = element_text(size = 8)) +
      theme(axis.text.x = element_text(
        angle = 0,
        hjust = 1,
        size = 10
      )) +
      theme(axis.text.y = element_text(size = 10)) +
            theme(axis.text.x = element_text(angle = 90,
                                             size = 8)) +
      theme(axis.title.y = element_text(size = 10)) +
      theme(plot.title = element_text(size = 12)) +
      scale_fill_brewer(palette = "Spectral")
      
    print(cb)
    
    if (isFractions) {
      cc <- ggplot(summary2fx,
                   aes(
                     x = bioreplicate,
                     y = ms.ms.identified....,
                     fill = factor(fraction)
                   )) +
        geom_bar(stat = "identity", alpha = 0.7, na.rm = TRUE) +
        geom_text(
          aes(label = round(ms.ms.identified...., digits = 1)),
          hjust = 0.5,
          vjust = 1.5,
          size = 2,
          position = position_stack()
        ) +
        xlab("Experiment") + ylab("Counts") +
        ggtitle("MS2 Identification rate per Fraction") +
        theme_linedraw() +
        theme(legend.text = element_text(size = 8)) +
        theme(axis.text.x = element_text(
          angle = 90,
          hjust = 0,
          size = 10
        )) +
        theme(axis.text.y = element_text(size = 10)) +
              theme(axis.text.x = element_text(angle = 90,
                                               size = 8)) +
        theme(axis.title.y = element_text(size = 10)) +
        theme(plot.title = element_text(size = 12))
        
      print(cc)
    }
    if(printPDF) garbage <- dev.off()
    if(verbose) message(" done ")
  }
  
  
  # Number of isotope patterns
  if (plotISOTOPE) {
    if(verbose) message("--- Plot Number of isotope patterns", appendLF = FALSE)
    
    if(printPDF){
      pdf(paste0(output_dir, "/", output_name,'.qcplot.Isotope.pdf'),
          width = 10, #nsamples * 3
          height = 6,
          onefile = TRUE)
    } 
    
    da <- ggplot(summarykeys,
                 aes(x = bioreplicate, y = isotope.patterns, fill = condition)) +
      geom_bar(stat = "identity", alpha = 0.7, na.rm = TRUE) +
      geom_text(aes(label = round(isotope.patterns, digits = 0)), vjust = 1 , size = 2) +
      xlab("Experiment") + ylab("Counts") +
      ggtitle("Number of detected Isotope Patterns") +
      theme_linedraw() +
      theme(legend.text = element_text(size = 8)) +
      theme(axis.text.x = element_text(
        angle = 90,
        hjust = 1,
        size = 10
      )) +
      theme(axis.text.y = element_text(size = 10)) +
            theme(axis.text.x = element_text(angle = 90,
                                             size = 8)) +
      theme(axis.title.y = element_text(size = 10)) +
      theme(plot.title = element_text(size = 12)) +
      scale_fill_brewer(palette = "Spectral")
      
    print(da)
    
    db <- ggplot(summary2,
                 aes(
                   x = condition,
                   y = num.IsotopePatterns.mean,
                   fill = factor(condition)
                 )) +
      geom_bar(stat = "identity",
               position = position_dodge(width = 1),
               alpha = 0.7, na.rm = TRUE) +
      geom_errorbar(
        aes(
          ymin = num.IsotopePatterns.mean - num.IsotopePatterns.sem,
          ymax = num.IsotopePatterns.mean + num.IsotopePatterns.sem
        ),
        width = .2,
        position = position_dodge(.9)
      ) +
      geom_text(
        aes(label = round(num.IsotopePatterns.mean, digits = 0)),
        hjust = 0.5,
        vjust = -0.5,
        size = 2,
        position = position_dodge(width = 1)
      ) +
      xlab("Condition") + ylab("Counts") +
      ggtitle("Mean number of detected Isotope Patterns") +
      theme_linedraw() +
      theme(legend.text = element_text(size = 8)) +
      theme(axis.text.x = element_text(
        angle = 0,
        hjust = 1,
        size = 10
      )) +
      theme(axis.text.y = element_text(size = 10)) +
            theme(axis.text.x = element_text(angle = 90,
                                             size = 8)) +
      theme(axis.title.y = element_text(size = 10)) +
      theme(plot.title = element_text(size = 12)) +
      scale_fill_brewer(palette = "Spectral")
      
    print(db)
    
    if (isFractions) {
      dc <- ggplot(summary2fx,
                   aes(
                     x = bioreplicate,
                     y = isotope.patterns,
                     fill = factor(fraction)
                   )) +
        geom_bar(stat = "identity", alpha = 0.7, na.rm = TRUE) +
        geom_text(
          aes(label = round(isotope.patterns, digits = 0)),
          hjust = 0.5,
          vjust = 1.5,
          size = 2,
          position = position_stack()
        ) +
        xlab("Experiment") + ylab("Counts") +
        ggtitle("Number of detected Isotope Patterns per Fraction") +
        theme_linedraw() +
        theme(legend.text = element_text(size = 8)) +
        theme(axis.text.x = element_text(
          angle = 90,
          hjust = 0,
          size = 10
        )) +
        theme(axis.text.y = element_text(size = 10)) +
              theme(axis.text.x = element_text(angle = 90,
                                               size = 8)) +
        theme(axis.title.y = element_text(size = 10)) +
        theme(plot.title = element_text(size = 12))
        
      print(dc)
    }
    
    # Number of sequenced isotope patterns with charge = 2 or more
    dd <- ggplot(
      summarykeys,
      aes(x = bioreplicate, y = isotope.patterns.sequenced..z.1., 
          fill = condition)
    ) +
      geom_bar(stat = "identity", alpha = 0.7, na.rm = TRUE) +
      geom_text(aes(label = round(
        isotope.patterns.sequenced..z.1., digits = 0
      )), vjust = 1 , size = 2) +
      xlab("Experiment") + ylab("Counts") +
      ggtitle("Number of sequenced Isotope Patterns with 
              charge state greater than 1") +
      theme_linedraw() +
      theme(legend.text = element_text(size = 8)) +
      theme(axis.text.x = element_text(
        angle = 90,
        hjust = 1,
        size = 10
      )) +
      theme(axis.text.y = element_text(size = 10)) +
            theme(axis.text.x = element_text(angle = 90,
                                             size = 8)) +
      theme(axis.title.y = element_text(size = 10)) +
      theme(plot.title = element_text(size = 12)) +
      scale_fill_brewer(palette = "Spectral")
      
    print(dd)
    
    de <- ggplot(summary2,
                 aes(
                   x = condition,
                   y = num.IsotopePatternsSeq.mean,
                   fill = factor(condition)
                 )) +
      geom_bar(stat = "identity",
               position = position_dodge(width = 1),
               alpha = 0.7, na.rm = TRUE) +
      geom_errorbar(
        aes(
          ymin = num.IsotopePatternsSeq.mean - num.IsotopePatternsSeq.sem,
          ymax = num.IsotopePatternsSeq.mean + num.IsotopePatternsSeq.sem
        ),
        width = .2,
        position = position_dodge(.9)
      ) +
      geom_text_repel(
        aes(label = round(
          num.IsotopePatternsSeq.mean, digits = 0
        )),
        hjust = 0.5,
        vjust = -0.5,
        size = 2,
        position = position_dodge(width = 1)
      ) +
      xlab("Condition") + ylab("Counts") +
      ggtitle("Mean number of sequenced Isotope 
              Patterns with charge state greater than 1") +
      theme_linedraw() +
      theme(legend.text = element_text(size = 8)) +
      theme(axis.text.x = element_text(
        angle = 0,
        hjust = 1,
        size = 10
      )) +
      theme(axis.text.y = element_text(size = 10)) +
            theme(axis.text.x = element_text(angle = 90,
                                             size = 8)) +
      theme(axis.title.y = element_text(size = 10)) +
      theme(plot.title = element_text(size = 12)) +
      scale_fill_brewer(palette = "Spectral")
      
    print(de)
    
    if (isFractions) {
      df <- ggplot(
        summary2fx,
        aes(
          x = bioreplicate,
          y = isotope.patterns.sequenced..z.1.,
          fill = factor(fraction)
        )
      ) +
        geom_bar(stat = "identity", alpha = 0.7, na.rm = TRUE) +
        geom_text(
          aes(label = round(
            isotope.patterns.sequenced..z.1., digits = 0
          )),
          hjust = 0.5,
          vjust = 1.5,
          size = 2,
          position = position_stack()
        ) +
        xlab("Experiment") + ylab("Counts") +
        ggtitle("Number of sequenced Isotope Patterns  with charge state greater than 1 per Fraction") +
        theme_linedraw() +
        theme(legend.text = element_text(size = 8)) +
        theme(axis.text.x = element_text(
          angle = 90,
          hjust = 0,
          size = 10
        )) +
        theme(axis.text.y = element_text(size = 10)) +
        theme(axis.title.x = element_text(size = 10)) +
        theme(axis.title.y = element_text(size = 10)) +
        theme(plot.title = element_text(size = 12))
        
      print(df)
    }
    if(printPDF) garbage <- dev.off()
    if(verbose) message(" done ")
  }
  
} # END OF SUMMARY
