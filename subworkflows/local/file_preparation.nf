//
// Raw file conversion and mzml indexing
//

params.options = [:]

include { THERMORAWFILEPARSER } from '../../modules/local/thermorawfileparser/main' addParams(options: params.options)
include { MZMLINDEXING } from '../../modules/local/openms/mzmlindexing/main' addParams(options: params.options)
include { OPENMSPEAKPICKER } from '../../modules/local/openms/openmspeakpicker/main' addParams( options: params.options )

workflow FILE_PREPARATION {
    take:
    mzmls            // channel: [ val(meta), raw/mzml ]

    main:
    ch_versions = Channel.empty()
    ch_results = Channel.empty()

    //
    // Divide mzml files
    //
    mzmls
    .branch {
        raw: WorkflowQuantms.hasExtension(it[1], 'raw')
        mzML: WorkflowQuantms.hasExtension(it[1], 'mzML')
    }
    .set {branched_input}

    //TODO we could also check for outdated mzML versions and try to update them
    branched_input.mzML
    .branch {
        nonIndexedMzML: file(it[1]).withReader {
            f = it; 1.upto(5) {
                if (f.readLine().contains("indexedmzML")) return false;
            }
                return true;
        }
        inputIndexedMzML: file(it[1]).withReader {
            f = it; 1.upto(5) {
                if (f.readLine().contains("indexedmzML")) return true;
            }
                return false;
        }
    }
    .set {branched_input_mzMLs}
    ch_results = ch_results.mix(branched_input_mzMLs.inputIndexedMzML)

    THERMORAWFILEPARSER( branched_input.raw )
    ch_versions = ch_versions.mix(THERMORAWFILEPARSER.out.version)
    ch_results = ch_results.mix(THERMORAWFILEPARSER.out.mzmls_converted)

    MZMLINDEXING( branched_input_mzMLs.nonIndexedMzML )
    ch_versions = ch_versions.mix(MZMLINDEXING.out.version)
    ch_results = ch_results.mix(MZMLINDEXING.out.mzmls_indexed)

    if (params.openms_peakpicking){
        OPENMSPEAKPICKER (
            ch_results
        )

        ch_versions = ch_versions.mix(OPENMSPEAKPICKER.out.version)
        ch_results = OPENMSPEAKPICKER.out.mzmls_picked
    }


    emit:
    results         = ch_results        // channel: [val(mzml_id), indexedmzml]

    version         = ch_versions       // channel: [ *.version.txt ]
}
