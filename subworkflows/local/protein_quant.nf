//
// ProteinQuant
//

include { ID_CONFLICT_RESOLVER as IDCONFLICTRESOLVER } from '../../modules/local/openms/id_conflict_resolver/main'
include { PROTEIN_QUANTIFIER as PROTEINQUANTIFIER  } from '../../modules/local/openms/protein_quantifier/main'
include { MSSTATS_CONVERTER as MSSTATSCONVERTER   } from '../../modules/local/openms/msstats_converter/main'

workflow PROTEINQUANT {
    take:
    ch_conflict_file
    ch_expdesign_file

    main:
    ch_version = Channel.empty()

    IDCONFLICTRESOLVER(ch_conflict_file)
    ch_version = ch_version.mix(IDCONFLICTRESOLVER.out.versions)

    PROTEINQUANTIFIER(IDCONFLICTRESOLVER.out.pro_resconf, ch_expdesign_file)
    ch_version = ch_version.mix(PROTEINQUANTIFIER.out.versions)

    MSSTATSCONVERTER(IDCONFLICTRESOLVER.out.pro_resconf, ch_expdesign_file, "ISO")
    ch_version = ch_version.mix(MSSTATSCONVERTER.out.versions)

    emit:
    msstats_csv = MSSTATSCONVERTER.out.out_msstats
    out_mztab   = PROTEINQUANTIFIER.out.out_mztab
    versions = ch_version
}
