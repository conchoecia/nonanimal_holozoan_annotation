#!/bin/bash

#SBATCH --job-name=liftoff   # This is the name of the parent job
#SBATCH --nodes=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32GB
#SBATCH --partition=tttt,owners
#SBATCH --time=0-1:00:00
#SBATCH --mail-type=ALL
#SBATCH --output=%x-%j.out
#SBATCH --error=%x-%j.err

# Thes are example parameters for running the GAP NCBI FCS adapter tool
#   with SLURM, including the expected RAM consumption and time.

# For this script we are running the NCBI FCS adapter tool
CORES=24

source activate /home/users/darrints/miniforge3/envs/liftoff

INPUT_DIR=./input
mkdir -p "$INPUT_DIR"
PROCESSED_DIR=./processed
mkdir -p "$PROCESSED_DIR"

verify_md5() {
  local expected="$1"
  local file="$2"
  if [ ! -f "$file" ]; then
    echo "Missing $file"
    return 1
  fi
  local actual
  actual=$(md5sum "$file" | awk '{print $1}')
  if [ "$actual" != "$expected" ]; then
    echo "MD5 mismatch for $file"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    return 1
  fi
  return 0
}

download_and_verify() {
  local url="$1"
  local out="${2:-$(basename "$url")}"
  local expected="${3:-}"
  mkdir -p "$(dirname "$out")"
  if [ -f "$out" ]; then
    if [ -n "$expected" ]; then
      if verify_md5 "$expected" "$out"; then
        echo "Found $out (md5 ok), skipping download."
        return 0
      fi
      echo "Re-downloading $out due to MD5 mismatch."
      rm -f "$out"
    else
      echo "Found $out, skipping download."
      return 0
    fi
  fi
  echo "Downloading $out"
  wget -O "$out" "$url"
  if [ -n "$expected" ]; then
    verify_md5 "$expected" "$out"
  fi
}

ungzip_if_needed() {
  local gz="$1"
  local out="${gz%.gz}"
  if [ -f "$out" ]; then
    echo "Found $out, skipping ungzip."
    return 0
  fi
  if [ ! -f "$gz" ]; then
    echo "Missing $gz; cannot ungzip."
    return 1
  fi
  echo "Ungzipping $gz"
  gunzip -k -f "$gz"
}

# Get files for Capsaspora owczarzaki
download_and_verify 'https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/033/442/345/GCA_033442345.1_MBARI_Capsaspora_owczarzaki_A_v1/GCA_033442345.1_MBARI_Capsaspora_owczarzaki_A_v1_genomic.fna.gz' "$INPUT_DIR/GCA_033442345.1_MBARI_Capsaspora_owczarzaki_A_v1_genomic.fna.gz" '7a9961dce91ed900ad3cf7f83dbfe658'
download_and_verify 'https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/151/315/GCF_000151315.2_C_owczarzaki_V2/GCF_000151315.2_C_owczarzaki_V2_genomic.fna.gz' "$INPUT_DIR/GCF_000151315.2_C_owczarzaki_V2_genomic.fna.gz" '6a2bd7ce92dc8c8673598c15ac2faaa5'
download_and_verify 'https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/151/315/GCF_000151315.2_C_owczarzaki_V2/GCF_000151315.2_C_owczarzaki_V2_genomic.gff.gz' "$INPUT_DIR/GCF_000151315.2_C_owczarzaki_V2_genomic.gff.gz" '56f3dbe0ac204f5c30ecba4d622d6c2e'
download_and_verify 'https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/151/315/GCF_000151315.2_C_owczarzaki_V2/GCF_000151315.2_C_owczarzaki_V2_protein.faa.gz' "$INPUT_DIR/GCF_000151315.2_C_owczarzaki_V2_protein.faa.gz" '2397b406e77751a122367d032ccf76b0'

# Get files for Creolimax fragrantissima
download_and_verify 'https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/033/442/365/GCA_033442365.1_MBARI_Creolimax_fragrantissima_v1/GCA_033442365.1_MBARI_Creolimax_fragrantissima_v1_genomic.fna.gz' "$INPUT_DIR/GCA_033442365.1_MBARI_Creolimax_fragrantissima_v1_genomic.fna.gz" 'dee530474bc91d368f312010e9f84301'
download_and_verify 'https://ndownloader.figshare.com/files/3328022' "$INPUT_DIR/Creolimax_fragrantissima.genome.fasta.gz" 'd6feb7946e8b0afd1e4ef1ba703a268b'
download_and_verify 'https://ndownloader.figshare.com/files/3328013' "$INPUT_DIR/Creolimax_fragrantissima.gtf.gz" 'dcd581287224fd291e81604a9f377638'
download_and_verify 'https://ndownloader.figshare.com/files/3328016' "$INPUT_DIR/Creolimax_fragrantissima.pep.fasta.gz" '4297f0058ce78db9e92f7d32d57b22ac'

