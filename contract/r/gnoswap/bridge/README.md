# Bridge

## Overview

Normally, importing a package specific path (e.g., `v1/somecontract`) means that path is embedded (hardcoded) within the contract implementation. If you upgrade or redeploy a new version of the contract (e.g., `v2/somecontract`), existing contracts are still locked to the old path (i.e., they continue calling the `v1` version).

To solve this, `bridge` provides a callback-based function call. Instead of directly importing the contract, dependent contracts can call a `beidge` contracr, which holds function pointers to whatever version of contract is currently registered. When we upgrade the contracr, we simply update the callbacks in the `bridge` – and all dependent contracts automatically call the new version, without needing to import the new path.

## How it Works?

Below is a simple representation of how the calls flow:

```plain
        (position)
            |
            | calls `MintAndDistributeGnsCallback()`
            v
       +------------+
       |  r/bridge  |
       +-----+------+
             |
    [fn ptrs]|
             |
             v
      v1/emission    v2/emission   ... (any future version)
       (register)     (register)            (register)
```

## Disclaimer

The current implementation is to verify the application of the callback pattern, and the structure or function registration method will be changed in the future.
