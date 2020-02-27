#!/bin/bash

if [[ $# -eq 0 ]] ; then
    echo "./test.sh <input_folder> <tops_file> <cut>"
    exit 0
fi

input_folder=$1       # folder that contains benchmarks to run
top_modules=$2        # csv file that contains the top module for each benchmark

if [ -z "$3" ]
then
  cut="false"
else
  cut=$3
fi
echo $cut

log_file="script.log"

# check that top_modules file exists
[ ! -f $top_modules ] && { echo "$top_modules file not found"; exit 99; }

# parse top file
declare -A tops

while IFS=',' read -r module top
do
  tops[$module]=$top
done < $top_modules

if [ -z "$4" ]                # $4 specifies the environment to run from : docker/fault/swift
  then
    echo "Running from Fault's installed environment"
    env="fault"
  else
    echo "Running from "
    echo $4
    (( env = $4 ))
fi

for file in $PWD/$input_folder*.v
do
  # SYNTHESIS
  file_name=$( echo ${file##/*/} )
  top_module="${tops[$file_name]}"
  echo "Synthesizing $file_name"
  $env synth -l Tech/osu035/osu035_stdcells.lib -t $top_module $file &>/dev/null
  # CUTTING IF SEQUENTIAL
  if [ $cut = "cut" ];
    then
      echo "Cutting $file_name file"
      $env cut $PWD/Netlists/$top_module.netlist.v  &>/dev/null
      sim_file=$PWD/Netlists/$top_module.netlist.v.cut.v
    else
      sim_file=$PWD/Netlists/$top_module.netlist.v
  fi
  # SIMULATIONS
  echo "Running Simulations for $top_module"
  printf "\n\nFile:  $file_name , Top Module: $top_module\n\n" >>$log_file
  $env -c Tech/osu035/osu035_stdcells.v -v 1 -r 1 -m 97 --ceiling 1 $sim_file >>$log_file

done