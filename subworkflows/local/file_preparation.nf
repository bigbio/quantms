//
// Raw file conversion and mzml indexing
//

include { THERMORAWFILEPARSER } from '../../modules/local/thermorawfileparser/main'
include { TDF2MZML            } from '../../modules/local/tdf2mzml/main'
include { DECOMPRESS          } from '../../modules/local/decompress_dotd/main'
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
    ch_spectrum_df = Channel.empty()

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
    //  See https://github.com/nf-core/quantms/issues/61
    //  This is now done in the search engines themselves if they need it.
    //  This means users should pre-index to save time and space, especially
    //  when re-running.

    if (params.reindex_mzml) {
        MZMLINDEXING( ch_branched_input.mzML )
        ch_versions = ch_versions.mix(MZMLINDEXING.out.versions)
        ch_results  = ch_results.mix(MZMLINDEXING.out.mzmls_indexed)
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


    MZMLSTATISTICS(ch_results)
    ch_statistics = ch_statistics.mix(MZMLSTATISTICS.out.ms_statistics.collect())
    ch_spectrum_df = ch_spectrum_df.mix(MZMLSTATISTICS.out.spectrum_df)

    ch_versions = ch_versions.mix(MZMLSTATISTICS.out.versions)

    if (params.openms_peakpicking) {
        // If the peak picker is enabled, it will over-write not bypass the .d files
        OPENMSPEAKPICKER (
            indexed_mzml_bundle
        )

        ch_versions = ch_versions.mix(OPENMSPEAKPICKER.out.versions)
        ch_results = OPENMSPEAKPICKER.out.mzmls_picked
    }

    emit:
    results         = ch_results        // channel: [val(mzml_id), indexedmzml|.d.tar]
    statistics      = ch_statistics     // channel: [ *_ms_info.parquet ]
    spectrum_data   = ch_spectrum_df    // channel: [val(mzml_id), *_spectrum_df.parquet]
    versions         = ch_versions       // channel: [ *.version.txt ]
}

//
// check file extension
//
def hasExtension(file, extension) {
    return file.toString().toLowerCase().endsWith(extension.toLowerCase())
}
