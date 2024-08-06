#!/bin/sh

# Renders a text based list of options that can be selected by the
# user using up, down and enter keys and returns the chosen option.
#
#   Arguments   : list of options, maximum of 256
#                 "opt1" "opt2" ...
#   Return value: selected index (0 for opt1, 1 for opt2 ...)
function multiselect {
  # helpers for terminal print control and key input
  ESC=$( printf "\033")
  cursor_blink_on()   { printf "$ESC[?25h"; }
  cursor_blink_off()  { printf "$ESC[?25l"; }
  cursor_to()         { printf "$ESC[$1;${2:-1}H"; }
  print_inactive()    { printf "$2   $1 "; }
  print_active()      { printf "$2  $ESC[7m $1 $ESC[27m"; }
  get_cursor_row()    { IFS=';' read -sdR -p $'\E[6n' ROW COL; echo ${ROW#*[}; }

  printf "j or \xE2\x96\xBC\t        \xE2\x86\x92 down\n"
  printf "k or \xE2\x96\xB2\t        \xE2\x86\x92 up\n"
  printf "_ (space)\t\xE2\x86\x92 toggle selection\n"
  printf "\xE2\x86\xB5 (enter)\t\xE2\x86\x92 confirm selection\n"
  printf "\n"

  local return_value=$1
  local options=$2

  # dereference options variable
  eval "local options=(\"\${$options[@]}\")"

  local selected=()
  # make space for the menu
  for ((i=0; i<${#options[@]}; i++)); do
    selected+=("false")
    printf "\n"
  done

  # determine current screen position for overwriting the options
  local lastrow=`get_cursor_row`
  local startrow=$(($lastrow - ${#options[@]}))

  # ensure cursor and input echoing back on upon a ctrl+c during read -s
  trap "cursor_blink_on; stty echo; printf '\n'; exit" 2
  cursor_blink_off

  read_input() {
    local key
    IFS= read -rsn1 key 2>/dev/null >&2
    if [[ $key = ""      ]]; then echo enter; fi;
    if [[ $key = $'\x20' ]]; then echo space; fi;
    if [[ $key = "k" ]]; then echo up; fi;
    if [[ $key = "j" ]]; then echo down; fi;
    if [[ $key = $'\x1b' ]]; then
      read -rsn2 key
      if [[ $key = [A || $key = k ]]; then echo up;    fi;
      if [[ $key = [B || $key = j ]]; then echo down;  fi;
    fi 
  }

  toggle_option() {
    local option=$1
    if [[ ${selected[option]} == true ]]; then
      selected[option]=false
    else
      selected[option]=true
    fi
  }

  # print options by overwriting the last lines
  print_options() {
    local idx=0
    for option in "${options[@]}"; do
      local prefix="[ ]"
      if [[ ${selected[idx]} == true ]]; then
        prefix="[\e[38;5;46m✔\e[0m]"
      fi

      cursor_to $(($startrow + $idx))
      if [ $idx -eq $1 ]; then
        print_active "$option" "$prefix"
      else
        print_inactive "$option" "$prefix"
      fi
      ((idx++))
    done
  }

  local active=0
  while true; do
    print_options $active

    case `read_input` in
      space)  toggle_option $active;;
      enter)  print_options -1; break;;
      up)     ((active--));
              if [ $active -lt 0 ]; then active=$((${#options[@]} - 1)); fi;;
      down)   ((active++));
              if [ $active -ge ${#options[@]} ]; then active=0; fi;;
    esac
  done

  # set cursor position back to normal
  cursor_to $lastrow
  cursor_blink_on

  eval $return_value='("${selected[@]}")'
}
