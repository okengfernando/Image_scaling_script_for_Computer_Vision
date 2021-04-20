#!/usr/bin/env bash

# ----------------------------------------------------------------------------
# 1. GLOBALS

cropDimension="3584x2688+0+0"   # imagemagick crop dimension for image
splitDimension="512x512"        # imagemagick split dimension
sharpenSigma="2.7"

# ----------------------------------------------------------------------------

die() { >&2 echo "ERROR: $* (Exiting)" ; exit 1; }

if [ ! -d "$1" ]; then
  echo "Usage: $0 <directory>"
  echo "   eg. $0 rawImages/"
  exit
fi

# ----------------------------------------------------------------------------
# 2. SCRIPT STARTUP

directory=$(basename -- "$1")
processingDirectory=${directory}-processed
echo "[$0] Processing from '$directory' to '$processingDirectory'."

if [ -d $processingDirectory ]; then
  echo -n "[$0] Removing and replacing processing directory... "
  rm -rf $processingDirectory &>/dev/null || die "Cannot rm $processingDirectory"
  mkdir $processingDirectory &>/dev/null || die "Cannot mkdir $processingDirectory"
  echo "done."
else
  echo -n "[$0] Creating processing directory... "
  mkdir $processingDirectory
  echo "done."
fi

# ----------------------------------------------------------------------------
# 3. COPY AND SPLIT PROCESSING IMAGES

for filename in $directory/*; do
    baseFilename=$(basename -- "$filename")
    baseFilename="${baseFilename%.*}"
    extension="${filename##*.}"
    newBasename="${baseFilename// /-}"
    newBasename="${baseFilename//./-}"
    newFilename="${processingDirectory}/${newBasename}.${extension}"

    identify "${filename}" &>/dev/null || die "Cannot identify (imagemagick) ${filename}"

    if [ $? -eq 0 ]; then
      echo -n "[$0] Splitting ${baseFilename}: "

      echo -n "copy... "
      cp "${filename}" "${newFilename}" &>/dev/null || die "Cannot cp ${filename} to ${newFilename}"

      echo -n "cropping (${cropDimension})... "
      convert "${newFilename}" -crop ${cropDimension} "${newFilename}" &>/dev/null || die "Cannot convert -crop ${newFilename}"

      echo -n "splitting (${splitDimension})... "
      convert "${newFilename}" -crop ${splitDimension} "$processingDirectory/${newBasename}-%02d.${extension}" &>/dev/null || die "Cannot convert -crop (split) ${newFilename}"

      echo -n "cleanup... "
      rm ${newFilename}  &>/dev/null || die "Cannot remove ${newFilename}"

      echo "done."
    fi
done

# ----------------------------------------------------------------------------
# 4. PROCESS SPLIT TILES

for filename in $processingDirectory/*; do
    baseFilename=$(basename -- "$filename")
    baseFilename="${baseFilename%.*}"
    extension="${filename##*.}"

    echo -n "[$0] Enhancing ${baseFilename}: "

    resizeFactor="200%"
    echo -n "resizing (${resizeFactor})... "
    convert "${filename}" -resize ${resizeFactor} "${filename}" &>/dev/null || die "Cannot convert -resize ${filename}"

    echo -n "sharpen (Σ=${sharpenSigma})... "
    convert "${filename}" -unsharp 0x${sharpenSigma} "${filename}" &>/dev/null || die "Cannot convert -unsharp ${filename}"

    resizeFactor="50%"
    echo -n "resizing (${resizeFactor})... "
    convert "${filename}" -resize ${resizeFactor} "${filename}" &>/dev/null || die "Cannot convert -resize ${filename}"

    echo "done."
done

# ----------------------------------------------------------------------------
# 5. FINISH

echo "[$0] Done."