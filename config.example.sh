#!/usr/bin/env bash
# Copy this file to config.sh, then replace every REPLACE_ME value.
# Do not edit env.sh. All paths are inside the running Linux container unless
# explicitly passed to 00.docker.sh as HOST_* variables.

workdir=/work/myt2t
datadir=/work/data
database=/work/database
scriptsdir=/work/script
threads=10
species=REPLACE_ME_species_prefix

# General assembly settings. GENOME_SIZE is bases (integer), not 146m notation.
GENOME_SIZE=REPLACE_ME_genome_size_bp
PLOIDY=REPLACE_ME_ploidy
KMER_SIZE=21
JELLYFISH_HASH=1G
KMER_HIST_MAX=10000000
CHROMOSOME_COUNT=REPLACE_ME_haploid_chromosome_count
CHROMOSOME_PREFIX=Chr
UNPLACED_PREFIX=unplaced_

# Read files: use absolute container paths with Docker and legacy shell scripts.
ILLUMINA_R1=/work/data/reads_R1.fq.gz
ILLUMINA_R2=/work/data/reads_R2.fq.gz
HIFI_READS=/work/data/hifi.fq.gz
ONT_READS=/work/data/ont.fq.gz
ONT_FASTA=/work/data/ont.fasta
RNASEQ_R1=/work/data/rnaseq_R1.fq.gz
RNASEQ_R2=/work/data/rnaseq_R2.fq.gz
HIC_R1=/work/data/hic_R1.fq.gz
HIC_R2=/work/data/hic_R2.fq.gz

# Assembly stage inputs: point these to the output you want each stage to use.
POLISH_INPUT=/work/myt2t/03.ONT_assembly_nextdenovo/out/03.ctg_graph/nd.asm.fasta
INPUT_CONTIGS=/work/myt2t/05.hifiONT_assembly_hifiasm/hifiONT.fa
SCAFFOLD_CONTIGS=/work/myt2t/07.rmimpurities/genome.final.fa
SCAFFOLD_FASTA=/work/myt2t/08.ChromSyn/ragtag.scaffold.fasta
FINAL_ASSEMBLY=/work/myt2t/10.polish_nextpolish/nextpolish_out/genome.nextpolish.fasta
GAPFILL_MODE=reads
GAPFILL_ASSEMBLY=
GAPFILL_MIN_READS=3
GAPFILL_MIN_MATCH=2000

# Contamination filtering is disabled by default; set the reference to enable it.
CONTAMINANT_FASTA=
CONTAM_IDENTITY=80
CONTAM_COVERAGE=80
ORGANELLE_FASTA=/work/data/cp_mt.fasta
RRNA45S_FASTA=/work/data/45s-rDNA.fa

# Reference evidence. Needed for comparative scaffolding, Liftoff and PASA.
REF_GENOME=
REF_GFF=
LIFTOFF_CHROM_MAP=
CHROMOSOME_MAP=
HOMOLOGY_REFERENCES=/work/data/homology_references.tsv
GEMOMA_JAR=/share/work/biosoft/GeMoMa/GeMoMa-1.9/GeMoMa-1.9.jar
# HOMOLOGY_REFERENCES is TSV without a header: ID, genome FASTA, protein-coding GFF3.
# Add one line per reference species; use paths visible inside the container.

# Hi-C enzyme name accepted by ALLHiC, PreprocessSAMs name, and recognition motif.
HIC_ENZYME=REPLACE_ME_enzyme
HIC_PREPROCESS_ENZYME=REPLACE_ME_enzyme_name
HIC_RE_SITE=REPLACE_ME_recognition_site
VISUALIZER=/share/work/biosoft/3d-dna/visualize/run-assembly-visualizer.sh

# Repeat and functional annotation resources; set taxonomic values for the sample.
REPEAT_TAXON=REPLACE_ME_repeatmasker_taxon
REPEATMASKER_LIB=/share/work/biosoft/RepeatMasker/RepeatMasker/Libraries/RepeatMaskerLib.h5
SPROT_CLEAN=/work/database/maker_repeat/uniprot_sprot_clean.fasta
UNIPROT_FASTA=/work/database/uniprot/uniprot_sprot.fasta
UNIPROT_DIAMOND=/work/database/uniprot/uniprot_sprot.fasta.dmnd
EGGNOG_TAX_SCOPE=REPLACE_ME_eggNOG_taxonomic_scope
BUSCO_LINEAGES='REPLACE_ME_lineage1 REPLACE_ME_lineage2'
BUSCO_PLOT=/work/database/busco_db/generate_plot.py
TRUSTED_TRANSCRIPTS=
EXPORT_TRAINING_SET=0

# Tunable resource and scientific parameters (review against genome and RAM).
NEXTDENOVO_JOBS=2
NEXTPOLISH_JOBS=5
TRINITY_MEMORY=64G
MERYL_MEMORY=24G
MERQURY_K=18
LTR_MUTATION_RATE=7e-9
CENTROMINER=quartet_centrominer.py
CENTROMERE_MIN=100
CENTROMERE_MAX=200
TELOEXPLORER=quartet_teloexplorer.py
TELOMERE_CLADE=plant
RNAMMER_DOMAIN=euk
TRNASCAN_OPTIONS=(-E -G)
ORF_MIN_AA=50
CIRCOS_WINDOW=300000
QUAL_MODULES='stats busco'

# Change these only if tools are installed in different locations in the image.
SOFTWARE_DIR=/share/work/biosoft
REPEATMASKER_DIR=/share/work/biosoft/RepeatMasker/RepeatMasker-4.1.4
TRANSDECODER_UTIL=/share/work/biosoft/TransDecoder/latest/util
GENOMETOOLS_BIN=/share/work/biosoft/genometools/genometools-v1.6.5/bin
RACON=/share/work/biosoft/Racon/latest/build/bin/racon
INTERPROSCAN=/work/database/InterProScan/latest/interproscan.sh
