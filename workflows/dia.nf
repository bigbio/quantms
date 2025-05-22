/*
========================================================================================
    IMPORT LOCAL MODULES/SUBWORKFLOWS
========================================================================================
*/

//
// MODULES: Local to the pipeline
//
include { GENERATE_CFG                } from '../modules/local/diann/generate_cfg/main'
include { CONVERT_RESULTS             } from '../modules/local/diann/convert_results/main'
include { MSSTATS_LFQ                 } from '../modules/local/msstats/msstats_lfq/main'
include { PRELIMINARY_ANALYSIS        } from '../modules/local/diann/preliminary_analysis/main'
include { ASSEMBLE_EMPIRICAL_LIBRARY  } from '../modules/local/diann/assemble_empirical_library/main'
include { INSILICO_LIBRARY_GENERATION } from '../modules/local/diann/insilico_library_generation/main'
include { INDIVIDUAL_ANALYSIS         } from '../modules/local/diann/individual_analysis/main'
include { FINAL_QUANTIFICATION        } from '../modules/local/diann/final_quantification/main'

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

    GENERATE_CFG(meta)
    ch_software_versions = ch_software_versions
        .mix(GENERATE_CFG.out.versions.ifEmpty(null))

    //
    // MODULE: SILICOLIBRARYGENERATION
    //
    if (params.diann_speclib != null && params.diann_speclib.toString() != "") {
        speclib = Channel.from(file(params.diann_speclib, checkIfExists: true))
    } else {
        INSILICO_LIBRARY_GENERATION(ch_searchdb, GENERATE_CFG.out.diann_cfg)
        speclib = INSILICO_LIBRARY_GENERATION.out.predict_speclib
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
        // MODULE: PRELIMINARY_ANALYSIS
        //
        if (params.random_preanalysis) {
            preanalysis_subset = ch_file_preparation_results
                .toSortedList{ a, b -> file(a[1]).getName() <=> file(b[1]).getName() }
                .flatMap()
                .randomSample(params.empirical_assembly_ms_n, params.random_preanalysis_seed)
            empirical_lib_files = preanalysis_subset
                .map { result -> result[1] }
                .collect( sort: { a, b -> file(a).getName() <=> file(b).getName() } )
            PRELIMINARY_ANALYSIS(preanalysis_subset.combine(speclib))
        } else {
            empirical_lib_files = ch_file_preparation_results
                .map { result -> result[1] }
                .collect( sort: { a, b -> file(a).getName() <=> file(b).getName() } )
            PRELIMINARY_ANALYSIS(ch_file_preparation_results.combine(speclib))
        }
        ch_software_versions = ch_software_versions
            .mix(PRELIMINARY_ANALYSIS.out.versions.ifEmpty(null))

        //
        // MODULE: ASSEMBLE_EMPIRICAL_LIBRARY
        //
        // Order matters in DIANN, This should be sorted for reproducible results.
        ASSEMBLE_EMPIRICAL_LIBRARY(
            empirical_lib_files,
            meta,
            PRELIMINARY_ANALYSIS.out.diann_quant.collect(),
            speclib
        )
        ch_software_versions = ch_software_versions
            .mix(ASSEMBLE_EMPIRICAL_LIBRARY.out.versions.ifEmpty(null))
        indiv_fin_analysis_in = ch_file_preparation_results
            .combine(ch_searchdb)
            .combine(ASSEMBLE_EMPIRICAL_LIBRARY.out.log)
            .combine(ASSEMBLE_EMPIRICAL_LIBRARY.out.empirical_library)

        empirical_lib = ASSEMBLE_EMPIRICAL_LIBRARY.out.empirical_library
    }

    //
    // MODULE: INDIVIDUAL_ANALYSIS
    //
    DIANN_INDIVIDUAL_ANALYSIS(indiv_fin_analysis_in)
    ch_software_versions = ch_software_versions
        .mix(DIANN_INDIVIDUAL_ANALYSIS.out.versions.ifEmpty(null))

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

    final_quantification(
        ms_file_names,
        meta,
        empirical_lib,
        DIANN_INDIVIDUAL_ANALYSIS.out.diann_quant.collect(),
        ch_searchdb)

    ch_software_versions = ch_software_versions.mix(
        final_quantification.out.versions.ifEmpty(null)
    )

    //
    // MODULE: DIANNCONVERT
    //
    diann_main_report = final_quantification.out.main_report.mix(final_quantification.out.report_parquet).last()

    CONVERT_RESULTS(
        diann_main_report, ch_expdesign,
        final_quantification.out.pg_matrix,
        final_quantification.out.pr_matrix, ch_ms_info,
        meta,
        ch_searchdb,
        final_quantification.out.versions
    )
    ch_software_versions = ch_software_versions
        .mix(CONVERT_RESULTS.out.versions.ifEmpty(null))

    //
    // MODULE: MSSTATS
    ch_msstats_out = Channel.empty()
    if (!params.skip_post_msstats) {
        MSSTATS_LFQ(CONVERT_RESULTS.out.out_msstats)
        ch_msstats_out = MSSTATS_LFQ.out.msstats_csv
        ch_software_versions = ch_software_versions.mix(
            MSSTATS_LFQ.out.versions.ifEmpty(null)
        )
    }

    emit:
    versions        = ch_software_versions
    diann_report    = final_quantification.out.main_report
    msstats_in      = CONVERT_RESULTS.out.out_msstats
    out_triqler     = CONVERT_RESULTS.out.out_triqler
    final_result    = CONVERT_RESULTS.out.out_mztab
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
