//
// MODULE: Local to the pipeline
//
include { CONSENSUSID          } from '../../../modules/local/openms/consensusid/main'
include { EXTRACT_PSM_FEATURES } from '../../../modules/local/openms/extract_psm_features/main'
include { PERCOLATOR           } from '../../../modules/local/openms/percolator/main'
include { ID_MERGER            } from '../../../modules/local/openms/id_merger/main'
include { ID_RIPPER            } from '../../../modules/local/openms/id_ripper/main'
include { PSM_CONVERSION       } from '../../../modules/local/utils/psm_conversion/main'
include { MSRESCORE_FEATURES   } from '../../../modules/local/utils/msrescore_features/main'
include { GET_SAMPLE           } from '../../../modules/local/utils/extract_sample/main'
include { SPECTRUM_FEATURES    } from '../../../modules/local/utils/spectrum_features/main'
include { PSM_CLEAN            } from '../../../modules/local/utils/psm_clean/main'

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { PEPTIDE_DATABASE_SEARCH } from '../peptide_database_search/main'
include { PSM_FDR_CONTROL         } from '../psm_fdr_control/main'

workflow DDA_ID {
    take:
    ch_file_preparation_results
    ch_database_wdecoy
    ch_ms2_statistics
    ch_expdesign

    main:

    ch_software_versions = Channel.empty()

    //
    // SUBWORKFLOW: DatabaseSearchEngines
    //
    PEPTIDE_DATABASE_SEARCH (
        ch_file_preparation_results,
        ch_database_wdecoy
    )
    ch_software_versions = ch_software_versions.mix(PEPTIDE_DATABASE_SEARCH.out.versions.ifEmpty(null))
    ch_id_files = PEPTIDE_DATABASE_SEARCH.out.ch_id_files_idx

    ch_id_files.branch{ meta, filename ->
        sage: filename.name.contains('sage')
            return [meta, filename]
        nosage: true
            return [meta, filename]
    }.set{ch_id_files_branched}

    ch_pmultiqc_consensus = Channel.empty()
    ch_pmultiqc_ids = Channel.empty()

    //
    // SUBWORKFLOW: Rescoring
    //
    if (params.skip_rescoring == false) {

        if (params.ms2rescore == true) {
            MSRESCORE_FEATURES(ch_id_files.combine(ch_file_preparation_results, by: 0))
            ch_software_versions = ch_software_versions.mix(MSRESCORE_FEATURES.out.versions)
            ch_id_files_feats = MSRESCORE_FEATURES.out.idxml
        } else {
            EXTRACT_PSM_FEATURES(ch_id_files_branched.nosage)
            ch_software_versions = ch_software_versions.mix(EXTRACT_PSM_FEATURES.out.versions)
            PSM_CLEAN(ch_id_files_branched.sage.mix(EXTRACT_PSM_FEATURES.out.id_files_feat).combine(ch_file_preparation_results, by: 0))
            ch_id_files_feats = PSM_CLEAN.out.idxml
            ch_software_versions = ch_software_versions.mix(PSM_CLEAN.out.versions)
        }

        // Add SNR features to percolator
        if (params.add_snr_feature_percolator) {
            SPECTRUM_FEATURES(ch_id_files_feats.combine(ch_file_preparation_results, by: 0))
            ch_id_files_feats = SPECTRUM_FEATURES.out.id_files_snr
            ch_software_versions = ch_software_versions.mix(SPECTRUM_FEATURES.out.versions)
        }

        // Rescoring for independent run, Sample or whole experiments
        if (params.rescore_range == "independent_run") {
            PERCOLATOR(ch_id_files_feats)
            ch_software_versions = ch_software_versions.mix(PERCOLATOR.out.versions)
            ch_consensus_input = PERCOLATOR.out.id_files_perc
        } else if (params.rescore_range == "by_sample") {
            // Sample map
            GET_SAMPLE(ch_expdesign)
            ch_software_versions = ch_software_versions.mix(GET_SAMPLE.out.versions)

            ch_expdesign_sample = GET_SAMPLE.out.ch_expdesign_sample
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
            ID_MERGER(ch_id_files_feat_branched.comet.groupTuple(by: 2)
                .mix(ch_id_files_feat_branched.msgf.groupTuple(by: 2))
                .mix(ch_id_files_feat_branched.sage.groupTuple(by: 2)))
            ch_software_versions = ch_software_versions.mix(ID_MERGER.out.versions)

            PERCOLATOR(ID_MERGER.out.id_merged)
            ch_software_versions = ch_software_versions.mix(PERCOLATOR.out.versions)

            // Currently only ID runs on exactly one mzML file are supported in CONSENSUSID. Split idXML by runs
            ID_RIPPER(PERCOLATOR.out.id_files_perc)
            ch_file_preparation_results.map{[it[0].mzml_id, it[0]]}.set{meta}
            ID_RIPPER.out.id_rippers.flatten().map { add_file_prefix (it)}.set{id_rippers}
            meta.combine(id_rippers, by: 0)
                    .map{ [it[1], it[2], "MS:1001491"]}
                    .set{ ch_consensus_input }
            ch_software_versions = ch_software_versions.mix(ID_RIPPER.out.versions)

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
            ID_MERGER(ch_id_files_feat_branched.comet.groupTuple(by: 2)
                .mix(ch_id_files_feat_branched.msgf.groupTuple(by: 2))
                .mix(ch_id_files_feat_branched.sage.groupTuple(by: 2)))
            ch_software_versions = ch_software_versions.mix(ID_MERGER.out.versions)

            PERCOLATOR(ID_MERGER.out.id_merged)
            ch_software_versions = ch_software_versions.mix(PERCOLATOR.out.versions)

            // Currently only ID runs on exactly one mzML file are supported in CONSENSUSID. Split idXML by runs
            ID_RIPPER(PERCOLATOR.out.id_files_perc)
            ch_file_preparation_results.map{[it[0].mzml_id, it[0]]}.set{meta}
            ID_RIPPER.out.id_rippers.flatten().map { add_file_prefix (it)}.set{id_rippers}
            meta.combine(id_rippers, by: 0)
                    .map{ [it[1], it[2], "MS:1001491"]}
                    .set{ ch_consensus_input }
            ch_software_versions = ch_software_versions.mix(ID_RIPPER.out.versions)

        }

        ch_rescoring_results = ch_consensus_input

        //
        // SUBWORKFLOW: PSM_FDR_CONTROL
        //
        ch_psmfdrcontrol     = Channel.empty()
        ch_consensus_results = Channel.empty()
        // see comments in id.nf
        if (params.search_engines.tokenize(",").unique().size() > 1) {
            CONSENSUSID(ch_consensus_input.groupTuple(size: params.search_engines.tokenize(",").unique().size()))
            ch_software_versions = ch_software_versions.mix(CONSENSUSID.out.versions.ifEmpty(null))
            ch_psmfdrcontrol = CONSENSUSID.out.consensusids
            ch_psmfdrcontrol
                .map { it -> it[1] }
                .set { ch_pmultiqc_consensus }
        } else {
            ch_psmfdrcontrol = ch_consensus_input
        }

        PSM_FDR_CONTROL(ch_psmfdrcontrol)
        ch_software_versions = ch_software_versions.mix(PSM_FDR_CONTROL.out.versions.ifEmpty(null))

        // Extract PSMs and export parquet format
        PSM_CONVERSION(PSM_FDR_CONTROL.out.id_filtered.combine(ch_ms2_statistics, by: 0))
        ch_software_versions = ch_software_versions.mix(PSM_CONVERSION.out.versions)

        ch_rescoring_results
            .map { it -> it[1] }
            .set { ch_pmultiqc_ids }
    } else {
        PSM_CONVERSION(ch_id_files.combine(ch_ms2_statistics, by: 0))
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
