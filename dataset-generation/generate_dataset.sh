#!/bin/bash

if [ $# -le 2 ]; then
  echo "Invalid syntax" 
  echo "usage: generate_dataset <file> <depth> [is_main_thread]"
  exit 1
fi

MAIN_THREAD=false

if [ $# == 3 ]; then
  MAIN_THREAD=$3
fi

POSITIONS=$1
DEPTH=$2
ENGINE=../NapoleonPP

function progress() {
  p=$1
  l=$(tput cols)
  str=" $p%\r"
  for i in $( seq 0 $(( l * p / 100 - ${#str} )) ); do
    echo -n "█"
  done
  echo -ne "$str"
}

coproc $ENGINE
# echo "FD in: ${COPROC[0]}"
# echo "FD out: ${COPROC[1]}"

trap ctrl_c INT SIGTERM
function ctrl_c() {
  echo "Stopping dataset generation..."
  echo "quit" >& ${COPROC[1]}
  wait $COPROC_PID
  exit 0
}


echo "setoption Record" >& ${COPROC[1]} # Tell the engine to record the evaluations in a csv file
LINES=$(wc -l < $POSITIONS)
COUNT=1

function restart() {
  wait $COPROC_PID;
  echo "Restoring failed coprocess...";
  coproc $ENGINE;
  echo "setoption Record" >& ${COPROC[1]};
}

while IFS= read -r fen; do
  # print a progress bar if this is the main thread
  if [[ $MAIN_THREAD == true ]]; then
    progress $((100 * COUNT / LINES))
  fi
  # echo "EVALUATING $fen"
  echo "position fen $fen" >& ${COPROC[1]}
  echo "go depth $DEPTH" >& ${COPROC[1]}

  { 
  while IFS= read -u ${COPROC[0]} -r line || restart; do
    if [[ $line == bestmove* ]]; then # Done searching
      break
    fi
    if [[ $line == Position* ]]; then # Error in the position
      restart
      break
    fi
  done } || { restart; } 
  COUNT=$((COUNT+1))
done < $POSITIONS

echo "quit" >& ${COPROC[1]}
# wait $COPROC_PID
