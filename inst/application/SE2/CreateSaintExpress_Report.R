# Author : Witold Wolski <wew@fgcz.ethz.ch>
# compatible with prolfqua 3.0.0 release available from https://github.com/wolski/prolfqua/releases/tag/v0.2.9


# Read b-fabric related information
yml <- yaml::read_yaml("config.yaml")

BFABRIC <- list()
BFABRIC$workunitID = yml$job_configuration$workunit_id
BFABRIC$workunitURL = paste0("https://fgcz-bfabric.uzh.ch/bfabric/workunit/show.html?id=",BFABRIC$workunitID,"&tab=details")
yml$job_configuration
#BFABRIC$projectID = yml$job_configuration$project_id
BFABRIC$orderID = yml$job_configuration$order_id

BFABRIC$inputID = purrr::map_chr(yml$job_configuration$input[[1]], "resource_id")
BFABRIC$inputID = tail(BFABRIC$inputID,n = 1)
BFABRIC$inputURL = purrr::map_chr(yml$job_configuration$input[[1]], "resource_url")
BFABRIC$inputURL = tail(BFABRIC$inputURL, n = 1)
BFABRIC$datasetID <- yml$application$parameters$datasetId



ZIPDIR = paste0("C",BFABRIC$orderID,"WU",BFABRIC$workunitID)
dir.create(ZIPDIR)


# list with data used with the markdown report
REPORTDATA <- list()

# Applciation parameters
REPORTDATA$spc <- if ( yml$application$parameters$SpcInt == "Spectral Count") { TRUE } else {FALSE}
REPORTDATA$FCthreshold <- as.numeric( yml$application$parameters$FCthreshold )
REPORTDATA$FDRthreshold <- as.numeric(yml$application$parameters$BFDRsignificance)

# Prefix for exported files
treat <- "FRAGPIPE_"

# load data
annotation <- readr::read_csv("dataset.csv")
colnames(annotation) <- tolower(make.names(colnames(annotation)))
annotation

library(tidyverse)
pp <- prolfqua::tidy_MSFragger_combined_protein_V16("combined_protein.tsv")
prot_annot <- dplyr::select(pp,protein , description) |> dplyr::distinct()
pp$raw.file |> unique()


# attach annotation to combined_protein data
annotation$raw.file <- basename(annotation$relative.path)
annotation <- dplyr::mutate(annotation, raw.file = gsub(".raw", "", raw.file))
annotation$relative.path <- NULL

stopifnot(sum(annotation$raw.file %in% pp$raw.file) > 0) # check that some files are annotated, if not exit script.
pdata <- dplyr::inner_join(annotation, pp )
# filter for more than 2 peptides per protein
pdata <- pdata |> dplyr::filter(combined.total.peptides > 1)
# configure prolfqua
ata <- prolfqua::AnalysisTableAnnotation$new()

# check if there is a sample name if so use it.
if (any(grepl("^name", colnames(annotation)))) {
  ata$sampleName = grep("^name", colnames(annotation), value = TRUE)
}

ata$fileName = "raw.file"
ata$factors[["CorT"]] = grep("control", colnames(annotation), value = TRUE)
ata$factors[["bait"]] = grep("bait", colnames(annotation), value = TRUE)

ata$factorDepth <- 2

ata$hierarchy[["protein_Id"]] = "protein"

if (REPORTDATA$spc) {
    ata$workIntensity = "razor.spectral.count"
} else {
    ata$workIntensity = "razor.intensity"
}


config <- prolfqua::AnalysisConfiguration$new(ata)
sdata <- prolfqua::setup_analysis(pdata, config)
lfqdata <- prolfqua::LFQData$new(sdata, config)
lfqdata$remove_small_intensities(threshold = 0.1)


# remove rev and contaminant sequences
lfqdata$data <- lfqdata$data |> dplyr::filter(!grepl("^REV__|^CON__", protein_Id))

RESULTS <- list() # RESULT is stored in excel table
RESULTS$annotation <- lfqdata$factors()

# Run Saint Analysis
intdata <- lfqdata$data

intdata <- dplyr::inner_join(intdata ,
                      dplyr::distinct( dplyr::select(pdata, protein, protein.length)),
                      by = c(protein_Id = "protein"))
