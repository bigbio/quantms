process DELTAMASSHISTOGRAM {
    label 'process_low'

    input:
    tuple val(meta), file(mzml_file), file(globalmod)

    output:
    path "${mzml_file.baseName}_delta-mass.html", emit: delta_mass_histo
    path "versions.yml",   emit: version
    path "*.log",   emit: log

    script:
    def args = task.ext.args ?: ''

    // install mpld3 in quantms container instead of process
    """
    pip install mpld3

    Delta_Mass_Hist.py -i $globalmod -o ${mzml_file.baseName}_delta-mass.html |& tee delta_mass_hist.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Python: \$(python3 --version 2>&1 | sed 's/Python //g')
    END_VERSIONS
    """
}
