//
// MODULE: Local to the pipeline
//
include { CONSENSUSID   } from '../../modules/local/openms/consensusid/main'
include { EXTRACTPSMFEATURES } from '../../modules/local/openms/extractpsmfeatures/main'
include { PERCOLATOR         } from '../../modules/local/openms/thirdparty/percolator/main'
include { IDMERGER           } from '../../modules/local/openms/idmerger/main'
include { IDRIPPER           } from '../../modules/local/openms/idripper/main'
include { FALSEDISCOVERYRATE as FDRIDPEP } from '../../modules/local/openms/falsediscoveryrate/main'
include { IDPEP                          } from '../../modules/local/openms/idpep/main'
include { PSMCONVERSION                  } from '../../modules/local/extract_psm/main'
include { MS2RESCORE                     } from '../../modules/local/ms2rescore/main'
include { IDSCORESWITCHER                } from '../../modules/local/openms/idscoreswitcher/main'
include { GETSAMPLE                      } from '../../modules/local/extract_sample/main'
include { SAGEFEATURE                    } from '../../modules/local/add_sage_feat/main'
include { SPECTRUM2FEATURES              } from '../../modules/local/spectrum2features/main'

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { DATABASESEARCHENGINES } from './databasesearchengines'
include { PSMFDRCONTROL         } from './psmfdrcontrol'

