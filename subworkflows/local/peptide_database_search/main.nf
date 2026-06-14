
include { MSGF_DB_INDEXING } from '../../../modules/local/utils/msgf_db_indexing/main'
include { MSGF  } from '../../../modules/local/openms/msgf/main'
include { COMET } from '../../../modules/local/openms/comet/main'
include { SAGE  } from '../../../modules/local/openms/sage/main'
include { PSM_CLEAN            } from '../../../modules/local/utils/psm_clean/main'
include { MSRESCORE_FINE_TUNING} from '../../../modules/local/utils/msrescore_fine_tuning/main'
include { MSRESCORE_FEATURES   } from '../../../modules/local/utils/msrescore_features/main'
include { SPECTRUM_FEATURES    } from '../../../modules/local/utils/spectrum_features/main'
include { EXTRACTPSMFEATURES           } from '../../../modules/local/openms/extractfeatures/main'

workflow PEPTIDE_DATABASE_SEARCH {
    take:
    ch_mzmls_search
    ch_searchengine_in_db
    ch_expdesign

    main:
    (ch_id_msgf, ch_id_comet, ch_id_sage, ch_versions) = [ channel.empty(), channel.empty(), channel.empty(), channel.empty() ]

    if (params.search_engines.contains("msgf")) {
        MSGF_DB_INDEXING(ch_searchengine_in_db)
        ch_versions = ch_versions.mix(MSGF_DB_INDEXING.out.versions)

        MSGF(ch_mzmls_search.combine(ch_searchengine_in_db).combine(MSGF_DB_INDEXING.out.msgfdb_idx))
        ch_versions = ch_versions.mix(MSGF.out.versions)
        ch_id_msgf = ch_id_msgf.mix(MSGF.out.id_files_msgf)
    }

    if (params.search_engines.contains("comet")) {
        COMET(ch_mzmls_search.combine(ch_searchengine_in_db))
        ch_versions = ch_versions.mix(COMET.out.versions)
        ch_id_comet = ch_id_comet.mix(COMET.out.id_files_comet)
    }

    // sorted mzmls to generate same batch ids when enable cache
    ch_mzmls_sorted_search = ch_mzmls_search.collect(flat: false, sort: { a, b -> a[0]["mzml_id"] <=> b[0]["mzml_id"] }).flatMap()
    if (params.search_engines.contains("sage")) {
        def cnt = 0
        ch_meta_mzml_db = ch_mzmls_sorted_search.map{ metapart, mzml ->
            cnt += 1
            def groupkey = metapart.labelling_type +
                    metapart.dissociationmethod +
                    metapart.fixedmodifications +
                    metapart.variablemodifications +
                    metapart.precursormasstolerance +
                    metapart.precursormasstoleranceunit +
                    metapart.fragmentmasstolerance +
                    metapart.fragmentmasstoleranceunit +
                    metapart.enzyme
            // TODO this only works if the metakeys are all the same
            //  otherwise we need to group by key first and then batch
            def batch = cnt % params.sage_processes
            // TODO hash the key to make it shorter?
            [groupkey, batch, metapart, mzml]
        }
        // group into chunks to be processed at the same time on the same node by sage
        // TODO I guess if we parametrize the nr of files per process, it is more
        //  efficient (because this process can start as soon as this number of files
        //  are available and does not need to wait and see how many Channel entries
        //  belong to batch X). But the problem is groupTuple(size:) cannot be
        //  specified with an output from a Channel. The only way would be to,
        //  IN THE VERY BEGINNING, parse
        //  the number of files (=lines?) in the SDRF/design (outside of a process),
        //  save this value and pass it along the pipeline.
        ch_meta_mzml_db_chunked = ch_meta_mzml_db.groupTuple(by: [0,1])

        SAGE(ch_meta_mzml_db_chunked.combine(ch_searchengine_in_db))
        ch_versions = ch_versions.mix(SAGE.out.versions)
        // we can safely use merge here since it is the same process
        ch_id_sage = ch_id_sage.mix(SAGE.out.id_files_sage.transpose())
    }

    (ch_id_files_msgf_feats, ch_id_files_comet_feats, ch_id_files_sage_feats) = [ channel.empty(), channel.empty(), channel.empty() ]

    if (params.skip_rescoring != true) {
        if (params.ms2features_enable == true){
            // Only add ms2_model_dir if it's actually set and not empty
            // Handle cases where parameter might be empty string, null, boolean true, or whitespace
            // When --ms2features_model_dir is passed with no value, Nextflow may set it to boolean true
            if (params.ms2features_model_dir && params.ms2features_model_dir != true) {
                ms2_model_dir = channel.from(file(params.ms2features_model_dir, checkIfExists: true))
            } else {
                // create a fake channel when don't specify model dir
                ms2_model_dir = channel.from(file("pretrained_models"))
            }

            if (params.ms2features_fine_tuning == true) {
                if (params.ms2features_generators.toLowerCase().contains('ms2pip')) {
                    error('Fine tuning only supports AlphaPeptdeep. Please set --ms2features_generators to include "alphapeptdeep" instead of "ms2pip".')
                } else {

                    // Preparing train datasets and fine tuning MS2 model
                    // Randomly select one search engine for fine-tuning sampling
                    engine_opts = []
                    if (params.search_engines.contains("sage"))  engine_opts.add("sage")
                    if (params.search_engines.contains("msgf"))  engine_opts.add("msgf")
                    if (params.search_engines.contains("comet")) engine_opts.add("comet")
                    selected_engine = engine_opts[new Random(2025).nextInt(engine_opts.size())]

                    ch_selected_engine = (selected_engine == "sage") ? ch_id_sage :
                                        (selected_engine == "msgf") ? ch_id_msgf :
                                        ch_id_comet

                    train_datasets = ch_selected_engine
                        .combine(ch_mzmls_search, by: 0)
                        .toSortedList()
                        .flatMap()
                        .randomSample(params.fine_tuning_sample_run, 2025)
                        .groupTuple(by: 3)

                    MSRESCORE_FINE_TUNING(train_datasets.combine(ms2_model_dir))
                    ch_versions = ch_versions.mix(MSRESCORE_FINE_TUNING.out.versions)

                    if (params.search_engines.tokenize(",").unique().size() > 1) {
                        ch_id_msgf.mix(ch_id_comet).mix(ch_id_sage).groupTuple(size: params.search_engines.tokenize(",").unique().size())
                        .combine(ch_mzmls_search, by: 0)
                        .combine(MSRESCORE_FINE_TUNING.out.model_weight).set{ ch_id_rescoring }
                    } else {
                        ch_id_msgf.mix(ch_id_comet).mix(ch_id_sage).combine(ch_mzmls_search, by: 0)
                            .combine(MSRESCORE_FINE_TUNING.out.model_weight).set{ ch_id_rescoring }
                    }

                    MSRESCORE_FEATURES(ch_id_rescoring)
                    ch_versions = ch_versions.mix(MSRESCORE_FEATURES.out.versions)
                    ch_id_files_feats = MSRESCORE_FEATURES.out.idparquet

                }
            } else{
                if (params.search_engines.tokenize(",").unique().size() > 1) {
                    ch_id_msgf.mix(ch_id_comet).mix(ch_id_sage).groupTuple(size: params.search_engines.tokenize(",").unique().size())
                    .combine(ch_mzmls_search, by: 0)
                    .combine(ms2_model_dir).set{ ch_id_rescoring }
                } else {
                    ch_id_msgf.mix(ch_id_comet).mix(ch_id_sage).combine(ch_mzmls_search, by: 0)
                        .combine(ms2_model_dir).set{ ch_id_rescoring }
                }
                MSRESCORE_FEATURES(ch_id_rescoring)
                ch_versions = ch_versions.mix(MSRESCORE_FEATURES.out.versions)
                ch_id_files_feats = MSRESCORE_FEATURES.out.idparquet
            }

            // Add SNR features to percolator
            if (params.ms2features_snr) {
                SPECTRUM_FEATURES(ch_id_files_feats.combine(ch_mzmls_search, by: 0))
                ch_id_files_out = SPECTRUM_FEATURES.out.id_files_snr
                ch_versions = ch_versions.mix(SPECTRUM_FEATURES.out.versions)
            } else {
                ch_id_files_out = ch_id_files_feats
            }

        } else if (params.search_engines.tokenize(",").unique().size() > 1) {
            PSM_CLEAN(ch_id_msgf.mix(ch_id_comet).mix(ch_id_sage).groupTuple(size: params.search_engines.tokenize(",").unique().size()).combine(ch_mzmls_search, by: 0))
            ch_id_files_out = PSM_CLEAN.out.idparquet
        } else {
            ch_id_files_out = ch_id_msgf.mix(ch_id_comet).mix(ch_id_sage)
        }

    } else if (params.psm_clean == true) {
        ch_id_files = ch_id_msgf.mix(ch_id_comet).mix(ch_id_sage)
        PSM_CLEAN(ch_id_files.combine(ch_mzmls_search, by: 0))
        ch_id_files_out = PSM_CLEAN.out.idparquet
        ch_versions = ch_versions.mix(PSM_CLEAN.out.versions)
    } else {
        ch_id_files_out = ch_id_msgf.mix(ch_id_comet).mix(ch_id_sage)
    }

    emit:
    ch_id_files_idx = ch_id_files_out
    versions        = ch_versions
}
