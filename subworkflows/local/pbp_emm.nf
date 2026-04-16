include { SHOVILL       } from '../../modules/local/shovill/shovill'
include { PBP_TYPER     } from '../../modules/local/pbp_typer/pbp_typer'
include { EMM_TYPER     } from '../../modules/local/emm_typer/emm_typer'


workflow PBP_EMM {
    take:
    ch_reads

    main:

    ch_versions = channel.empty()

    //
    // SHOVILL: assemble reads into contigs
    //
    SHOVILL (
        // tuple val(meta), path(reads)
        ch_reads
    )
    ch_versions = ch_versions.mix(SHOVILL.out.versions())

    //
    // PBP_TYPER: type penicillin binding proteins
    //
    PBP_TYPER (
        // tuple val(meta), path(fasta)
        // path(db)
        SHOVILL.out.contigs
    )

    //
    // EMM_TYPER: type emm gene
    //
    EMM_TYPER (
        // tuple val(meta), file(contigs), file(script)
        SHOVILL.out.contigs
    )

    emit:
    versions = ch_versions
    // TODO: PBP output type
    // TODO: EMM type sequences
    // TODO: PHYLOGENETICS
    // TODO: QUAST
}
