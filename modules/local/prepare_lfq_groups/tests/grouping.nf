include { group_lfq_inputs } from '../main'

workflow GROUPING_TEST {
    take:
    ch_runs
    ch_manifest

    main:
    ch_inputs = group_lfq_inputs(ch_runs, ch_manifest)

    emit:
    inputs = ch_inputs.map { mzmls, ids, design, sdrf ->
        tuple(design.name, sdrf.name,
            mzmls.collect { it.name }.sort().join('|'),
            ids.collect { it.name }.sort().join('|'))
    }
}
