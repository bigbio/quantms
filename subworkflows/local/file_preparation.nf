//
// Raw file conversion and mzml indexing
//

include { THERMORAWFILEPARSER } from '../../modules/local/thermorawfileparser/main'
include { TDF2MZML } from '../../modules/local/tdf2mzml/main'
include { MZMLINDEXING        } from '../../modules/local/openms/mzmlindexing/main'
include { MZMLSTATISTICS      } from '../../modules/local/mzmlstatistics/main'
include { OPENMSPEAKPICKER    } from '../../modules/local/openms/openmspeakpicker/main'

workflow FILE_PREPARATION {
    take:
    ch_mzmls            // channel: [ val(meta), raw/mzml/d.tar ]

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
        dotD: WorkflowQuantms.hasExtension(it[1], '.d.tar')
    }
    .set { ch_branched_input }

    //TODO we could also check for outdated mzML versions and try to update them
    ch_branched_input.mzML
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
    .set { ch_branched_input_mzMLs }
    ch_results = ch_results.mix(ch_branched_input_mzMLs.inputIndexedMzML)

    THERMORAWFILEPARSER( ch_branched_input.raw )
    // Output is
    // {'mzmls_converted': Tuple[val(meta), path(mzml)],
    //  'version': Path(versions.yml),
    //  'log': Path(*.txt)}

    // Where meta is the same as the input meta
    ch_versions = ch_versions.mix(THERMORAWFILEPARSER.out.version)
    ch_results  = ch_results.mix(THERMORAWFILEPARSER.out.mzmls_converted)

    MZMLINDEXING( ch_branched_input_mzMLs.nonIndexedMzML )
    ch_versions = ch_versions.mix(MZMLINDEXING.out.version)
    ch_results  = ch_results.mix(MZMLINDEXING.out.mzmls_indexed)

    ch_results.map{ it -> [it[0], it[1]] }.set{ indexed_mzml_bundle }

    TDF2MZML( ch_branched_input.dotD )
    ch_versions = ch_versions.mix(TDF2MZML.out.version)
    ch_results = indexed_mzml_bundle.mix(TDF2MZML.out.dotd_files)
    indexed_mzml_bundle = indexed_mzml_bundle.mix(TDF2MZML.out.mzmls_converted)

    MZMLSTATISTICS( indexed_mzml_bundle )
    ch_statistics = ch_statistics.mix(MZMLSTATISTICS.out.mzml_statistics.collect())
    ch_versions = ch_versions.mix(MZMLSTATISTICS.out.version)

    if (params.openms_peakpicking){
        // If the peak picker is enabled, it will over-write not bypass the .d files
        OPENMSPEAKPICKER (
            indexed_mzml_bundle
        )

        ch_versions = ch_versions.mix(OPENMSPEAKPICKER.out.version)
        ch_results = OPENMSPEAKPICKER.out.mzmls_picked
    }


    emit:
    results         = ch_results        // channel: [val(mzml_id), indexedmzml|.d.tar]
    statistics      = ch_statistics     // channel: [ *_mzml_info.tsv ]
    version         = ch_versions       // channel: [ *.version.txt ]
}
