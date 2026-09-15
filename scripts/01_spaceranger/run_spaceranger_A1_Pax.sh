#!/bin/bash -l

# ========================================
# SGE settings
# ========================================

#$ -P weberlab
#$ -N spcrng_A1_Pax
#$ -pe omp 8
#$ -l mem_per_core=8G
#$ -l h_rt=48:00:00

set -euo pipefail


# ========================================
# Space Ranger installation
# ========================================

export PATH="$HOME/software/spaceranger-4.1.0:$PATH"

echo "Space Ranger version:"
spaceranger --version


# ========================================
# Space Ranger settings and paths
# ========================================

AREA="A1"

SAMPLE="2026-04_A1_Pax"

# Name for the Space Ranger output directory
RUN_ID="VisiumHD_A1_Pax"

FASTQ_DIR="/projectnb/jonesgrp/2026_06_25_JonesD_Visium/samples/A1_Pax/fastq"

TRANSCRIPTOME="/projectnb/jonesgrp/references/refdata-gex-mm10-2020-A"

PROBE_SET="$HOME/software/spaceranger-4.1.0/probe_sets/Visium_Mouse_Transcriptome_Probe_Set_v2.0_mm10-2020-A.csv"

# not needed if spaceranger has internet access
SLIDEFILE="/projectnb/jonesgrp/2026_06_25_JonesD_Visium/slidefiles/H1-3M26FH4.vlf"

SLIDE="H1-3M26FH4"

CYTAIMAGE="/projectnb/jonesgrp/2026_06_25_JonesD_Visium/Mazzilli_PID_2026_04_Jones_Lab/CyAssist_run1_04302026/CAVG10202_2026-05-01_14-25-47_2026-04-2026-5-1_H1-3M26FH4_A1_Pax.tif"

IMAGE="/projectnb/jonesgrp/2026_06_25_JonesD_Visium/Mazzilli_PID_2026_04_Jones_Lab/CyAssist_run1_04302026/HighRes_H&E/MCAP/Scan1/MCAP_Scan1.qptiff"

OUTPUT_DIR="/projectnb/jonesgrp/2026_06_25_JonesD_Visium/spaceranger"


# ========================================
# Run Space Ranger
# ========================================

mkdir -p "${OUTPUT_DIR}"
cd "${OUTPUT_DIR}"

spaceranger count \
    --id="${RUN_ID}" \
    --transcriptome="${TRANSCRIPTOME}" \
    --fastqs="${FASTQ_DIR}" \
    --sample="${SAMPLE}" \
    --probe-set="${PROBE_SET}" \
    --slide="${SLIDE}" \
    --slidefile="${SLIDEFILE}" \
    --area="${AREA}" \
    --cytaimage="${CYTAIMAGE}" \
    --image="${IMAGE}" \
    --create-bam=false \
    --disable-cell-annotation \
    --localcores="${NSLOTS}" \
    --localmem=64
