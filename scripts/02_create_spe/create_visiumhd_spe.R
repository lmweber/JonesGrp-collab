# -------------------------------------------------------------------------
# R script to create SpatialExperiment objects
# from Space Ranger outputs for Visium HD samples
# -------------------------------------------------------------------------
#
# Expected Space Ranger output directories:
#   spaceranger/
#     VisiumHD_A1_Pax/
#     VisiumHD_A1_Vax/
#     VisiumHD_D1_D42/
#     VisiumHD_D1_Naive/
#
# Each Space Ranger run directory is expected to contain an "outs/" directory.
#
# This script creates 12 independent .rds files:
#   - 4 samples x 8 um bins
#   - 4 samples x 16 um bins
#   - 4 samples x Space Ranger segmented cells
#
# Run this script from the project directory containing "spaceranger/".
#

# -------------------------------------------------------------------------
# Load packages
# -------------------------------------------------------------------------

library(VisiumIO)
library(SpatialExperiment)
library(SummarizedExperiment)
library(BiocIO)
library(Matrix)
library(S4Vectors)
library(arrow)
library(sf)
library(magick)


# -------------------------------------------------------------------------
# Workaround for arrow open_dataset() / sf conflict in VisiumIO
# -------------------------------------------------------------------------

source("fix_VisiumIO_arrow_sf.R")


# -------------------------------------------------------------------------
# Directories
# -------------------------------------------------------------------------

sample_dirs <- c(
  A1_Pax   = "spaceranger/VisiumHD_A1_Pax",
  A1_Vax   = "spaceranger/VisiumHD_A1_Vax",
  D1_D42   = "spaceranger/VisiumHD_D1_D42",
  D1_Naive = "spaceranger/VisiumHD_D1_Naive"
)

out_dir <- "spe"
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Visium HD bin sizes to import
bin_sizes <- c(
  `8um`  = "008",
  `16um` = "016"
)

# -------------------------------------------------------------------------
# Helper functions
# -------------------------------------------------------------------------

get_outs_dir <- function(run_dir) {
  
  run_dir <- normalizePath(run_dir, mustWork = TRUE)
  
  # Allow either the Space Ranger run directory or "outs/" itself as input
  if (dir.exists(file.path(run_dir, "binned_outputs"))) {
    outs_dir <- run_dir
  } else {
    outs_dir <- file.path(run_dir, "outs")
  }
  
  if (!dir.exists(outs_dir)) {
    stop("Could not find Space Ranger outs directory for: ", run_dir)
  }
  
  normalizePath(outs_dir, mustWork = TRUE)
}


make_self_contained <- function(
    spe,
    sample_id,
    resolution,
    representation,
    source_dir
) {
  
  # Materialize the count assay as an ordinary in-memory sparse matrix
  
  counts_current <- SummarizedExperiment::assay(spe, "counts")
  
  if (!inherits(counts_current, "dgCMatrix")) {
    
    counts_sparse <- methods::as(counts_current, "dgCMatrix")
    
    SummarizedExperiment::assay(
      spe,
      "counts",
      withDimnames = FALSE
    ) <- counts_sparse
    
    rm(counts_sparse)
    invisible(gc())
  }
  
  rm(counts_current)

  # Explicitly load image rasters so the saved object does not depend on PNGs.
  # This does not rely on version-specific VisiumIO loadImage support.
  img <- SpatialExperiment::imgData(spe)

  if (nrow(img) == 0L) {
    stop("No image was imported for ", sample_id, " / ", resolution)
  }

  img$data <- lapply(as.list(img$data), function(x) {
    methods::as(x, "LoadedSpatialImage")
  })

  SpatialExperiment::imgData(spe) <- img
  
  # Add standardized sample / representation metadata.
  
  spe$sample_id <- sample_id
  spe$resolution <- resolution
  spe$representation <- representation
  
  md <- S4Vectors::metadata(spe)
  
  resource_fields <- intersect(
    names(md),
    c("resources", "resouces", "spatialList")
  )
  
  if (length(resource_fields) > 0L) {
    md[resource_fields] <- NULL
  }
  
  md$import_provenance <- list(
    source_space_ranger_dir = source_dir,
    sample_id = sample_id,
    resolution = resolution,
    representation = representation,
    counts_storage = "dgCMatrix",
    image_storage = "LoadedSpatialImage"
  )
  
  S4Vectors::metadata(spe) <- md
  
  spe
}


