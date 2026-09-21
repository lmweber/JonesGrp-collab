# -------------------------------------------------------------------------
# Workaround for arrow open_dataset() / sf conflict in VisiumIO
# -------------------------------------------------------------------------

.parquet_colnames <- function(resource) {
  reader <- arrow::ParquetFileReader$create(
    BiocGenerics::path(resource)
  )
  names(reader$GetSchema())
}


TENxSpatialParquet_fixed <- function(resource, colnames) {
  
  if (!methods::is(resource, "TENxFile")) {
    resource <- TENxIO::TENxFile(resource)
  }
  
  cnames <- .parquet_colnames(resource)
  
  if (missing(colnames)) {
    colnames <- cnames
  }
  
  if (!all(colnames %in% cnames)) {
    warning(
      "The provided column names do not match all in the Parquet file.",
      call. = FALSE
    )
    colnames <- intersect(colnames, cnames)
  }
  
  constructor <- getFromNamespace(
    ".TENxSpatialParquet",
    "VisiumIO"
  )
  
  constructor(
    resource,
    colnames = colnames
  )
}


TENxMappingParquet_fixed <- function(
    resource,
    colnames = c(
      "square_002um",
      "square_008um",
      "square_016um",
      "cell_id",
      "in_nucleus",
      "in_cell"
    )
) {
  
  if (!methods::is(resource, "TENxFile")) {
    resource <- TENxIO::TENxFile(resource)
  }
  
  cnames <- .parquet_colnames(resource)
  
  if (!all(colnames %in% cnames)) {
    warning(
      "The provided column names do not match all in the Parquet file.",
      call. = FALSE
    )
    colnames <- intersect(colnames, cnames)
  }
  
  constructor <- getFromNamespace(
    ".TENxMappingParquet",
    "VisiumIO"
  )
  
  constructor(
    resource,
    colnames = colnames
  )
}


assignInNamespace(
  "TENxSpatialParquet",
  TENxSpatialParquet_fixed,
  ns = "VisiumIO"
)

assignInNamespace(
  "TENxMappingParquet",
  TENxMappingParquet_fixed,
  ns = "VisiumIO"
)
