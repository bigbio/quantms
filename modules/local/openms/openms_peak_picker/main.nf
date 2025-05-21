process OPENMS_PEAK_PICKER {
    tag "$meta.mzml_id"
    label 'process_low'
    label 'openms'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://ghcr.io/bigbio/openms-tools-thirdparty-sif:2025.04.14' :
        'ghcr.io/bigbio/openms-tools-thirdparty:2025.04.14' }"

    input:
    tuple val(meta), path(mzml_file)

    output:
    tuple val(meta), path("*.mzML"), emit: mzmls_picked
    path "versions.yml", emit: versions
    path "*.log", emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

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
        2>&1 | tee ${mzml_file.baseName}_pp.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        PeakPickerHiRes: \$(PeakPickerHiRes 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
    END_VERSIONS
    """
}
