## description

"any2opus.sh" is an FFmpeg wrapper for the parallel conversion of audio files.

Metadata is preserved. Any directory on the command line is traversed
recursively. By default, the original audio files are deleted.

Symbolic links like "any2ogg.sh", "any2mp3.sh" and "any2wav.sh" change the
default output format - which can also be changed using command line arguments.

## usage

```bash
$ ./any2opus.sh --help
any2opus.sh, version 0.1

Usage: any2opus.sh [options] file|dir...
Supported input formats: all supported by FFmpeg
Options:
-h | --help		        this help
-q | --quality QUAL	    encoding quality as understood by 'libopus' - higher is better (default: 192)
-k | --keep		        keep original file (unless it's a *.opus)
-d | --dir DIR		    put the result in DIR (create if missing)
-n | --dry-run		    do not run the conversion
-j | --jobs		        number of parallel jobs (default is 0, which means as many as logical CPU cores)
--only-exts EXTS	    only process files with these extensions (space separated, e.g.: ".flac .wav")
--opus			        output Opus (default)
--ogg			        output Ogg/Vorbis
--mp3			        output MP3
--wav			        output WAV
--version		        show version
```

## examples

Convert any FLAC and WAV files in the current directory to 192 Kb/s (VBR) Opus, recursively
and using all CPU cores (file extension matching is case-insensitive, original files are deleted):

```bash
./any2opus.sh --only-exts ".flac .wav" .
```

Convert all files with an audio stream in directory "in\_dir" to Opus, 160 KB/s
(VBR), writing the output to directory "out\_dir" and leaving the original files intact:

```bash
./any2opus.sh --quality 160 --dir out_dir in_dir
```

Convert all audio files in "my\_dir" to MP3, deleting the originals:

```bash
./any2opus.sh --mp3 my_dir
# or
./any2mp3.sh my_dir
```

## requirements

- [Bash](https://www.gnu.org/software/bash/)

- [FFmpeg](https://ffmpeg.org/)

- [GNU Parallel](https://www.gnu.org/software/parallel/)

## credits

- author: Ștefan Talpalaru <stefantalpalaru@yahoo.com>

- homepage: https://github.com/stefantalpalaru/any2opus.sh

