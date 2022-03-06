process OPENMSPEAKPICKER {
    tag "$meta.id"
    label 'process_low'

    conda (params.enable_conda ? "openms::openms=2.8.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/openms-thirdparty:2.8.0--h9ee0642_0' :
        'quay.io/biocontainers/openms-thirdparty:2.8.0--h9ee0642_0' }"

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
        > ${mzml_file.baseName}_pp.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        PeakPickerHiRes: \$(PeakPickerHiRes 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g')
    END_VERSIONS
    """
}
