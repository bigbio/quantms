//
// Assigns protein/peptide identifications to features or consensus features.
//

include { ISOBARICANALYZER } from '../../modules/local/openms/isobaricanalyzer/main'
include { IDMAPPER         } from '../../modules/local/openms/idmapper/main'

workflow FEATUREMAPPER {
    take:
    ch_mzml_files
    ch_id_files

    main:
    ch_version = Channel.empty()

    ISOBARICANALYZER(ch_mzml_files)
    ch_version = ch_version.mix(ISOBARICANALYZER.out.versions)

    IDMAPPER(ch_id_files.combine(ISOBARICANALYZER.out.id_files_consensusXML, by: 0))
    ch_version = ch_version.mix(IDMAPPER.out.versions)

    emit:
    id_map  = IDMAPPER.out.id_map

    versions = ch_version
}
