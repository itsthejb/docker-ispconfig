#!/bin/bash -e

function cleanup {
  "./hooks/post_test"
}

trap cleanup EXIT

for SCRIPT in pre_test build test; do
  "./hooks/$SCRIPT"
done
