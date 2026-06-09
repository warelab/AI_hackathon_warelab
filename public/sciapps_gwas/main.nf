// Include modules
include { preprocess_vcf; preprocess_trait;
          mergeg2p; npute; numericaltransform; pca; mlm; emmax } from './modules/gwas.nf'

workflow {

    main:
    vcf_ch = Channel.fromPath(params.marker_files)
            .splitText()
            .map { line -> line.trim() }
            .filter { line -> line.length() > 0 && !line.startsWith('#') }
            .map { line -> file(line) }
            .ifEmpty { error "No marker files found in: ${params.marker_files}" }

    trait_ch = Channel.fromPath(params.trait, checkIfExists: true)
            .ifEmpty { error "Trait file not found: ${params.trait}" }

    // Preprocess
    vcf_hmp = preprocess_vcf(vcf_ch)
    trait_proc = preprocess_trait(trait_ch)

    // Emit (tn, trait_file) so join auto-matches on tn
    trait_files = trait_proc.trait_proc.flatten().map { tf ->
        def tn = tf.simpleName - "${file(params.trait).simpleName}_"
        tuple(tn, tf)
    }

    // Build (tn, marker, trait) triples for mergeg2p
    pairs = vcf_hmp.combine(trait_files).map {
        tuple(it[1], it[0], it[2])
    }

    // Downstream (runs in parallel per VCF per trait)
    mm = mergeg2p(pairs)
    npt = npute(mm.mm)
    nt = numericaltransform(npt.npt)
    pca_out = pca(npt.npt)

    // Join channels by trait_name (first tuple element = tn)
    mlm( npt.npt.join(pca_out.pca).join(mm.mt1) )
    emmax( nt.nt3.join(nt.nt4).join(mm.mt1) )

}
