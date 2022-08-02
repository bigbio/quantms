process PEPTIDEPROPHET {
    tag "$meta.phil_psm"
    label 'process_low'

    input:
    tuple val(meta), file(pepXML_file), file(database)

    output:
    tuple val(meta), path("${pepXML_file.baseName}_psm.tsv"),  emit: psm_philosopher
    path "versions.yml",   emit: version
    path "*.log",   emit: log

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    echo "------------Workspace init------------" >> ${pepXML.baseName}_peptideprophet.log
    philosopher workspace --clean >> ${pepXML.baseName}_peptideprophet.log
    philosopher workspace --init >> ${pepXML.baseName}_peptideprophet.log
    echo "------------Read Database-------------" >> ${pepXML.baseName}_peptideprophet.log
    philosopher database --custom ${database} >> ${pepXML.baseName}_peptideprophet.log
    echo "--------------Read File--------------" >> ${pepXML.baseName}_peptideprophet.log
    philosopher peptideprophet --database ${database} --ppm --accmass --expectscore --decoyprobs --nonparam ${pepXML} >> ${pepXML.baseName}_peptideprophet.log
    echo "\n------------Postprocess------------" >> ${pepXML.baseName}_peptideprophet.log
    philosopher filter --pepxml "interact-${pepXML.baseName}.pep.xml" --tag ${params.decoy_affix} >> ${pepXML.baseName}_peptideprophet.log
    philosopher report >> ${pepXML.baseName}_peptideprophet.log
    mv psm.tsv ${pepXML.baseName}_psm.tsv
    """
}
