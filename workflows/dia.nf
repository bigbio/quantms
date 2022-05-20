/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULES: Local to the pipeline
//
include { GENERATE_DIANN_CFG  as DIANNCFG } from '../modules/local/generate_diann_cfg/main'
include { DIANNCONVERT } from '../modules/local/diannconvert/main'
include { MSSTATS } from '../modules/local/msstats/main'
include { DIANN_PRELIMINARY_ANALYSIS } from '../modules/local/diann_preliminary_analysis/main'
include { ASSEMBLE_EMPIRICAL_LIBRARY } from '../modules/local/assemble_empirical_library/main'
include { SILICOLIBRARYGENERATION } from '../modules/local/silicolibrarygeneration/main'
include { INDIVIDUAL_FINAL_ANALYSIS } from '../modules/local/individual_final_analysis/main'
include { DIANNSUMMARY } from '../modules/local/diannsummary/main'

//
// SUBWORKFLOWS: Consisting of a mix of local and nf-core/modules
//


/*
========================================================================================
    RUN MAIN WORKFLOW
========================================================================================
*/

// Info required for completion email and summary
def multiqc_report = []

workflow DIA {
    take:
    file_preparation_results
    ch_expdesign

    main:

    ch_software_versions = Channel.empty()
    Channel.fromPath(params.database).set{ searchdb }

    file_preparation_results.multiMap {
                                meta: it[0]
                                mzml: it[1]
                                }
                            .set { result }

    DIANNCFG(result.meta.first())
    ch_software_versions = ch_software_versions.mix(DIANNCFG.out.version.ifEmpty(null))

    //
    // MODULE: SILICOLIBRARYGENERATION
    //
    SILICOLIBRARYGENERATION(searchdb, DIANNCFG.out.diann_cfg)

    //
    // MODULE: DIANN_PRELIMINARY_ANALYSIS
    //
    DIANN_PRELIMINARY_ANALYSIS(file_preparation_results.combine(SILICOLIBRARYGENERATION.out.predict_speclib))
    ch_software_versions = ch_software_versions.mix(DIANN_PRELIMINARY_ANALYSIS.out.version.ifEmpty(null))

    //
    // MODULE: ASSEMBLE_EMPIRICAL_LIBRARY
    //
    ASSEMBLE_EMPIRICAL_LIBRARY(result.mzml.collect(),
                                DIANN_PRELIMINARY_ANALYSIS.out.diann_quant.collect(),
                                SILICOLIBRARYGENERATION.out.predict_speclib
                            )
    ch_software_versions = ch_software_versions.mix(ASSEMBLE_EMPIRICAL_LIBRARY.out.version.ifEmpty(null))

    //
    // MODULE: INDIVIDUAL_FINAL_ANALYSIS
    //
    INDIVIDUAL_FINAL_ANALYSIS(result.mzml.combine(ASSEMBLE_EMPIRICAL_LIBRARY.out.log).combine(ASSEMBLE_EMPIRICAL_LIBRARY.out.empirical_library))
    ch_software_versions = ch_software_versions.mix(INDIVIDUAL_FINAL_ANALYSIS.out.version.ifEmpty(null))

    //
    // MODULE: DIANNSUMMARY
    //
    DIANNSUMMARY(result.mzml.collect(), ASSEMBLE_EMPIRICAL_LIBRARY.out.empirical_library,
                    INDIVIDUAL_FINAL_ANALYSIS.out.diann_quant.collect(), searchdb)
    ch_software_versions = ch_software_versions.mix(DIANNSUMMARY.out.version.ifEmpty(null))

    //
    // MODULE: DIANNCONVERT
    //
    DIANNCONVERT(DIANNSUMMARY.out.report, ch_expdesign)
    ch_software_versions = ch_software_versions.mix(DIANNCONVERT.out.version.ifEmpty(null))

    //
    // MODULE: MSSTATS
    ch_msstats_out = Channel.empty()
    if(!params.skip_post_msstats){
        MSSTATS(DIANNCONVERT.out.out_msstats)
        ch_msstats_out = MSSTATS.out.msstats_csv
        ch_software_versions = ch_software_versions.mix(MSSTATS.out.version.ifEmpty(null))
    }

    versions        = ch_software_versions

    emit:
    versions        = versions
    diann_report    = DIANNSUMMARY.out.report
    msstats_csv     = DIANNCONVERT.out.out_msstats
    out_triqler     = DIANNCONVERT.out.out_triqler
    msstats_out     = ch_msstats_out

}

/*
========================================================================================
    THE END
========================================================================================
*/
