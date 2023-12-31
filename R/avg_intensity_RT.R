# ==============================================================================
#' @title Summarize average intensity and retention time per protein
#'
#' @description Input an evidence file from MaxQuant and a file
#' containing a list of proteins of interest (optional).
#' The function will summarize from the evidence file and report back the
#' average intensity, average retention time, and the average caliberated
#' retention time. If a list of proteins is provided, then only those proteins
#' will be summarized and returned.
#' @param evidence_file (char) The filepath to the MaxQuant searched data
#' (evidence) file (txt tab delimited file).
#' @param protein_file (char) The file path to a file or vector containing
#' a list of proteins of interest.
#' @param output_file (char) The file name for the results
#' (must have the extension `.txt`). If empty, then the
#' results will be returned as an R object.
#' @param verbose (logical) `TRUE` (default) shows function messages
#' @return An R object with the results and a file with the results (if the
#' output_file argument is provided). It contains averages of Intensity,
#' Retention Time, Caliberated Retention Time
#' @keywords MaxQuant, evidence, summary, intensity, retention time, caliberated
#' @examples
#' ave_int <- artmsAvgIntensityRT(evidence_file = artms_data_ph_evidence)
#' @export
artmsAvgIntensityRT <- function(evidence_file,
                                protein_file = NULL,
                                output_file = FALSE,
                                verbose = TRUE) {
                                   
  
  if(any(missing(evidence_file)))
    stop("Missed evidence_file required argument.
         Please, check the help of this function to find out more")
  
  # read in data
  if(verbose) message(">> READING IN FILES... ")
  dat <- .artms_checkIfFile(evidence_file, is.evidence = TRUE)
  
  if (!is.null(protein_file)) {
    if(verbose) message(">> FILTERING OUT UNWANTED PROTEINS... ")
    proteins <- .artms_checkIfFile(protein_file)
    
    # pull out only cases where the proteins appear
    query <- paste(t(proteins), collapse = "|")
    idx <- grep(query, dat$Proteins)
    dat <- dat[idx,]
  }
  
  if(verbose) message(">> COMPUTING AVERAGES... ")
  # Compute the average Intensity
  dat.avg <-
    aggregate(data = dat[, c("Proteins",
                             "Modified.sequence",
                             "Charge",
                             "Intensity")], 
              Intensity ~ .,
              mean, na.rm = TRUE)
  # Compute the average Retention Time
  dat.ret <-
    aggregate(data = dat[, c("Proteins",
                             "Modified.sequence",
                             "Charge",
                             "Retention.time")], 
              Retention.time ~., 
              mean, na.rm = TRUE)
  # Compute the average Calibrated retention time
  dat.cal <-
    aggregate(data = dat[, c("Proteins",
                             "Modified.sequence",
                             "Charge",
                             "Calibrated.retention.time")],
              Calibrated.retention.time ~ .,
              mean,
              na.rm = TRUE)
  
  if(verbose) message(">> MERGING RESULTS... ")
  results <-
    merge(
      dat.avg,
      dat.ret,
      by = c("Proteins", "Modified.sequence", "Charge"),
      all.y = TRUE
    )
  results <-
    merge(
      results,
      dat.cal,
      by = c("Proteins", "Modified.sequence", "Charge"),
      all.y = TRUE
    )
  # add 'Avg' to names
  names(results)[4:6] = paste0("Avg_", names(results)[5:7])
  
  if(verbose) message(">> SUMMARIZATION COMPLETE!! ")
  
  if (output_file) {
    # write out results
    if(verbose) message("--- WRITING OUT RESULTS TO ", output_file, " ")
    write.table(
      results,
      output_file,
      quote = FALSE,
      row.names = FALSE,
      sep = "\t"
    )
    return(results)
  } else{
    return(results)
  }
}
