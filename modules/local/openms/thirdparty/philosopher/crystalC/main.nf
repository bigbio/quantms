process CRYSTALC {
    label 'process_low'

    container = 'tillenglert/oopenms:latest'

    input:
    tuple val(meta), file(mzml_file), file(pepXML), file(database)

    output:
    tuple val(meta), path("${mzml_file.baseName}_c.pepXML"), emit: pepxml_file_crystalc
    path "versions.yml",   emit: version
    path "*.log",   emit: log

    script:
    def args = task.ext.args ?: ''

    """
    echo "
    thread = -1
    fasta = $database
    raw_file_location = \$PWD
    raw_file_extension = mzML
    output_location = \$PWD

    precursor_charge = 1 6
    isotope_number = 3
    precursor_mass = 20.0
    precursor_isolation_window = 0.7
    correct_isotope_error = false
    " > crystalc.params

    java -Xmx53G -cp "/thirdparty/CrystalC/CrystalC-1.4.2.jar" crystalc.Run crystalc.params $pepXML |& tee ${mzml_file.baseName}_crystalc.log

    
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        CrystalC: 1.4.2
    END_VERSIONS
    """
}
