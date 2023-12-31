
utils::globalVariables(
  c("AbMean",
    "Charge",
    "Intensity.H",
    "Intensity.L",
    "Label_variable",
    "Modified.sequence",
    "RawFile_IsotopeLabelType"))

# @title Long to Wide format selecting the `Modified.sequence` column of the
# evidence file
#
# @description Facilitates applying the pivot_wider function, i.e., takes long-format
# data and casts it into wide-format data.
# @param d_long (data.frame) in long format
# @return (data.frame) Evidence file reshaped by rawfile and IsotopeLabelType
# @keywords internal, data.frame, pivot_wider, ptm
.artms_castMaxQToWidePTM <- function(d_long) {
  # Old data.table approach
  # data_w <- data.table::dcast(
  #   Proteins + Modified.sequence + Charge ~ RawFile + IsotopeLabelType,
  #   data = d_long,
  #   value.var = 'Intensity',
  #   fun.aggregate = sum,
  #   fill = NA
  # )

  data_w <- d_long %>%
      dplyr::mutate(RawFile_IsotopeLabelType = paste(RawFile, IsotopeLabelType, sep = "_")) %>%
      dplyr::select(Proteins, Modified.sequence, Charge, RawFile_IsotopeLabelType, Intensity) %>%
      tidyr::pivot_wider(names_from = RawFile_IsotopeLabelType,
                         values_from = Intensity,
                         values_fn = list(Intensity = sum)) %>%
                
      dplyr::arrange(Proteins)
  
  #artmsChangeColumnName is faster than dplyr rename
  data_w <- artmsChangeColumnName(data_w, 
                                  oldname = "Modified.sequence", 
                                  newname = "Sequence")

  return(data_w)
}


# @title Check the `MS/MS Count` column name on the evidence data.table
#
# @description Address case issue with the MS/MS Count column name
# @param (data.frame) keys or evidence files
# @return (data.frame) with the `MS/MS Count` column name
# @keywords internal msmscount, columname
.artms_checkMSMSColumnName <- function(df) {
  if (!('MS/MS Count' %in% colnames(df))) {
    if ("MS/MS count" %in% colnames(df)) {
      df <- artmsChangeColumnName(df, 'MS/MS count', 'MS/MS Count')
    } else{
      stop("cannot find the <MS/MS Count> column")
    }
  }
  return(df)
}



# @title Check the `Raw file` column name on the evidence or keys data.frame
#
# @description Depending on how the data is loaded, the `Raw file` column
# might have different format. This function check to ensure consistency in
# both the evidence and keys data.frames
# @param (data.frame) keys or evidence files
# @return (data.frame) with the `RawFile` column name
# @keywords internal rawfile, columname
.artms_checkRawFileColumnName <- function(df) {
  if (!('RawFile' %in% colnames(df))) {
    if ("Raw.file" %in% colnames(df)) {
      df <- artmsChangeColumnName(df, 'Raw.file', 'RawFile')
    } else if ("Raw file" %in% colnames(df)) {
      df <- artmsChangeColumnName(df, 'Raw file', 'RawFile')
    } else{
      stop("cannot find the <Raw.file> column")
    }
  }
  return(df)
}



#' @title Change a specific column name in a given data.frame
#'
#' @description Making easier to change a column name in any data.frame
#' @param dataset (data.frame) with the column name you want to change
#' @param oldname (char) the old column name
#' @param newname (char) the new name for that column
#' @return (data.frame) with the new specified column name
#' @keywords rename, data.frame, columns
#' @examples
#' artms_data_ph_evidence <- artmsChangeColumnName(
#'                                dataset = artms_data_ph_evidence,
#'                                oldname = "Phospho..STY.",
#'                                newname = "PH_STY")
#' @export
artmsChangeColumnName <- function(dataset, oldname, newname) {
  if (!(oldname %in% colnames(dataset))) {
    stop(" The Column name provided <",
         oldname,
         "> was not found in the object provided ")
  }
  colnames(dataset)[grep(paste0('^', oldname, '$'), colnames(dataset))] <-
    newname
  return(dataset)
}


