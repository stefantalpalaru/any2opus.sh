#!/bin/bash
# shellcheck enable=avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,require-double-brackets,require-variable-braces,quote-safe-variables

# Copyright (c) 2007-2024 Ștefan Talpalaru <stefantalpalaru@yahoo.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

VERSION="0.1"
HOMEPAGE="https://github.com/stefantalpalaru/any2opus.sh"

# Check for required programs.
check_if_programs_exist() {
 for PROGRAM; do
  if ! command -v "${PROGRAM}" &>/dev/null; then
   echo "'${PROGRAM}' not found. Please install it and run this script again."
   exit 1
  fi
 done
}

check_if_programs_exist ffmpeg ffprobe parallel

# OS detection.
if uname | grep -qi darwin; then
  # macOS
  GETOPT_BINARY=$(find /opt/homebrew/opt/gnu-getopt/bin/getopt /usr/local/opt/gnu-getopt/bin/getopt 2>/dev/null || true)
  [[ -f "${GETOPT_BINARY}" ]] || { echo "GNU getopt not installed. Please run 'brew install gnu-getopt'. Aborting."; exit 1; }
  NICE_CMD="nice -n19" # probably ignored by the kernel
else
  GETOPT_BINARY="getopt"
  NICE_CMD="nice -n19 ionice -c2 -n7"
  check_if_programs_exist ionice
fi

# We need to put a limit on the number of background shell jobs and keeping
# track of the number of directories processed at the same level seems like a
# good proxy.
MAX_PROCESSED_DIRS=10

# Default values.
KEEP=0 # keep orig file
DEFAULT_MP3=""
DEFAULT_OGG=""
DEFAULT_WAV=""
DEFAULT_OPUS=""
OUTPUT_DIR=""
DRY_RUN=0
ONLY_EXTS=""
QUAL=""
QUAL_MP3=2 # level
QUAL_OGG=6 # level
QUAL_OPUS=192 # Kb/s
JOBS=0

# Script-name-dependent defaults.
case $0 in
 *mp3*)
  OUTPUT="mp3"
  DEFAULT_QUAL="${QUAL_MP3}"
  ENCODER="libmp3lame"
  ENCODER_BETTER="lower"
  DEFAULT_MP3=" (default)"
 ;;
 *ogg*)
  OUTPUT="ogg"
  DEFAULT_QUAL="${QUAL_OGG}"
  ENCODER="libvorbis"
  ENCODER_BETTER="higher"
  DEFAULT_OGG=" (default)"
 ;;
 *opus*)
  OUTPUT="opus"
  DEFAULT_QUAL="${QUAL_OPUS}"
  ENCODER="libopus"
  ENCODER_BETTER="higher"
  DEFAULT_OPUS=" (default)"
 ;;
 *wav*)
  OUTPUT=wav
  DEFAULT_QUAL="N/A"
  ENCODER="N/A"
  ENCODER_BETTER="N/A"
  DEFAULT_WAV=" (default)"
 ;;
 *flac*)
  OUTPUT=flac
  DEFAULT_QUAL="N/A"
  ENCODER="N/A"
  ENCODER_BETTER="N/A"
  DEFAULT_FLAC=" (default)"
 ;;
esac

USAGE="$(basename "$0"), version ${VERSION}\n\
\n\
Usage: $(basename "$0") [options] file|dir...\n\
Supported input formats: all supported by FFmpeg\n\
Options:\n\
-h | --help\t\tthis help\n\
-q | --quality QUAL\tencoding quality as understood by '${ENCODER}' - ${ENCODER_BETTER} is better (default: ${DEFAULT_QUAL})\n\
-k | --keep\t\tkeep original file (unless it's a *.${OUTPUT})\n\
-d | --dir DIR\t\tput the result in DIR (create if missing)\n\
-n | --dry-run\t\tdo not run the conversion\n\
-j | --jobs\t\tnumber of parallel jobs (default is 0, which means as many as logical CPU cores)\n\
--only-exts EXTS\tonly process files with these extensions (space separated, e.g.: \".flac .wav\")\n\
--opus\t\t\toutput Opus${DEFAULT_OPUS}\n\
--ogg\t\t\toutput Ogg/Vorbis${DEFAULT_OGG}\n\
--mp3\t\t\toutput MP3${DEFAULT_MP3}\n\
--flac\t\t\toutput FLAC${DEFAULT_FLAC}\n\
--wav\t\t\toutput WAV${DEFAULT_WAV}\n\
--version\t\tshow version\n\
"

# Argument parsing.
! ${GETOPT_BINARY} --test > /dev/null
if [[ "${PIPESTATUS[0]}" != "4" ]]; then
  echo '"getopt --test" failed in this environment.'
  exit 1
fi

OPTS="hq:kd:nj:"
LONGOPTS="help,quality:,keep,dir:,dry-run,ogg,mp3,flac,wav,opus,only-exts:,jobs:,version"

! PARSED=$(${GETOPT_BINARY} --options="${OPTS}" --longoptions="${LONGOPTS}" --name "$0" -- "$@")
if [[ "${PIPESTATUS[0]}" != "0" ]]; then
  # Getopt has complained about wrong arguments to stdout.
  exit 1
fi

