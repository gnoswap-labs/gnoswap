# Launchpad v3-valid upgrade fixture

This directory contains the `v3_valid` launchpad implementation used by
upgrade and filetest scenarios. It is a test fixture, not the production
launchpad entry point or a standalone deployment.

The fixture covers project creation, GNS deposits, reward collection, tier
handling, and deposit withdrawal after an implementation upgrade. Its
constants intentionally use scenario values (including a one-hour minimum
project-start delay), so they must not be read as production configuration.

For the production launchpad API and configuration, see [the production
launchpad README](../../../../../gnoswap/launchpad/README.md).
