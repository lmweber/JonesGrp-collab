#!/bin/bash -l

# ========================================
# SGE settings
# ========================================

#$ -P weberlab
#$ -N spcrng_A1
#$ -pe omp 8
#$ -l mem_per_core=8G
#$ -l h_rt=48:00:00


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

SAMPLE="2026-04_A1_Vax"

# Name for the Space Ranger output directory
RUN_ID="VisiumHD_A1"

FASTQ_DIR="/projectnb/jonesgrp/2026_06_25_JonesD_Visium/samples/A1_Vax/fastq"

TRANSCRIPTOME="/projectnb/jonesgrp/references/refdata-gex-mm10-2020-A"

PROBE_SET="$HOME/software/spaceranger-4.1.0/probe_sets/Visium_Mouse_Transcriptome_Probe_Set_v2.0_mm10-2020-A.csv"

# not needed if spaceranger has internet access
# SLIDEFILE="/path/to/H1-96R39RW.vlf"

SLIDE="H1-96R39RW"

CYTAIMAGE="/projectnb/jonesgrp/2026_06_25_JonesD_Visium/Mazzilli_PID_2026_04_Jones_Lab/CytAssist Run 2_6-5-2026/CAVG10202_2026-06-05_13-58-49_2026-04-6-5-2026_H1-96R39RW_A1_Vax.tif"

IMAGE="/projectnb/jonesgrp/2026_06_25_JonesD_Visium/Mazzilli_PID_2026_04_Jones_Lab/CytAssist Run 2_6-5-2026/HighResHE/Vax TDLN/Scan2/Vax TDLN_Scan2.qptiff"

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
    --area="${AREA}" \
    --cytaimage="${CYTAIMAGE}" \
    --image="${IMAGE}" \
    --create-bam=false \
    --disable-cell-annotation \
    --localcores="${NSLOTS}" \
    --localmem=64