# Read getopt's output this way to handle the quoting right.
eval set -- "${PARSED}"
while true; do
 case "$1" in
  -h|--help)
   echo -e "${USAGE}"
   exit 1
  ;;
  -q|--quality)
   QUAL="$2"
   shift 2
  ;;
  -k|--keep)
   KEEP=1
   shift
  ;;
  -d|--dir)
   OUTPUT_DIR="$2"
   shift 2
  ;;
  -n|--dry-run)
   DRY_RUN=1
   shift
  ;;
  --only-exts)
   ONLY_EXTS="$2"
   shift 2
  ;;
  --ogg)
   OUTPUT="ogg"
   shift
  ;;
  --opus)
   OUTPUT="opus"
   shift
  ;;
  --mp3)
   OUTPUT="mp3"
   shift
  ;;
  --wav)
   OUTPUT="wav"
   shift
  ;;
  --flac)
   OUTPUT="flac"
   shift
  ;;
  --jobs)
   JOBS="$2"
   shift 2
  ;;
  --version)
   echo -e "$(basename "$0"), version ${VERSION}\n\
Copyright (c) 2007-$(date +%Y) Ștefan Talpalaru <stefantalpalaru@yahoo.com>\n\
Licensed under MPL-2.0: https://mozilla.org/MPL/2.0/
Home page: ${HOMEPAGE}"
   shift
   exit 0
  ;;
  --)
   shift
   break
  ;;
  *)
   echo "argument parsing error!"
   exit 1
  ;;
 esac
done

[[ $# == 0 ]] && { echo -e "${USAGE}"; exit 1; }

# Default quality, in case the output was specified through an argument.
if [[ -z "${QUAL}" ]]; then
 case "${OUTPUT}" in
  mp3)
   QUAL="${QUAL_MP3}"
  ;;
  ogg)
   QUAL="${QUAL_OGG}"
  ;;
  opus)
   QUAL="${QUAL_OPUS}"
  ;;
 esac
fi

# For GNU Parallel.
export QUAL OUTPUT KEEP DRY_RUN ONLY_EXTS NICE_CMD
if [[ "${JOBS}" -le "0" ]]; then
 JOBS="+0" # Weird GNU Parallel syntax meaning "add 0 to the number of CPU threads".
fi
PARALLEL_OPTS=(
 --line-buffer
 --semaphore
 --id "any2mp3_$$"
 --jobs "${JOBS}"
)

any2mp3_encode() {
 F="$1"

 INODE=$(/bin/ls -i "${F}" | cut -d ' ' -f 1)
 T=/tmp/any2mp3$$-${INODE}.${OUTPUT}
 # shellcheck disable=SC2064
 trap "rm -f ${T}" EXIT HUP INT TRAP TERM

 FFMPEG_OPTS=(
  -nostdin
  -vn
  -loglevel error
  -i "${F}"
  -map_metadata 0
  -map_metadata 0:s:0
 )

 case "${OUTPUT}" in
  mp3)
   FFMPEG_OPTS+=(
    -codec:a libmp3lame
    -qscale:a "${QUAL}"
   )
  ;;
  ogg)
   FFMPEG_OPTS+=(
    -codec:a libvorbis
    -qscale:a "${QUAL}"
   )
  ;;
  opus)
   FFMPEG_OPTS+=(
    -codec:a libopus
    -b:a "${QUAL}K"
   )
  ;;
  flac)
   FFMPEG_OPTS+=(
    -compression_level 12
   )
  ;;
 esac

 echo "\"${F}\" -> \"${T}\""

 if [[ "${DRY_RUN}" == "1" ]]; then
  return
 fi

 ${NICE_CMD} \
  ffmpeg "${FFMPEG_OPTS[@]}" "${T}"

 # Final move.
 OUTF="${F%.*}.${OUTPUT}"
 mv "${T}" "${OUTF}"

 # Cleanup.
 case "${F}" in
  *${OUTPUT})
   # Already overwritten.
   :
  ;;
  *)
   # Delete it.
   [[ ${KEEP} == 0 ]] && rm -f "${F}"
  ;;
 esac
}

# For GNU Parallel.
export -f any2mp3_encode

# Recursive function.
any2mp3_reenc () {
 PROCESSED_DIRS="${1}"
 shift

 for F; do
  # Cosmetic change.
  F="${F%/}"

  # Descend in directories.
  if [[ -d "${F}" ]]; then
   for FF in "${F}"/*; do
    # Put a limit on RAM usage.
    PROCESSED_DIRS="$(( PROCESSED_DIRS + 1 ))"
    if [[ "${PROCESSED_DIRS}" -ge "${MAX_PROCESSED_DIRS}" ]]; then
     wait
     PROCESSED_DIRS=0
    fi

    # It's easier to use background shell jobs in here.
    any2mp3_reenc "${PROCESSED_DIRS}" "${FF}" &
   done
   continue
  fi

  # Skip '*' returned in empty directories.
  [[ ! -e "${F}" ]] && continue

  # Do we limit the type of files we can process?
  if [[ -n "${ONLY_EXTS}" ]]; then
   SKIP=1
   shopt -s nocasematch # Case-insensitive extension matching.
   for EXT in ${ONLY_EXTS}; do
    if [[ "${F}" == *${EXT} ]]; then
     SKIP=0
    fi
   done
   shopt -u nocasematch
   if [[ "${SKIP}" == "1" ]]; then
    continue
   fi
  fi

  # Skip files without an audio stream.
  ffprobe -loglevel quiet -select_streams a -show_entries stream=codec_type -of csv=p=0 "${F}" | grep -q audio || continue

  # Encoding.
  parallel "${PARALLEL_OPTS[@]}" any2mp3_encode "\"${F}\""
 done

 wait
}

if [[ -z "${OUTPUT_DIR}" ]]; then
 any2mp3_reenc 0 "$@"
else
 export KEEP=0
 mkdir -p "${OUTPUT_DIR}"
 cp -a "$@" "${OUTPUT_DIR}"/
 any2mp3_reenc 0 "${OUTPUT_DIR}"
fi

parallel "${PARALLEL_OPTS[@]}" --wait

# vim: expandtab:shiftwidth=1:softtabstop=1
