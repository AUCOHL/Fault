#!/bin/bash

if [[ $# -eq 0 ]] ; then
    echo "./test.sh <input-folder> <tops-file> <cut> <type-of-TVGenerator> <env>"
    exit 0
fi

input_folder=$1       # folder that contains benchmarks to run
top_modules=$2        # csv file that contains the top module for each benchmark
cut=$3                # specifies to use cut option if set to true.
tvgen=$4              # type of TV generator : swift, LFSR, podem, atalanta

if [ "$3" = "true" ]
then
  echo "Running sequential circuits..using the cut option..."
else
  echo "Running combinational circuits.."
fi

if [ -z "$4" ]
then
  tvgen = "swift"
fi

echo "Using the $4 as TV generator"

log_file="script.log"

# check that top_modules file exists
[ ! -f $top_modules ] && { echo "$top_modules file not found"; exit 99; }

# parse top file
declare -A tops

while IFS=',' read -r module top
do
  tops[$module]=$top
done < $top_modules

if [ -z "$5" ]                # $4 specifies the environment to run from : docker/fault/swift
  then
    echo "Running from Fault's installed environment"
    env="swift run Fault"
  else
    echo "Running from $5 "
    (( env = $5 ))
fi

parentdir="$(dirname "$PWD")"
echo "Current DIR $parentdir"

for file in $parentdir/Benchmarks/$input_folder*.v
do
  # SYNTHESIS
  file_name=$( echo ${file##/*/} )
  top_module="${tops[$file_name]}"
  echo "Synthesizing $file_name"
  $env synth -l $parentdir/Tech/osu035/osu035_stdcells_simple.lib -t $top_module $file &>/dev/null
  # CUTTING IF SEQUENTIAL
  if [ $cut = "true" ];
    then
      echo "Cutting $file_name file"
      $env cut $parentdir/Netlists/$top_module.netlist.v  &>/dev/null
      sim_file=$parentdir/Netlists/$top_module.netlist.v.cut.v
    else
      sim_file=$parentdir/Netlists/$top_module.netlist.v
  fi
  
  # SIMULATIONS
  echo "Running Simulations for $top_module"
  printf "\n\nFile:  $file_name , Top Module: $top_module\n\n" >>$log_file

  # CHECK TV Gen type
  if [ $tvgen = "atalanta" ] || [ $tvgen = "podem" ];
    then
      echo "Generating bench circuit for $top_module"
      $env bench -c $parentdir/Tech/osu035/osu035_stdcells.v.json $sim_file
      $env -g $tvgen -b $sim_file.bench -c $parentdir/Tech/osu035/osu035_stdcells.v -m 100 -v 10 -r 10 $sim_file >>$log_file
    else
      $env -c $parentdir/Tech/osu035/osu035_stdcells.v -v 1 -r 1 -m 97 --ceiling 1 $sim_file >>$log_file
  fi
done