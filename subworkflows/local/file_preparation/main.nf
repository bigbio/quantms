//
// Raw file conversion and mzml indexing
//

include { THERMORAWFILEPARSER } from '../../../modules/local/thermorawfileparser/main'
include { TDF2MZML            } from '../../../modules/local/utils/tdf2mzml/main'
include { DECOMPRESS          } from '../../../modules/local/utils/decompress_dotd/main'
include { MZML_INDEXING       } from '../../../modules/local/openms/mzml_indexing/main'
include { MZML_STATISTICS     } from '../../../modules/local/utils/mzml_statistics/main'
include { OPENMS_PEAK_PICKER  } from '../../../modules/local/openms/openms_peak_picker/main'

workflow FILE_PREPARATION {
    take:
    ch_rawfiles            // channel: [ val(meta), raw/mzml/d.tar ]

    main:
    ch_versions   = Channel.empty()
    ch_results    = Channel.empty()
    ch_statistics = Channel.empty()
    ch_ms2_statistics = Channel.empty()
    ch_feature_statistics = Channel.empty()
    ch_mqc_data   = Channel.empty()


    // Divide the compressed files
    ch_rawfiles
    .branch {
        dottar: hasExtension(it[1], '.tar')
        dotzip: hasExtension(it[1], '.zip')
        gz: hasExtension(it[1], '.gz')
        uncompressed: true
    }.set { ch_branched_input }

    compressed_files = ch_branched_input.dottar.mix(ch_branched_input.dotzip, ch_branched_input.gz)
    DECOMPRESS(compressed_files)
    ch_versions = ch_versions.mix(DECOMPRESS.out.versions)
    ch_rawfiles = ch_branched_input.uncompressed.mix(DECOMPRESS.out.decompressed_files)

    //
    // Divide mzml files
    ch_rawfiles
    .branch {
        raw: hasExtension(it[1], '.raw')
        mzML: hasExtension(it[1], '.mzML')
        dotd: hasExtension(it[1], '.d')
    }.set { ch_branched_input }

    // Note: we used to always index mzMLs if not already indexed but due to
    //  either a bug or limitation in nextflow
    //  peeking into a remote file consumes a lot of RAM
    //  See https://github.com/bigbio/quantms/issues/61
    //  This is now done in the search engines themselves if they need it.
    //  This means users should pre-index to save time and space, especially
    //  when re-running.

    if (params.reindex_mzml) {
        MZML_INDEXING( ch_branched_input.mzML )
        ch_versions = ch_versions.mix(MZML_INDEXING.out.versions)
        ch_results  = ch_results.mix(MZML_INDEXING.out.mzmls_indexed)
    } else {
        ch_results = ch_results.mix(ch_branched_input.mzML)
    }

    THERMORAWFILEPARSER( ch_branched_input.raw )
    // Output is
    // {'mzmls_converted': Tuple[val(meta), path(mzml)],
    //  'version': Path(versions.yml),
    //  'log': Path(*.txt)}

    // Where meta is the same as the input meta
    ch_versions = ch_versions.mix(THERMORAWFILEPARSER.out.versions)
    ch_results  = ch_results.mix(THERMORAWFILEPARSER.out.mzmls_converted)

    ch_results.map{ it -> [it[0], it[1]] }.set{ indexed_mzml_bundle }

    // Convert .d files to mzML
    if (params.convert_dotd) {
        TDF2MZML( ch_branched_input.dotd )
        ch_versions = ch_versions.mix(TDF2MZML.out.versions)
        ch_results = indexed_mzml_bundle.mix(TDF2MZML.out.mzmls_converted)
        // indexed_mzml_bundle = indexed_mzml_bundle.mix(TDF2MZML.out.mzmls_converted)
    } else {
        ch_results = indexed_mzml_bundle.mix(ch_branched_input.dotd)
    }


    MZML_STATISTICS(ch_results)
    ch_statistics = ch_statistics.mix(MZML_STATISTICS.out.ms_statistics.collect())
    ch_ms2_statistics = ch_statistics.mix(MZML_STATISTICS.out.ms2_statistics)
    ch_feature_statistics = ch_statistics.mix(MZML_STATISTICS.out.feature_statistics.collect())
    ch_versions = ch_versions.mix(MZML_STATISTICS.out.versions)

    if (params.openms_peakpicking) {
        // If the peak picker is enabled, it will over-write not bypass the .d files
        OPENMS_PEAK_PICKER (
            indexed_mzml_bundle
        )

        ch_versions = ch_versions.mix(OPENMS_PEAK_PICKER.out.versions)
        ch_results = OPENMS_PEAK_PICKER.out.mzmls_picked
    }

    emit:
    results         = ch_results        // channel: [val(mzml_id), indexedmzml|.d.tar]
    statistics      = ch_statistics     // channel: [ *_ms_info.parquet ]
    ms2_statistics  = ch_ms2_statistics // channel: [ *_ms2_info.parquet ]
    feature_statistics = ch_feature_statistics // channel: [ *_feature_info.parquet ]
    versions        = ch_versions       // channel: [ *.versions.yml ]
}

//
// check file extension
//
def hasExtension(file, extension) {
    return file.toString().toLowerCase().endsWith(extension.toLowerCase())
}
