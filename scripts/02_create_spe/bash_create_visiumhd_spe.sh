#!/bin/bash -l

#$ -P weberlab
#$ -N create_spe
#$ -pe omp 8
#$ -l mem_per_core=8G
#$ -l h_rt=12:00:00
#$ -cwd
#$ -j y

set -euo pipefail

module purge
module load gcc

# modules needed for 'sf' and related packages
module load udunits
module load gdal/3.11.5
module load proj/9.7.1
module load sqlite3/3.44.2
module load geos

# -------------------------------------------------------------------------
# Project directories
# -------------------------------------------------------------------------

PROJECT_DIR="/projectnb/jonesgrp/2026_06_25_JonesD_Visium"
SCRIPT_DIR="$PROJECT_DIR/scripts"
SPACERANGER_DIR="$PROJECT_DIR/spaceranger"
SPE_DIR="$PROJECT_DIR/spe"

R_SCRIPT="$SCRIPT_DIR/create_visiumhd_spe.R"
WORKAROUND_R_SCRIPT="$SCRIPT_DIR/fix_arrow_sf_VisiumIO.R"

# -------------------------------------------------------------------------
# R installation
# -------------------------------------------------------------------------

R_BIN="$HOME/software/R/4.6.1/bin"
export PATH="$R_BIN:$PATH"

# -------------------------------------------------------------------------
# Run
# -------------------------------------------------------------------------

mkdir -p "$SPE_DIR"

"$R_BIN/Rscript" --version

export R_SCRIPT
export WORKAROUND_R_SCRIPT

# run from project root directory
cd "$PROJECT_DIR"

"$R_BIN/Rscript" -e '
library(VisiumIO)
source(Sys.getenv("WORKAROUND_R_SCRIPT"))
source(Sys.getenv("R_SCRIPT"))
'
