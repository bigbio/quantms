process OPENMSPEAKPICKER {
    tag "$meta.id"
    label 'process_low'

    conda (params.enable_conda ? "bioconda::openms=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://ftp.pride.ebi.ac.uk/pub/databases/pride/resources/tools/ghcr.io-openms-openms-executables-latest.img' :
        'ghcr.io/openms/openms-executables:latest' }"

    input:
    tuple val(meta), path(mzml_file)

    output:
    tuple val(meta), path("*.mzML"), emit: mzmls_picked
    path "versions.yml", emit: version
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    in_mem = params.peakpicking_inmemory ? "inmermory" : "lowmemory"
    lvls = params.peakpicking_ms_levels ? "-algorithm:ms_levels ${params.peakpicking_ms_levels}" : ""

    """
    PeakPickerHiRes \\
        -in ${mzml_file} \\
        -out ${mzml_file.baseName}.mzML \\
        -threads $task.cpus \\
        -debug $params.pp_debug \\
        -processOption ${in_mem} \\
        ${lvls} \\
        $args \\
        |& tee ${mzml_file.baseName}_pp.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        PeakPickerHiRes: \$(PeakPickerHiRes 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g')
    END_VERSIONS
    """
}
