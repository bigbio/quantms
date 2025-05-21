//
// ProteinQuant
//

include { ID_CONFLICT_RESOLVER as ID_CONFLICT_RESOLVER } from '../../modules/local/openms/id_conflict_resolver/main'
include { PROTEIN_QUANTIFIER as PROTEIN_QUANTIFIER  } from '../../modules/local/openms/protein_quantifier/main'
include { MSSTATS_CONVERTER as MSSTATS_CONVERTER   } from '../../modules/local/openms/msstats_converter/main'

workflow PROTEINQUANT {
    take:
    ch_conflict_file
    ch_expdesign_file

    main:
    ch_version = Channel.empty()

    ID_CONFLICT_RESOLVER(ch_conflict_file)
    ch_version = ch_version.mix(ID_CONFLICT_RESOLVER.out.versions)

    PROTEIN_QUANTIFIER(ID_CONFLICT_RESOLVER.out.pro_resconf, ch_expdesign_file)
    ch_version = ch_version.mix(PROTEIN_QUANTIFIER.out.versions)

    MSSTATS_CONVERTER(ID_CONFLICT_RESOLVER.out.pro_resconf, ch_expdesign_file, "ISO")
    ch_version = ch_version.mix(MSSTATS_CONVERTER.out.versions)

    emit:
    msstats_csv = MSSTATS_CONVERTER.out.out_msstats
    out_mztab   = PROTEIN_QUANTIFIER.out.out_mztab
    versions = ch_version
}
