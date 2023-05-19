# prolfquapp: Streamlining Protein Differential Expression Analysis in Core Facilities

## Introduction

The prolfquapp is a user-friendly application to streamline protein differential expression analysis (DEA) in core facilities. The application leverages the preprocessing methods and statistical models implemented in the R package prolfqua. It generates dynamic HTML reports that contain quality control plots and visualizations of the DEA results. The prolfquapp also exports results in multiple formats, including XLSX files, .rnk or txt files for gene set enrichment analysis, and Bioconductor SummarizedExperiment format for import into interactive visualization tools like OmicsViewer and iSEE. The prolfquapp offers a comprehensive and efficient solution for researchers seeking to analyze protein differential expression data in a core facility setting.

## Methods

The prolfquapp is a highly configurable application. The application interfaces with the laboratory data management systems through a YAML file and a '.tsv' file. To showcase this functionality, we developed an R Shiny application that collects user inputs, generates the configuration files, and runs prolfquapp. The YAML file enables the specification of key parameters, such as data normalization and modeling methods. It can also contain information about the input data and project integrated into the HTML report. This makes prolfquapp a user-friendly and flexible tool for protein DEA.

## Preliminary data

We developed an application based on the *R* package for users unfamiliar with statistics and *R* programming to ease the usage barriers of the *prolfqua* package. Furthermore, we integrated it into the data management platform B-Fabric. This integration enables users to select the input data and basic settings in a graphical user interface (GUI).
Using sample annotation information stored in B-Fabric, the user creates a table with the following columns: the sample name, a column with the sample groupings, an optional column with an additional explanatory variable, and finally, a column that defines which group differences to compute. This file format is similar to the one used by SAINTexpress, MSstats, or LFQAnalyst. In addition, other parameters, e.g., which of the modeling methods implemented in the prolfqua R-package can be specified.
The application then generates multiple result files, including an HTML report. The report integrates project-related information from B-Fabric and introduces the DEA. Furthermore, QC plots and summaries focus on the quality of protein and peptide identification and quantification. Next, we show the results of the DEA using dynamic tables and figures, which can be queried and filtered. Finally, in the section on additional analysis, we introduce methods of downstream omics analysis, e.g., gene set enrichment analysis, and provide links to web services (e.g., Webgestalt, String-db). 
Most importantly, the user receives all the data and code to reproduce the analysis on his infrastructure. This way, prolfquapp, and B-Fabric help scientists meet requirements from funding agencies, journals, and academic institutions while publishing their data according to the FAIR data principles. The source code of the prolfquapp R package is available from https://gitlab.bfabric.org/wolski/prolfquapp.

## Novel aspect


The prolfquapp can be tightly integrated with the LIMS system, and, at the same time, You can replicate the analysis on your laptop computer. 
