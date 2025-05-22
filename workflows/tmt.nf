/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULES: Local to the pipeline
//
include { FILE_MERGE  } from '../modules/local/openms/file_merge/main'
include { MSSTATS_TMT } from '../modules/local/msstats/msstats_tmt/main'

//
// SUBWORKFLOWS: Consisting of a mix of local and nf-core/modules
//
include { FEATURE_MAPPER    } from '../subworkflows/local/feature_mapper/main'
include { PROTEIN_INFERENCE } from '../subworkflows/local/protein_inference/main'
include { PROTEIN_QUANT     } from '../subworkflows/local/protein_quant/main'
include { ID                } from '../subworkflows/local/id/main'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow TMT {
    take:
    ch_file_preparation_results
    ch_expdesign
    ch_database_wdecoy

    main:

    ch_software_versions = Channel.empty()

    //
    // SUBWORKFLOWS: ID
    //
    ID(ch_file_preparation_results, ch_database_wdecoy, ch_expdesign)
    ch_software_versions = ch_software_versions.mix(ID.out.versions.ifEmpty(null))

    //
    // SUBWORKFLOW: FEATUREMAPPER
    //
    FEATURE_MAPPER(ch_file_preparation_results, ID.out.id_results)
    ch_software_versions = ch_software_versions.mix(FEATURE_MAPPER.out.versions.ifEmpty(null))

    //
    // MODULE: FILEMERGE
    //
    FILE_MERGE(FEATURE_MAPPER.out.id_map.collect())
    ch_software_versions = ch_software_versions.mix(FILE_MERGE.out.versions.ifEmpty(null))

    //
    // SUBWORKFLOW: PROTEININFERENCE
    //
    PROTEIN_INFERENCE(FILE_MERGE.out.id_merge)
    ch_software_versions = ch_software_versions.mix(PROTEIN_INFERENCE.out.versions.ifEmpty(null))

    //
    // SUBWORKFLOW: PROTEINQUANT
    //
    PROTEIN_QUANT(PROTEIN_INFERENCE.out.epi_idfilter, ch_expdesign)
    ch_software_versions = ch_software_versions.mix(PROTEIN_QUANT.out.versions.ifEmpty(null))

    //
    // MODULE: MSSTATSTMT
    //
    ch_msstats_out = Channel.empty()
    if(!params.skip_post_msstats){
        MSSTATS_TMT(PROTEIN_QUANT.out.msstats_csv)
        ch_msstats_out = MSSTATS_TMT.out.msstats_csv
        ch_software_versions = ch_software_versions.mix(MSSTATS_TMT.out.versions.ifEmpty(null))
    }

    ID.out.psmrescoring_results
        .map { it -> it[1] }
        .set { ch_pmultiqc_ids }

    ID.out.ch_consensus_results
        .map { it -> it[1] }
        .set { ch_pmultiqc_consensus }

    emit:
    ch_pmultiqc_ids         = ch_pmultiqc_ids
    ch_pmultiqc_consensus   = ch_pmultiqc_consensus
    final_result            = PROTEIN_QUANT.out.out_mztab
    msstats_in              = PROTEIN_QUANT.out.msstats_csv
    msstats_out             = ch_msstats_out
    versions                = ch_software_versions
}
