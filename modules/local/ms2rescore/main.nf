process MS2RESCORE {
    tag "$meta.mzml_id"
    label 'process_high'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
    'https://depot.galaxyproject.org/singularity/quantms-rescoring:0.0.9--pyhdfd78af_0' :
    'biocontainers/quantms-rescoring:0.0.9--pyhdfd78af_0' }"

    // userEmulation settings when docker is specified
    containerOptions = (workflow.containerEngine == 'docker') ? '-u $(id -u) -e "HOME=${HOME}" -v /etc/passwd:/etc/passwd:ro -v /etc/shadow:/etc/shadow:ro -v /etc/group:/etc/group:ro -v $HOME:$HOME' : ''

    input:
    tuple val(meta), path(idxml), path(mzml)

    output:
    tuple val(meta), path("*ms2rescore.idXML") , emit: idxml
    tuple val(meta), path("*.html" )           , optional:true, emit: html
    path "versions.yml"                        , emit: versions
    path "*.log"                               , emit: log

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}_ms2rescore"


    // ms2rescore only supports Da unit. https://ms2rescore.readthedocs.io/en/v3.0.2/userguide/configuration/
    if (meta['fragmentmasstoleranceunit'].toLowerCase().endsWith('da')) {
        ms2_tolerance = meta['fragmentmasstolerance']
    } else {
        log.info "Warning: MS2Rescore only supports Da unit. Set ms2 tolerance in nextflow config!"
        ms2_tolerance = params.ms2rescore_fragment_tolerance
    }

    if (params.decoy_string_position == "prefix") {
        decoy_pattern = "^${params.decoy_string}"
    } else {
        decoy_pattern = "${params.decoy_string}\$"
    }

    if (params.force_model) {
        force_model = "--force_model"
    } else {
        force_model = ""
    }

    """
    rescoring msrescore2feature \\
        --idxml $idxml \\
        --mzml $mzml \\
        --ms2_tolerance $ms2_tolerance \\
        --output ${idxml.baseName}_ms2rescore.idXML \\
        --ms2pip_model_dir ${params.ms2pip_model_dir} \\
        --processes $task.cpus \\
        ${force_model} \\
        $args \\
        2>&1 | tee ${idxml.baseName}_ms2rescore.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        quantms-rescoring: \$(rescoring --version 2>&1 | grep -Eo '[0-9].[0-9].[0-9]')
        ms2pip: \$(ms2pip --version 2>&1 | grep -Eo '[0-9].[0-9].[0-9]')
        deeplc: \$(deeplc --version 2>&1 | grep -Eo '[0-9].[0-9].[0-9]')
        MS2Rescore: \$(ms2rescore --version 2>&1 | grep -Eo '[0-9].[0-9].[0-9]' | head -n 1)
    END_VERSIONS
    """
}
