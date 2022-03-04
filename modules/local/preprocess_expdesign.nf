// Fixing file endings only necessary if the experimental design is user-specified
process PREPROCESS_EXPDESIGN {
    label 'process_very_low'
    label 'process_single_thread'

    input:
    path design

    output:
    path "experimental_design.tsv", emit: ch_expdesign
    path "process_experimental_design.tsv", emit: process_ch_expdesign

    script:

    """
    sed 's/.raw\\t/.mzML\\t/I' $design > experimental_design.tsv
    a=\$(grep -n '^\$' $design | head -n1| awk -F":" '{print \$1}'); sed -e ''"\${a}"',\$d' $design > process_experimental_design.tsv
    """
}
