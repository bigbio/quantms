//
// Raw file conversion and mzml indexing
//

params.options = [:]

include { THERMORAWFILEPARSER } from '../../modules/local/openms/thirdparty/thermorawfileparser/main' addParams(options: params.options)
include { MZMLINDEXING } from '../../modules/local/openms/mzmlindexing/main' addParams(options: params.options)

workflow FILE_PREPARATION {
    take:
    rawfiles            // channel: [ val(mzml_id), raw ]
    nonIndexedMzML      // channel: [ val(mzml_id), nonIndexedmzml ]

    main:
    ch_versions = Channel.empty()
    ch_results = Channel.empty()

    THERMORAWFILEPARSER( rawfiles )
    ch_versions = ch_versions.mix(THERMORAWFILEPARSER.out.version)
    ch_results = ch_results.mix(THERMORAWFILEPARSER.out.mzmls_converted)

    MZMLINDEXING( nonIndexedMzML )
    ch_versions = ch_versions.mix(MZMLINDEXING.out.version)
    ch_results = ch_results.mix(MZMLINDEXING.out.mzmls_indexed)

    emit:
    results         = ch_results        // channel: [val(mzml_id), indexedmzml]

    version         = ch_versions       // channel: [ *.version.txt ]
}
