##nextflow run main.nf --marker_files test_data/vcf_list.txt --trait test_data/SAP_TEST_Phenotype_Data.txt --trait_key_column FULL_NEW_Publ --trait_header_lines 2 -resume -bg 1 >| run.log 2>&1
nextflow run main.nf --marker_files test_data/hmp_list.txt --trait test_data/trait.txt -resume -bg 1 >| run.log 2>&1
