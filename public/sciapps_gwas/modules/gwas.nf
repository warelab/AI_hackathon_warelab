/*
 * Preprocess VCF/HapMap: format → IUPAC coding
 * Detects input format by content (VCF, regular HapMap, IUPAC HapMap).
 */
process preprocess_vcf {
    label 'medium'

    publishDir "${params.outdir}", mode: 'copy'

    input:
        path vcf

    output:
        path "${vcf.simpleName}.hmp.txt.gz", emit: marker_hmp

    script:
    """
    set -e
    # vcf_to_hapmap.sh v3 — fix GT parsing from first data line (not #CHROM header)
    cp ${params.scripts}/formatter/detect_format.sh .
    cp ${params.scripts}/formatter/hapmap_to_iupac.sh .
    cp ${params.scripts}/formatter/format_vcf.sh .
    cp ${params.scripts}/formatter/vcf_to_hapmap.sh .
    fmt=\$(bash detect_format.sh "$vcf")
    fname=\$(basename "$vcf")
    base=\${fname%%.*}
    case "\$fmt" in
      vcf)
        bash format_vcf.sh --input "$vcf"
        bash vcf_to_hapmap.sh "$vcf" "\${base}.regular.hmp.txt.gz"
        bash hapmap_to_iupac.sh "\${base}.regular.hmp.txt.gz" "\${base}.hmp.txt.gz"
        ;;
      hapmap_regular)
        bash hapmap_to_iupac.sh "$vcf" "\${base}.hmp.txt.gz"
        ;;
      hapmap_iupac)
        zcat -f "$vcf" | gzip > "\${base}.hmp.txt.gz"
        ;;
      *)
        echo "ERROR: Unknown input format: \$fmt" >&2
        exit 1
        ;;
    esac
    """
}

/*
 * Preprocess trait: extract key/value columns
 */
process preprocess_trait {
    label 'light'

    publishDir "${params.outdir}", mode: 'copy'

    input:
        path trait

    output:
        path "${trait.simpleName}_*.txt", emit: trait_proc

    script:
    """
    set -e
    cp ${params.scripts}/formatter/extract_cols.sh .
    cp ${params.scripts}/formatter/detect_key_columns.sh .

    if [ -n "${params.trait_value_columns}" ]; then
        for col in \$(echo "${params.trait_value_columns}" | tr ',' ' '); do
            bash extract_cols.sh --input "$trait" \\
                ${params.trait_key_column ? "--key_column ${params.trait_key_column}" : ''} \\
                --value_column "\$col" \\
                --header_lines ${params.trait_header_lines} \\
                --output ${trait.simpleName}_\${col}.txt
        done
    else
        key_info=\$(bash detect_key_columns.sh --input "$trait" ${params.trait_key_column ? "--key_column ${params.trait_key_column}" : ''})
        key_idx=\$(echo "\$key_info" | head -1)
        cols=\$(echo "\$key_info" | tail -n +2)
        for col in \$cols; do
            bash extract_cols.sh --input "$trait" \\
                --key_column "\$key_idx" \\
                --value_column "\$col" \\
                --header_lines ${params.trait_header_lines} \\
                --output ${trait.simpleName}_\${col}.txt
        done
    fi
    """
}

/*
 * Intersecting genotype data with phenotype data
 */
process mergeg2p {
    label 'light'

    publishDir "${params.outdir}", mode: 'copy'

    input:
        tuple val(trait_name), path(marker), path(trait)

    output:
        tuple val(trait_name), path("mm_${trait_name}_${marker}"), emit: mm
        tuple val(trait_name), path("mt1_${trait_name}_${marker.simpleName}"), emit: mt1

    script:

    """
    set -e
    export CONDA_PREFIX=${params.conda}
    export PATH=\${CONDA_PREFIX}/bin:\$PATH
    export sid=${marker}
    export trait=${trait}
    export extracols=11
    export headlines=1
    cp ${params.scripts}/mergeg2p/* .
    chmod +x wrapper.sh
    sh wrapper.sh
    mv mm_${marker} mm_${trait_name}_${marker}
    mv mt1_${marker.simpleName}.${trait} mt1_${trait_name}_${marker.simpleName}
    """
}

/*
 * Imputing missing SNPs
 */
process npute {
    label 'medium'

    publishDir "${params.outdir}", mode: 'copy'

    input:
        tuple val(trait_name), path(mm)

    output:
        tuple val(trait_name), path("npt_${mm}"), emit: npt

    script:
    """
    set -e
    export CONDA_PREFIX=${params.conda}
    export PATH=\${CONDA_PREFIX}/bin:\$PATH
    export i=${mm}
    export stepWindow=1
    export endWindow=5
    export mode=Imputing
    export missing=N
    export startWindow=2
    export ploidy=1
    export extracols=11
    export header=1
    cp ${params.scripts}/npute/* .
    chmod +x wrapper.sh
    sh wrapper.sh
    """
}

/*
 * Numerical Transform of marker data
 */
