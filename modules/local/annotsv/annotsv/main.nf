process ANNOTSV_ANNOTSV {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/16/1695a6ee48c649aa10ad42526b3af6e8ed9e3221d23b39abebcb62271ba13079/data' :
        'community.wave.seqera.io/library/annotsv:3.5.8--a24f79b3f422fbe8' }"

    // Container options are needed to allow AnnotSV to overwrite a file in a dependency directory in Singularity
    containerOptions "${ workflow.containerEngine == 'singularity' ? '--writable-tmpfs' : ''}"

    input:
    tuple val(meta), path(sv_vcf), path(sv_vcf_index), path(candidate_small_variants)
    tuple val(meta2), path(annotations)
    tuple val(meta3), path(candidate_genes)
    tuple val(meta4), path(false_positive_snv)
    tuple val(meta5), path(gene_transcripts)
    val genome

    output:
    tuple val(meta), path("*.tsv")            , emit: tsv
    tuple val(meta), path("*.unannotated.tsv"), emit: unannotated_tsv, optional: true
    tuple val(meta), path("*.vcf")            , emit: vcf            , optional: true
    tuple val("${task.process}"), val('annotsv'), eval("AnnotSV --version | sed 's/AnnotSV //'"), emit: versions_annotsv, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    def cand_genes     = candidate_genes          ? "-candidateGenesFile ${candidate_genes}"              : ""
    def small_variants = candidate_small_variants ? "-candidateSnvIndelFiles ${candidate_small_variants}" : ""
    def fp_snv         = false_positive_snv       ? "-snvIndelFiles ${false_positive_snv}"                : ""
    def transcripts    = gene_transcripts         ? "-txFile ${gene_transcripts}"                         : ""

    """
    # Close all extra file descriptors in the current shell
    exec 3>&- 2>/dev/null || true
    exec 4>&- 2>/dev/null || true
    exec 5>&- 2>/dev/null || true
    exec 6>&- 2>/dev/null || true
    exec 7>&- 2>/dev/null || true
    exec 8>&- 2>/dev/null || true
    exec 9>&- 2>/dev/null || true
    
    # Redirect stdin
    exec 0</dev/null


    AnnotSV \\
        -genomeBuild ${genome} \\
        -annotationsDir ${annotations} \\
        ${cand_genes} \\
        ${small_variants} \\
        ${fp_snv} \\
        ${transcripts} \\
        ${args} \\
        -outputFile ${prefix}.tsv \\
        -SVinputFile ${sv_vcf} 

    mv *_AnnotSV/* .
    """

    stub:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    def create_vcf = args.contains("-vcf 1") ? "touch ${prefix}.vcf" : ""

    """
    touch ${prefix}.tsv
    touch ${prefix}.unannotated.tsv
    ${create_vcf}
    """
}
