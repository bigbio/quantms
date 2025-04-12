process INDEXPEPTIDES {
    tag "$meta.mzml_id"
    label 'process_low'
    label 'openms'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:3.3.0--h9ee0642_8' :
        'biocontainers/openms-thirdparty:3.3.0--h9ee0642_8' }"

    input:
    tuple val(meta), path(id_file), path(database)


    output:
    tuple val(meta), path("${id_file.baseName}_idx.idXML"), emit: id_files_idx
    path "versions.yml", emit: versions
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

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
        $args \\
        2>&1 | tee ${id_file.baseName}_index_peptides.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        PeptideIndexer: \$(PeptideIndexer 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
