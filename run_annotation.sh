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
CHROM_LIST_DIR=./chrom_lists
mkdir -p "$CHROM_LIST_DIR"
SCHULTZ_DIR=./schultz2023
mkdir -p "$SCHULTZ_DIR"
SCRIPTS_DIR=./scripts
mkdir -p "$SCRIPTS_DIR"
COMPARE_DIR=./chrom_compare
mkdir -p "$COMPARE_DIR"
ANNOTATIONS_DIR=./annotations
mkdir -p "$ANNOTATIONS_DIR"
TOOLS_DIR=./tools
GFFREAD_DIR=$TOOLS_DIR/gffread
GFFREAD_BIN=$GFFREAD_DIR/gffread
mkdir -p "$TOOLS_DIR"

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
  if ! wget -O "$out" "$url"; then
    rm -f "$out"
    return 1
  fi
  if [ -n "$expected" ]; then
    verify_md5 "$expected" "$out" || return 1
  fi
}

unpack_tar_if_needed() {
  local tarball="$1"
  local outdir="$2"
  local marker="$outdir/.unpacked"
  if [ -f "$marker" ]; then
    echo "Found $marker, skipping unpack."
    return 0
  fi
  if [ ! -s "$tarball" ]; then
    echo "Missing or empty $tarball; cannot unpack."
    return 1
  fi
  if ! gzip -t "$tarball" >/dev/null 2>&1; then
    echo "Invalid gzip archive: $tarball"
    return 1
  fi
  mkdir -p "$outdir"
  echo "Unpacking $tarball into $outdir"
  if tar -xzf "$tarball" -C "$outdir"; then
    touch "$marker"
  else
    return 1
  fi
}

ensure_gffread() {
  if [ -x "$GFFREAD_BIN" ]; then
    return 0
  fi
  if [ ! -d "$GFFREAD_DIR" ]; then
    git clone https://github.com/gpertea/gffread "$GFFREAD_DIR"
  fi
  (cd "$GFFREAD_DIR" && make release)
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
  local tmp="${out}.tmp.$$"
  if gzip -cd "$gz" > "$tmp"; then
    mv "$tmp" "$out"
  else
    rm -f "$tmp"
    return 1
  fi
}

chrom_from_gtf() {
  local gtf="$1"
  local out="$2"
  local tmp="${out}.tmp.$$"
  awk -F'\t' '
  $0 !~ /^#/ && $3=="CDS" {
    tid=""
    n=split($9,a,";")
    for(i=1;i<=n;i++){
      gsub(/^ +| +$/,"",a[i])
      if(a[i] ~ /^transcript_id /){
        sub(/^transcript_id[ ]+/,"",a[i]); gsub(/"/,"",a[i]); tid=a[i]
      }
    }
    if(tid!=""){
      if(!(tid in min) || $4<min[tid]) min[tid]=$4
      if(!(tid in max) || $5>max[tid]) max[tid]=$5
      seq[tid]=$1; strand[tid]=$7
    }
  }
  END{ for(tid in min) print tid, seq[tid], strand[tid], min[tid], max[tid] }
  ' OFS='\t' "$gtf" > "$tmp"
  sort -t $'\t' -k2,2 -k4,4n -k5,5n "$tmp" > "$out"
  rm -f "$tmp"
}

chrom_from_gff() {
  local gff="$1"
  local out="$2"
  local tmp="${out}.tmp.$$"
  awk -F'\t' '
  $0 !~ /^#/ && $3=="CDS" {
    pid=""
    n=split($9,a,";")
    for(i=1;i<=n;i++){
      if(a[i] ~ /^protein_id=/){ sub(/^protein_id=/,"",a[i]); pid=a[i] }
    }
    if(pid!=""){
      if(!(pid in min) || $4<min[pid]) min[pid]=$4
      if(!(pid in max) || $5>max[pid]) max[pid]=$5
      seq[pid]=$1; strand[pid]=$7
    }
  }
  END{ for(pid in min) print pid, seq[pid], strand[pid], min[pid], max[pid] }
  ' OFS='\t' "$gff" > "$tmp"
  sort -t $'\t' -k2,2 -k4,4n -k5,5n "$tmp" > "$out"
  rm -f "$tmp"
}

