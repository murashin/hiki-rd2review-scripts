#!/bin/sh
#
# Copyright 2012 Shin-ya MURAKAMI <murashin _at_ gfd-dennou.org>
#

SRCDIR=../rd
DSTDIR=../re

TOOLDIR=rd2review-scripts
HIKIRD2RE=./hiki-rd2review.rb
CHAPS=${DSTDIR}/CHAPS

mkdir -p ${DSTDIR}
touch ${CHAPS}

for f in `ls ${SRCDIR}`; do
    ${HIKIRD2RE} "${SRCDIR}/${f}" "${DSTDIR}"
done

# don't change CHAPS if already exists
if [ ! -e ${CHAPS} ]; then
    cp ${CHAPS}.sample ${CHAPS}
fi
