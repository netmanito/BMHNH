#!/bin/bash
# Key variable
echo "Removing channel-artifacts"
rm -rf ~/BMHNH/channel-artifacts/*
echo "Removing crypto-config"
rm -rf ~/BMHNH/crypto-config/*
echo "listing dirs"
echo
ls -las ~/BMHNH/crypto-config/ 
echo
ls -las ~/BMHNH/channel-artifacts/
echo
echo "Done"
