graphql()
{ curl --location "http://localhost:$1/graphql" \
--header "Content-Type: application/json" \
--data "{\"query\":\"query Q {$2}\"}"
}

get_height_and_slot_of_earliest()
{ graphql "$1" 'bestChain { protocolState { consensusState { blockHeight slotSinceGenesis } } }' \
| jq -r '.data.bestChain[0].protocolState.consensusState | .blockHeight + "," + .slotSinceGenesis'
}

get_height()
{ graphql "$1" 'bestChain(maxLength: 1) { protocolState { consensusState { blockHeight } } }' \
| jq -r '.data.bestChain[-1].protocolState.consensusState.blockHeight'
}

get_fork_config()
{ graphql "$1" 'fork_config' | jq '.data.fork_config'
}

blocks_with_user_commands()
{ graphql "$1" 'bestChain { commandTransactionCount }' \
| jq -r '[.data.bestChain[] | select(.commandTransactionCount>0)] | length'
}

blocks_query="$(cat << EOF
bestChain {
  commandTransactionCount
  protocolState {
    consensusState {
      blockHeight
      slotSinceGenesis
    }
  }
  transactions {
    coinbase
    feeTransfer {
      fee
    }
  }
  stateHash
}
EOF
)"

blocks_filter='.data.bestChain[] | [.stateHash,(.protocolState.consensusState.blockHeight|tonumber),(.protocolState.consensusState.slotSinceGenesis|tonumber),.commandTransactionCount + (.transactions.feeTransfer|length) + (if .transactions.coinbase == "0" then 0 else 1 end)>0] | join(",")'

blocks()
{ graphql "$1" "$blocks_query" | jq -r "$blocks_filter"
}

# Reads stream of blocks (ouput of blocks() command) and
# calculates maximum seen slot, along with hash/height/slot of
# a non-empty block with largest slot and an empty block
# with the smallest slot
#
# In a regular run, first empty block will be a successor of
# the last non-empty block and the following relation would hold:
#   last_ne_slot < slot_tx_end <= first_e_slot
find_tx_end_slot(){
  # data of a non-empty block with the largest slot
  last_ne_shash=""
  last_ne_height=0
  last_ne_slot=0

  # data of an empty block with the smallest slot
  first_e_shash=""
  first_e_height=0
  first_e_slot=1000000
  # ^ number so high that we don't expect such slot in a test run

  max_slot=0

  # Read line by line, updating data above
  while read l; do
    IFS=, read -ra f <<< "$l"
    slot=${f[2]}
    non_empty="${f[3]}"
    if [[ $max_slot -lt $slot ]]; then
      max_slot=$slot
    fi
    if $non_empty && [[ $last_ne_slot -lt $slot ]]; then
      last_ne_shash="${f[0]}"
      last_ne_height=${f[1]}
      last_ne_slot=$slot
    fi
    if ! $non_empty && [[ $first_e_slot -gt $slot ]]; then
      first_e_shash="${f[0]}"
      first_e_height=${f[1]}
      first_e_slot=$slot
    fi
  done

  echo "$max_slot,$last_ne_shash,$last_ne_height,$last_ne_slot,$first_e_shash,$first_e_height,$first_e_slot"
}
