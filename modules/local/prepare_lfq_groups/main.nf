process PREPARE_LFQ_GROUPS {
    tag "${sdrf.baseName}"
    label 'process_single'

    container 'quay.io/biocontainers/quantms-utils:0.0.30--pyhdfd78af_0'

    input:
    path(sdrf)
    path(expdes)
    path(splitter)
    val(columns)

    output:
    path 'lfq_groups.tsv', emit: manifest
    path 'lfq_group_*.tsv', emit: designs
    path 'versions.yml', emit: versions

    script:
    def columnArgs = columns.collect { "'${it.replace("'", "'\"'\"'")}'" }.join(' ')
    """
    python3 '${splitter}' \\
        --sdrf '${sdrf}' \\
        --design '${expdes}' \\
        --columns ${columnArgs}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        Python: \$(python3 --version | cut -d ' ' -f 2)
    END_VERSIONS
    """
}

// Keep the run/design/SDRF association in one tuple even when groups finish out of order.
def group_lfq_inputs(ch_runs, ch_manifest) {
    def ch_group_runs = ch_manifest
        .map { manifest -> tuple(manifest.parent, manifest) }
        .splitCsv(elem: 1, header: true, sep: '\t')
        .map { directory, row ->
            tuple(row.run_id, row.group_id, directory.resolve(row.design_file), directory.resolve(row.sdrf_file))
        }
    return ch_runs
        .map { meta, mzml, ids -> tuple(mzml.baseName, mzml, ids) }
        .join(ch_group_runs, failOnDuplicate: true, failOnMismatch: true)
        .map { run, mzml, ids, groupId, design, groupSdrf -> tuple(groupId, design, groupSdrf, mzml, ids) }
        .groupTuple(by: [0, 1, 2])
        .map { groupId, design, groupSdrf, mzmls, ids -> tuple(mzmls, ids, design, groupSdrf) }
}
