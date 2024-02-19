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

create_account test1   # g1jg8mtutu9khhfwc4nxmuhcpftf0pajdhfvsqf5
create_account gsa 10  # g12l9splsyngcgefrwa52x5a7scc29e9v086m6p4
create_account lp01 11 # g1jqpr8r5akez83kp7ers0sfjyv2kgx45qa9qygd
create_account lp02 12 # g126yz2f34qdxaqxelmky40dym379q0vw3yzhyrq
create_account tr01 13 # g1wgdjecn5lylgvujzyspfzvhjm6qn4z8xqyyxdn
# ira // g1paqttvcjcluuya9n9twyw7yacv54mt7ld3gvzm