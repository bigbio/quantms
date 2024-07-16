process MS2RESCORE {
    tag "$meta.mzml_id"
    label 'process_high'

    conda "bioconda::ms2rescore=3.0.3 bioconda::psm-utils=0.8.0 conda-forge::pydantic=1.10 pygam=0.9.1"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/ms2rescore:3.0.3--pyhdfd78af_0':
        'biocontainers/ms2rescore:3.0.3--pyhdfd78af_0' }"

    // userEmulation settings when docker is specified
    containerOptions = (workflow.containerEngine == 'docker') ? '-u $(id -u) -e "HOME=${HOME}" -v /etc/passwd:/etc/passwd:ro -v /etc/shadow:/etc/shadow:ro -v /etc/group:/etc/group:ro -v $HOME:$HOME' : ''

    input:
    tuple val(meta), path(idxml), path(mzml)

    output:
    tuple val(meta), path("*ms2rescore.idXML") , emit: idxml
    tuple val(meta), path("*feature_names.tsv"), emit: feature_names
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
        ms2_tolerence = meta['fragmentmasstolerance']
    } else {
        log.info "Warning: MS2Rescore only supports Da unit. Set default ms2 tolerance as 0.02!"
        ms2_tolerence = 0.02
    }

    if (params.decoy_string_position == "prefix") {
        decoy_pattern = "^${params.decoy_string}"
    } else {
        decoy_pattern = "${params.decoy_string}\$"
    }

    """
    ms2rescore_cli.py \\
        --psm_file $idxml \\
        --spectrum_path . \\
        --ms2_tolerance $ms2_tolerence \\
        --output_path ${idxml.baseName}_ms2rescore.idXML \\
        --ms2pip_model_dir ${params.ms2pip_model_dir} \\
        --processes $task.cpus \\
        --id_decoy_pattern $decoy_pattern \\
        $args \\
        2>&1 | tee ${meta.mzml_id}_ms2rescore.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        MS2Rescore: \$(echo \$(ms2rescore --version 2>&1) | grep -oP 'MS²Rescore \\(v\\K[^\\)]+' )
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.mzml_id}_ms2rescore"

    """
    touch ${prefix}.idXML

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        MS2Rescore: \$(echo \$(ms2rescore --version 2>&1) | grep -oP 'MS²Rescore \\(v\\K[^\\)]+' )
    END_VERSIONS
    """
}
