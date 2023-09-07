process SEARCHENGINESAGE {
    tag "${metas.toList().collect{it.mzml_id}}"
    label 'process_medium' // we could make it dependent on the number of files

    conda "openms::openms-thirdparty=3.1.0"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'ghcr.io/openms/openms-executables-sif:latest' :
        'ghcr.io/openms/openms-executables:latest' }"

    input:
    tuple val(key), val(batch), val(metas), path(mzml_files), path(database)

    output:
    tuple val(metas), path(meta_order_files), emit: id_files_sage
    path "versions.yml"                     , emit: version
    path "*.log"                            , emit: log

    script:
    def meta             = metas[0] // due to groupTuple they should all be the same (TODO check to use groupBy?)
    // Make sure that the output order is consistent with the meta ids
    meta_order_files     = metas.collect{ it.mzml_id.toString() + "*_sage.idXML" }
    def args             = task.ext.args ?: ''
    enzyme               = meta.enzyme
    outname              = mzml_files.size() > 1 ? "out_${batch}" : mzml_files[0].baseName

    il_equiv = params.IL_equivalent ? "-PeptideIndexing:IL_equivalent" : ""

    """
    export SAGE_LOG=trace
    SageAdapter \\
        -in ${mzml_files} \\
        -out ${outname}_sage.idXML \\
        -threads $task.cpus \\
        -database "${database}" \\
        -decoy_prefix $params.decoy_string \\
        -min_len $params.min_peptide_length \\
        -max_len $params.max_peptide_length \\
        -min_matched_peaks 1 \\
        -min_peaks 1 \\
        -max_peaks 500 \\
        -missed_cleavages $params.allowed_missed_cleavages \\
        -report_psms $params.num_hits \\
        -enzyme "${enzyme}" \\
        -precursor_tol_left ${-meta.precursormasstolerance} \\
        -precursor_tol_right ${meta.precursormasstolerance} \\
        -precursor_tol_unit $meta.precursormasstoleranceunit \\
        -fragment_tol_left ${-meta.fragmentmasstolerance} \\
        -fragment_tol_right ${meta.fragmentmasstolerance} \\
        -fragment_tol_unit $meta.fragmentmasstoleranceunit \\
        -fixed_modifications ${meta.fixedmodifications.tokenize(',').collect{ "'${it}'" }.join(" ") } \\
        -variable_modifications ${meta.variablemodifications.tokenize(',').collect{ "'${it}'" }.join(" ") } \\
        -max_variable_mods $params.max_mods \\
        -isotope_error_range $params.isotope_error_range \\
        ${il_equiv} \\
        -PeptideIndexing:unmatched_action ${params.unmatched_action} \\
        -debug $params.db_debug \\
        $args \\
        2>&1 | tee ${outname}_sage.log

    if [[ ${mzml_files.size()} -ge 2 ]]; then
        IDRipper -in ${outname}_sage.idXML -out . -split_ident_runs
        rm ${outname}_sage.idXML
        for f in *.idXML
        do
            mv "\$f" "\${f%.*}_sage.idXML"
        done
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        SageAdapter: \$(SageAdapter 2>&1 | grep -E '^Version(.*)' | sed 's/Version: //g' | cut -d ' ' -f 1)
        sage: \$(sage 2>&1 | grep -E 'Version [0-9]+\\.[0-9]+\\.[0-9]+')
    END_VERSIONS
    """
}
