% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/gene_names_xref_util.r
\name{gen_10x_mars_gene_match}
\alias{gen_10x_mars_gene_match}
\title{Generate mapping of 10x to mars names}
\usage{
gen_10x_mars_gene_match(mars_mc_id, tenx_mc_id)
}
\arguments{
\item{mars_mc_id}{metacell id of a mars-seq dataset}

\item{tenx_mc_id}{metacell id of a 10x dataset}
}
\description{
Not more than finding which concatenated names (";" delimited) are related to 10x gene names. Should be replaced by something more systematic that will happen during import
}
