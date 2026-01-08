//
// MODULE: Local to the pipeline
//
include { CONSENSUSID          } from '../../../modules/local/openms/consensusid/main'
include { PERCOLATOR           } from '../../../modules/local/openms/percolator/main'
include { ID_RIPPER            } from '../../../modules/local/openms/id_ripper/main'
include { PSM_CONVERSION       } from '../../../modules/local/utils/psm_conversion/main'
include { PHOSPHO_SCORING      } from '../phospho_scoring/main'

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
        ch_database_wdecoy,
        ch_expdesign
    )
    ch_software_versions = ch_software_versions.mix(PEPTIDE_DATABASE_SEARCH.out.versions)
    ch_id_files_feats = PEPTIDE_DATABASE_SEARCH.out.ch_id_files_idx

    ch_pmultiqc_consensus = Channel.empty()
    ch_pmultiqc_ids = Channel.empty()

    //
    // SUBWORKFLOW: Rescoring
    //
    if (params.skip_rescoring == false) {
        // Rescoring for independent run, Sample or whole experiments
        if (params.ms2features_range == "independent_run") {
            PERCOLATOR(ch_id_files_feats)
            ch_software_versions = ch_software_versions.mix(PERCOLATOR.out.versions)
            ch_consensus_input = PERCOLATOR.out.id_files_perc
        } else {
            PERCOLATOR(ch_id_files_feats)
            ch_software_versions = ch_software_versions.mix(PERCOLATOR.out.versions)
            // Currently only ID runs on exactly one mzML file are supported in CONSENSUSID. Split idXML by runs
            ID_RIPPER(PERCOLATOR.out.id_files_perc)
            ch_file_preparation_results.map{[it[0].mzml_id, it[0]]}.set{meta}
            ID_RIPPER.out.id_rippers.flatten().map { add_file_prefix (it)}.set{id_rippers}
            meta.combine(id_rippers, by: 0)
                    .map{ [it[1], it[2]]}
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
            ch_software_versions = ch_software_versions.mix(CONSENSUSID.out.versions)
            ch_psmfdrcontrol = CONSENSUSID.out.consensusids
            ch_psmfdrcontrol
                .map { it -> it[1] }
                .set { ch_pmultiqc_consensus }
        } else {
            ch_psmfdrcontrol = ch_consensus_input
        }

        PSM_FDR_CONTROL(ch_psmfdrcontrol)
        ch_software_versions = ch_software_versions.mix(PSM_FDR_CONTROL.out.versions)

        if (params.enable_mod_localization) {
            PHOSPHO_SCORING(ch_file_preparation_results, PSM_FDR_CONTROL.out.id_filtered)
            ch_software_versions = ch_software_versions.mix(PHOSPHO_SCORING.out.versions.ifEmpty(null))
            ch_id_results = PHOSPHO_SCORING.out.id_onsite
        } else {
            ch_id_results = PSM_FDR_CONTROL.out.id_filtered
        }

        // Extract PSMs and export parquet format
        PSM_CONVERSION(ch_id_results.combine(ch_ms2_statistics, by: 0))
        ch_software_versions = ch_software_versions.mix(PSM_CONVERSION.out.versions)

        ch_rescoring_results
            .map { it -> it[1] }
            .set { ch_pmultiqc_ids }
    } else {
        PSM_CONVERSION(ch_id_files_feats.combine(ch_ms2_statistics, by: 0))
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