localSAINTinput <- prolfqua::protein_2localSaint(
  intdata,
  quantcolumn = lfqdata$config$table$getWorkIntensity())


RESULTS <- c(RESULTS, localSAINTinput)
resSaint <- prolfqua::runSaint(localSAINTinput, spc = REPORTDATA$spc)
resSaint$list |> head()

resSaint$list <- dplyr::inner_join(prot_annot, resSaint$list, by = c(protein = "Prey"), keep = TRUE)
resSaint$list$protein <- NULL

RESULTS <- c(RESULTS, resSaint)
# write analysis results

# Prepare result visualization and render report
#prolfqua::ContrastsSaintExpress$debug("get_Plotter")
cse <- prolfqua::ContrastsSaintExpress$new(resSaint$list)


resContrasts <- cse$get_contrasts()
resContrasts <- resContrasts |> dplyr::select(-dplyr::all_of( c("group_1_name", "group_2_name", "group_1", "group_2" )))
sig <- resContrasts |>
  dplyr::filter(.data$BFDR  <  REPORTDATA$FDRthreshold & .data$log2_EFCs  >  log2(REPORTDATA$FCthreshold))

head(resContrasts)

library(prozor)

resContrasts$Prey

# Transform data for PCA visualization etc
tt <- lfqdata$get_Transformer()$log2()
lfqdata_transformed <- tt$lfq


prepUpset <- function(data, cf, tr = 2) {
  tmp <- prolfqua::interaction_missing_stats(data, cf)
  nrMiss <- tmp$data %>% tidyr::pivot_wider(id_cols = cf$table$hkeysDepth(),
                                            names_from = cf$table$fkeysDepth(),
                                            values_from = !!rlang::sym("nrMeasured"))

  nrMiss[,-(1:cf$table$hierarchyDepth)][nrMiss[,-(1:cf$table$hierarchyDepth)] < tr] <- 0
  nrMiss[,-(1:cf$table$hierarchyDepth)][nrMiss[,-(1:cf$table$hierarchyDepth)] >= tr] <- 1
  return(as.data.frame(nrMiss))
}

REPORTDATA$pups <- prepUpset(lfqdata$data, lfqdata$config)
RESULTS$InputData <- lfqdata$to_wide()$data

gs <- lfqdata$get_Summariser()
RESULTS$MissingInformation <- gs$interaction_missing_stats()$data
RESULTS$MissingInformation$isotopeLabel <- NULL
RESULTS$listFile <- NULL
writexl::write_xlsx(RESULTS, path = file.path(ZIPDIR,paste0(treat, "_data.xlsx")))


REPORTDATA$BFABRIC <- BFABRIC
REPORTDATA$lfqdata_transformed <- lfqdata_transformed
REPORTDATA$sig <- sig
REPORTDATA$resContrasts <- resContrasts
REPORTDATA$prot_annot <- prot_annot

tmp <- prolfqua::get_UniprotID_from_fasta_header(REPORTDATA$pups, "protein_Id")
write.table(data.frame(tmp$UniprotID), file = file.path(ZIPDIR,"ORA_background.txt"), col.names = FALSE, row.names = FALSE, quote = FALSE )
sig |> dplyr::group_by(Bait) |> nest() -> sigg

for (i in 1:nrow(sigg)) {
  tmp <- prolfqua::get_UniprotID_from_fasta_header(sigg$data[[i]], "Prey")
  filename <- paste0("ORA_Bait_", sigg$Bait[i] , ".txt")
  write.table(data.frame(tmp$UniprotID),
              file = file.path(ZIPDIR, filename),
              col.names = FALSE,
              row.names = FALSE,
              quote = FALSE )
}


SEP <- REPORTDATA

saveRDS(REPORTDATA, file = "REPORTDATA.rds")
rm(list = setdiff(ls(), c("REPORTDATA","ZIPDIR","treat"))) # delete all variables not needed for rendering
SEP <- REPORTDATA

rmarkdown::render("SaintExpressReportMsFragger.Rmd",
                  params = list(sep = REPORTDATA),
                  output_format = bookdown::html_document2())
                  #,envir = new.env())


file.copy("SaintExpressReportMsFragger.html",
 file.path(ZIPDIR, paste0(treat, "SaintExpressReportMsFragger.html")),
 overwrite = TRUE)

