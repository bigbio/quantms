/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULES: Local to the pipeline
//
include { FILEMERGE } from '../modules/local/openms/filemerge/main'
include { PMULTIQC } from '../modules/local/pmultiqc/main'

//
// SUBWORKFLOWS: Consisting of a mix of local and nf-core/modules
//
include { FEATUREMAPPER } from '../subworkflows/local/featuremapper'
include { PROTEININFERENCE } from '../subworkflows/local/proteininference'
include { PROTEINQUANT } from '../subworkflows/local/proteinquant'
include { ID } from '../subworkflows/local/id'

/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

workflow TMT {
    take:
    file_preparation_results
    ch_expdesign

    main:

    ch_software_versions = Channel.empty()

    //
    // SUBWORKFLOWS: ID
    //
    ID(file_preparation_results)
    ch_software_versions = ch_software_versions.mix(ID.out.version.ifEmpty(null))

    //
    // SUBWORKFLOW: FEATUREMAPPER
    //
    FEATUREMAPPER(file_preparation_results, ID.out.id_results)
    ch_software_versions = ch_software_versions.mix(FEATUREMAPPER.out.version.ifEmpty(null))

    //
    // MODULE: FILEMERGE
    //
    FILEMERGE(FEATUREMAPPER.out.id_map.collect())
    ch_software_versions = ch_software_versions.mix(FILEMERGE.out.version.ifEmpty(null))

    //
    // SUBWORKFLOW: PROTEININFERENCE
    //
    PROTEININFERENCE(FILEMERGE.out.id_merge)
    ch_software_versions = ch_software_versions.mix(PROTEININFERENCE.out.version.ifEmpty(null))

    //
    // SUBWORKFLOW: PROTEINQUANT
    //
    PROTEINQUANT(PROTEININFERENCE.out.epi_idfilter, ch_expdesign)
    ch_software_versions = ch_software_versions.mix(PROTEINQUANT.out.version.ifEmpty(null))

    //
    // MODULE: PMULTIQC
    // TODO PMULTIQC package will be improved and restructed
    if (params.enable_pmultiqc) {
        file_preparation_results
            .map { it -> it[1] }
            .set { ch_pmultiqc_mzmls }
        ID.out.psmrescoring_results
            .map { it -> it[1] }
            .set { ch_pmultiqc_ids }

        PMULTIQC(ch_expdesign, ch_pmultiqc_mzmls.collect(), PROTEINQUANT.out.out_mztab, ch_pmultiqc_ids.collect())
        ch_software_versions = ch_software_versions.mix(PMULTIQC.out.version.ifEmpty(null))
    }
}
