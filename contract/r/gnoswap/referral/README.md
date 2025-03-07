# Referral

The Referral contract implementation for managing referral relationships in the Gnoswap. It provides functionality to register, update, and remove referral relationships between addresses.

## Features

- Register referral relationships between addresses
- Update existing referral relationships
- Remove referral relationships
- Query referral information
- Rate limiting for operations (24-hour cooldown period)

### Keeper

The underlying implementation that handles the actual storage and validation of referral relationships using an AVL tree data structure.
