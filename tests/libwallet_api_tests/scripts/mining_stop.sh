#!/bin/bash

rlwrap sherkitty-wallet-cli --wallet-file wallet_m --password "" --testnet --trusted-daemon --daemon-address localhost:20770  --log-file wallet_miner.log stop_mining

