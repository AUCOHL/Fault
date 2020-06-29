#!/bin/bash

set -e

function usage() {
  echo "Usage: $0 [-h|--help] [-i|--input] [-t|--top] [-g|--tvgen] [--cut] [-o|--output]"
  echo "  -h, --help          print this help message"
  echo "  -i, --input         path of the input folder containing designs to run"
  echo "  -t, --top           .csv file describing the top module of each design"
  echo "  --all               Runs Fault's complete flow"
  echo "  --synth             Runs synthesis script"
  echo "  --cut               Runs cut option on the synthesized netlist" 
  echo "  -g, --tvgen         Runs fault simulation using the specified TV generator (swift, atalanta, LFSR, PODEM)"
  echo "  --chain             Runs chain option on the synthesized netlist" 
  echo "  --tap               Runs tap option on the chained netlist" 
  echo " --area               Reports estimated area of the designs after synthesis, chain, and stitching jtag"
  echo "  -o, --output        log file path"

  echo "This script runs Fault's complete flow on the input designs."
  echo "The results are recorded in the output log file."
}

# default
output="script.log"
area_log="area.log"
liberty=$PWD/Tech/osu035/osu035_stdcells.lib
cell_models=$PWD/Tech/osu035/osu035_stdcells.v
env="swift run Fault"

# Parse Arguments
while (( "$#" )); do
  case "$1" in
    -h|--help)
      usage 2> /dev/null
      exit
      ;;
    -i|--input)
      input=$2
      shift 2
      ;;
    -t|--top)
      top=$2
      shift 2
      ;;
    --all)
      echo "Fault's complete flow is selected"
      all="true"
      shift
      ;;
    --synth)
      echo "Synthesis is selected."
      synth="true"
      shift
      ;;
    --cut)
      echo "Cut is selected."
      cut="true"
      shift
      ;;
    -g|--tvgen)
      echo "Main option with $2 as TV generator is selected."
      tvgen=$2
      shift
      ;;
    --chain)
      echo "Chain is selected."
      chain="true"
      shift
      ;;
    --tap)
      echo "Tap is selected."
      tap="true"
      shift
      ;;
    --area)
      area="true"
      shift
      ;;
    -o|--output)
      output=$2
      area_log=$2.area.log
      shift
      ;;
    -*|--*=) 
      echo "Error: invalid flag $1" >&2
      usage 2> /dev/null
      exit 1
      ;;
    *)
      PARAMS="$PARAMS $1"
      shift
      ;;
  esac
done

if [ ! -z "$synth" ] || [ ! -z "$chain" ] || [ ! -z "$tap" ] 
then
    # check that top_modules file is specified
    if [ -z "$top" ]
    then
        echo "top modules file must be specified using -t|--top o"
        exit 99;
    fi
    # check that top_modules file exists
    [ ! -f $top ] && { echo "$top file not found"; exit 99; }

    # parse top file
    declare -A top_dict
    declare -A clock_dict
    declare -A reset_dict
    declare -A ignored_dict
    while IFS=',' read -r module top_module clock reset ignored
    do
    top_dict[$module]=$top_module
    clock_dict[$module]=$clock
    reset_dict[$module]=$reset
    ignored_dict[$module]=$ignored
    done < $top
fi

# Navigate to Fault's directory
#parentdir="$(dirname "$PWD")"
#echo "Current DIR $parentdir"

# Read files from the input folder
for file in $PWD/$input*.v
do
  # Read file name 
  file_name=$( echo ${file##/*/} )
  netlist=file_name
  cut_netlist=file_name
  # Design config
  top_module="${top_dict[$file_name]}"
  clock_signal="${clock_dict[$file_name]}"
  reset_signal="${reset_dict[$file_name]}"
  ignored_input="${ignored_dict[$file_name]}"

  if [ ! -z "$chain" ] || [ ! -z "$tap" ]
  then
    if [ -z "$clock_signal" ] 
    then
      echo "Warning: Clock signal isn't defined for $top_module."
      clock_opt=""
      else
      clock_opt="--clock $clock_signal"
    fi
    if [ -z "$reset_signal" ]
    then
        echo "Warning: Reset signal isn't defined for $top_module."
        reset_opt=""
        else
        reset_opt="--reset $reset_signal"
    fi
  fi
  # Run Synthesis
  if [ ! -z "$synth" ]
  then
    netlist=$PWD/Netlists/$top_module.netlist.v
    echo "Synthesizing $file_name with top module as  $top_module..."
    $env synth -l $liberty -t $top_module $file &>/dev/null
    if [ ! -z "$area" ]
    then
      echo "Synthesized netlist area: $top_module" >>$area_log 
      # run yosys
      echo """
      read_verilog $netlist
      tee -a $area_log stat -liberty $liberty
      """ | yosys &>/dev/null
    fi
  fi
  # Run Cut
  if [ ! -z "$cut" ]
  then
    cut_netlist=$netlist.cut.v
    echo "Cutting $netlist ..."
    $env cut $netlist  &>/dev/null
  fi
  # Run main
  if [ ! -z "$tvgen" ]
  then
    echo "Running simulations for $cut_netlist using $tvgen..."
    if [ ! -z "$clock_signal" ] || [ ! -z "$reset_signal" ] || [ ! -z "$ignored_input" ]
    then
        ignoring="-i $ignored_input,$clock_signal,$reset_signal"
    fi
    # Check tvgen type
    if [ $tvgen = "atalanta" ] || [ $tvgen = "podem" ];
        then
        bench=$cut_netlist.bench
        echo "Generating bench circuit for $cut_netlist"
        $env bench -c $PWD/Tech/osu035/osu035_stdcells.v.json $cut_netlist
        $env -g $tvgen -b $bench -c $cell_models $ignoring -m 100 -v 10 -r 10 $cut_netlist >>$output
        else
        $env -c $cell_models $ignoring -v 1 -r 1 -m 97 --ceiling 1 $cut_netlist >>$output  #-i $clock_signal,$reset_signal,$ignored_dict
    fi
  fi
  # Run Chain
  if [ ! -z "$chain" ]
  then
    chained_netlist=$netlist.chained.v
    if [ ! -z "$ignored_input" ]
    then
        ignoring="-i $ignored_input"
    fi
    echo "Running chain for $netlist..."
    $env chain $clock_opt $reset_opt $ignoring -l $liberty -c $cell_models $netlist  >>$output
    if [ ! -z "$area" ]
    then
      # run yosys
      echo "Chained netlist area: $top_module" >>$area_log 
      echo """
      read_verilog $chained_netlist
      tee -a $area_log stat -liberty $liberty
      """ | yosys &>/dev/null
    fi
  fi
   # Run tap
  if [ ! -z "$tap" ]
  then
    if [ ! -z "$ignored_input" ]
    then
        ignoring="-i $ignored_input"
    fi
    jtag_netlist=$chained_netlist.jtag.v
    echo $chained_netlist
    echo $jtag_netlist
    echo "Running tap for $chained_netlist..."
    $env tap $clock_opt $reset_opt $ignoring $chained_netlist -l $liberty -c $cell_models  >>$output
    if [ ! -z "$area" ]
    then
      # run yosys
      echo "JTAG netlist area: $top_module" >>$area_log
      echo """
      read_verilog $jtag_netlist
      tee -a $area_log stat -liberty $liberty
      """ | yosys &>/dev/null
    fi
  fi
done