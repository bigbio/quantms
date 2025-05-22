//
// ProteinInference
//

include { PROTEIN_INFERENCE_EPIFANY } from '../../../modules/local/openms/protein_inference_epifany/main'
include { PROTEIN_INFERENCE_GENERIC } from '../../../modules/local/openms/protein_inference_generic/main'
include { ID_FILTER                 } from '../../../modules/local/openms/id_filter/main'

workflow PROTEIN_INFERENCE {
    take:
    ch_consus_file

    main:
    ch_version = Channel.empty()

    if (params.protein_inference_method == "bayesian") {
        PROTEIN_INFERENCE_EPIFANY(ch_consus_file)
        ch_version = ch_version.mix(PROTEIN_INFERENCE_EPIFANY.out.versions)
        ch_inference = PROTEIN_INFERENCE_EPIFANY.out.epi_inference
    } else {
        PROTEIN_INFERENCE_GENERIC(ch_consus_file)
        ch_version = ch_version.mix(PROTEIN_INFERENCE_GENERIC.out.versions)
        ch_inference = PROTEIN_INFERENCE_GENERIC.out.protein_inference
    }

    ID_FILTER(ch_inference)
    ch_version = ch_version.mix(ID_FILTER.out.versions)
    ID_FILTER.out.id_filtered
        .multiMap{ it ->
            meta: it[0]
            results: it[1]
            }
        .set{ ch_epi_results }

    emit:
    epi_idfilter    = ch_epi_results.results

    versions         = ch_version

}
