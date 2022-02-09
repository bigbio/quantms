// Import generic module functions
include { initOptions; saveFiles; getSoftwareName } from './functions'

params.options = [:]
options        = initOptions(params.options)

process INDEXPEPTIDES {
    label 'process_low'
    publishDir "${params.outdir}",
        mode: params.publish_dir_mode,
        saveAs: { filename -> saveFiles(filename:filename, options:params.options, publish_dir:getSoftwareName(task.process), meta:[:], publish_by_meta:[]) }

    conda (params.enable_conda ? "openms::openms=2.8.0.dev" : null)
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/openms-thirdparty:2.7.0--h9ee0642_1"
    } else {
        container "quay.io/biocontainers/openms-thirdparty:2.7.0--h9ee0642_1"
    }

    input:
    tuple val(meta), path(id_file), path(database)


    output:
    tuple val(meta), path("${id_file.baseName}_idx.idXML"), emit: id_files_idx
    path "*.version.txt", emit: version
    path "*.log", emit: log

    script:
    def software = getSoftwareName(task.process)

    enzyme = meta.enzyme
    // see comment in CometAdapter. Alternative here in PeptideIndexer is to let it auto-detect the enzyme by not specifying.
    if (params.search_engines.contains("msgf"))
    {
        if (meta.enzyme == 'Trypsin') enzyme = 'Trypsin/P'
        else if (meta.enzyme == 'Arg-C') enzyme = 'Arg-C/P'
        else if (meta.enzyme == 'Asp-N') enzyme = 'Asp-N/B'
        else if (meta.enzyme == 'Chymotrypsin') enzyme = 'Chymotrypsin/P'
        else if (meta.enzyme == 'Lys-C') enzyme = 'Lys-C/P'
    }
    if (meta.enzyme == "unspecific cleavage")
    {
        params.num_enzyme_termini = "none"
    }
    num_enzyme_termini = params.num_enzyme_termini
    if (params.num_enzyme_termini == "fully")
    {
        num_enzyme_termini = "full"
    }
    def il = params.IL_equivalent ? '-IL_equivalent' : ''
    def allow_um = params.allow_unmatched ? '-allow_unmatched' : ''

    """
    PeptideIndexer \\
        -in ${id_file} \\
        -out ${id_file.baseName}_idx.idXML \\
        -threads $task.cpus \\
        -fasta ${database} \\
        -enzyme:name "${enzyme}" \\
        -enzyme:specificity ${num_enzyme_termini} \\
        ${il} \\
        ${allow_um} \\
        $options.args \\
        > ${id_file.baseName}_index_peptides.log

    echo \$(PeptideIndexer 2>&1) > ${software}.version.txt
    """
}
