// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process PERCOLATOR {
    label 'process_medium'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "bioconda::bumbershoot bioconda::comet-ms bioconda::crux-toolkit=3.2 bioconda::fido=1.0 conda-forge::gnuplot bioconda::luciphor2=2020_04_03 bioconda::msgf_plus=2021.03.22 openms::openms=2.7.0pre bioconda::pepnovo=20101117 bioconda::percolator=3.5 bioconda::sirius-csifingerid=4.0.1
bioconda::thermorawfileparser=1.3.4 bioconda::xtandem=15.12.15.2 openms::openms-thirdparty=2.7.0pre" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/openms-thirdparty:2.6.0--0"
    } else {
        container "quay.io/biocontainers/openms-thirdparty:2.6.0--0"
    }

    input:
    tuple val(meta), path(id_file)

    output:
    tuple val(meta), path("${id_file.baseName}_perc.idXML"), val("MS:1001491"), emit: id_files_perc
    path "*.version.txt", emit: version
    path "*.log", emit: log

    script:
    def software = getSoftwareName(task.process)

    """
    OMP_NUM_THREADS=$task.cpus PercolatorAdapter \\
        -in ${id_file} \\
        -out ${id_file.baseName}_perc.idXML \\
        -threads $task.cpus \\
        -subset_max_train $params.subset_max_train \\
        -decoy_pattern $params.decoy_string \\
        -post_processing_tdc \\
        -score_type pep \\
        $options.args \\
        > ${id_file.baseName}_percolator.log

    echo \$(PercolatorAdapter 2>&1) > percolatoradapter.version.txt
    percolator -h &> percolator.version.txt

    """
}
