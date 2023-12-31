% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/enrichments.R
\name{artmsEnrichProfiler}
\alias{artmsEnrichProfiler}
\title{Enrichment analysis using GprofileR}
\usage{
artmsEnrichProfiler(
  x,
  categorySource = c("GO"),
  species,
  background = NA,
  verbose = TRUE
)
}
\arguments{
\item{x}{(list, data.frame) List of protein ids. It can be anything:
either a list of ids, or you could also send a data.frame and it will find
the columns with the IDs. Is not cool? Multiple list can be also sent
simultaneously, as for example running:
\code{tmp <- split(enrichment$Gene, enrichment$cl_number, drop= TRUE)}}

\item{categorySource}{(vector) Resources providing the terms on which
the enrichment will be performed. The supported resources by gprofiler are:
\itemize{
\item GO (GO:BP, GO:MF, GO:CC): Gene Ontology (see more below)
\item KEGG: Biological pathways
\item REAC: Biological pathways (Reactome)
\item TF: Regulatory motifs in DNA (TRANSFAC TFBS)
\item MI: Regulatory motifs in DNA (miRBase microRNAs)
\item CORUM: protein complexes database
\item HP: Human Phenotype Ontology
\item HPA: Protein databases (Human Protein Atlas)
\item OMIM: Online Mendelian Inheritance in Man annotations:
\item BIOGRID: BioGRID protein-protein interactions
The type of annotations for Gene Ontology:
\item Inferred from experiment (IDA, IPI, IMP, IGI, IEP)
\item Direct assay (IDA) / Mutant phenotype (IMP]
\item Genetic interaction (IGI) / Physical interaction (IPI)
\item Traceable author (TAS) / Non-traceable author (NAS) /
Inferred by curator (IC)
\item Expression pattern (IEP) / Sequence or structural similarity (ISS)
/ Genomic context (IGC)
\item Biological aspect of ancestor (IBA) / Rapid divergence (IRD)
\item Reviewed computational analysis (RCA) / Electronic annotation (IEA)
\item No biological data (ND) / Not annotated or not in background (NA)
}}

\item{species}{(char) Specie code: Organism names are constructed by
concatenating the first letter of the name and the family name.
Example: human - ’hsapiens’, mouse - ’mmusculus’. Check gProfileR to find out
more about supported species.}

\item{background}{(vector) gene list to use as background for the enrichment
analysis. Default: \code{NA}}

\item{verbose}{(logical) \code{TRUE} (default) shows function messages}
}
\value{
The enrichment results as provided by gprofiler
}
\description{
This function simplifies the enrichment analysis performed by
the excellent tool GprofileR.
}
\details{
This function uses the following \code{gprofiler} arguments as default:
\itemize{
\item ordered_query = FALSE
\item significant = TRUE
\item exclude_iea = TRUE
\item underrep = FALSE
\item evcodes = FALSE
\item region_query = FALSE
\item max_p_value = 0.05
\item min_set_size = 0
\item max_set_size = 0
\item min_isect_size = 0
\item correction_method = "analytical" #Options: "gSCS", "fdr", "bonferroni"
\item hier_filtering = "none"
\item domain_size = "known" # annotated or known
\item numeric_ns = ""
\item png_fn = NULL
\item include_graph = TRUE
}
}
\examples{
\dontrun{
# annotate the MSstats results to get the Gene name
data_annotated <- artmsAnnotationUniprot(
                                     x = artms_data_ph_msstats_results,
                                     columnid = "Protein",
                                     species = "human")

# Filter the list of genes with a log2fc > 2
filtered_data <- 
unique(data_annotated$Gene[which(data_annotated$log2FC > 2)])

# And perform enrichment analysis
data_annotated_enrich <- artmsEnrichProfiler(
                                   x = filtered_data,
                                   categorySource = c('KEGG'),
                                   species = "hsapiens",
                                   background = unique(data_annotated$Gene))
}
}
\keyword{enrichment}
