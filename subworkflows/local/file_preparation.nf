//
// Raw file conversion and mzml indexing
//

include { THERMORAWFILEPARSER } from '../../modules/local/thermorawfileparser/main'
include { TDF2MZML            } from '../../modules/local/tdf2mzml/main'
include { DECOMPRESS          } from '../../modules/local/decompress_dotd/main'
include { DOTD2MQC_INDIVIDUAL } from '../../modules/local/dotd_to_mqc/main'
include { DOTD2MQC_AGGREGATE  } from '../../modules/local/dotd_to_mqc/main'
include { MZMLINDEXING        } from '../../modules/local/openms/mzmlindexing/main'
include { MZMLSTATISTICS      } from '../../modules/local/mzmlstatistics/main'
include { OPENMSPEAKPICKER    } from '../../modules/local/openms/openmspeakpicker/main'

workflow FILE_PREPARATION {
    take:
    ch_rawfiles            // channel: [ val(meta), raw/mzml/d.tar ]

    main:
    ch_versions   = Channel.empty()
    ch_results    = Channel.empty()
    ch_statistics = Channel.empty()
    ch_mqc_data   = Channel.empty()

    // Divide the compressed files
    ch_rawfiles
    .branch {
        dottar: WorkflowQuantms.hasExtension(it[1], '.tar')
        dotgz: WorkflowQuantms.hasExtension(it[1], '.tar')
        gz: WorkflowQuantms.hasExtension(it[1], '.gz')
        uncompressed: true
    }.set { ch_branched_input }

    compressed_files = ch_branched_input.dottar.mix(ch_branched_input.dotgz, ch_branched_input.gz)
    DECOMPRESS(compressed_files)
    ch_versions = ch_versions.mix(DECOMPRESS.out.version)
    ch_rawfiles = ch_branched_input.uncompressed.mix(DECOMPRESS.out.decompressed_files)

    //
    // Divide mzml files
    ch_rawfiles
    .branch {
        raw: WorkflowQuantms.hasExtension(it[1], '.raw')
        mzML: WorkflowQuantms.hasExtension(it[1], '.mzML')
        dotd: WorkflowQuantms.hasExtension(it[1], '.d')
    }.set { ch_branched_input }

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

    // Exctract qc data from .d files
    DOTD2MQC_INDIVIDUAL(ch_branched_input.dotd)
    // The map extracts the tsv files from the tuple, the other elem is the yml config.
    ch_mqc_data = ch_mqc_data.mix(DOTD2MQC_INDIVIDUAL.out.dotd_mqc_data.map{ it -> it[1] }.collect())
    DOTD2MQC_AGGREGATE(DOTD2MQC_INDIVIDUAL.out.general_stats.collect())
    ch_mqc_data = ch_mqc_data.mix(DOTD2MQC_AGGREGATE.out.dotd_mqc_data.collect())
    ch_versions = ch_versions.mix(DOTD2MQC_INDIVIDUAL.out.version)
    ch_versions = ch_versions.mix(DOTD2MQC_AGGREGATE.out.version)

    // Convert .d files to mzML
    if (params.convert_dotd) {
        TDF2MZML( ch_branched_input.dotd )
        ch_versions = ch_versions.mix(TDF2MZML.out.version)
        ch_results = indexed_mzml_bundle.mix(TDF2MZML.out.mzmls_converted)
        // indexed_mzml_bundle = indexed_mzml_bundle.mix(TDF2MZML.out.mzmls_converted)
    } else{
        ch_results = indexed_mzml_bundle.mix(ch_branched_input.dotd)
    }

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
    mqc_custom_data = ch_mqc_data       // channel: [ *.tsv ]
    version         = ch_versions       // channel: [ *.version.txt ]
}
