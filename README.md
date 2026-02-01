# Nonanimal holozoan genome annotations

This repository contains genome annotations for the nonanimal holozoan species _Creolimax fragrantissima_, _Capsaspora owczarzaki_, and _Salpingoeca rosetta_. In the [Dryad repository](https://datadryad.org/dataset/doi:10.5061/dryad.dncjsxm47) for Schultz et al. (2023), the genome annotation files (.gff) were not included with the genome assemblies (.fa), protein fasta files (.pep), and gene coordinate files (.chrom). This repository newly generates the annotation files (.gff) for comparative genomics studies.


`READ THIS  vvvvvvvvvvvvvv`
The generated annotations are available in the `annotations/` directory (GFF, PEP, and CHROM files for each species).
`READ THIS  ^^^^^^^^^^^^^^`

## Requirements

This workflow requires the following software to be available on your `PATH` (or in your activated environment) before running `run_annotation.sh`:

- [Liftoff](https://github.com/agshumate/Liftoff)
- [gffread](https://github.com/gpertea/gffread) (the script can clone/build it if `git` + `make` are available)
- `samtools` (for `.pep` extraction)
- `wget`, `gzip`, and `tar` (for downloads and unpacking)
- `python3` (for comparison steps)

## Citation

If you use the chrom files in `Schultzetal2023/`, cite the Dryad dataset as the source:

- Schultz, D. T., Haddock, S. H. D., Bredeson, J. V., Green, R. E., Simakov, O., & Rokhsar, D. S. (2023). Data for: Ancient gene linkages support ctenophores as sister to other animals [Dataset]. Dryad. https://doi.org/10.5061/dryad.dncjsxm47

If you use results derived from this repository, please cite:

- Schultz, D. T., Haddock, S. H., Bredeson, J. V., Green, R. E., Simakov, O., & Rokhsar, D. S. (2023). Ancient gene linkages support ctenophores as sister to other animals. Nature, 618(7963), 110-117. https://www.nature.com/articles/s41586-023-05936-6

## Validation against Schultz et al. (2023)

We compared these annotations to the Schultz et al. (2023) chrom files and gene-group list. The annotations are consistent with the versions used in that study.

- **Chrom overlap (protein IDs):**
  - **CFR:** 8408 / 8416 proteins overlap (99.90% of old; 98.51% of new)
  - **COW:** 8742 / 8791 proteins overlap (99.44% of old; 100.00% of new)
  - **SRO:** 11669 / 11669 proteins overlap (100.00% of old; 99.52% of new)

All of the gene families in the three species from the ALGs defined in Schultz et al. (2023) are present in these annotations. Therefore, these annotations do not affect the conclusions of Schultz et al. (2023).

- **Gene-group presence (UnicellMetazoanLGs.rbh):**
  - **CFR:** 55 / 55 groups present (100.00%)
  - **COW:** 213 / 213 groups present (100.00%)
  - **SRO:** 150 / 150 groups present (100.00%)
