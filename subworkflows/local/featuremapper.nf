//
// Assigns protein/peptide identifications to features or consensus features.
//

params.isobaric = [:]
params.idmapper = [:]

include { ISOBARICANALYZER } from '../../modules/local/openms/isobaricanalyzer/main' addParams( options: params.isobaric )
include { IDMAPPER } from '../../modules/local/openms/idmapper/main' addParams( options: params.idmapper )

workflow FEATUREMAPPER {
    take:
    mzml_files
    id_files

    main:
    ch_version = Channel.empty()

    ISOBARICANALYZER(mzml_files)
    ch_version = ch_version.mix(ISOBARICANALYZER.out.version)

    IDMAPPER(id_files.combine(ISOBARICANALYZER.out.id_files_consensusXML, by: 0))
    ch_version = ch_version.mix(IDMAPPER.out.version)

    emit:
    id_map  = IDMAPPER.out.id_map

    version = ch_version
}
