% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/protein2SiteConversion.R
\name{artmsProtein2SiteConversion}
\alias{artmsProtein2SiteConversion}
\title{Converts the Protein ID column of the evidence
file selected by the user to mod-site-specific notation:
\code{ProteinID} to \code{ProteinID_AAnumber} notation}
\usage{
artmsProtein2SiteConversion(
  evidence_file,
  ref_proteome_file,
  column_name = c("Leading razor protein", "Leading proteins", "Proteins"),
  output_file,
  mod_type,
  overwrite_evidence = FALSE,
  verbose = TRUE
)
}
\arguments{
\item{evidence_file}{(char) The evidence file name and location}

\item{ref_proteome_file}{(char) The reference proteome used as database
to search the \code{evidence.txt} file with MaxQuant. It will be used to map the
modified peptide to the protein sequence and find the site location.
Therefore, it does not use the MaxQuant's \verb{Phospho (STY)Sites.txt}}

\item{column_name}{(char) The Protein Column Name to map. Options:
\itemize{
\item \verb{Leadind razor protein} (default)
\item \verb{Leading protein}
\item \code{Proteins}
It only supports Uniprot Entry IDs and RefSeq, but it might work for
other database IDs
}}

\item{output_file}{(char) Output file name
(\code{ptmsites-evidence.txt} recommended)}

\item{mod_type}{(char) The posttranslational modification. Options:
\itemize{
\item \code{UB}: Protein Ubiquitination
\item \code{PH}: Protein Phosphorylation
\item \code{AC}: Protein Acetylation
\item \code{PTM:XXX:yy} : User defined PTM. Replace XXX with 1 or more 1-letter amino
acid codes on which to find modifications (all uppercase).  Replace yy with
modification name used within the evidence file (require lowercase characters).
Example: \code{PTM:STY:ph} will find modifications on aa S,T,Y with this
format \verb{_AAGGAPS(ph)PPPPVR_}. This would be equivalent to \code{mod_type = PH}
}}

\item{overwrite_evidence}{(logical) if <output_file> is the same
as <evidence_file>, \code{overwrite_evidence = FALSE} (default) doesn't allow to
overwrite the evidence file. Otherwise, \code{overwrite_evidence = TRUE} allows
to overwrite the evidence_file (this option might be activated if the user
allows to use the same \code{ptm-sites-evidence.txt} file to re-annotate all
the Protein IDs columns)}

\item{verbose}{(logical) \code{TRUE} (default) shows function messages}
}
\value{
(file) Return a new evidence file with the specified Protein id
column modified by adding the sequence site location(s) + postranslational
modification(s) to the uniprot entry / refseq id.

Output ID examples: \code{A34890_ph3}; \code{Q64890_ph24_ph456};
\code{Q64890_ub34_ub129_ub234}; \code{Q64890_ac35}.
}
\description{
It enables the modified-peptide specific quantification by
converting the Protein column of the evidence file selected by the user
to an \code{ProteinID_AAnumber}notation.
In this way, each of the modified peptides can be quantified
independently across conditions.

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

WARNING: we have detected a version of MaxQuant (>1.6.3.0) outputs a`
"Modified sequence" column of the evidence file that has two important
changes for the annotation of phosphorylation:
\itemize{
\item Uses \code{p} instead of \code{(ph)}
\item The modified residue (i.e. \code{STY}) is the residue on the right of the \code{p},
instead of the residue to the left of \code{(ph)}, as usual.
We have introduced a modification to detect and address this issue, but
we advice the user to double check both the new evidence file with the
introduce new notation and the \code{-mapping.txt} file and check that there
are no NA values for the notation of phophopeptides.
}

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
}
\examples{
# Testing warning if files are not submitted. 
artmsProtein2SiteConversion(evidence_file = NULL, ref_proteome_file = NULL, 
output_file = NULL)
}
\keyword{ac}
\keyword{convert,}
\keyword{evidence,}
\keyword{ph,}
\keyword{ptm,}
\keyword{ub,}