# @title Filtering data
#
# @description Apply the filtering options, i.e., remove protein groups and/or
# contaminants, and/or, select posttranslational modification (if any)
# @param x (data.frame) Evidence file
# @param config (yaml.object) Configuration object (opened yaml file)
# @param verbose (logical) `TRUE` (default) shows function messages
# @return (data.frame) filtered according to the options selected
# @keywords internal, filtering, remove, proteingroups, ptms
.artms_filterData <- function(x, 
                              config,
                              verbose = TRUE) {
  if(verbose) message(">> FILTERING ")
  
  if (config$data$filters$contaminants) {
    x <- artmsFilterEvidenceContaminants(x, verbose = verbose)
  }
  
  if (config$data$filters$protein_groups == 'remove') {
    if(verbose) message("-- Removing protein groups")
    # SELECT FIRST THE LEADING RAZOR PROTEIN AS PROTEINS, DEPENDING ON THE 
    # MAXQUANT VERSION
    
    # Address the old version of maxquant
    if ( "Leading.Razor.Protein" %in% colnames(x) ) {
      x <- artmsChangeColumnName(x, "Leading.Razor.Protein", "Leading.razor.protein")
    }
    
    x <- artmsLeaveOnlyUniprotEntryID(x, "Proteins")
    x <- artmsLeaveOnlyUniprotEntryID(x, "Leading.razor.protein")
    
    # Check: if neither old version nor new version of leading razor protein
    # is found... stop it
    if ( "Leading.razor.protein" %in% colnames(x) ) {
      x$Proteins <- NULL
      data_f <- artmsChangeColumnName(x, "Leading.razor.protein", "Proteins")
      if(verbose) message("-- Use <Leading.razor.protein> as Protein ID")
    }else{
      stop("<Leading razor protein> column not found. Proteins groups cannot be removed")
    }
    
    # This is not necessary for now: the leading razor protein is unique
    # data_f <- .artms_removeMaxQProteinGroups(x)

  } else if (config$data$filters$protein_groups == 'keep') {
    if(verbose) message("-- Protein groups are kept")
    data_f <- x
  } else{
    stop(
      "\nfiltering option for <protein_groups> not valid 
      (options available: keep or remove)"
    )
  }

  
  # DEAL WITH OLD CONFIGURATION FILES WHEN config$data$filters$modification 
  # COULD BE EMPTY
  if (is.null(config$data$filters$modification)) {
    if(verbose) message("--- NO config$data$filters$modification provided. 
        Using 'AB' as default ")
  } else if (config$data$filters$modification == 'AB' |
             config$data$filters$modification == 'APMS') {
    if(verbose) message(sprintf("-- PROCESSING %s",
                                config$data$filters$modification))
  } else if (config$data$filters$modification == 'UB') {
    data_f = data_f[Modifications %like% 'GlyGly']
  } else if (config$data$filters$modification == 'PH') {
    data_f = data_f[Modifications %like% 'Phospho']
  } else if (config$data$filters$modification == 'AC') {
    data_f = data_f[Modifications %like% 'Acetyl']
  } else{
    stop("The config > data > filters > modification ",
         config$data$filters$modification," is not valid option")
  }
  return(data_f)
}


#' @title Remove contaminants and empty proteins from the MaxQuant evidence file
#'
#' @description Remove contaminants and erronously identified 'reverse'
#' sequences by MaxQuant, in addition to empty protein ids
#' @param x (data.frame) of the Evidence file
#' @param verbose (logical) `TRUE` (default) shows function messages
#' @return (data.frame) without REV__ and CON__ Protein ids
#' @keywords cleanup, contaminants
#' @examples
#' ef <- artmsFilterEvidenceContaminants(x = artms_data_ph_evidence)
#' @export
artmsFilterEvidenceContaminants <- function(x,
                                            verbose = TRUE) {
  # Remove contaminants and reversed sequences (labeled by MaxQuant)
  
  x <- .artms_checkIfFile(x)
  x <- .artms_checkRawFileColumnName(x)
  
  data_selected <- x[grep("CON__|REV__", x$Proteins, invert = TRUE), ]
  
  # Remove empty proteins names
  blank.idx <- which(data_selected$Proteins == "")
  if (length(blank.idx) > 0)
    data_selected = data_selected[-blank.idx, ]
  
  if(verbose) message("-- Contaminants CON__|REV__ removed")
  return(data_selected)
}


#' @title Merge evidence.txt (or summary.txt) with keys.txt files 
#' @description Merge the evidence and keys files on the given columns
#' @param x (data.frame or char) The evidence data, either as data.frame or
#' the file name (and path). It also works for the summary.txt file
#' @param keys The keys data, either as a data.frame or file name (and path)
#' @param by (vector) specifying the columns use to merge the evidence and keys.
#' Default: `by=c('RawFile')`
#' @param isSummary (logical) TRUE or FALSE (default)
#' @param verbose (logical) `TRUE` (default) shows function messages
#' @return (data.frame) with the evidence and keys merged
#' @keywords merge, evidence, summary, keys
#' @examples
#' evidenceKeys <- artmsMergeEvidenceAndKeys(x = artms_data_ph_evidence,
#'                                            keys = artms_data_ph_keys)
#' @export
artmsMergeEvidenceAndKeys <- function(x, 
                                     keys, 
                                     by = c('RawFile'),
                                     isSummary = FALSE,
                                     verbose = TRUE) {

  if(verbose){
    message(">> MERGING FILES ")
  }

  x <- .artms_checkIfFile(x)
  keys <- .artms_checkIfFile(keys)
  
  x <- .artms_checkRawFileColumnName(x)
  keys <- .artms_checkRawFileColumnName(keys)
  
  # Make sure that the Intensity column is not empty
  if(!isSummary){
    if(all(is.na(x$Intensity))){
      stop("The <Intensity> column of the evidence file is empty. artMS cannot continue")
    }  
  }
  
  if(any(grepl("Experiment", colnames(keys)))){
    keys <- artmsChangeColumnName(keys, "Experiment", "ExperimentKeys")
  }
  
  if(isSummary){
    if(any(grepl("Experiment", colnames(x)))){
      x <- subset(x, Experiment != "") 
    }
  }
  
  # Processing FRACTIONS
  # Helping users: processing old requirement
  if("FractionKey" %in% colnames(keys)){
    keys <- artmsChangeColumnName(keys, "FractionKey", "Fraction")
    if(verbose) message("-- (!!) WARNING: column name <FractionKey> deprecated. Please, use <Fraction> instead")
  }
  
  if("Fraction" %in% colnames(keys)){
    # The Fraction column will be the one to use: delete from evidence
    if("Fraction" %in% colnames(x)){
      x <- subset(x, select = -c(Fraction))
    }
  }
  
  requiredColumns <- c('RawFile', 
                       'IsotopeLabelType',
                       'Condition',
                       'BioReplicate', 
                       'Run')
                   
  # Check that the keys file is correct
  if (any(!requiredColumns %in% colnames(keys))) {
    stop('Column names in keys not conform to schema. Required columns:\n', 
           sprintf('\t%s ', requiredColumns))
  }
  
  # Check if the number of RawFiles is the same.
  unique_data <- sort(unique(x$RawFile))
  unique_keys <- sort(unique(keys$RawFile))
  
  keys_not_found <- setdiff(unique_keys, unique_data)
  data_not_found <- setdiff(unique_data, unique_keys)
  
  if(length(keys_not_found) > 0 | length(data_not_found) > 0){
    if(length(keys_not_found) != 0){
      message(
        sprintf(
          "--(-) Raw.files in keys not found in evidence file:\n %s\n",
          paste(keys_not_found, collapse = ';'))
      ) 
    }
    if(length(data_not_found) != 0){
      if (!any(grepl("Total", data_not_found))){
        message(
          sprintf(
            "--(-) Raw.files in evidence not found in keys file:\n %s\n",
            paste(data_not_found, collapse = ';')
          )
        )
      }
    }
  }
  
  x <- merge(x, keys, by = by)
  
  # Make the 0 values, NA values
  if(any(x$Intensity == 0, na.rm = TRUE)){
    zero_values <- length(x$Intensity[(x$Intensity == 0)])
    total_values <- length(x$Intensity)
    x$Intensity[(x$Intensity == 0)] <- NA
    message("---- (r) ", zero_values, " peptides with Intensity = 0 out of ", total_values, " replaced by NAs")
  }
  
  return(x)
}



#' @title Convert the SILAC evidence file to MSstats format
#'
#' @description Converting the evidence file from a SILAC search to a format
#' compatible with MSstats. It basically modifies the Raw.files adding the
#' Heavy and Light label
#' @param evidence_file (char) Text filepath to the evidence file
#' @param output (char) Text filepath of the output name. If NULL it does not
#' write the output
#' @param verbose (logical) `TRUE` (default) shows function messages
#' @return (data.frame) with SILAC data processed for MSstats (and output file)
#' @keywords convert, silac, evidence
#' @examples \dontrun{
#' evidence2silac <- artmsSILACtoLong(evidence_file = "silac.evicence.txt",
#'                                    output = "silac-evidence.txt")
#' }
#' @export
artmsSILACtoLong <- function(evidence_file, 
                             output = NULL,
                             verbose = TRUE) {
  
  file <- Sys.glob(evidence_file)
  if(verbose) message(">> PROCESSING SILAC EVIDENCE FILE")

  # LEGACY reshape the data and split the heavy and light data
  # tmp <- fread(file, integer64 = 'double')
  # tmp_long <- data.table::melt(tmp, 
  #                               measure.vars = c("Intensity L", "Intensity H"))
  # tmp_long[, Intensity := NULL]
  # setnames(tmp_long, 'value', 'Intensity')
  # setnames(tmp_long, 'variable', 'IsotopeLabelType')
  # setnames(tmp_long, 'Raw file', 'Raw.file')
  # levels(tmp_long$IsotopeLabelType) = c('L', 'H')
  # tmp_long[!(is.na(tmp_long$Intensity) && tmp_long$Intensity < 1), ]$Intensity = NA
  
  tmp <- read.delim(file, stringsAsFactors = FALSE)
  tmp <- dplyr::select (tmp,-c(Intensity))
  
  tmp_long <- tmp %>% 
    tidyr::pivot_longer(cols = c(`Intensity.L`, `Intensity.H`), 
                        names_to = "IsotopeLabelType", 
                        values_to = "Intensity")
  
  tmp_long$IsotopeLabelType <- gsub("Intensity.L", "L", tmp_long$IsotopeLabelType)
  tmp_long$IsotopeLabelType <- gsub("Intensity.H", "H", tmp_long$IsotopeLabelType)
  
  if(!is.null(output)){
    write.table(
      tmp_long,
      file = output,
      sep = '\t',
      quote = FALSE,
      row.names = FALSE,
      col.names = TRUE
    )
    if(verbose) message("--- File ", output, " is ready ")
  }
  # colnames(tmp_long) <- gsub(" ", ".", colnames(tmp_long))
  # colnames(tmp_long) <- gsub("/", ".", colnames(tmp_long))
  # colnames(tmp_long) <- gsub("\\(", ".", colnames(tmp_long))
  # colnames(tmp_long) <- gsub("\\)", ".", colnames(tmp_long))
  tmp_long <- as.data.frame(tmp_long)
  return(tmp_long)
}

# @title Provide missing MSstats configuration parameters 
#
# @description MSstats version > 4 introduced a number of major changes 
# affecting the `dataProcess` function. As consequence, the artMS configuration 
# file was updated. The user can now provide any parameter required by 
# dataProcess. But if the user is still using old artMS configuration files,
# this function provides the new extra paramenters not available in previous
# versions
# @param d_long (data.frame) in long format
# @return (data.frame) Evidence file reshaped by rawfile and IsotopeLabelType
# @keywords msstats, parameters
.artms_provide_msstats_config_miss_parameters <- function(config, 
                                                          verbose = TRUE){
  
  Fraction = NULL
  
  if(any(grepl("^msstats$", names(config)))){
    
    cmmp = 0 #count missing msstats parameters
    
    if( !any(grepl("^logTrans$", names(config$msstats))) ){
      config$msstats$logTrans = 2
      cmmp = cmmp + 1
    }
    if( !any(grepl("^normalization_method$", names(config$msstats))) ){
      config$msstats$normalization_method = "equalizeMedians"
      cmmp = cmmp + 1
    }
    if( !any(grepl("^normalization_reference$", names(config$msstats))) ){
      config$msstats$normalization_reference = list(NULL)
      cmmp = cmmp + 1
    }
    if( !any(grepl("^feature_subset$", names(config$msstats))) ){
      config$msstats$feature_subset = "all"
      cmmp = cmmp + 1
    }
    if( !any(grepl("^remove_uninformative_feature_outlier$", names(config$msstats))) ){
      config$msstats$remove_uninformative_feature_outlier = FALSE
      cmmp = cmmp + 1
    }
    if( !any(grepl("^min_feature_count$", names(config$msstats))) ){
      config$msstats$min_feature_count = 2
      cmmp = cmmp + 1
    }
    if( !any(grepl("^n_top_feature$", names(config$msstats))) ){
      config$msstats$n_top_feature = 3
      cmmp = cmmp + 1
    }
    if( !any(grepl("^summaryMethod$", names(config$msstats))) ){
      config$msstats$summaryMethod = "TMP"
      cmmp = cmmp + 1
    }
    if( !any(grepl("^equalFeatureVar$", names(config$msstats))) ){
      config$msstats$equalFeatureVar = TRUE
      cmmp = cmmp + 1
    }
    if( !any(grepl("^censoredInt$", names(config$msstats))) ){
      config$msstats$censoredInt = "NA"
      cmmp = cmmp + 1
    }
    if( !any(grepl("^MBimpute$", names(config$msstats))) ){
      config$msstats$MBimpute = TRUE
      cmmp = cmmp + 1
    }
    if( !any(grepl("^remove50missing$", names(config$msstats))) ){
      config$msstats$remove50missing = FALSE
      cmmp = cmmp + 1
    }
    if( !any(grepl("^fix_missing$", names(config$msstats))) ){
      config$msstats$fix_missing = list(NULL)
      cmmp = cmmp + 1
    }
    if(!any(grepl("^maxQuantileforCensored$", names(config$msstats)))){
      config$msstats$maxQuantileforCensored = 0.999
      cmmp = cmmp + 1
    }
    if(!any(grepl("^use_log_file$", names(config$msstats)))){
      config$msstats$use_log_file = FALSE
      cmmp = cmmp + 1
    }
    if(!any(grepl("^append$", names(config$msstats)))){
      config$msstats$append = FALSE
      cmmp = cmmp + 1
    }
    if(!any(grepl("^log_file_path$", names(config$msstats)))){
      config$msstats$log_file_path = list(NULL)
    }
    
    if(cmmp > 0){
      message(paste("(!) WARNING:", cmmp," <msstats> parameter(s) missing. 
                Default paramenter(s) will be provided. 
                Please, check the artMS configuration file: you might be using an old version. 
                To get a new version use artmsWriteConfigYamlFile()"))
    }
    return(config)
  }
}


# @title Merge keys and Evidence from SILAC experiments
#
# @description Merge keys and Evidence from SILAC experiments
# @param evisilac (char) Output from artmsSILACtoLong
# @param keysilac (char) keys files with SILAC details
# @return df with both evidence and keys from silac merge
# @keywords internal, silac, merge
.artmsMergeSilacEvidenceKeys <- function(evisilac, 
                                         keysilac){
  
  
  evisilac <- .artms_checkIfFile(evisilac)
  evisilac <- .artms_checkRawFileColumnName(evisilac)
  
  keys <- .artms_checkIfFile(keysilac)
  keys <- .artms_checkRawFileColumnName(keys)
  
  # Check the labels from the keys file
  hlvalues <- unique(keys$IsotopeLabelType)
  hl2find <- c("L","H")
  
  if(length(setdiff(hlvalues, hl2find)) > 0){
    stop("The IsotopeLabelType available in the keys file are not from a 
         SILAC experiment: they must be H and L")
  }
  
  evisilac$RawFile = paste(evisilac$RawFile, 
                           evisilac$IsotopeLabelType, 
                           sep = '')
  keysilac$RawFile = paste(keysilac$RawFile, 
                       keysilac$IsotopeLabelType, 
                       sep = '')
  keysilac$Run = paste(keysilac$IsotopeLabelType, 
                   keysilac$Run , 
                   sep = '')
  
  evisilac$IsotopeLabelType = 'L'
  keysilac$IsotopeLabelType = 'L'
  
  df <- artmsMergeEvidenceAndKeys(x = evisilac, 
                                  keys =  keysilac,
                                  by = c('RawFile', 'IsotopeLabelType'),
                                  verbose = FALSE)
  return(df)
}
  


# @title Remove protein groups
#
# @description Remove the group of proteins ids separated by separated by `;`
# @param x (data.frame) with a `Proteins` column.
# @return (data.frame) with the protein groups removed
# @keywords maxquant, remove, proteingroups
.artms_removeMaxQProteinGroups <- function(x) {
  data_selected = x[grep(";", x$Proteins, invert = TRUE), ]
  return(data_selected)
}



#' @title Reshape the MSstats results file from long to wide format
#'
#' @description Converts the normal MSStats results.txt file into "wide" format
#' where each row represents a unique protein's results, and each column
#' represents the comparison made by MSStats. The fold change and p-value
#' of each comparison will be its own column.
#' @param results_msstats (char) Input file name and location
#' (MSstats `results.txt` file)
#' @param output_file (char) Output file name and location
#' (e.g. `results-wide.txt`). If `NULL` (default) returns an
#' R object (data.frame)
#' @param select_pvalues (char) Either
#' - `pvalue` or
#' - `adjpvalue` (default)
#' @param species (char) Specie name for annotation purposes.
#' Check `?artmsMapUniprot2Entrez` to find out more about the
#' supported species (e.g `species = "human"`)
#' @param verbose (logical) `TRUE` (default) shows function messages
#' @return (output file tab delimited) reshaped file with unique protein ids
#' and as many columns log2fc and adj.pvalues as comparisons available
#' @keywords msstats, results, wide, reshape
#' @examples
#' ph_results_wide <- artmsResultsWide(
#'                          results_msstats = artms_data_ph_msstats_results,
#'                          output_file = NULL,
#'                          species = "human")
#' @export
artmsResultsWide <- function(results_msstats,
                             output_file = NULL,
                             select_pvalues = c("adjpvalue", "pvalue"),
                             species,
                             verbose = TRUE) {
  
  # Debug
  # results_msstats = artms_data_ph_msstats_results
  # output_file = NULL
  # select_pvalues = "pvalue"
  # species = "human"
  # verbose = TRUE
  
  if(any(missing(results_msstats) | missing(species)))
    stop("Missed (one or many) required argument(s)
         Please, check the help of this function to find out more")
  
  if(verbose) message(">> RESHAPING MSSTATS RESULTS TO wide FORMAT ")
  results_msstats <- .artms_checkIfFile(results_msstats)
  
  select_pvalues <- match.arg(select_pvalues)
  pvals <- if(select_pvalues == "adjpvalue") "adj.pvalue" else "pvalue"
  selectedColumns <- c('Protein', 'Label', 'log2FC', pvals)
  
  # input_l <- data.table::melt(data = results_msstats[,selectedColumns], 
  #                             id.vars = c('Protein', 'Label'))
  
  input_l <- results_msstats %>%
    dplyr::select(one_of(selectedColumns)) %>%
    tidyr::pivot_longer(
      cols = -c(Protein, Label), 
      names_to = "variable", 
      values_to = "value")
  
  
  # ## then cast to get combinations of LFCV/PVAl and Label as columns
  # input_w <- data.table::dcast(Protein ~ Label + variable,
  #                              data = input_l,
  #                              value.var = c('value'))
  
  input_w <- input_l %>% 
    dplyr::mutate(Label_variable = paste(Label, variable, sep = "_")) %>%
    dplyr::select(Protein, Label_variable, value) %>%
    tidyr::pivot_wider(names_from = Label_variable,
                       values_from = value)
  
  suppressMessages(
    input_w <- artmsAnnotationUniprot(input_w, 
                                      "Protein", 
                                      species)
    )
                                                      

  if (!is.null(output_file)) {
    write.table(
      input_w,
      file = output_file,
      eol = '\n',
      sep = '\t',
      quote = FALSE,
      row.names = FALSE,
      col.names = TRUE
    )
    if(verbose) message("--- Results wide are out! ")
  } else{
    return(input_w)
  }
}


#' @title Outputs the spectral counts from the MaxQuant evidence file.
#'
#' @description Outputs the spectral counts from the MaxQuant evidence file.
#' @param evidence_file (char) Maxquant evidence file or data object
#' @param keys_file (char) Keys file with the experimental design or data object
#' @param output_file (char) Output file name (add `.txt` extension).
#' If `NULL` (default) it returns a data.frame object
#' @param verbose (logical) `TRUE` (default) shows function messages
#' @return A txt file with biological replicates, protein id, and spectral
#' count columns
#' @keywords spectral_counts, evidence
#' @examples
#' summary_spectral_counts <- artmsSpectralCounts(
#'                                  evidence_file = artms_data_ph_evidence,
#'                                  keys_file = artms_data_ph_keys)
#' @export
artmsSpectralCounts <- function(evidence_file,
                                 keys_file,
                                 output_file = NULL,
                                 verbose = TRUE) {
  if(verbose) message(">> EXTRACTING SPECTRAL COUNTS FROM THE EVIDENCE FILE ")
  
  x <- .artms_checkIfFile(evidence_file)
  keys <- .artms_checkIfFile(keys_file)
  
  x <- .artms_checkRawFileColumnName(x)
  keys <- .artms_checkRawFileColumnName(keys)
  
  
  x <- artmsMergeEvidenceAndKeys(x, 
                                 keys, 
                                 by = c('RawFile'),
                                 verbose = verbose)
  data_sel <-
    x[, c('Proteins',
             'Condition',
             'BioReplicate',
             'Run',
             'MS.MS.count')]
  data_sel <-
    artmsChangeColumnName(data_sel, 'MS.MS.count', 'spectral_counts')
  data_sel <-
    aggregate(
      spectral_counts ~ Proteins + Condition + BioReplicate + Run,
      data = data_sel,
      FUN = sum
    )
  data_sel <-
    data.frame(
      data_sel,
      AllCondition = paste(
        data_sel$Condition,
        data_sel$BioReplicate,
        data_sel$Run,
        sep = '_'
      )
    )
  
  if (!is.null(output_file)) {
    write.table(
      data_sel[, c('AllCondition', 'Proteins', 'spectral_counts')],
      file = output_file,
      eol = '\n',
      sep = '\t',
      quote = FALSE,
      row.names = FALSE,
      col.names = TRUE
    )
    if(verbose) message(">> OUTPUT FILE <", output_file, "> is ready ")
  } else{
    return(data_sel)
  }
}


# @title Remove white spaces
#
# @description Remove white spaces
# @param x (vector) A string
# @return (vector) with no white spaces
# @keywords internal, remove, whitespace
.artms_trim <- function (x) {
  gsub("^\\s+|\\s+$", "", x)
}


# @title Generate the contrast matrix required by MSstats from a txt file
# @description It simplifies the process of creating the contrast file
# @param contrast_file The text filepath of contrasts
# @param all_conditions a vector with all the conditions in the keys file
# @return (data.frame) with the contrast file in the format required by
# MSstats
# @author Tom Nguyen, David Jimenez-Morales
# @keywords check, contrast
.artms_writeContrast <- function(contrast_file, 
                                 all_conditions = NULL) {

  if(file.exists(contrast_file)){
    input_contrasts <- readLines(contrast_file, warn = FALSE)
  }else{
    # It assumes it is an already opened file
    input_contrasts <- contrast_file
    if(!is.character(input_contrasts)) stop("CONTRAST file/data is NULL")
    if(!grepl("-", input_contrasts)) stop("CONTRAST file/data not according guidelines")
  }

  #remove empty lines
  input_contrasts <- input_contrasts[vapply(input_contrasts, nchar, FUN.VALUE = 0) > 0]
  
  # check if contrast_file is old-format (i.e the contrast_file is a matrix)
  headers <- unlist(strsplit(input_contrasts[1], split = "\t"))
  if (length(headers) > 1) {
    newinput_contrasts <- c()
    for (i in 2:length(input_contrasts)) {
      newinput_contrasts <-
        c(newinput_contrasts, unlist(strsplit(input_contrasts[i], 
                                              split = "\t"))[1])
    }
    input_contrasts <- newinput_contrasts
  }
  
  # validate the input
  input_contrasts <- trimws(input_contrasts)
  valid <- TRUE
  accepted_chars <- c(LETTERS, letters, 0:9, '-', '_')
  for (x in input_contrasts) {
    if (x != "") {
      characs <- unlist(strsplit(x, split = ''))
      not_allowed_count <-
        length(which(!(characs %in% accepted_chars)))
      if (not_allowed_count > 0) {
        valid <- FALSE
        stop(paste(x, " is not a valid input"))
      }
      
      dash_count <- length(which(characs == '-'))
      if (dash_count != 1) {
        valid <- FALSE
        stop(paste(x, "needs to contain exactly 1 '-'"))
      }
    }
  }
  
  if (valid) {
    mat <- t(as.data.frame(strsplit(input_contrasts, split = '-')))
    rownames(mat) <- NULL
    conds <- sort(unique(c(mat[, 1], mat[, 2])))
    contrast_matrix <-
      matrix(0, nrow = nrow(mat), ncol = length(conds))
    colnames(contrast_matrix) <- conds
    rownames(contrast_matrix) <- input_contrasts
    
    for (i in seq_len(nrow(mat)) ) {
      cond1 <- mat[i, 1]
      cond2 <- mat[i, 2]
      contrast_matrix[i, cond1] <- 1
      contrast_matrix[i, cond2] <- -1
    }
    
    # check if conditions are all found in Evidence/Key
    if (!is.null(all_conditions)) {
      d <- setdiff(conds, all_conditions)
      if (length(d) > 0) {
        msg <-
          paste("These conditions are not found in the dataset:",
                paste(d, collapse = ","))
        stop(msg)
      }
    }
    return (contrast_matrix)
  } else{
    stop(
      'Something went wrong while generating the contrast file.
      Please, let the developers know at <artms.help@gmail.com>'
    )
  }
}