workflow DDA_ID {
    take:
    ch_file_preparation_results
    ch_database_wdecoy
    ch_spectrum_data
    ch_expdesign

    main:

    ch_software_versions = Channel.empty()

    //
    // SUBWORKFLOW: DatabaseSearchEngines
    //
    DATABASESEARCHENGINES (
        ch_file_preparation_results,
        ch_database_wdecoy
    )
    ch_software_versions = ch_software_versions.mix(DATABASESEARCHENGINES.out.versionss.ifEmpty(null))
    ch_id_files = DATABASESEARCHENGINES.out.ch_id_files_idx

    ch_id_files.branch{ meta, filename ->
        sage: filename.name.contains('sage')
            return [meta, filename]
        nosage: true
            return [meta, filename, []]
    }.set{ch_id_files_branched}

    ch_pmultiqc_consensus = Channel.empty()
    ch_pmultiqc_ids = Channel.empty()

    //
    // SUBWORKFLOW: Rescoring
    //
    if (params.skip_rescoring == false) {
        if (params.posterior_probabilities == 'percolator') {
            if (params.ms2rescore == true) {
                MS2RESCORE(ch_id_files.combine(ch_file_preparation_results, by: 0))
                ch_software_versions = ch_software_versions.mix(MS2RESCORE.out.versionss)

                MS2RESCORE.out.idxml.join(MS2RESCORE.out.feature_names).branch{ meta, idxml, feature_name ->
                    sage: idxml.name.contains('sage')
                        return [meta, idxml, feature_name]
                    nosage: true
                        return [meta, idxml, feature_name]
                }.set{ch_ms2rescore_branched}

                EXTRACTPSMFEATURES(ch_ms2rescore_branched.nosage)
                SAGEFEATURE(ch_ms2rescore_branched.sage)
                ch_id_files_feats = EXTRACTPSMFEATURES.out.id_files_feat.mix(SAGEFEATURE.out.id_files_feat)
                ch_software_versions = ch_software_versions.mix(EXTRACTPSMFEATURES.out.versions, SAGEFEATURE.out.versions)
            } else {
                EXTRACTPSMFEATURES(ch_id_files_branched.nosage)
                ch_id_files_feats = ch_id_files_branched.sage.mix(EXTRACTPSMFEATURES.out.id_files_feat)
                ch_software_versions = ch_software_versions.mix(EXTRACTPSMFEATURES.out.versions)
            }

            // Add SNR features to percolator
            if (params.add_snr_feature_percolator) {
                SPECTRUM2FEATURES(ch_id_files_feats.combine(ch_file_preparation_results, by: 0))
                ch_id_files_feats = SPECTRUM2FEATURES.out.id_files_snr
                ch_software_versions = ch_software_versions.mix(SPECTRUM2FEATURES.out.versions)
            }


            // Rescoring for independent run, Sample or whole experiments
            if (params.rescore_range == "independent_run") {
                PERCOLATOR(ch_id_files_feats)
                ch_software_versions = ch_software_versions.mix(PERCOLATOR.out.versions)
                ch_consensus_input = PERCOLATOR.out.id_files_perc
            } else if (params.rescore_range == "by_sample") {
                // Sample map
                GETSAMPLE(ch_expdesign)
                ch_software_versions = ch_software_versions.mix(GETSAMPLE.out.versions)

                ch_expdesign_sample = GETSAMPLE.out.ch_expdesign_sample
                ch_expdesign_sample.splitCsv(header: true, sep: '\t')
                    .map { get_sample_map(it) }.set{ sample_map_idv }

                ch_id_files_feats.map {[it[0].mzml_id, it[0], it[1]]}
                    .combine(sample_map_idv, by: 0)
                    .map {[it[1], it[2], it[3]]}
                    .set{ch_id_files_feats_sample}

                // Group by search_engines and sample
                ch_id_files_feats_sample.branch{ meta, filename, sample  ->
                    sage: filename.name.contains('sage')
                        return [meta, filename, sample]
                    msgf: filename.name.contains('msgf')
                        return [meta, filename, sample]
                    comet: filename.name.contains('comet')
                        return [meta, filename, sample]
                }.set{ch_id_files_feat_branched}

                // IDMERGER for samples group
                IDMERGER(ch_id_files_feat_branched.comet.groupTuple(by: 2)
                    .mix(ch_id_files_feat_branched.msgf.groupTuple(by: 2))
                    .mix(ch_id_files_feat_branched.sage.groupTuple(by: 2)))
                ch_software_versions = ch_software_versions.mix(IDMERGER.out.versions)

                PERCOLATOR(IDMERGER.out.id_merged)
                ch_software_versions = ch_software_versions.mix(PERCOLATOR.out.versions)

                // Currently only ID runs on exactly one mzML file are supported in CONSENSUSID. Split idXML by runs
                IDRIPPER(PERCOLATOR.out.id_files_perc)
                ch_file_preparation_results.map{[it[0].mzml_id, it[0]]}.set{meta}
                IDRIPPER.out.id_rippers.flatten().map { add_file_prefix (it)}.set{id_rippers}
                meta.combine(id_rippers, by: 0)
                        .map{ [it[1], it[2], "MS:1001491"]}
                        .set{ ch_consensus_input }
                ch_software_versions = ch_software_versions.mix(IDRIPPER.out.versions)

            } else if (params.rescore_range == "by_project"){
                ch_id_files_feats.map {[it[0].experiment_id, it[0], it[1]]}.set { ch_id_files_feats}

                // Split ch_id_files_feats by search_engines
                ch_id_files_feats.branch{ experiment_id, meta, filename ->
                    sage: filename.name.contains('sage')
                        return [meta, filename, experiment_id]
                    msgf: filename.name.contains('msgf')
                        return [meta, filename, experiment_id]
                    comet: filename.name.contains('comet')
                        return [meta, filename, experiment_id]
                }.set{ch_id_files_feat_branched}

                // IDMERGER for whole experiments
                IDMERGER(ch_id_files_feat_branched.comet.groupTuple(by: 2)
                    .mix(ch_id_files_feat_branched.msgf.groupTuple(by: 2))
                    .mix(ch_id_files_feat_branched.sage.groupTuple(by: 2)))
                ch_software_versions = ch_software_versions.mix(IDMERGER.out.versions)

                PERCOLATOR(IDMERGER.out.id_merged)
                ch_software_versions = ch_software_versions.mix(PERCOLATOR.out.versions)

                // Currently only ID runs on exactly one mzML file are supported in CONSENSUSID. Split idXML by runs
                IDRIPPER(PERCOLATOR.out.id_files_perc)
                ch_file_preparation_results.map{[it[0].mzml_id, it[0]]}.set{meta}
                IDRIPPER.out.id_rippers.flatten().map { add_file_prefix (it)}.set{id_rippers}
                meta.combine(id_rippers, by: 0)
                        .map{ [it[1], it[2], "MS:1001491"]}
                        .set{ ch_consensus_input }
                ch_software_versions = ch_software_versions.mix(IDRIPPER.out.versions)

            }

            ch_rescoring_results = ch_consensus_input

        } else if (params.posterior_probabilities == 'mokapot') {
            MS2RESCORE(ch_id_files.combine(ch_file_preparation_results, by: 0))
            ch_software_versions = ch_software_versions.mix(MS2RESCORE.out.versionss)
            IDSCORESWITCHER(MS2RESCORE.out.idxml.combine(Channel.value("PEP")))
            ch_software_versions = ch_software_versions.mix(IDSCORESWITCHER.out.versions)
            ch_consensus_input = IDSCORESWITCHER.out.id_score_switcher.combine(Channel.value("MS:1001491"))
            ch_rescoring_results = IDSCORESWITCHER.out.ch_consensus_input
        } else {
            ch_fdridpep = Channel.empty()
            if (params.search_engines.split(",").size() == 1) {
                FDRIDPEP(ch_id_files)
                ch_software_versions = ch_software_versions.mix(FDRIDPEP.out.versions)
                ch_id_files = Channel.empty()
                ch_fdridpep = FDRIDPEP.out.id_files_idx_ForIDPEP_FDR
            }
            IDPEP(ch_fdridpep.mix(ch_id_files))
            ch_software_versions = ch_software_versions.mix(IDPEP.out.versions)
            ch_consensus_input = IDPEP.out.id_files_ForIDPEP
            ch_rescoring_results = ch_consensus_input
        }

        //
        // SUBWORKFLOW: PSMFDRCONTROL
        //
        ch_psmfdrcontrol     = Channel.empty()
        ch_consensus_results = Channel.empty()
        if (params.search_engines.split(",").size() > 1) {
            CONSENSUSID(ch_consensus_input.groupTuple(size: params.search_engines.split(",").size()))
            ch_software_versions = ch_software_versions.mix(CONSENSUSID.out.versions.ifEmpty(null))
            ch_psmfdrcontrol = CONSENSUSID.out.consensusids
            ch_psmfdrcontrol
                .map { it -> it[1] }
                .set { ch_pmultiqc_consensus }
        } else {
            ch_psmfdrcontrol = ch_consensus_input
        }

        PSMFDRCONTROL(ch_psmfdrcontrol)
        ch_software_versions = ch_software_versions.mix(PSMFDRCONTROL.out.versions.ifEmpty(null))

        // Extract PSMs and export parquet format
        PSMCONVERSION(PSMFDRCONTROL.out.id_filtered.combine(ch_spectrum_data, by: 0))
        ch_software_versions = ch_software_versions.mix(PSMCONVERSION.out.versions)

        ch_rescoring_results
            .map { it -> it[1] }
            .set { ch_pmultiqc_ids }
    } else {
        PSMCONVERSION(ch_id_files.combine(ch_spectrum_data, by: 0))
    }


    emit:
    ch_pmultiqc_ids         = ch_pmultiqc_ids
    ch_pmultiqc_consensus   = ch_pmultiqc_consensus
    versions                = ch_software_versions
}

// Function to add file prefix
def add_file_prefix(file_path) {
    position = file(file_path).name.lastIndexOf('_sage_perc.idXML')
    if (position == -1) {
        position = file(file_path).name.lastIndexOf('_comet_perc.idXML')
        if (position == -1) {
            position = file(file_path).name.lastIndexOf('_msgf_perc.idXML')
        }
    }
    file_name = file(file_path).name.take(position)
    return [file_name, file_path]
}

// Function to get sample map
def get_sample_map(LinkedHashMap row) {
    def sample_map = [:]

    filestr               = row.Spectra_Filepath
    file_name             = file(filestr).name.take(file(filestr).name.lastIndexOf('.'))
    sample                = row.Sample

    return [file_name, sample]

}