chrom_from_gff_transcript() {
  local gff="$1"
  local out="$2"
  local tmp="${out}.tmp.$$"
  awk -F'\t' '
  $0 !~ /^#/ && $3=="CDS" {
    tid=""
    n=split($9,a,";")
    for(i=1;i<=n;i++){
      if(a[i] ~ /^transcript_id=/){ sub(/^transcript_id=/,"",a[i]); tid=a[i] }
      if(tid=="" && a[i] ~ /^Parent=/){
        sub(/^Parent=/,"",a[i]); split(a[i],p,","); tid=p[1]
      }
    }
    if(tid!=""){
      if(!(tid in min) || $4<min[tid]) min[tid]=$4
      if(!(tid in max) || $5>max[tid]) max[tid]=$5
      seq[tid]=$1; strand[tid]=$7
    }
  }
  END{ for(tid in min) print tid, seq[tid], strand[tid], min[tid], max[tid] }
  ' OFS='\t' "$gff" > "$tmp"
  sort -t $'\t' -k2,2 -k4,4n -k5,5n "$tmp" > "$out"
  rm -f "$tmp"
}

ids_from_chrom() {
  local chrom="$1"
  local out="$2"
  if [ ! -f "$chrom" ]; then
    echo "Missing $chrom; cannot build ID list."
    return 1
  fi
  cut -f1 "$chrom" | sort -u > "$out"
}

pep_from_list() {
  local ids="$1"
  local fa="$2"
  local out="$3"
  if [ ! -f "$ids" ]; then
    echo "Missing $ids; cannot build pep file."
    return 1
  fi
  if [ ! -f "$fa" ]; then
    echo "Missing $fa; cannot build pep file."
    return 1
  fi
  if [ -f "$out" ]; then
    echo "Found $out, skipping pep extraction."
    return 0
  fi
  samtools faidx "$fa"
  samtools faidx -r "$ids" "$fa" > "$out"
}

run_liftoff_if_missing() {
  local out="$1"
  shift
  if [ -f "$out" ]; then
    echo "Found $out, skipping liftoff."
    return 0
  fi
  "$@"
}

compare_chroms() {
  local new_chrom="$1"
  local old_chrom="$2"
  local tag="$3"
  if [ ! -f "$new_chrom" ]; then
    echo "Missing $new_chrom; cannot compare."
    return 1
  fi
  if [ ! -f "$old_chrom" ]; then
    echo "Missing $old_chrom; cannot compare."
    return 1
  fi
  python3 "$SCRIPTS_DIR/compare_chroms.py" --new "$new_chrom" --old "$old_chrom" --tag "$tag" --outdir "$COMPARE_DIR"
}

run_overlap_analysis() {
  local rbh="$SCHULTZ_DIR/UnicellMetazoanLGs.rbh"
  if [ ! -f "$rbh" ]; then
    echo "Missing $rbh; skipping UnicellMetazoanLGs overlap."
    return 1
  fi
  for f in Capsaspora_owczarzaki.chrom Creolimax_fragrantissima.chrom Salpingoeca_rosetta.chrom; do
    if [ ! -f "$f" ]; then
      echo "Missing $f; skipping UnicellMetazoanLGs overlap."
      return 1
    fi
  done
  python3 "$SCRIPTS_DIR/compare_unicell_metazoan_lgs.py" \
    --rbh "$rbh" \
    --cow Capsaspora_owczarzaki.chrom \
    --sro Salpingoeca_rosetta.chrom \
    --cfr Creolimax_fragrantissima.chrom \
    --outdir "$COMPARE_DIR"
}

