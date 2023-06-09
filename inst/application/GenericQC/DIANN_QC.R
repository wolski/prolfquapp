#R
# R_LIBS_SITE="/scratch/FRAGPIPEDIA_A312/R_LIBS_V1/"

args <- commandArgs(trailingOnly = TRUE)
if (length(args) > 0) {
  cat(args, sep = "\n")
  path <- args[1]
  project_Id <- args[2]
  output_dir <- args[3]
  libPath <- args[4]

  print(paste("libPath :" , .libPaths(), collapse = " ;"))

  if (!is.na(libPath) & dir.exists(libPath) ) {
    print(paste("Setting libPath:", libPath, collapse = " ;"))
    .libPaths(libPath)
    cat(.libPaths(), sep = "\n")
  }
} else {
  warning("please provide :\n",
          "path       : folder containing fasta, diann-output.tsv and dataset.tsv file \n",
          "project_id : b-fabric project id\n",
          "output_dir : folder to write the results to \n",
          "libPath.   : (optional) R library path\n"
          )
  path = "."
  project_Id = "o3000"
  output_dir = "qc_dir"
}




# this must be executed after the libPath is modified.

library(dplyr)
library(prolfquapp)
library(logger)


ps <- list()
ps$workunit_Id = basename(getwd())
ps$project_Id = project_Id
ps$order_Id = project_Id


if (!dir.exists(output_dir)) {
  dir.create(output_dir)
}

mdir <- function(path, pattern){
  dir(path, pattern, full.names = TRUE, recursive = TRUE)
}

fasta.file <- mdir(path,
                   pattern = "*.fasta$")
logger::log_info(fasta.file)

diann.output <- mdir(path,
                     pattern = "diann-output.tsv")
logger::log_info(diann.output)

dataset.csv <- mdir(path,
                    pattern = "dataset.csv")
logger::log_info(dataset.csv)

peptide <- read_DIANN_output(
  diann.path = diann.output,
  fasta.file = fasta.file,
  nrPeptides = 1,
  Q.Value = 0.1)

prot_annot <- prolfquapp::dataset_protein_annot(
  peptide,
  c("protein_Id" = "Protein.Group"),
  protein_annot = "fasta.header",
  more_columns = c("nrPeptides", "fasta.id", "Protein.Group.2")
)


# dataset.csv must either contain columns:
# `Relative Path` Name `Grouping Var` FileType
# else the report will be generated but without this information.
if (length(dataset.csv) > 0) {
  annotation <- read.csv(dataset.csv)
  annotation$inputresource.name <- tools::file_path_sans_ext(basename(annotation$Relative.Path))
  annotation$inputresource.name <- gsub("\\.d$","", annotation$inputresource.name) # remove .d for bruker timstof data.
  if ("Name" %in% colnames(annotation)) {
    annotation$sample.name <- make.unique(annotation$Name)
  } else {
    annotation$sample.name <- gsub("^[0-9]{8,8}_[0-9]{3,3}_S[0-9]{6,6}_","", annotation$inputresource.name)
  }

  if (!any(grepl("Group", colnames(annotation)))) {
    annotation$Grouping.Var <- "None_Specified"
  }

} else{
  annotation <- data.frame(Relative.Path = unique(peptide$raw.file))
  annotation$inputresource.name <- tools::file_path_sans_ext(basename(annotation$Relative.Path))
  annotation$sample.name <- gsub("^[0-9]{8,8}_","", annotation$inputresource.name)
  annotation$Grouping.Var <- "None_Specified"
}


peptide <- dplyr::inner_join(
  annotation,
  peptide,
  by = c("inputresource.name" = "raw.file"),
  multiple = "all")

# MSFragger specific (moving target)
atable <- prolfqua::AnalysisTableAnnotation$new()
atable$fileName = "inputresource.name"
atable$sampleName = "sample.name"
atable$ident_qValue = "PEP"
atable$hierarchy[["protein_Id"]] <- c("Protein.Group")
atable$hierarchy[["peptide_Id"]] <- c("Stripped.Sequence")
atable$hierarchyDepth <- 1
atable$set_response("Peptide.Quantity")
atable$factors[["group"]] = grep("Group",colnames(annotation), value = TRUE)
atable$factorDepth <- 1


config <- prolfqua::AnalysisConfiguration$new(atable)
adata <- prolfqua::setup_analysis(peptide, config)

lfqdata <- prolfqua::LFQData$new(adata, config)
lfqdata$remove_small_intensities(threshold = 1)

TABLES2WRITE <- list()
TABLES2WRITE$peptide_wide <- left_join(prot_annot,
                                       lfqdata$to_wide()$data,
                                       multiple = "all")

TABLES2WRITE$annotation <- lfqdata$factors()
lfqdataProt <- prolfquapp::aggregate_data(lfqdata, agg_method = "medpolish")
TABLES2WRITE$proteins_wide <- left_join(prot_annot,
                                        lfqdataProt$to_wide()$data,
                                        multiple = "all")

summarizer <- lfqdata$get_Summariser()
precabund <- summarizer$percentage_abundance()
precabund <- inner_join(
  prot_annot,
  precabund,
  multiple = "all",
  by = lfqdata$config$table$hierarchy_keys_depth())

TABLES2WRITE$proteinAbundances <- precabund
writexl::write_xlsx(TABLES2WRITE, path = file.path(output_dir, "proteinAbundances.xlsx"))

file.copy(system.file("application/GenericQC/QC_ProteinAbundances.Rmd", package = "prolfquapp"),
          to = output_dir, overwrite = TRUE)

rmarkdown::render(file.path(output_dir,"QC_ProteinAbundances.Rmd"),
                  params = list(config = lfqdataProt$config$table,
                                precabund = precabund,
                                project_info = ps,
                                factors = TRUE),
                  output_file = "proteinAbundances.html")



if (nrow(lfqdata$factors()) > 1) {
  file.copy(system.file("application/GenericQC/QCandSSE.Rmd", package = "prolfquapp"),
            to = output_dir, overwrite = TRUE)

  rmarkdown::render(file.path(output_dir,"QCandSSE.Rmd"),
                    params = list(data = lfqdata$data,
                                  configuration = lfqdata$config,
                                  project_conf = ps,
                                  pep = FALSE),
                    output_file = "QC_sampleSizeEstimation.html"
                    )
} else{
  message("only a single sample: ", nrow(lfqdata$factors()))
}

