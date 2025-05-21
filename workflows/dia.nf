/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULES: Local to the pipeline
//
include { DIANN_GENERATE_CFG } from '../modules/local/diann/generate_cfg/main'
include { DIANN_CONVERT  } from '../modules/local/diann/convert/main'
include { MSSTATS_LFQ       } from '../modules/local/msstats/msstats_lfq/main'
include { DIANN_PRELIMINARY_ANALYSIS     } from '../modules/local/diann/preliminary_analysis/main'
include { DIANN_ASSEMBLE_EMPIRICAL_LIBRARY } from '../modules/local/diann/assemble_empirical_library/main'
include { DIANN_INSILICO_LIBRARY_GENERATION } from '../modules/local/diann/insilico_library_generation/main'
include { INDIVIDUAL_FINAL_ANALYSIS      } from '../modules/local/diann/individual_final_analysis/main'
include { DIANN_SUMMARY   } from '../modules/local/diann/summary/main'

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
    ch_ms_info

    main:

    ch_software_versions = Channel.empty()
    Channel.fromPath(params.database).set { ch_searchdb }

    ch_file_preparation_results.multiMap {
        result ->
        meta:   preprocessed_meta(result[0])
        ms_file:result[1]
    }.set { ch_result }

    meta = ch_result.meta.unique { it[0] }

    DIANN_GENERATE_CFG(meta)
    ch_software_versions = ch_software_versions
        .mix(DIANN_GENERATE_CFG.out.versions.ifEmpty(null))

    //
    // MODULE: SILICOLIBRARYGENERATION
    //
    if (params.diann_speclib != null && params.diann_speclib.toString() != "") {
        speclib = Channel.from(file(params.diann_speclib, checkIfExists: true))
    } else {
        DIANN_INSILICO_LIBRARY_GENERATION(ch_searchdb, DIANN_GENERATE_CFG.out.diann_cfg)
        speclib = DIANN_INSILICO_LIBRARY_GENERATION.out.predict_speclib
    }

    if (params.skip_preliminary_analysis) {
        assembly_log = Channel.fromPath(params.empirical_assembly_log)
        empirical_library = Channel.fromPath(params.diann_speclib)
        indiv_fin_analysis_in = ch_file_preparation_results.combine(ch_searchdb)
            .combine(assembly_log)
            .combine(empirical_library)
        empirical_lib = empirical_library
    } else {
        //
        // MODULE: DIANN_PRELIMINARY_ANALYSIS
        //
        if (params.random_preanalysis) {
            preanalysis_subset = ch_file_preparation_results
                .toSortedList{ a, b -> file(a[1]).getName() <=> file(b[1]).getName() }
                .flatMap()
                .randomSample(params.empirical_assembly_ms_n, params.random_preanalysis_seed)
            empirical_lib_files = preanalysis_subset
                .map { result -> result[1] }
                .collect( sort: { a, b -> file(a).getName() <=> file(b).getName() } )
            DIANN_PRELIMINARY_ANALYSIS(preanalysis_subset.combine(speclib))
        } else {
            empirical_lib_files = ch_file_preparation_results
                .map { result -> result[1] }
                .collect( sort: { a, b -> file(a).getName() <=> file(b).getName() } )
            DIANN_PRELIMINARY_ANALYSIS(ch_file_preparation_results.combine(speclib))
        }
        ch_software_versions = ch_software_versions
            .mix(DIANN_PRELIMINARY_ANALYSIS.out.versions.ifEmpty(null))

        //
        // MODULE: ASSEMBLE_EMPIRICAL_LIBRARY
        //
        // Order matters in DIANN, This should be sorted for reproducible results.
        DIANN_ASSEMBLE_EMPIRICAL_LIBRARY(
            empirical_lib_files,
            meta,
            DIANN_PRELIMINARY_ANALYSIS.out.diann_quant.collect(),
            speclib
        )
        ch_software_versions = ch_software_versions
            .mix(DIANN_ASSEMBLE_EMPIRICAL_LIBRARY.out.versions.ifEmpty(null))
        indiv_fin_analysis_in = ch_file_preparation_results
            .combine(ch_searchdb)
            .combine(DIANN_ASSEMBLE_EMPIRICAL_LIBRARY.out.log)
            .combine(DIANN_ASSEMBLE_EMPIRICAL_LIBRARY.out.empirical_library)

        empirical_lib = DIANN_ASSEMBLE_EMPIRICAL_LIBRARY.out.empirical_library
    }

    //
    // MODULE: INDIVIDUAL_FINAL_ANALYSIS
    //
    DIANN_INDIVIDUAL_FINAL_ANALYSIS(indiv_fin_analysis_in)
    ch_software_versions = ch_software_versions
        .mix(DIANN_INDIVIDUAL_FINAL_ANALYSIS.out.versions.ifEmpty(null))

    //
    // MODULE: DIANNSUMMARY
    //
    // Order matters in DIANN, This should be sorted for reproducible results.
    // NOTE: ch_results.ms_file contains the name of the ms file, not the path.
    // The next step only needs the name (since it uses the cached .quant)
    // Converting to a file object and using its name is necessary because ch_result.ms_file contains
    // locally, evey element in ch_result is a string, whilst on cloud it is a path.
    ch_result
        .ms_file.map { msfile -> file(msfile).getName() }
        .collect(sort: true)
        .set { ms_file_names }

    DIANN_SUMMARY(
        ms_file_names,
        meta,
        empirical_lib,
        DIANN_INDIVIDUAL_FINAL_ANALYSIS.out.diann_quant.collect(),
        ch_searchdb)

    ch_software_versions = ch_software_versions.mix(
        DIANN_SUMMARY.out.versions.ifEmpty(null)
    )

    //
    // MODULE: DIANNCONVERT
    //
    diann_main_report = DIANN_SUMMARY.out.main_report.mix(DIANN_SUMMARY.out.report_parquet).last()

    DIANN_CONVERT(
        diann_main_report, ch_expdesign,
        DIANN_SUMMARY.out.pg_matrix,
        DIANN_SUMMARY.out.pr_matrix, ch_ms_info,
        meta,
        ch_searchdb,
        DIANN_SUMMARY.out.versions
    )
    ch_software_versions = ch_software_versions
        .mix(DIANN_CONVERT.out.versions.ifEmpty(null))

    //
    // MODULE: MSSTATS
    ch_msstats_out = Channel.empty()
    if (!params.skip_post_msstats) {
        MSSTATS_LFQ(DIANN_CONVERT.out.out_msstats)
        ch_msstats_out = MSSTATS_LFQ.out.msstats_csv
        ch_software_versions = ch_software_versions.mix(
            MSSTATS_LFQ.out.versions.ifEmpty(null)
        )
    }

    emit:
    versions        = ch_software_versions
    diann_report    = DIANN_SUMMARY.out.main_report
    msstats_in      = DIANN_CONVERT.out.out_msstats
    out_triqler     = DIANN_CONVERT.out.out_triqler
    final_result    = DIANN_CONVERT.out.out_mztab
    msstats_out     = ch_msstats_out
}

// remove meta.id to make sure cache identical HashCode
def preprocessed_meta(LinkedHashMap meta) {
    def parameters = [:]
    parameters['experiment_id']                 = meta.experiment_id
    parameters['acquisition_method']            = meta.acquisition_method
    parameters['dissociationmethod']            = meta.dissociationmethod
    parameters['labelling_type']                = meta.labelling_type
    parameters['fixedmodifications']            = meta.fixedmodifications
    parameters['variablemodifications']         = meta.variablemodifications
    parameters['precursormasstolerance']        = meta.precursormasstolerance
    parameters['precursormasstoleranceunit']    = meta.precursormasstoleranceunit
    parameters['fragmentmasstolerance']         = meta.fragmentmasstolerance
    parameters['fragmentmasstoleranceunit']     = meta.fragmentmasstoleranceunit
    parameters['enzyme']                        = meta.enzyme

    return parameters
}

/*
========================================================================================
    THE END
========================================================================================
*/
