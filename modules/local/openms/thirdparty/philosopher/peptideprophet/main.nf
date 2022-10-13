process PEPTIDEPROPHET {
    label 'process_low'

    container = 'prvst/philosopher:latest'

    input:
    tuple val(meta), file(pepXML_file), file(database)

    output:
    tuple val(meta), path("${pepXML_file.baseName}_psm.tsv"),  emit: psm_philosopher
    path "versions.yml",   emit: version
    path "*.log",   emit: log

    script:
    def args = task.ext.args ?: ''

    """
    echo "------------Workspace init------------" >> ${pepXML_file.baseName}_peptideprophet.log
    philosopher workspace --clean >> ${pepXML_file.baseName}_peptideprophet.log
    philosopher workspace --init >> ${pepXML_file.baseName}_peptideprophet.log
    echo "------------Read Database-------------" >> ${pepXML_file.baseName}_peptideprophet.log
    philosopher database --custom ${database} >> ${pepXML_file.baseName}_peptideprophet.log
    echo "--------------Read File--------------" >> ${pepXML_file.baseName}_peptideprophet.log
    philosopher peptideprophet --database ${database} --ppm --accmass --expectscore --decoyprobs --decoy ${params.decoy_string} --nonparam ${pepXML_file} >> ${pepXML_file.baseName}_peptideprophet.log
    echo "\n------------Postprocess------------" >> ${pepXML_file.baseName}_peptideprophet.log
    philosopher filter --pepxml "interact-${pepXML_file.baseName}.pep.xml" --tag ${params.decoy_string} >> ${pepXML_file.baseName}_peptideprophet.log
    philosopher report >> ${pepXML_file.baseName}_peptideprophet.log    // isotope error
    mv psm.tsv ${pepXML_file.baseName}_psm.tsv

cat <<-END_VERSIONS > versions.yml
"${task.process}":
    Philosopher: \$(philosopher version 2>&1 | grep -E '* version=v*' | sed 's/.*version=v//g')
END_VERSIONS
    """
}
