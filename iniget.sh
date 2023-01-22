#!/bin/bash

#[Machine1]
#app=version1
#[Machine2]
#app=version1
#app=version2
#[Machine3]
#app=version1
#app=version3

# iniget file.ini --list
# $ iniget file.ini Machine3
# $ iniget file.ini Machine1 app

# DBS
aliases=/etc/profile.d/00-dbs-aliases.sh
if [ -s $aliases ]; then
  . /etc/profile.d/00-dbs-aliases.sh
fi

function iniget() {
  if [[ $# -lt 2 || ! -f $1 ]]; then
    echo "usage: iniget <file> [--list|<section> [key]]"
    return 1
  fi
  local inifile=$1

  if [ "$2" == "--list" ]; then
#    for section in $(cat $inifile | sed '/ *#/d; /^ *$/d' | grep "\[" | sed -e "s#\[##g" | sed -e "s#\]##g"); do
    for section in $(cat $inifile | sed '/^#.*$/d; /^ *$/d' | grep "\[" | sed -e "s#\[##g" | sed -e "s#\]##g"); do
      echo $section
    done
    return 0
  fi

  local section=$2
  local key
  [ $# -eq 3 ] && key=$3

  # https://stackoverflow.com/questions/49399984/parsing-ini-file-in-bash
  # This awk line turns ini sections => [section-name]key=value
  # local lines=$(awk '/\[/{prefix=$0; next} $1{print prefix $0}' $inifile)
#  local lines=$(awk '/\[/{prefix=$0; gsub(/[ \t]+$/,"",prefix); next} $1{print prefix $0}' $inifile | sed '/ *#/d; /^ *$/d')
  local lines=$(awk '/\[/{prefix=$0; gsub(/[ \t]+$/,"",prefix); next} $1{s=gensub("^#.*$","","G",$1); if(s!="") print prefix s}' $inifile)
  for line in $lines; do
    if [[ "$key" == "db" && -s $aliases ]]; then               # DBS
       s1=$(grep $section /etc/profile.d/00-dbs-aliases.sh 2>/dev/null | sed 's/alias //' | awk -F= '{print $1}' | head -1)    #DBS
       section=$s1                               #DBS
    fi                                          #DBS
    if [[ "$line" == \[$section\]* ]]; then
      local keyval=$(echo $line | sed -e "s/^\[$section\]//")
      if [[ -z "$key" ]]; then
        echo $keyval
      else
        if [[ "$keyval" = $key=* ]]; then
          if [[ "$section" =~ "servers"  ]]; then          #DBS
              str1=$(echo $keyval | sed -e "s/^$key=//")     #DBS
              str2=$(alias "$str1" 2>/dev/null|  awk -F"=" '{print $3}'  | tr -d \' | awk '{print $NF}')  #DBS
              if [[ -n "$str2" ]]; then                    #DBS
                echo $str2                                 #DBS
              else
                echo $(echo $keyval | sed -e "s/^$key=//")
              fi
          else                                             #DBS
              echo $(echo $keyval | sed -e "s/^$key=//")
          fi                                               #DBS
        fi
      fi
    fi
  done
}


BASEDIR=`dirname $0`
INI_FILE="$BASEDIR/$1"
if [ -f "$INI_FILE" ]; then
  iniget $INI_FILE $2 $3
else
  echo "Configuration file: "$INI_FILE" not found. Exiting.."
  exit 127
fi