process numericaltransform {
    label 'medium'

    publishDir "${params.outdir}", mode: 'copy'

    input:
        tuple val(trait_name), path(npt)

    output:
        tuple val(trait_name), path("nt1_marker_${npt.simpleName}.txt.gz"), emit: nt1
        tuple val(trait_name), path("nt2mlmm_${npt.simpleName}.txt.gz"), emit: nt2
        tuple val(trait_name), path("nt3_${npt.simpleName}.tfam"), emit: nt3
        tuple val(trait_name), path("nt4_${npt.simpleName}.tped.gz"), emit: nt4

    script:
    """
    set -e
    export CONDA_PREFIX=${params.conda}
    export PATH=\${CONDA_PREFIX}/bin:\$PATH
    export h=${npt}
    export numericalGenoTransform=collapse
    export markerformat=Hapmap
    export minfreq=0.05
    cp ${params.scripts}/tassel/nt/* .
    chmod +x wrapper.sh
    sh wrapper.sh
    mv nt1_marker.txt.gz nt1_marker_${npt.simpleName}.txt.gz
    mv nt2mlmm.txt.gz nt2mlmm_${npt.simpleName}.txt.gz
    mv nt3.tfam nt3_${npt.simpleName}.tfam
    mv nt4.tped.gz nt4_${npt.simpleName}.tped.gz
    """
}

/*
 * Perform PCA with R's prcomp function
 */
process pca {
    label 'light'

    publishDir "${params.outdir}", mode: 'copy'

    input:
        tuple val(trait_name), path(npt)

    output:
        tuple val(trait_name), path("pca_${npt.simpleName}.txt"), emit: pca
        tuple val(trait_name), path("scree_${npt.simpleName}.png"), emit: scree
        tuple val(trait_name), path("pcplot_${npt.simpleName}.png"), emit: pcplot

    script:
    """
    set -e
    export CONDA_PREFIX=${params.conda}
    export PATH=\${CONDA_PREFIX}/bin:\$PATH
    export input=${npt}
    export numPCs=3
    export model=pca
    cp ${params.scripts}/pca/* .
    chmod +x wrapper.sh
    sh wrapper.sh
    mv pca_output.txt pca_${npt.simpleName}.txt
    mv scree_out.png scree_${npt.simpleName}.png
    mv pcplot_out.png pcplot_${npt.simpleName}.png
    """
}

/*
 * Mixed Linear Model analysis
 */
process mlm {
    label 'medium'

    publishDir "${params.outdir}", mode: 'copy'

    input:
        tuple val(trait_name), path(npt), path(pca), path(mt1)

    output:
        tuple val(trait_name), path("mlm1_${npt.simpleName}.txt"), emit: mlm1
        tuple val(trait_name), path("mlm2_${npt.simpleName}.txt"), emit: mlm2
        tuple val(trait_name), path("mlm3_${npt.simpleName}.txt"), emit: mlm3
        tuple val(trait_name), path("mlm4_${npt.simpleName}.txt"), emit: mlm4
        tuple val(trait_name), path("manhattan_plot_mlm_${npt.simpleName}.view.tgz"), emit: manh

    script:
    """
    set -e
    export CONDA_PREFIX=${params.conda}
    export PATH=\${CONDA_PREFIX}/bin:\$PATH
    export hmarker=${npt}
    export rtrait=${mt1}
    export qstructure=${pca}
    export level=1
    export mlmVarCompEst=P3D
    export filter=0.05
    export markerformat=Hapmap
    export maxp=1
    export mlmCompressionLevel=Optimum

    cp ${params.scripts}/tassel/mlm/* .
    chmod +x wrapper.sh
    sh wrapper.sh
    mv MLM1.txt mlm1_${npt.simpleName}.txt
    mv MLM2.txt mlm2_${npt.simpleName}.txt
    mv MLM3.txt mlm3_${npt.simpleName}.txt
    mv MLM4.txt mlm4_${npt.simpleName}.txt
    mv manhattan_plot.view.tgz manhattan_plot_mlm_${npt.simpleName}.view.tgz
    """
}

/*
 * Efficient Mixed-Model Association eXpedited
 */
process emmax {
    label 'medium'

    publishDir "${params.outdir}", mode: 'copy'

    input:
        tuple val(trait_name), path(tfam), path(tped), path(mt1)

    output:
        tuple val(trait_name), path("emmax_${tfam.simpleName}.reml"), emit: emmax
        tuple val(trait_name), path("pval_emmax_${tfam.simpleName}.ps"), emit: pval
        tuple val(trait_name), path("manhattan_emmax_${tfam.simpleName}.plot"), emit: manh

    script:
    """
    set -e
    export CONDA_PREFIX=${params.conda}
    export PATH=\${CONDA_PREFIX}/bin:\$PATH
    export tfam=${tfam}
    export pheno=${mt1}
    export tped=${tped}
    export kin_method=BN
    export header=1

    cp ${params.scripts}/emmax/* .
    chmod +x wrapper.sh
    sh wrapper.sh
    mv EMMAX.reml emmax_${tfam.simpleName}.reml
    mv pval_EMMAX.ps pval_emmax_${tfam.simpleName}.ps
    mv manhattan.plot manhattan_emmax_${tfam.simpleName}.plot
    """
}
