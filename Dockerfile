FROM ghcr.io/foundry-rs/foundry AS builder

WORKDIR /app
COPY lib lib/
COPY script script/
COPY src src/
COPY foundry.toml foundry.lock ./

RUN anvil --state ./anvil-state.json --state-interval 1 & ANVIL_PID=$!; \
    echo "Waiting for anvil started..."; \
    attempts=5; while [ $attempts -gt 0 ]; do  \
      sleep 1; cast block-number --rpc-url http://127.0.0.1:8545  >/dev/null 2>&1 && break; attempts=$((attempts-1)); \
    done; \
    if [ $attempts -eq 0 ]; then echo "Anvil is unavailable"; exit 1; fi; \
    echo "Anvil is up. Installing contracts..."; \
    forge script script/DeployUpgradeable.s.sol:DeployUpgradeable --rpc-url http://127.0.0.1:8545 --broadcast -vvvv  \
    && echo "Contracts installed" || (echo "Contracts installation failed"; exit 1); \
    sleep 1; # to give it time to save the state \
    kill "$ANVIL_PID"; wait "$ANVIL_PID"

FROM ghcr.io/foundry-rs/foundry

WORKDIR /app
COPY --from=builder /app/anvil-state.json ./anvil-state.json
COPY --chown=foundry --chmod=740 entrypoint.sh ./

ENV OWNER_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    OWNER_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

EXPOSE 8545
HEALTHCHECK --interval=2s --timeout=1s --retries=5 \
    CMD cast --rpc-url http://127.0.0.1:8545 block-number >/dev/null 2>&1 || exit 1

ENTRYPOINT ["./entrypoint.sh"]
