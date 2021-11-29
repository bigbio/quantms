// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process MZMLINDEXING {
    tag "$meta.id"
    label 'process_low'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:meta, publish_by_meta:['id']) }

    conda (params.enable_conda ? "bioconda::bumbershoot bioconda::comet-ms bioconda::crux-toolkit=3.2 bioconda::fido=1.0 conda-forge::gnuplot bioconda::luciphor2 =2020_04_03 bioconda::msgf_plus=2021.03.22 openms::openms=2.7.0pre bioconda::pepnovo=20101117 bioconda::percolator=3.5 bioconda::sirius-csifingerid=4.0.1
bioconda::thermorawfileparser=1.3.4 bioconda::xtandem=15.12.15.2 openms::openms-thirdparty=2.7.0pre" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        // TODO Need to built single container
        container "https://ftp.pride.ebi.ac.uk/pride/data/tools/quantms-dev.sif"
    } else {
        // TODO Need to built single container
        container "quay.io/bigbio/quantms:dev"
    }

    input:
    tuple val(meta), path(mzmlfile)

    output:
    tuple val(meta), path("out/*.mzML"), emit: mzmls_indexed
    path "*.version.txt", emit: version
    path "*.log", emit: log

    script:
    def software = getSoftwareName(task.process)
    """
    mkdir out
    FileConverter -in ${mzmlfile} -out out/${mzmlfile.baseName}.mzML > ${mzmlfile.baseName}_mzmlindexing.log

    echo \$(FileConverter 2>&1) > fileconverter.version.txt
    """
}
