// Fixing file endings only necessary if the experimental design is user-specified
// TODO can we combine this with another step? Feels like a waste to spawn a worker for this.
// Maybe the renaming can be done in the rawfileconversion step? Or check if the OpenMS tools
// accept different file endings already?
process PREPROCESS_EXPDESIGN {
    label 'process_very_low'
    label 'process_single_thread'

    container "frolvlad/alpine-bash"

    input:
    path design

    output:
    path "experimental_design.tsv", emit: ch_expdesign
    path "config.tsv", emit: ch_config

    script:

    """
    # since we know that we will need to convert from raw to mzML for all tools that need the design (i.e., OpenMS tools)
    # we edit the design here and change the endings.
    sed 's/.raw\\t/.mzML\\t/I' $design > experimental_design.tsv

    # here we extract the filenames and fake an empty config (since the config values will be deduced from the workflow params)
    a=\$(grep -n '^\$' $design | head -n1| awk -F":" '{print \$1}'); sed -e ''"\${a}"',\$d' $design > config.tsv
    """
}
