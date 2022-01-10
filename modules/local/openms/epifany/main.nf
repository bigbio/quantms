// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process EPIFANY {
    label 'process_medium'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "bioconda::bumbershoot bioconda::comet-ms bioconda::crux-toolkit=3.2 bioconda::fido=1.0 conda-forge::gnuplot bioconda::luciphor2=2020_04_03 bioconda::msgf_plus=2021.03.22 bioconda::openms=2.7.0 bioconda::pepnovo=20101117 bioconda::percolator=3.5 bioconda::sirius-csifingerid=4.0.1 bioconda::thermorawfileparser=1.3.4 bioconda::xtandem=15.12.15.2 bioconda::openms-thirdparty=2.7.0" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/openms-thirdparty:2.7.0--h9ee0642_1"
    } else {
        container "quay.io/biocontainers/openms-thirdparty:2.7.0--h9ee0642_1"
    }

    input:
    tuple val(meta), path(consus_file)

    output:
    tuple val(meta), path("${consus_file.baseName}_epi.consensusXML"), emit: epi_inference
    path "*.version.txt", emit: version
    path "*.log", emit: log

    script:
    def software = getSoftwareName(task.process)

    """
    Epifany \\
        -in ${consus_file} \\
        -protein_fdr true \\
        -threads $task.cpus \\
        -debug 100 \\
        -algorithm:keep_best_PSM_only $params.keep_best_PSM_only \\
        -algorithm:update_PSM_probabilities $params.update_PSM_probabilities \\
        -greedy_group_resolution $params.greedy_group_resolution \\
        -algorithm:top_PSMs $params.top_PSMs \\
        -out ${consus_file.baseName}_epi.consensusXML \\
        > ${consus_file.baseName}_inference.log

    echo \$(Epifany 2>&1) > ${software}.version.txt
    """
}
