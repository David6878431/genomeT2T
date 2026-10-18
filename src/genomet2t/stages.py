from dataclasses import dataclass


@dataclass(frozen=True)
class Stage:
    name: str
    script: str
    description: str
    image: str = "assembly"
    args: tuple[str, ...] = ()
    required: tuple[str, ...] = ()


STAGES = (
    Stage("kmer", "01.Kmer.sh", "Jellyfish / GenomeScope", required=("ILLUMINA_R1", "ILLUMINA_R2", "PLOIDY")),
    Stage("hifi", "02.hifi_assembly_hifiasm.sh", "HiFi assembly", required=("HIFI_READS",)),
    Stage("ont", "03.ONT_assembly_nextdenovo.sh", "ONT assembly", required=("ONT_READS", "GENOME_SIZE")),
    Stage("ont-polish", "04.ONT_polish_nextpolish.sh", "ONT NextPolish", required=("HIFI_READS", "ONT_READS", "ILLUMINA_R1", "ILLUMINA_R2")),
    Stage("hybrid", "05.hifiONT_assembly_hifiasm.sh", "HiFi + ONT assembly", required=("HIFI_READS", "ONT_READS")),
    Stage("merge", "06.merge_ragtag.sh", "Compare / merge existing assemblies"),
    Stage("filter", "07.rmimpurities.sh", "Optional contamination screening", required=("INPUT_CONTIGS",)),
    Stage("scaffold", "08.ChromSyn.sh", "Reference-guided scaffolding", required=("REF_GENOME", "SCAFFOLD_CONTIGS", "CHROMOSOME_COUNT")),
    Stage("hic-prepare", "08.Chromhic.sh", "Prepare Hi-C / Juicebox", args=("prepare",), required=("CHROMOSOME_COUNT", "SCAFFOLD_CONTIGS", "HIC_R1", "HIC_R2", "HIC_ENZYME", "HIC_PREPROCESS_ENZYME", "HIC_RE_SITE", "VISUALIZER")),
    Stage("hic-finalize", "08.Chromhic.sh", "Finalize after manual Juicebox review", args=("finalize",), required=("CHROMOSOME_COUNT", "CHROMOSOME_MAP")),
    Stage("gapfill", "09.gapfill.sh", "Gap filling", required=("SCAFFOLD_FASTA", "GAPFILL_MODE")),
    Stage("polish", "10.polish_nextpolish.sh", "Final NextPolish", required=("HIFI_READS", "POLISH_INPUT")),
    Stage("centromere", "11.Centromere.sh", "Centromere candidates", required=("FINAL_ASSEMBLY",)),
    Stage("telomere", "12.Telomere.sh", "Telomere detection", required=("FINAL_ASSEMBLY", "TELOMERE_CLADE")),
    Stage("assess", "13.qualAssess.sh", "Selected assembly quality modules", required=("FINAL_ASSEMBLY", "QUAL_MODULES")),
    Stage("repeats", "14.Repeat.sh", "Repeat annotation (requires LAI outputs)", "annotation", required=("FINAL_ASSEMBLY", "REPEAT_TAXON", "REPEATMASKER_LIB", "SPROT_CLEAN")),
    Stage("ncrna", "15.ncRNA.sh", "ncRNA annotation", "annotation", required=("RNAMMER_DOMAIN", "TRNASCAN_OPTIONS")),
    Stage("gemoma", "16.GeMoMa.sh", "Multi-reference gene prediction", "annotation", required=("HOMOLOGY_REFERENCES", "GEMOMA_JAR")),
    Stage("liftoff", "17.liftoff.sh", "Reference annotation transfer", "annotation", required=("REF_GENOME", "REF_GFF")),
    Stage("pasa", "18.PASA.sh", "RNA-seq / PASA evidence", "annotation", required=("RNASEQ_R1", "RNASEQ_R2")),
    Stage("evm", "19.EVM.sh", "Integrate annotation evidence", "annotation"),
    Stage("pasa-update", "20.PASA_update.sh", "Update and filter gene models", "annotation", required=("species",)),
    Stage("function", "21.genefunction.sh", "Functional annotation", "annotation", required=("UNIPROT_FASTA", "EGGNOG_TAX_SCOPE", "INTERPROSCAN")),
    Stage("circos", "22.MCScanX_circos.sh", "MCScanX / Circos", "annotation"),
    Stage("gene-stats", "23.gene_stat.sh", "Gene model statistics", "annotation", required=("species",)),
    Stage("busco", "24.BUSCO.sh", "Protein BUSCO assessment", "annotation", required=("BUSCO_LINEAGES", "BUSCO_PLOT")),
)


def get_stage(name: str) -> Stage:
    for stage in STAGES:
        if stage.name == name:
            return stage
    raise ValueError(f"Unknown stage {name!r}; use 'genomet2t stages' to list stages.")
