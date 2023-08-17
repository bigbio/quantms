
process TDF2MZML {
    tag "$meta.mzml_id"
    label 'process_low'
    label 'process_single'
    label 'error_retry'

    // for rawfileparser this is conda "conda-forge::mono bioconda::thermorawfileparser=1.3.4"
    // conda is not enabled for DIA so ... disabling anyway

    // container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    //    'https://depot.galaxyproject.org/singularity/thermorawfileparser:1.3.4--ha8f3691_0' :
    //    'quay.io/biocontainers/thermorawfileparser:1.3.4--ha8f3691_0' }"
    container 'mfreitas/tdf2mzml:latest' // I don't know which stable tag to use...

    stageInMode {
        if (task.attempt == 1) {
            if (executor == "awsbatch") {
                'symlink'
            } else {
                'link'
            }
        } else if (task.attempt == 2) {
            if (executor == "awsbatch") {
                'copy'
            } else {
                'symlink'
            }
        } else {
            'copy'
        }
    }

    input:
    tuple val(meta), path(rawfile)

    output:
    tuple val(meta), path("*.mzML"), emit: mzmls_converted
    tuple val(meta), path("*.d"),   emit: dotd_files
    path "versions.yml",   emit: version
    path "*.log",   emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}"

    """
    echo "Converting..." | tee --append ${rawfile.baseName}_conversion.log
    tdf2mzml.py -i *.d 2>&1 | tee --append ${rawfile.baseName}_conversion.log
    mv *.mzml ${file(rawfile.baseName).baseName}.mzML
    mv *.d ${file(rawfile.baseName).baseName}.d

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        tdf2mzml.py: \$(tdf2mzml.py --version)
    END_VERSIONS
    """
}
