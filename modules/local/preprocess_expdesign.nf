// Fixing file endings only necessary if the experimental design is user-specified
// TODO can we combine this with another step? Feels like a waste to spawn a worker for this.
// Maybe the renaming can be done in the rawfileconversion step? Or check if the OpenMS tools
// accept different file endings already?
process PREPROCESS_EXPDESIGN {
    tag "$design.Name"
    label 'process_low'

    conda "bioconda::sdrf-pipelines=0.0.26"
    if (workflow.containerEngine == 'singularity' && !params.singularity_pull_docker_container) {
        container "https://depot.galaxyproject.org/singularity/sdrf-pipelines:0.0.26--pyhdfd78af_0"
    } else {
        container "biocontainers/sdrf-pipelines:0.0.26--pyhdfd78af_0"
    }

    input:
    path design

    output:
    path "${design.baseName}_openms_design.tsv", emit: ch_expdesign
    path "${design.baseName}_config.tsv", emit: ch_config
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    # since we know that we will need to convert from raw to mzML for all tools that need the design (i.e., OpenMS tools)
    # we edit the design here and change the endings.
    sed 's/.raw\\t/.mzML\\t/I' ${design} > ${design.baseName}_openms_design.tsv

    # here we extract the filenames and fake an empty config (since the config values will be deduced from the workflow params)
    a=\$(grep -n '^\$' ${design} | head -n 1 | awk -F ":" '{print \$1}')
    sed -e ''"\${a}"',\$d' ${design} > ${design.baseName}_config.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sdrf-pipelines: \$(parse_sdrf --version 2>&1 | awk -F ' ' '{print \$2}')
    END_VERSIONS
    """
}
