#!/usr/bin/env bash

# DO NOT RUN THIS SCRIPT LOCALLY
# THIS SCRIPT IS FROM https://github.com/konst-aa/fun

if [ -d .git ]; then
  echo "ERROR: .git/ already exists, and I don't want to delete it if this script was called by accident."
  echo
  echo "If you intend to download part of this repository, please rm -rf .git/ manually, then re-run."
  exit 1
fi

# https://stackoverflow.com/a/52269934
git clone --depth 1  --filter=blob:none  --no-checkout \
  "https://github.com/konst-aa/fun.git"

mv fun/.git .
rm -d fun

# change stuff here, to taste
TO_CHECKOUT=(
    "README.md"
    "LICENSE"
    ".gitignore"
)


rm ${TO_CHECKOUT[@]}
git checkout main -- ${TO_CHECKOUT[@]}


mv README.md README-TEMP.md
echo "# THIS README IS FOR THE REPOSITORY THIS SCRIPT BELONGS TO: [https://github.com/konst-aa/fun]" > README.md
echo "Please refer to this program's entry in the **rundown** section of the README" >> README.md
cat README-TEMP.md >> README.md
rm README-TEMP.md