save_spe <- function(
    spe,
    sample_id,
    resolution,
    representation,
    source_dir,
    out_file
) {
  
  spe <- make_self_contained(
    spe = spe,
    sample_id = sample_id,
    resolution = resolution,
    representation = representation,
    source_dir = source_dir
  )
  
  # Check the main assay and images before saving.
  stopifnot(
    inherits(spe, "SpatialExperiment"),
    inherits(
      SummarizedExperiment::assay(spe, "counts", withDimnames = FALSE),
      "dgCMatrix"
    ),
    nrow(SpatialExperiment::spatialCoords(spe)) == ncol(spe),
    ncol(SpatialExperiment::spatialCoords(spe)) == 2L,
    all(is.finite(SpatialExperiment::spatialCoords(spe))),
    all(vapply(
      as.list(SpatialExperiment::imgData(spe)$data),
      function(x) inherits(x, "LoadedSpatialImage"),
      logical(1)
    ))
  )

  saveRDS(
    spe,
    file = out_file
  )

  # The import loops expect both result$summary and result$spe.
  list(
    summary = data.frame(
      sample_id = sample_id,
      resolution = resolution,
      representation = representation,
      n_features = nrow(spe),
      n_observations = ncol(spe),
      rds_size_gib = round(file.info(out_file)$size / 1024^3, 3),
      file = normalizePath(out_file, mustWork = TRUE),
      stringsAsFactors = FALSE
    ),
    spe = spe
  )
}


# -------------------------------------------------------------------------
# Import all samples
# -------------------------------------------------------------------------

summary_list <- list()
summary_index <- 1L

for (sample_id in names(sample_dirs)) {
  
  message("Sample: ", sample_id)
  
  outs_dir <- get_outs_dir(sample_dirs[[sample_id]])
  
  
  # ---------------------------------------------------------------------
  # 8 um and 16 um binned outputs
  # ---------------------------------------------------------------------
  
  for (resolution in names(bin_sizes)) {
    
    bin_size <- bin_sizes[[resolution]]
    
    bin_dir <- file.path(
      outs_dir,
      "binned_outputs",
      paste0("square_", bin_size, "um")
    )
    
    h5_file <- file.path(
      bin_dir,
      "filtered_feature_bc_matrix.h5"
    )
    
    if (!dir.exists(bin_dir)) {
      stop("Missing binned output directory: ", bin_dir)
    }
    
    if (!file.exists(h5_file)) {
      stop("Missing filtered HDF5 matrix: ", h5_file)
    }
    
    message("Importing ", sample_id, " / ", resolution, "...")
    
    # Import from the filtered H5 matrix. make_self_contained() then
    # materializes the sparse counts and loads the image raster before saving.
    spe <- TENxVisiumHD(
      spacerangerOut = outs_dir,
      sample_id = sample_id,
      processing = "filtered",
      format = "h5",
      images = "lowres",
      bin_size = bin_size
    ) |>
      import()
    
    out_file <- file.path(
      out_dir,
      paste0("spe_", sample_id, "_", resolution, ".rds")
    )
    
    result <- save_spe(
      spe = spe,
      sample_id = sample_id,
      resolution = resolution,
      representation = "binned",
      source_dir = outs_dir,
      out_file = out_file
    )
    
    summary_list[[summary_index]] <- result$summary
    summary_index <- summary_index + 1L
    
    spe <- result$spe
    
    message("Saved: ", out_file)
    
    rm(spe, result)
    invisible(gc())
    
  }
  
  
  # ---------------------------------------------------------------------
  # Space Ranger segmented output
  # ---------------------------------------------------------------------
  
  segmented_dir <- file.path(outs_dir, "segmented_outputs")
  
  if (!dir.exists(segmented_dir)) {
    stop("Missing segmented output directory: ", segmented_dir)
  }
  
  segmented_h5 <- file.path(
    segmented_dir,
    "filtered_feature_cell_matrix.h5"
  )
  
  if (!file.exists(segmented_h5)) {
    stop("Missing segmented filtered HDF5 matrix: ", segmented_h5)
  }
  
  message("Importing ", sample_id, " / segmented...")
  
  # Current Space Ranger segmented outputs are naturally imported from H5.
  # The resulting TENxMatrix is then converted to an in-memory dgCMatrix,
  # so the saved RDS is independent of this H5 file. The image raster
  # is also loaded by make_self_contained().
  spe <- TENxVisiumHD(
    segmented_outputs = segmented_dir,
    sample_id = sample_id,
    format = "h5",
    images = "lowres"
  ) |>
    import()
  
  out_file <- file.path(
    out_dir,
    paste0("spe_", sample_id, "_segmented.rds")
  )
  
  result <- save_spe(
    spe = spe,
    sample_id = sample_id,
    resolution = "segmented",
    representation = "segmented",
    source_dir = segmented_dir,
    out_file = out_file
  )
  
  summary_list[[summary_index]] <- result$summary
  summary_index <- summary_index + 1L
  
  spe <- result$spe
  
  message("Saved: ", out_file)
  
  rm(spe, result)
  invisible(gc())
  
}


# -------------------------------------------------------------------------
# Save import summary
# -------------------------------------------------------------------------

import_summary <- do.call(rbind, summary_list)

summary_file <- file.path(out_dir, "import_summary.tsv")
write.table(
  import_summary,
  file = summary_file,
  sep = "\t",
  quote = FALSE,
  row.names = FALSE
)
