process TDF2MZML {
    tag "$meta.mzml_id"
    label 'process_single'
    label 'error_retry'

    container 'quay.io/bigbio/tdf2mzml:latest' // Switch to latest tag in bigbio

    input:
    tuple val(meta), path(rawfile)

    output:
    tuple val(meta), path("*.mzML"), emit: mzmls_converted
    tuple val(meta), path("*.d"),   emit: dotd_files
    path "versions.yml",   emit: versions
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