verify_against_annotations() {
  local mismatches=0
  local missing=0
  local files=(
    Capsaspora_owczarzaki_liftoff.gff
    Capsaspora_owczarzaki_liftoff.pep
    Capsaspora_owczarzaki.chrom
    Creolimax_fragrantissima_liftoff.gff
    Creolimax_fragrantissima_liftoff.pep
    Creolimax_fragrantissima.chrom
    Salpingoeca_rosetta_liftoff.gff
    Salpingoeca_rosetta_liftoff.pep
    Salpingoeca_rosetta.chrom
  )

  diff_gff_ignore_comments() {
    local file="$1"
    local ref="$2"
    local tmp1="${file}.tmp.$$"
    local tmp2="${ref}.tmp.$$"
    grep -v '^#' "$file" > "$tmp1"
    grep -v '^#' "$ref" > "$tmp2"
    diff -q "$tmp1" "$tmp2" >/dev/null
    local status=$?
    rm -f "$tmp1" "$tmp2"
    return $status
  }

  diff_fasta_normalized() {
    local file="$1"
    local ref="$2"
    local tmp1="${file}.tmp.$$"
    local tmp2="${ref}.tmp.$$"
    awk '
      /^>/ {
        if (seq != "") print header "\t" seq
        header=$0
        seq=""
        next
      }
      { gsub(/[[:space:]]/,""); seq=seq $0 }
      END { if (seq != "") print header "\t" seq }
    ' "$file" | sort > "$tmp1"
    awk '
      /^>/ {
        if (seq != "") print header "\t" seq
        header=$0
        seq=""
        next
      }
      { gsub(/[[:space:]]/,""); seq=seq $0 }
      END { if (seq != "") print header "\t" seq }
    ' "$ref" | sort > "$tmp2"
    diff -q "$tmp1" "$tmp2" >/dev/null
    local status=$?
    rm -f "$tmp1" "$tmp2"
    return $status
  }

  report_mismatch() {
    local file="$1"
    local ref="$2"
    local size1 size2 md51 md52
    size1=$(wc -c < "$file" 2>/dev/null || echo "NA")
    size2=$(wc -c < "$ref" 2>/dev/null || echo "NA")
    md51=$(md5sum "$file" 2>/dev/null | awk '{print $1}')
    md52=$(md5sum "$ref" 2>/dev/null | awk '{print $1}')
    echo "  sizes: $size1 (output) vs $size2 (ref)"
    echo "  md5:   $md51 (output)"
    echo "         $md52 (ref)"
    if [[ "$file" == *.gff ]]; then
      local tmp1="${file}.tmp.$$"
      local tmp2="${ref}.tmp.$$"
      grep -v '^#' "$file" > "$tmp1"
      grep -v '^#' "$ref" > "$tmp2"
      echo "  diff (first 10 lines, comments stripped):"
      diff -u "$tmp1" "$tmp2" | head -n 10
      rm -f "$tmp1" "$tmp2"
    elif [[ "$file" == *.pep ]]; then
      echo "  diff (first 10 lines, FASTA normalized):"
      local tmp1="${file}.tmp.$$"
      local tmp2="${ref}.tmp.$$"
      awk '
        /^>/ {
          if (seq != "") print header "\t" seq
          header=$0
          seq=""
          next
        }
        { gsub(/[[:space:]]/,""); seq=seq $0 }
        END { if (seq != "") print header "\t" seq }
      ' "$file" | sort > "$tmp1"
      awk '
        /^>/ {
          if (seq != "") print header "\t" seq
          header=$0
          seq=""
          next
        }
        { gsub(/[[:space:]]/,""); seq=seq $0 }
        END { if (seq != "") print header "\t" seq }
      ' "$ref" | sort > "$tmp2"
      diff -u "$tmp1" "$tmp2" | head -n 10
      rm -f "$tmp1" "$tmp2"
    else
      echo "  diff (first 10 lines):"
      diff -u "$file" "$ref" | head -n 10
    fi
  }

  for f in "${files[@]}"; do
    local ref="$ANNOTATIONS_DIR/$f"
    if [ ! -f "$ref" ]; then
      echo "Missing reference: $ref"
      missing=1
      continue
    fi
    if [ ! -f "$f" ]; then
      echo "Missing output: $f"
      missing=1
      continue
    fi
    if [[ "$f" == *.gff ]]; then
      if ! diff_gff_ignore_comments "$f" "$ref"; then
        echo "Mismatch: $f"
        report_mismatch "$f" "$ref"
        mismatches=1
      fi
      continue
    fi
    if [[ "$f" == *.pep ]]; then
      if ! diff_fasta_normalized "$f" "$ref"; then
        echo "Mismatch: $f"
        report_mismatch "$f" "$ref"
        mismatches=1
      fi
      continue
    fi
    if ! diff -q "$f" "$ref" >/dev/null; then
      echo "Mismatch: $f"
      report_mismatch "$f" "$ref"
      mismatches=1
    fi
  done

  if [ "$missing" -ne 0 ]; then
    echo "Annotation verification failed due to missing files."
    return 1
  fi
  if [ "$mismatches" -ne 0 ]; then
    echo "Annotation verification failed due to content mismatches."
    return 1
  fi
  echo "Annotation verification passed."
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
run_liftoff_if_missing "${OUTGFF}" liftoff -g ${ANNOTA} -o ${OUTGFF} ${TARGET} ${REFERE}
if [ -f "${OUTGFF}" ]; then
  chrom_from_gff "${OUTGFF}" Capsaspora_owczarzaki.chrom
  ids_from_chrom Capsaspora_owczarzaki.chrom "$CHROM_LIST_DIR/Capsaspora_owczarzaki.ids"
  pep_from_list "$CHROM_LIST_DIR/Capsaspora_owczarzaki.ids" "$INPUT_DIR/GCF_000151315.2_C_owczarzaki_V2_protein.faa" "${OUTGFF%.*}.pep"
fi

ANNOTA=$INPUT_DIR/Creolimax_fragrantissima.gtf
FIXED=$PROCESSED_DIR/Creolimax_fragrantissima.fixed.gtf
FIXED_GFF3=$PROCESSED_DIR/Creolimax_fragrantissima.fixed.gff3
FEATURES_FILE=$PROCESSED_DIR/liftoff_features.txt
# Keep features that should already have gene_id/transcript_id
cp ${ANNOTA} ${FIXED}
sed -i.bak -E 's/\tgene\t([0-9]+)\t([0-9]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\tCFRCFR([^\t]+)$/\tgene\t\1\t\2\t\3\t\4\t\5\tgene_id "CFR\6";/' ${FIXED}
sed -i -E 's/\ttranscript\t([0-9]+)\t([0-9]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t(CFR[^T]+)(T[0-9]+)$/\ttranscript\t\1\t\2\t\3\t\4\t\5\tgene_id "\6"; transcript_id "\6\7";/' ${FIXED}
if [ ! -f "$FIXED_GFF3" ]; then
  ensure_gffread
  "$GFFREAD_BIN" "$FIXED" -o "$FIXED_GFF3"
fi
if [ ! -f "$FEATURES_FILE" ]; then
  echo "transcript" > "$FEATURES_FILE"
fi
TARGET=$INPUT_DIR/GCA_033442365.1_MBARI_Creolimax_fragrantissima_v1_genomic.fna
REFERE=$INPUT_DIR/Creolimax_fragrantissima.genome.fasta
OUTGFF=Creolimax_fragrantissima_liftoff.gff
run_liftoff_if_missing "${OUTGFF}" liftoff -f "$FEATURES_FILE" -g ${FIXED_GFF3} -o ${OUTGFF} ${TARGET} ${REFERE}
if [ -f "${OUTGFF}" ]; then
  chrom_from_gff_transcript "${OUTGFF}" Creolimax_fragrantissima.chrom
  ids_from_chrom Creolimax_fragrantissima.chrom "$CHROM_LIST_DIR/Creolimax_fragrantissima.ids"
  pep_from_list "$CHROM_LIST_DIR/Creolimax_fragrantissima.ids" "$INPUT_DIR/Creolimax_fragrantissima.pep.fasta" "${OUTGFF%.*}.pep"
fi

ANNOTA=$INPUT_DIR/GCF_000188695.1_Proterospongia_sp_ATCC50818_genomic.gff
TARGET=$INPUT_DIR/GCA_033442325.1_MBARI_Salpingoeca_rosetta_v1_genomic.fna
REFERE=$INPUT_DIR/GCF_000188695.1_Proterospongia_sp_ATCC50818_genomic.fna
OUTGFF=Salpingoeca_rosetta_liftoff.gff
run_liftoff_if_missing "${OUTGFF}" liftoff -g ${ANNOTA} -o ${OUTGFF} ${TARGET} ${REFERE}
if [ -f "${OUTGFF}" ]; then
  chrom_from_gff "${OUTGFF}" Salpingoeca_rosetta.chrom
  ids_from_chrom Salpingoeca_rosetta.chrom "$CHROM_LIST_DIR/Salpingoeca_rosetta.ids"
  pep_from_list "$CHROM_LIST_DIR/Salpingoeca_rosetta.ids" "$INPUT_DIR/GCF_000188695.1_Proterospongia_sp_ATCC50818_protein.faa" "${OUTGFF%.*}.pep"
fi

# Compare new chrom files to Schultz et al. 2023 chrom files
compare_chroms Capsaspora_owczarzaki.chrom "$SCHULTZ_DIR/COW.chrom" COW
compare_chroms Creolimax_fragrantissima.chrom "$SCHULTZ_DIR/CFR.chrom" CFR
compare_chroms Salpingoeca_rosetta.chrom "$SCHULTZ_DIR/SRO.chrom" SRO

# Compare UnicellMetazoanLGs gene lists to new annotations
run_overlap_analysis

# Verify outputs against reference annotations
verify_against_annotations
