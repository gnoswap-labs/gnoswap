#!/bin/bash

create_account(){
  local test_mnemonic="source bonus chronic canvas draft south burst lottery vacant surface solve popular case indicate oppose farm nothing bullet exhibit title speed wink action roast"
  local username=$1
  local index=${2:-0}

  if [ -z "$username" ]; then
    echo "Please input a username."
    exit 1
  fi

  gnokey add $username -recover=true -index $index -insecure-password-stdin=true &> /dev/null<<EOM


  ${test_mnemonic}
EOM

  if [ $? -eq 0 ]; then
    echo "Success: create account ($username, index=$index)"
  else
    echo "Failed: create account ($username, index=$index)"
    exit 1
  fi
}

create_account test1
create_account gsa 10
create_account lp01 11
create_account lp02 12
create_account tr01 13
