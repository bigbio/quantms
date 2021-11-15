//
// ProteinInference
//

params.epifany = [:]
params.protein_inference = [:]
params.epifilter = [:]

include { EPIFANY } from '../../modules/local/openms/epifany/main' addParams( options: params.epifany )
include { PROTEININFERENCE as PROTEIN_INFERENCE} from '../../modules/local/openms/proteininference/main' addParams( options: params.protein_inference )
include { IDFILTER as EPIFILTER } from '../../modules/local/openms/idfilter/main' addParams( options: params.epifilter )

workflow PROTEININFERENCE {
    take:
    consus_file

    main:
    ch_version = Channel.empty()

    if (params.protein_inference_bayesian) {
        EPIFANY(consus_file)
        ch_version = ch_version.mix(EPIFANY.out.version)
        ch_epifilter = EPIFANY.out.epi_inference
    } else {
        PROTEIN_INFERENCE(consus_file)
        ch_version = ch_version.mix(PROTEIN_INFERENCE.out.version)
        ch_epifilter = PROTEIN_INFERENCE.out.protein_inference
    }

    EPIFILTER(ch_epifilter)
    ch_version = ch_version.mix(EPIFILTER.out.version)
    EPIFILTER.out.id_filtered
        .multiMap{ it ->
            meta: it[0]
            results: it[1]
            }
        .set{ epi_results }

    emit:
    epi_idfilter    = epi_results.results

    version         = ch_version

}