# Get files for Salpingoeca rosetta
download_and_verify 'https://ftp.ncbi.nlm.nih.gov/genomes/all/GCA/033/442/325/GCA_033442325.1_MBARI_Salpingoeca_rosetta_v1/GCA_033442325.1_MBARI_Salpingoeca_rosetta_v1_genomic.fna.gz' "$INPUT_DIR/GCA_033442325.1_MBARI_Salpingoeca_rosetta_v1_genomic.fna.gz" 'dcd4b693c227367357acdf9cfa926c8e'
download_and_verify 'https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/188/695/GCF_000188695.1_Proterospongia_sp_ATCC50818/GCF_000188695.1_Proterospongia_sp_ATCC50818_genomic.gff.gz' "$INPUT_DIR/GCF_000188695.1_Proterospongia_sp_ATCC50818_genomic.gff.gz" 'c99eabae2f2754c004dfae9a56feab03'
download_and_verify 'https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/188/695/GCF_000188695.1_Proterospongia_sp_ATCC50818/GCF_000188695.1_Proterospongia_sp_ATCC50818_genomic.fna.gz' "$INPUT_DIR/GCF_000188695.1_Proterospongia_sp_ATCC50818_genomic.fna.gz" 'cc3feb134051d666bc15db08d8dca3ad'
download_and_verify 'https://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/000/188/695/GCF_000188695.1_Proterospongia_sp_ATCC50818/GCF_000188695.1_Proterospongia_sp_ATCC50818_protein.faa.gz' "$INPUT_DIR/GCF_000188695.1_Proterospongia_sp_ATCC50818_protein.faa.gz" 'bbe9c47f0f5cc2e532c4642c1413db05'

# Ungzip all downloads (keep .gz)
ungzip_if_needed "$INPUT_DIR/GCA_033442345.1_MBARI_Capsaspora_owczarzaki_A_v1_genomic.fna.gz"
ungzip_if_needed "$INPUT_DIR/GCF_000151315.2_C_owczarzaki_V2_genomic.fna.gz"
ungzip_if_needed "$INPUT_DIR/GCF_000151315.2_C_owczarzaki_V2_genomic.gff.gz"
ungzip_if_needed "$INPUT_DIR/GCF_000151315.2_C_owczarzaki_V2_protein.faa.gz"
ungzip_if_needed "$INPUT_DIR/GCA_033442365.1_MBARI_Creolimax_fragrantissima_v1_genomic.fna.gz"
ungzip_if_needed "$INPUT_DIR/Creolimax_fragrantissima.genome.fasta.gz"
ungzip_if_needed "$INPUT_DIR/Creolimax_fragrantissima.gtf.gz"
ungzip_if_needed "$INPUT_DIR/Creolimax_fragrantissima.pep.fasta.gz"
ungzip_if_needed "$INPUT_DIR/GCA_033442325.1_MBARI_Salpingoeca_rosetta_v1_genomic.fna.gz"
ungzip_if_needed "$INPUT_DIR/GCF_000188695.1_Proterospongia_sp_ATCC50818_genomic.fna.gz"
ungzip_if_needed "$INPUT_DIR/GCF_000188695.1_Proterospongia_sp_ATCC50818_genomic.gff.gz"
ungzip_if_needed "$INPUT_DIR/GCF_000188695.1_Proterospongia_sp_ATCC50818_protein.faa.gz"


ANNOTA=$INPUT_DIR/GCF_000151315.2_C_owczarzaki_V2_genomic.gff
TARGET=$INPUT_DIR/GCA_033442345.1_MBARI_Capsaspora_owczarzaki_A_v1_genomic.fna
REFERE=$INPUT_DIR/GCF_000151315.2_C_owczarzaki_V2_genomic.fna
OUTGFF=Capsaspora_owczarzaki_liftoff.gff
liftoff -g ${ANNOTA} -o ${OUTGFF} ${TARGET} ${REFERE}

ANNOTA=$INPUT_DIR/Creolimax_fragrantissima.gtf
FIXED=$PROCESSED_DIR/Creolimax_fragrantissima.fixed.gtf
# Keep features that should already have gene_id/transcript_id
cp ${ANNOTA} ${FIXED}
sed -i.bak -E 's/\tgene\t([0-9]+)\t([0-9]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\tCFRCFR([^\t]+)$/\tgene\t\1\t\2\t\3\t\4\t\5\tgene_id "CFR\6";/' ${FIXED}
sed -i -E 's/\ttranscript\t([0-9]+)\t([0-9]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t(CFR[^T]+)(T[0-9]+)$/\ttranscript\t\1\t\2\t\3\t\4\t\5\tgene_id "\6"; transcript_id "\6\7";/' ${FIXED}
TARGET=$INPUT_DIR/GCA_033442365.1_MBARI_Creolimax_fragrantissima_v1_genomic.fna
REFERE=$INPUT_DIR/Creolimax_fragrantissima.genome.fasta
OUTGFF=Creolimax_fragrantissima_liftoff.gff
liftoff -g ${FIXED} -o ${OUTGFF} ${TARGET} ${REFERE}

ANNOTA=$INPUT_DIR/GCF_000188695.1_Proterospongia_sp_ATCC50818_genomic.gff
TARGET=$INPUT_DIR/GCA_033442325.1_MBARI_Salpingoeca_rosetta_v1_genomic.fna
REFERE=$INPUT_DIR/GCF_000188695.1_Proterospongia_sp_ATCC50818_genomic.fna
OUTGFF=Salpingoeca_rosetta_liftoff.gff
liftoff -g ${ANNOTA} -o ${OUTGFF} ${TARGET} ${REFERE}
