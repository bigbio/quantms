//
// ProteinInference
//

include { EPIFANY                                } from '../../modules/local/openms/epifany/main'
include { PROTEIN_INFERENCE as PROTEININFERENCER  } from '../../modules/local/openms/protein_inference/main'
include { ID_FILTER as IDFILTER                  } from '../../modules/local/openms/id_filter/main'

workflow PROTEININFERENCE {
    take:
    ch_consus_file

    main:
    ch_version = Channel.empty()

    if (params.protein_inference_method == "bayesian") {
        EPIFANY(ch_consus_file)
        ch_version = ch_version.mix(EPIFANY.out.versions)
        ch_inference = EPIFANY.out.epi_inference
    } else {
        PROTEININFERENCER(ch_consus_file)
        ch_version = ch_version.mix(PROTEININFERENCER.out.versions)
        ch_inference = PROTEININFERENCER.out.protein_inference
    }

    IDFILTER(ch_inference)
    ch_version = ch_version.mix(IDFILTER.out.versions)
    IDFILTER.out.id_filtered
        .multiMap{ it ->
            meta: it[0]
            results: it[1]
            }
        .set{ ch_epi_results }

    emit:
    epi_idfilter    = ch_epi_results.results

    versions         = ch_version

}
