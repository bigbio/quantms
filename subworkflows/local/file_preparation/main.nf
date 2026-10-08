//
// Raw file conversion and mzml indexing
//

include { THERMORAWFILEPARSER } from '../../../modules/bigbio/thermorawfileparser/main'
include { TDF2MZML            } from '../../../modules/local/utils/tdf2mzml/main'
include { DECOMPRESS          } from '../../../modules/local/utils/decompress_dotd/main'
include { MZML_INDEXING       } from '../../../modules/local/openms/mzml_indexing/main'
include { MZML_STATISTICS     } from '../../../modules/local/utils/mzml_statistics/main'
include { OPENMS_PEAK_PICKER  } from '../../../modules/local/openms/openms_peak_picker/main'

workflow FILE_PREPARATION {
    take:
    ch_rawfiles            // channel: [ val(meta), raw/mzml/d.tar ]

    main:
    ch_versions   = channel.empty()
    ch_results    = channel.empty()
    ch_statistics = channel.empty()
    ch_ms2_statistics = channel.empty()
    ch_feature_statistics = channel.empty()


    // Divide the compressed files
    ch_rawfiles
    .branch { item ->
        dottar: hasExtension(item[1], '.tar')
        dotzip: hasExtension(item[1], '.zip')
        gz: hasExtension(item[1], '.gz')
        uncompressed: true
    }.set { ch_branched_input }

    compressed_files = ch_branched_input.dottar.mix(ch_branched_input.dotzip, ch_branched_input.gz)
    DECOMPRESS(compressed_files)
    ch_versions = ch_versions.mix(DECOMPRESS.out.versions)
    ch_rawfiles = ch_branched_input.uncompressed.mix(DECOMPRESS.out.decompressed_files)

    //
    // Divide mzml files
    ch_rawfiles
    .branch { item ->
        raw: hasExtension(item[1], '.raw')
        mzML: hasExtension(item[1], '.mzML')
        dotd: hasExtension(item[1], '.d')
        dia: hasExtension(item[1], '.dia')
        unsupported: true
    }.set { ch_branched_input }

    // Warn about unsupported file formats
    ch_branched_input.unsupported
        .collect()
        .subscribe { files ->
            if (files.size() > 0) {
                log.warn "=" * 80
                log.warn "WARNING: ${files.size()} file(s) with unsupported format(s) detected and will be SKIPPED from processing:"
                files.each { _meta, file ->
                    log.warn "  - ${file}"
                }
                log.warn "\nSupported formats: .raw, .mzML, .d (Bruker), .dia"
                log.warn "Compressed variants (.gz, .tar, .tar.gz, .zip) are also supported."
                log.warn "=" * 80
            }
        }

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

    // Thermo .raw files are read directly by the OpenMS tools (ProSE, Comet, Sage, ProteomicsLFQ)
    // through the Thermo RawFileReader bridge in the OpenMS image. Conversion to mzML is opt-in.
    if (params.convert_raw) {
        THERMORAWFILEPARSER( ch_branched_input.raw )
        ch_results  = ch_results.mix(THERMORAWFILEPARSER.out.spectra)
    }

    ch_results.map{ it -> [it[0], it[1]] }.set{ indexed_mzml_bundle }

    // Convert .d files to mzML
    if (params.convert_dotd) {
        TDF2MZML( ch_branched_input.dotd )
        ch_versions = ch_versions.mix(TDF2MZML.out.versions)
        ch_results = indexed_mzml_bundle.mix(TDF2MZML.out.mzmls_converted)
    } else {
        ch_results = indexed_mzml_bundle
    }

    if (params.mzml_statistics) {
        // Only run on mzML files, skip .d directories
        ch_mzml_for_stats = ch_results.filter { _meta, file ->
            !file.toString().toLowerCase().endsWith('.d')
        }
        MZML_STATISTICS(ch_mzml_for_stats)
        ch_statistics = ch_statistics.mix(MZML_STATISTICS.out.ms_statistics.collect())
        ch_ms2_statistics = ch_ms2_statistics.mix(MZML_STATISTICS.out.ms2_statistics)
        ch_feature_statistics = ch_feature_statistics.mix(MZML_STATISTICS.out.feature_statistics.collect())
        ch_versions = ch_versions.mix(MZML_STATISTICS.out.versions)
    }

    // Pass through vendor files that are read directly by OpenMS (no conversion). They bypass
    // mzML statistics, which only reads mzML.
    ch_vendor = channel.empty()
    if (!params.convert_raw) {
        ch_vendor = ch_vendor.mix(ch_branched_input.raw)
    }
    if (!params.convert_dotd) {
        ch_vendor = ch_vendor.mix(ch_branched_input.dotd)
    }
    ch_vendor = ch_vendor.map { meta, file ->
        checkVendorFileSupport(meta, file)
        [meta, file]
    }
    ch_results = ch_results.mix(ch_vendor)

    // Pass through .dia files without conversion (DIA-NN handles them natively)
    // Note: .dia files bypass peak picking and mzML statistics (when enabled) as they are only used with DIA-NN
    ch_results = ch_results.mix(ch_branched_input.dia)

    if (params.openms_peakpicking) {
        // Only mzML can be peak picked; vendor files are rejected by checkVendorFileSupport
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
// Vendor files (.raw/.d) that are not converted are only read by OpenMS tools with native
// vendor support. Fail early instead of silently dropping or converting them.
//
def checkVendorFileSupport(meta, file) {
    def reasons = []
    def engines = params.search_engines.tokenize(',')*.trim()
    if (engines.contains('msgf')) {
        reasons << 'MS-GF+ (--search_engines msgf) only reads mzML'
    }
    if (params.openms_peakpicking) {
        reasons << 'PeakPickerHiRes (--openms_peakpicking) only reads mzML'
    }
    if (params.ms2features_enable) {
        reasons << 'MS2 feature generation (--ms2features_enable) only reads mzML'
    }
    if (params.psm_clean || (engines.size() > 1 && !params.skip_rescoring)) {
        reasons << 'PSM cleaning/merging of multiple search engines (quantms-rescoring) only reads mzML'
    }
    if (params.enable_mod_localization) {
        reasons << 'modification localization (--enable_mod_localization, onsite) only reads mzML'
    }
    if (meta.labelling_type.contains('tmt') || meta.labelling_type.contains('itraq')) {
        reasons << 'isobaric quantification (IsobaricWorkflow) only reads mzML'
    }
    if (reasons) {
        def flag = hasExtension(file, '.raw') ? '--convert_raw' : '--convert_dotd'
        error("Vendor file '${file.name}' is read directly by OpenMS (no conversion), but the following " +
            "steps require mzML: ${reasons.join('; ')}. Set ${flag} true to convert vendor files to mzML, " +
            "or disable these steps.")
    }
    if (params.mzml_statistics) {
        log.warn("mzML statistics are not computed for vendor file '${file.name}' (only mzML is supported).")
    }
}

//
// check file extension
//
def hasExtension(file, extension) {
    return file.toString().toLowerCase().endsWith(extension.toLowerCase())
}
