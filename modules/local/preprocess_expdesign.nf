// Fixing file endings only necessary if the experimental design is user-specified
// TODO can we combine this with another step? Feels like a waste to spawn a worker for this.
// Maybe the renaming can be done in the rawfileconversion step? Or check if the OpenMS tools
// accept different file endings already?
process PREPROCESS_EXPDESIGN {

    conda (params.enable_conda ? "bioconda::sdrf-pipelines=0.0.21 conda-forge::pandas" : null)
    label 'process_very_low'
    label 'process_single_thread'
    tag "$design.Name"

    container "frolvlad/alpine-bash"

    input:
    path design

    output:
    path "${design.baseName}_openms_design.tsv", emit: ch_expdesign
    path "${design.baseName}_config.tsv", emit: ch_config

    script:

    """
    # since we know that we will need to convert from raw to mzML for all tools that need the design (i.e., OpenMS tools)
    # we edit the design here and change the endings.
    sed 's/.raw\\t/.mzML\\t/I' ${design} > ${design.baseName}_openms_design.tsv

    # here we extract the filenames and fake an empty config (since the config values will be deduced from the workflow params)
    a=\$(grep -n '^\$' ${design} | head -n1| awk -F":" '{print \$1}'); sed -e ''"\${a}"',\$d' ${design} > ${design.baseName}_config.tsv
    """
}
