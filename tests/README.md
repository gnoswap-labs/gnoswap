# Gnoswap Deployment and Testing Scripts

This directory contains scripts for deploying and testing Gnoswap contracts.

## Directory Structure

```
tests/
├── scripts/
│   ├── config/          # Environment-specific configuration files
│   │   ├── local.mk     # Local environment configuration
│   │   ├── dev.mk       # Development environment configuration
│   │   ├── staging.mk   # Staging environment configuration
│   │   └── production.mk # Production environment configuration
│   ├── deploy.mk        # Deployment scripts
│   └── test.mk          # Test scripts
├── Makefile             # Main entry point
└── README.md            # This file
```

## Usage

### Basic Commands

Execute commands with environment specification:

```bash
# Show help
make help

# Check environment information
make info ENV=dev

# List available environments
make envs
```

### Pre-Deployment Commands

**⚠️ IMPORTANT: These commands must be executed before deployment!**

```bash
# Step 1: Remove all test files (REQUIRED before deployment)
make remove-test

# Step 2: Faucet admin account (for local/test environments)
make faucet-admin ENV=local
```

**What these commands do:**

1. **`make remove-test`**: Removes all `*_test.gno` and `testutils.gno` files

   - Prevents test files from being deployed to the blockchain
   - Reduces deployment costs and contract size
   - Protects internal testing logic from exposure

2. **`make faucet-admin`**: Sends ugnot to necessary admin accounts
   - Required for local/test environments
   - Funds accounts needed for contract deployment
   - Sends 10,000,000,000 ugnot to: ADDR_GNOSWAP, ADDR_ADMIN, ADDR_TEST

### Deployment Commands

```bash
# Full deployment (local environment)
make deploy ENV=local

# Full deployment to development environment
make deploy ENV=dev

# Deploy specific components only
make deploy-tokens ENV=dev      # Test tokens only
make deploy-libs ENV=dev         # Libraries only
make deploy-base ENV=dev         # Base contracts only
make deploy-realms ENV=dev       # Gnoswap realms only
make deploy-v1 ENV=dev           # v1 implementations only
```

### Testing Commands

```bash
# Pool tests
make test-pool ENV=dev

# Swap tests
make test-swap ENV=dev

# Staking tests
make test-stake ENV=dev

# Governance tests
make test-gov ENV=dev

# Run all tests
make test-all ENV=dev

# Transfer tokens (for testing)
make transfer-tokens ENV=dev
```

## Environment Configuration

### Adding a New Environment

1. Create a new environment configuration file in `scripts/config/` directory:

```bash
cp scripts/config/local.mk scripts/config/production.mk
```

2. Edit the new file to configure environment-specific settings:

   - `GNOLAND_RPC_URL`: RPC endpoint
   - `CHAINID`: Chain ID
   - `ADDR_*`: Contract and user addresses

3. Execute commands with the new environment:

```bash
make deploy ENV=production
```

### Key Configuration Settings

Each environment configuration file (`scripts/config/*.mk`) should configure:

- **RPC and Chain Settings**

  - `GNOLAND_RPC_URL`: Gnoland RPC URL
  - `CHAINID`: Chain ID

- **Contract Addresses** (update after deployment)

  - `ADDR_POOL`, `ADDR_POSITION`, `ADDR_ROUTER`, etc.

- **User Addresses**

  - `ADDR_GNOSWAP`: Gnoswap administrator address
  - `ADDR_ADMIN`: Admin address
  - `ADDR_TEST`: Test account address
  - `ADDR_USER_1` ~ `ADDR_USER_4`: Test user addresses

- **Transaction Settings**
  - `MAX_APPROVE`: Maximum approval amount
  - `TX_EXPIRE`: Transaction expiration time

## Environment Examples

### Local Development

** Prerequisites:**

Before starting, ensure `gnoswap_admin` account is registered in gnokey:

```bash
# Check if account exists
gnokey list

# If not registered, add it
gnokey add gnoswap_admin

# Verify the account
gnokey list | grep gnoswap_admin
```

**Complete workflow for local testing:**

```bash
# Step 0: Start local gnoland (in another terminal)
gnoland start

# Step 1: Remove test files before deployment
make remove-test
# This removes all *_test.gno and testutils.gno files from the project
# Ensures test files are not deployed to the blockchain

# Step 2: Faucet admin accounts
make faucet-admin ENV=local
# Sends 10,000,000,000 ugnot to necessary admin accounts:
# - ADDR_GNOSWAP: Main gnoswap admin account
# - ADDR_ADMIN: Admin account for contract management
# - ADDR_TEST: Test account for initial operations

# Step 3: Deploy contracts
make deploy ENV=local
# Deploys all contracts in the following order:
# 1. Test tokens (bar, baz, foo, obl, qux, usdc)
# 2. Libraries (uint256, int256, rbac, gnsmath, store, version_manager)
# 3. Base contracts (access, rbac-realm, halt, referral, gns, emission, etc.)
# 4. Gnoswap realms (protocol_fee, pool, position, router, staker, governance, launchpad)
# 5. v1 implementations

# Step 4: Run test scripts
make test-pool ENV=local
make test-swap ENV=local
make test-all ENV=local
```

**Quick start (all-in-one):**

```bash
# Execute all steps sequentially
make remove-test && \
make faucet-admin ENV=local && \
make deploy ENV=local && \
make test-pool ENV=local
```

### Development Server

```bash
# Step 1: Remove test files before deployment
make remove-test

# Step 2: Faucet admin accounts (if needed)
make faucet-admin ENV=local

# Step 3: Deploy to development server
make deploy ENV=local

# Step 4: Run tests
make test-pool ENV=local
```

### Staging Environment

```bash
# Step 1: Remove test files before deployment
make remove-test

# Step 2: Deploy to staging environment
make deploy ENV=staging

# Step 3: Run comprehensive tests
make test-pool ENV=staging
```

### Production Environment

**⚠️ CRITICAL: Extra caution required for production deployment!**

```bash
# Step 1: Remove test files (MANDATORY)
make remove-test

# Step 2: Verify environment configuration
make info ENV=production.local

# Step 3: Deploy to production (after thorough review)
make deploy ENV=production.local

# Note: Faucet is NOT needed for production as accounts should already be funded
```

## Important Notes

1. **Gnokey Account Setup (REQUIRED)**:

   - **MUST** have `gnoswap_admin` account registered in gnokey before deployment
   - Check: `gnokey list`
   - Add if missing: `gnokey add gnoswap_admin`
   - This account is used for all contract deployments

2. **Pre-Deployment Steps (MANDATORY)**:

   - **Step 1**: Run `make remove-test` to remove all test files
   - **Step 2**: Run `make faucet-admin` for local/test environments
   - **Step 3**: Verify with `make info ENV=<env>` before deployment

3. **Test Files**: Test files (`*_test.gno`, `testutils.gno`) should NEVER be deployed to the blockchain. They increase costs and may expose internal logic.

4. **Account Requirements**:

   - Local/Dev: Use `make faucet-admin` to fund admin accounts
   - Staging/Production: Ensure accounts are pre-funded with sufficient GNOT

5. **Deployment Order**: Contracts must be deployed in this specific order:

   - Test tokens → Libraries → Base contracts → Gnoswap realms → v1 implementations

6. **Contract Addresses**: Update environment config files with deployed contract addresses after successful deployment.
