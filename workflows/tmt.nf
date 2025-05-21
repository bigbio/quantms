/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULES: Local to the pipeline
//
include { FILE_MERGE  } from '../modules/local/openms/filemerge/main'
include { MSSTATS_TMT as MSSTATSTMT } from '../modules/local/msstats/msstats_tmt/main'

//
// SUBWORKFLOWS: Consisting of a mix of local and nf-core/modules
//
include { FEATUREMAPPER    } from '../subworkflows/local/feature_mapper'
include { PROTEININFERENCE } from '../subworkflows/local/protein_inference'
include { PROTEINQUANT     } from '../subworkflows/local/protein_quant'
include { ID               } from '../subworkflows/local/id'

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
    FEATUREMAPPER(ch_file_preparation_results, ID.out.id_results)
    ch_software_versions = ch_software_versions.mix(FEATUREMAPPER.out.versions.ifEmpty(null))

    //
    // MODULE: FILEMERGE
    //
    FILEMERGE(FEATUREMAPPER.out.id_map.collect())
    ch_software_versions = ch_software_versions.mix(FILEMERGE.out.versions.ifEmpty(null))

    //
    // SUBWORKFLOW: PROTEININFERENCE
    //
    PROTEININFERENCE(FILEMERGE.out.id_merge)
    ch_software_versions = ch_software_versions.mix(PROTEININFERENCE.out.versions.ifEmpty(null))

    //
    // SUBWORKFLOW: PROTEINQUANT
    //
    PROTEINQUANT(PROTEININFERENCE.out.epi_idfilter, ch_expdesign)
    ch_software_versions = ch_software_versions.mix(PROTEINQUANT.out.versions.ifEmpty(null))

    //
    // MODULE: MSSTATSTMT
    //
    ch_msstats_out = Channel.empty()
    if(!params.skip_post_msstats){
        MSSTATSTMT(PROTEINQUANT.out.msstats_csv)
        ch_msstats_out = MSSTATSTMT.out.msstats_csv
        ch_software_versions = ch_software_versions.mix(MSSTATSTMT.out.versions.ifEmpty(null))
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
    final_result            = PROTEINQUANT.out.out_mztab
    msstats_in              = PROTEINQUANT.out.msstats_csv
    msstats_out             = ch_msstats_out
    versions                = ch_software_versions
}
