//
// Check input sdrf and get read channels
//

params.options = [:]

include { SDRF_CHECK } from '../../modules/local/sdrf_check' addParams( options: params.options )

workflow INPUT_CHECK {
    take:
    sdrf_file // file: /path/to/*.sdrf.csv

    main:
    ch_logs = Channel.empty()

    SDRF_CHECK ( sdrf_file )
    ch_logs = ch_logs.mix(SDRF_CHECK.out.log)

    emit:
    ch_logs      = ch_logs
    ch_sdrf_file = SDRF_CHECK.out.sdrf
}
