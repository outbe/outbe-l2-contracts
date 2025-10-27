#!/bin/sh -e

# Cleanup function
cleanup() {
    echo "Shutting down Anvil..."
    if [ -n "${ANVIL_PID:-}" ] && kill -0 "$ANVIL_PID" 2>/dev/null; then
        kill "$ANVIL_PID"
        wait "$ANVIL_PID" 2>/dev/null || true
    fi
    exit 0
}

# Setup trap for cleanup
trap cleanup TERM INT

# Start anvil in background
echo "Starting Anvil..."

ANVIL_ARGS="--host 0.0.0.0 --port 8545 --state ./anvil-state.json --state-interval 1"
anvil $ANVIL_ARGS > /dev/stdout 2>&1 &
ANVIL_PID=$!
echo "Anvil PID: $ANVIL_PID" > /dev/stdout

# Wait for anvil to start and check health
echo "Waiting for Anvil to start..."
for i in $(seq 1 30); do
    if cast block-number > /dev/null 2>&1; then
        echo "READY"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Anvil failed to start"
        exit 1
    fi
    sleep 1
done

# register CRA
if [ -n "$CRA_ADDRESS" ]; then
    echo "Registering CRA $CRA_ADDRESS ..."
    if ! cast send $CRA_REGISTRY_PROXY "registerCRA(address,string)" $CRA_ADDRESS "Test CRA" --private-key $OWNER_PRIVATE_KEY; then
        echo "Failed to register CRA"
        exit 1
    fi

    echo "Sending 1000 ETH to the newly registered CRA..."
    if ! cast send $CRA_ADDRESS --value 1000000000000000000000 --private-key $OWNER_PRIVATE_KEY; then
      echo "Failed to top-up CRA balance"
      exit 1
    fi

    echo "CRA REGISTERED"
fi

# Keep container running and forward output
wait $ANVIL_PID
