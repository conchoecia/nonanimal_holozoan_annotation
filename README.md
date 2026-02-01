# Nonanimal holozoan genome annotations

This repository contains genome annotations for the nonanimal holozoan species _Creolimax fragrantissima_, _Capsaspora owczarzaki_, and _Salpingoeca rosetta_. In the [Dryad repository](https://datadryad.org/dataset/doi:10.5061/dryad.dncjsxm47) for [Schultz et al. (2023)](https://www.nature.com/articles/s41586-023-05936-6), the genome annotation files (.gff) were not included with the genome assemblies (.fa), protein fasta files (.pep), and gene coordinate files (.chrom). This repository newly generates the annotation files (.gff) for comparative genomics studies.


`READ THIS  vvvvvvvvvvvvvv`

The generated annotations are available in the `annotations/` directory (GFF, PEP, and CHROM files for each species).

These are annotations for the chromosome-scale assemblies we published in 2023, where I generated Hi-C data from ATCC samples while in Steve Haddock's lab at MBARI, then scaffolded and annotated existing assemblies to chromosome scale with Jessen Bredeson. [Please see the manuscript](https://www.nature.com/articles/s41586-023-05936-6) for citations and methods about the original genome assemblies and the scaffolding.
- _Capsaspora owczarzaki_: [GCA_033442345.1_MBARI_Capsaspora_owczarzaki_A_v1_genomic.fna.gz](https://www.ncbi.nlm.nih.gov/datasets/genome/GCA_033442345.1/)
- _Creolimax fragrantissima_: [GCA_033442365.1_MBARI_Creolimax_fragrantissima_v1_genomic.fna.gz](https://www.ncbi.nlm.nih.gov/datasets/genome/GCA_033442365.1/)
- _Salpingoeca rosetta_: [GCA_033442325.1_MBARI_Salpingoeca_rosetta_v1_genomic.fna.gz](https://www.ncbi.nlm.nih.gov/datasets/genome/GCA_033442325.1/)

`READ THIS  ^^^^^^^^^^^^^^`

## Requirements

IF you want to generate the annotations from scratch for yourself for comparison, the bash script `run_annotation.sh` will generate the same files that are in the `./annotations` directory.
This script requires the following software to be available on your `PATH` (or in your activated environment) before running. 

- [Liftoff](https://github.com/agshumate/Liftoff)
- [gffread](https://github.com/gpertea/gffread) (the script can clone/build it if `git` + `make` are available)
- `samtools` (for `.pep` extraction)
- `wget`, `gzip`, and `tar` (for downloads and unpacking)
- `python3` (for comparison steps)

run with:

```sh
git clone https://github.com/conchoecia/nonanimal_holozoan_annotation.git
cd nonanimal_holozoan_annotation
bash run_annotation.sh
```

This will generate files comparing the annotations published here with the .chrom files published in the 2023 Dryad repository: [Dryad repository](https://datadryad.org/dataset/doi:10.5061/dryad.dncjsxm47)

## Citation

If you use the chrom files in `Schultzetal2023/`, cite the Dryad dataset as the source:

- Schultz, D. T., Haddock, S. H. D., Bredeson, J. V., Green, R. E., Simakov, O., & Rokhsar, D. S. (2023). Data for: Ancient gene linkages support ctenophores as sister to other animals [Dataset]. Dryad. [https://doi.org/10.5061/dryad.dncjsxm47](https://doi.org/10.5061/dryad.dncjsxm47)

If you use results derived from this repository, please cite:

- Schultz, D. T., Haddock, S. H., Bredeson, J. V., Green, R. E., Simakov, O., & Rokhsar, D. S. (2023). Ancient gene linkages support ctenophores as sister to other animals. Nature, 618(7963), 110-117. [https://www.nature.com/articles/s41586-023-05936-6](https://www.nature.com/articles/s41586-023-05936-6)

## Comparison with Schultz et al. (2023) .chrom files

We compared these annotations to the Schultz et al. (2023) chrom files and gene-group list. The annotations are consistent with the versions used in that study.


- **Chrom overlap (protein IDs):**
  - **CFR:** 8408 / 8416 proteins overlap (99.90% of old; 98.51% of new)
  - **COW:** 8742 / 8791 proteins overlap (99.44% of old; 100.00% of new)
  - **SRO:** 11669 / 11669 proteins overlap (100.00% of old; 99.52% of new)

All of the gene families in the three species from the ALGs defined in Schultz et al. (2023) are present in these annotations. These annotations therefore do not affect the conclusions of Schultz et al. (2023).

- **Gene-group presence (UnicellMetazoanLGs.rbh):**
  - **CFR:** 55 / 55 groups present (100.00%)
  - **COW:** 213 / 213 groups present (100.00%)
  - **SRO:** 150 / 150 groups present (100.00%)


My raw output when running the above script, `run_annotation.sh`, yields:

```
./CFR_summary.txt
new_file	Creolimax_fragrantissima.chrom
old_file	schultz2023/CFR.chrom
new_proteins	8535
old_proteins	8416
intersection	8408
intersection_frac_new	0.985120
intersection_frac_old	0.999049

./COW_summary.txt
new_file	Capsaspora_owczarzaki.chrom
old_file	schultz2023/COW.chrom
new_proteins	8742
old_proteins	8791
intersection	8742
intersection_frac_new	1.000000
intersection_frac_old	0.994426

./SRO_summary.txt
new_file	Salpingoeca_rosetta.chrom
old_file	schultz2023/SRO.chrom
new_proteins	11725
old_proteins	11669
intersection	11669
intersection_frac_new	0.995224
intersection_frac_old	1.000000

./UnicellMetazoanLGs_summary.txt
rows	312
COW_present	213
COW_total	213
COW_fraction	1.000000
SRO_present	150
SRO_total	150
SRO_fraction	1.000000
CFR_present	55
CFR_total	55
CFR_fraction	1.000000
```
