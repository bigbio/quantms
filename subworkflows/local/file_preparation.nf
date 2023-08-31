//
// Raw file conversion and mzml indexing
//

include { THERMORAWFILEPARSER } from '../../modules/local/thermorawfileparser/main'
include { MZMLINDEXING        } from '../../modules/local/openms/mzmlindexing/main'
include { MZMLSTATISTICS      } from '../../modules/local/mzmlstatistics/main'
include { OPENMSPEAKPICKER    } from '../../modules/local/openms/openmspeakpicker/main'

workflow FILE_PREPARATION {
    take:
    ch_mzmls            // channel: [ val(meta), raw/mzml ]

    main:
    ch_versions   = Channel.empty()
    ch_results    = Channel.empty()
    ch_statistics = Channel.empty()

    //
    // Divide mzml files
    //
    ch_mzmls
    .branch {
        raw: WorkflowQuantms.hasExtension(it[1], 'raw')
        mzML: WorkflowQuantms.hasExtension(it[1], 'mzML')
    }
    .set { ch_branched_input }

    // Note: we used to always index mzMLs if not already indexed but due to
    //  either a bug or limitation in nextflow
    //  peeking into a remote file consumes a lot of RAM
    //  See https://github.com/nf-core/quantms/issues/61
    //  This is now done in the search engines themselves if they need it.
    //  This means users should pre-index to save time and space, especially
    //  when re-running.

    if (params.reindex_mzml){
        MZMLINDEXING( ch_branched_input.mzML )
        ch_versions = ch_versions.mix(MZMLINDEXING.out.version)
        ch_results  = ch_results.mix(MZMLINDEXING.out.mzmls_indexed)
    } else {
        ch_results = ch_results.mix(ch_branched_input.mzML)
    }

    THERMORAWFILEPARSER( ch_branched_input.raw )
    ch_versions = ch_versions.mix(THERMORAWFILEPARSER.out.version)
    ch_results  = ch_results.mix(THERMORAWFILEPARSER.out.mzmls_converted)

    ch_results.map{ it -> [it[0], it[1]] }.set{ ch_mzml }

    MZMLSTATISTICS( ch_mzml )
    ch_statistics = ch_statistics.mix(MZMLSTATISTICS.out.mzml_statistics.collect())
    ch_versions = ch_versions.mix(MZMLSTATISTICS.out.version)

    if (params.openms_peakpicking){
        OPENMSPEAKPICKER (
            ch_results
        )

        ch_versions = ch_versions.mix(OPENMSPEAKPICKER.out.version)
        ch_results = OPENMSPEAKPICKER.out.mzmls_picked
    }


    emit:
    results         = ch_results        // channel: [val(mzml_id), indexedmzml]
    statistics      = ch_statistics     // channel: [ *_mzml_info.tsv ]
    version         = ch_versions       // channel: [ *.version.txt ]
}
