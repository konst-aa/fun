#!/usr/bin/env bash

case $1 in
    autodiff)
        sudo -i nix develop .#autodiff -c csi -s autodiff.scm
        ;;
    vm-mergesort)
        sudo -i nix develop .#mips-c-vm --command bash -c 'cd mips-c-vm && make example'
        ;;
    *)
        echo demo $1 does not exist
        echo for a list of available demos, consult the README
        exit 1
        ;;
esac