% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/annotations.R
\name{artmsAnnotationUniprot}
\alias{artmsAnnotationUniprot}
\title{Annotate table with Gene Symbol and Name based on Uniprot ID(s)}
\usage{
artmsAnnotationUniprot(x, columnid, species, verbose = TRUE)
}
\arguments{
\item{x}{(data.frame) to be annotated (or file path and name)}

\item{columnid}{(char) The column with the uniprotkb ids}

\item{species}{(char) The species name. Check \code{?artmsMapUniprot2Entrez}
to find out more about supported species.}

\item{verbose}{(logical) \code{TRUE} (default) shows function messages}
}
\value{
(data.frame) with two new columns: \code{Gene} and \code{Protein.name}
}
\description{
Annotate gene name and symbol based on uniprot ids. It will
take the column from your data.frame specified by the \code{columnid} argument,
search for the gene symbol, name, and entrez based on the species (\code{species}
argument) and merge the information back to the input data.frame
}
\examples{
# This example adds annotations to the example evidence file included in
# artMS, based on the column 'Proteins'.

evidence_anno <- artmsAnnotationUniprot(x = artms_data_ph_evidence,
                                         columnid = 'Proteins',
                                         species = 'human')
}
\keyword{annotation,}
\keyword{uniprot}
