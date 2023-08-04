/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULES: Local to the pipeline
//
include { GENERATE_DIANN_CFG as DIANNCFG } from '../modules/local/generate_diann_cfg/main'
include { DIANNCONVERT                   } from '../modules/local/diannconvert/main'
include { MSSTATS                        } from '../modules/local/msstats/main'
include { DIANN_PRELIMINARY_ANALYSIS     } from '../modules/local/diann_preliminary_analysis/main'
include { ASSEMBLE_EMPIRICAL_LIBRARY     } from '../modules/local/assemble_empirical_library/main'
include { SILICOLIBRARYGENERATION        } from '../modules/local/silicolibrarygeneration/main'
include { INDIVIDUAL_FINAL_ANALYSIS      } from '../modules/local/individual_final_analysis/main'
include { DIANNSUMMARY                   } from '../modules/local/diannsummary/main'

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
    ch_file_preparation_results
    ch_expdesign
    ch_mzml_info

    main:

    ch_software_versions = Channel.empty()
    Channel.fromPath(params.database).set{ ch_searchdb }

    ch_file_preparation_results.multiMap {
                                meta: preprocessed_meta(it[0])
                                mzml: it[1]
                                }
                            .set { ch_result }

    meta = ch_result.meta.unique {it[0]}

    DIANNCFG(meta)
    ch_software_versions = ch_software_versions.mix(DIANNCFG.out.version.ifEmpty(null))

    //
    // MODULE: SILICOLIBRARYGENERATION
    //
    if (!params.diann_speclib) {
        SILICOLIBRARYGENERATION(ch_searchdb, DIANNCFG.out.diann_cfg)
        speclib = SILICOLIBRARYGENERATION.out.predict_speclib
    } else {
        speclib = Channel.fromPath(params.diann_speclib)
    }


    //
    // MODULE: DIANN_PRELIMINARY_ANALYSIS
    //
    DIANN_PRELIMINARY_ANALYSIS(ch_file_preparation_results.combine(speclib))
    ch_software_versions = ch_software_versions.mix(DIANN_PRELIMINARY_ANALYSIS.out.version.ifEmpty(null))

    //
    // MODULE: ASSEMBLE_EMPIRICAL_LIBRARY
    //
    ASSEMBLE_EMPIRICAL_LIBRARY(ch_result.mzml.collect(),
                                meta,
                                DIANN_PRELIMINARY_ANALYSIS.out.diann_quant.collect(),
                                speclib
                            )
    ch_software_versions = ch_software_versions.mix(ASSEMBLE_EMPIRICAL_LIBRARY.out.version.ifEmpty(null))

    //
    // MODULE: INDIVIDUAL_FINAL_ANALYSIS
    //
    INDIVIDUAL_FINAL_ANALYSIS(ch_file_preparation_results.combine(ch_searchdb).combine(ASSEMBLE_EMPIRICAL_LIBRARY.out.log).combine(ASSEMBLE_EMPIRICAL_LIBRARY.out.empirical_library))
    ch_software_versions = ch_software_versions.mix(INDIVIDUAL_FINAL_ANALYSIS.out.version.ifEmpty(null))

    //
    // MODULE: DIANNSUMMARY
    //
    DIANNSUMMARY(ch_result.mzml.collect(), meta, ASSEMBLE_EMPIRICAL_LIBRARY.out.empirical_library,
                    INDIVIDUAL_FINAL_ANALYSIS.out.diann_quant.collect(), ch_searchdb)
    ch_software_versions = ch_software_versions.mix(DIANNSUMMARY.out.version.ifEmpty(null))

    //
    // MODULE: DIANNCONVERT
    //
    DIANNCONVERT(DIANNSUMMARY.out.main_report, ch_expdesign, DIANNSUMMARY.out.pg_matrix, DIANNSUMMARY.out.pr_matrix, ch_mzml_info,
                meta, ch_searchdb, DIANNSUMMARY.out.version)
    ch_software_versions = ch_software_versions.mix(DIANNCONVERT.out.version.ifEmpty(null))

    //
    // MODULE: MSSTATS
    ch_msstats_out = Channel.empty()
    if(!params.skip_post_msstats){
        MSSTATS(DIANNCONVERT.out.out_msstats)
        ch_msstats_out = MSSTATS.out.msstats_csv
        ch_software_versions = ch_software_versions.mix(MSSTATS.out.version.ifEmpty(null))
    }

    emit:
    versions        = ch_software_versions
    diann_report    = DIANNSUMMARY.out.main_report
    msstats_in      = DIANNCONVERT.out.out_msstats
    out_triqler     = DIANNCONVERT.out.out_triqler
    msstats_out     = ch_msstats_out

}


// remove meta.id to make sure cache identical HashCode
def preprocessed_meta(LinkedHashMap meta){
    def parameters = [:]
    parameters["experiment_id"]                 = meta.experiment_id
    parameters["acquisition_method"]            = meta.acquisition_method
    parameters["dissociationmethod"]            = meta.dissociationmethod
    parameters["labelling_type"]                = meta.labelling_type
    parameters["fixedmodifications"]            = meta.fixedmodifications
    parameters["variablemodifications"]         = meta.variablemodifications
    parameters["precursormasstolerance"]        = meta.precursormasstolerance
    parameters["precursormasstoleranceunit"]    = meta.precursormasstoleranceunit
    parameters["fragmentmasstolerance"]         = meta.fragmentmasstolerance
    parameters["fragmentmasstoleranceunit"]     = meta.fragmentmasstoleranceunit
    parameters["enzyme"]                        = meta.enzyme

    return parameters
}

/*
========================================================================================
    THE END
========================================================================================
*/
