#!/bin/bash

TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

if [ $# -ne 2 ] ; then
    echo "Usage: pupexplode <pup> <out_dir>"
    echo "pupexplode expands all important files in a PUP and tries to decrypt every file as a self"
    exit 1
fi

pup="$1"
outdir="$2"

$TOOLS/pupunpack $pup $outdir || exit

cd $outdir || exit

mkdir update_files
cd update_files
tar xvf ../update_files.tar || exit

# Need the PS3 keys otherwise next steps won't work
if [ ! -d $TOOLS/.ps3 ];then
  echo "PS3 folder '.ps3' doesn't exist!, please copy the requires ps3 keys to that folder"
  exit 1
fi

if [ -f dev_flash* ];then

for f in dev_flash*; do
    $TOOLS/unpkg $f ${f}_unpkg || exit
    tar xvf ${f}_unpkg/content || exit
done
fi

for f in *.pkg; do
    $TOOLS/unpkg $f ${f%.pkg}
    if [ $f = "CORE_OS_PACKAGE.pkg" ]; then
        $TOOLS/cosunpkg CORE_OS_PACKAGE/content CORE_OS_PACKAGE/
    fi
done

report_result()
{
    local r

    printf "$1"
    shift
    eval $@ >/dev/null 2>&1
    r=$?
    if [ $r -ne 0 ] ; then
        printf 'ko\n'
    else
        printf 'ok\n'
    fi
    return $r
}

cd ..
for f in $(find . -type f); do
    if $TOOLS/readself $f >/dev/null 2>&1; then
        report_result "unselfing $f... " $TOOLS/unself $f ${f}.elf
        if [ $? -eq 0 ] ; then
            cpu=$($TOOLS/readelf -h ${f}.elf | awk '/Machine:/ {print $2}')
            if [ "$cpu" = "SPU" ] ; then
                report_result "disassembling ${f} for SPU..." "$TOOLS/spu-objdump -d ${f}.elf > ${f}.asm 2>/dev/null" 
            elif [ "$cpu" = "PowerPC64" ] ; then
                report_result "disassembling ${f} for PPC..." "$TOOLS/ppu-objdump -d -m powerpc:common64 -EB ${f}.elf > ${f}.asm 2>/dev/null"
            fi
        fi
    fi
done

