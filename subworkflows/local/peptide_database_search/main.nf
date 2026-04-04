
include { MSGF_DB_INDEXING } from '../../../modules/local/utils/msgf_db_indexing/main'
include { MSGF  } from '../../../modules/local/openms/msgf/main'
include { COMET } from '../../../modules/local/openms/comet/main'
include { SAGE  } from '../../../modules/local/openms/sage/main'
include { PSM_CLEAN            } from '../../../modules/local/utils/psm_clean/main'
include { MSRESCORE_FINE_TUNING} from '../../../modules/local/utils/msrescore_fine_tuning/main'
include { MSRESCORE_FEATURES   } from '../../../modules/local/utils/msrescore_features/main'
include { GET_SAMPLE           } from '../../../modules/local/utils/extract_sample/main'
include { SPECTRUM_FEATURES    } from '../../../modules/local/utils/spectrum_features/main'
include { ID_MERGER            } from '../../../modules/local/openms/id_merger/main'

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
                    sage_train_datasets = ch_id_sage
                        .combine(ch_mzmls_search, by: 0)
                        .toSortedList()
                        .flatMap()
                        .randomSample(params.fine_tuning_sample_run, 2025)
                        .combine(channel.value("sage"))
                        .groupTuple(by: 3)

                    msgf_train_datasets = ch_id_msgf
                        .combine(ch_mzmls_search, by: 0)
                        .toSortedList()
                        .flatMap()
                        .randomSample(params.fine_tuning_sample_run, 2025)
                        .combine(channel.value("msgf"))
                        .groupTuple(by: 3)

                    comet_train_datasets = ch_id_comet
                        .combine(ch_mzmls_search, by: 0)
                        .toSortedList()
                        .flatMap()
                        .randomSample(params.fine_tuning_sample_run, 2025)
                        .combine(channel.value("comet"))
                        .groupTuple(by: 3)

                    sage_train_datasets.mix(msgf_train_datasets)
                        .mix(comet_train_datasets)
                        .combine(ms2_model_dir)
                        .set { train_datasets }
                    MSRESCORE_FINE_TUNING(train_datasets)
                    ch_versions = ch_versions.mix(MSRESCORE_FINE_TUNING.out.versions)

                    channel.value("msgf").combine(ch_id_msgf.combine(ch_mzmls_search, by: 0))
                        .combine(MSRESCORE_FINE_TUNING.out.model_weight, by:0)
                        .map { v -> [v[1], v[2], v[3], v[4], v[0] ] }
                        .set { msgf_features_input }

                    channel.value("sage").combine(ch_id_sage.combine(ch_mzmls_search, by: 0))
                        .combine(MSRESCORE_FINE_TUNING.out.model_weight, by:0)
                        .map { v -> [v[1], v[2], v[3], v[4], v[0] ] }
                        .set { sage_features_input }

                    channel.value("comet").combine(ch_id_comet.combine(ch_mzmls_search, by: 0))
                        .combine(MSRESCORE_FINE_TUNING.out.model_weight, by:0)
                        .map { v -> [v[1], v[2], v[3], v[4], v[0] ] }
                        .set { comet_features_input }

                    MSRESCORE_FEATURES(msgf_features_input.mix(sage_features_input).mix(comet_features_input))
                    ch_versions = ch_versions.mix(MSRESCORE_FEATURES.out.versions)
                    ch_id_files_feats = MSRESCORE_FEATURES.out.idxml


                }
            } else{
                ch_id_msgf.combine(ch_mzmls_search, by: 0)
                    .combine(ms2_model_dir)
                    .combine(channel.value("msgf")).set{ ch_id_msgf }
                ch_id_comet.combine(ch_mzmls_search, by: 0)
                    .combine(ms2_model_dir)
                    .combine(channel.value("comet")).set{ ch_id_comet }
                ch_id_sage.combine(ch_mzmls_search, by: 0)
                    .combine(ms2_model_dir)
                    .combine(channel.value("sage")).set{ ch_id_sage }

                MSRESCORE_FEATURES(ch_id_msgf.mix(ch_id_comet).mix(ch_id_sage))
                ch_versions = ch_versions.mix(MSRESCORE_FEATURES.out.versions)
                ch_id_files_feats = MSRESCORE_FEATURES.out.idxml
            }

            // Add SNR features to percolator
            if (params.ms2features_snr) {
                SPECTRUM_FEATURES(ch_id_files_feats.combine(ch_mzmls_search, by: 0))
                ch_id_files_feats_snr = SPECTRUM_FEATURES.out.id_files_snr
                ch_versions = ch_versions.mix(SPECTRUM_FEATURES.out.versions)
            } else {
                ch_id_files_feats_snr = ch_id_files_feats
            }

            ch_id_files_feats_snr
                .branch { _meta, _file_name, engine_name ->
                    msgf: engine_name == "msgf"
                    comet: engine_name == "comet"
                    sage: engine_name == "sage"
                }
                .set {ch_id_files_feats_branch}
            ch_id_files_feats_branch.msgf.map { v -> [v[0], v[1]] }.set {ch_id_files_msgf_feats}
            ch_id_files_feats_branch.comet.map {it -> [it[0], it[1]]}.set {ch_id_files_comet_feats}
            ch_id_files_feats_branch.sage.map {it -> [it[0], it[1]]}.set {ch_id_files_sage_feats}

        } else {
            ch_id_files_msgf_feats = ch_id_msgf
            ch_id_files_comet_feats = ch_id_comet
            ch_id_files_sage_feats = ch_id_sage
        }

        if (params.ms2features_range == "by_sample") {
            // Sample map
            GET_SAMPLE(ch_expdesign)
            ch_versions = ch_versions.mix(GET_SAMPLE.out.versions)
            ch_expdesign_sample = GET_SAMPLE.out.ch_expdesign_sample
            ch_expdesign_sample.splitCsv(header: true, sep: '\t')
                .map { v -> get_sample_map(v) }.set{ sample_map_idv }

            ch_id_files_msgf_feats.map { v -> [v[0].mzml_id, v[0], v[1]] }.set { ch_id_files_msgf_feats }
            ch_id_files_msgf_feats.combine(sample_map_idv, by: 0).map { v -> [v[1], v[2], v[3]] }.set{ ch_id_files_msgf_feats }

            ch_id_files_comet_feats.map { v -> [v[0].mzml_id, v[0], v[1]] }.set { ch_id_files_comet_feats }
            ch_id_files_comet_feats.combine(sample_map_idv, by: 0).map { v -> [v[1], v[2], v[3]] }.set{ ch_id_files_comet_feats }

            ch_id_files_sage_feats.map { v -> [v[0].mzml_id, v[0], v[1]] }.set { ch_id_files_sage_feats }
            ch_id_files_sage_feats.combine(sample_map_idv, by: 0).map { v -> [v[1], v[2], v[3]] }.set{ ch_id_files_sage_feats }

            // ID_MERGER for samples group
            ID_MERGER(ch_id_files_msgf_feats.groupTuple(by: 2)
                .mix(ch_id_files_comet_feats.groupTuple(by: 2))
                .mix(ch_id_files_sage_feats.groupTuple(by: 2))
            )
            ch_versions = ch_versions.mix(ID_MERGER.out.versions)
            ch_id_files_out = ID_MERGER.out.id_merged

        } else if (params.ms2features_range == "by_project") {
            ch_id_files_msgf_feats.map { v -> [v[0].experiment_id, v[0], v[1]] }.set { ch_id_files_msgf_feats }
            ch_id_files_comet_feats.map { v -> [v[0].experiment_id, v[0], v[1]] }.set { ch_id_files_comet_feats }
            ch_id_files_sage_feats.map { v -> [v[0].experiment_id, v[0], v[1]] }.set { ch_id_files_sage_feats }

            // ID_MERGER for whole experiments
            ID_MERGER(ch_id_files_msgf_feats.groupTuple(by: 2)
                .mix(ch_id_files_comet_feats.groupTuple(by: 2))
                .mix(ch_id_files_sage_feats.groupTuple(by: 2)))
            ch_versions = ch_versions.mix(ID_MERGER.out.versions)
            ch_id_files_out = ID_MERGER.out.id_merged
        } else {
            ch_id_files_out = ch_id_files_msgf_feats.mix(ch_id_files_comet_feats).mix(ch_id_files_sage_feats)
        }


    } else if (params.psm_clean == true) {
        ch_id_files = ch_id_msgf.mix(ch_id_comet).mix(ch_id_sage)
        PSM_CLEAN(ch_id_files.combine(ch_mzmls_search, by: 0))
        ch_id_files_out = PSM_CLEAN.out.idxml
        ch_versions = ch_versions.mix(PSM_CLEAN.out.versions)
    } else {
        ch_id_files_out = ch_id_msgf.mix(ch_id_comet).mix(ch_id_sage)
    }

    emit:
    ch_id_files_idx = ch_id_files_out
    versions        = ch_versions
}

// Function to get sample map
def get_sample_map(LinkedHashMap row) {

    def filestr               = row.Spectra_Filepath
    def file_name             = file(filestr).name.take(file(filestr).name.lastIndexOf('.'))
    def sample                = row.Sample

    return [file_name, sample]

}
