# AntonLabs

Infrastructure-as-code and automation for my home lab environment. This repository is the single source of truth for how my self-hosted services, servers, and network infrastructure are provisioned, configured, and maintained.

## What's in here

This repo is organized by tool/purpose:

- **`terraform/`** — Infrastructure provisioning (VMs, networking, storage pools, etc.) defined declaratively.
- **`ansible/`** — Playbooks and roles for configuration management: OS hardening, package installs, service configuration, and day-2 operations across hosts.
- **`docker/`** — Dockerfiles and Compose stacks for self-hosted services and containers.
- **`scripts/`** — Standalone shell/Python scripts for one-off tasks, cron jobs, and maintenance utilities (e.g. backups, cleanup jobs).
- **`docs/`** — Notes, diagrams, and reference material describing the lab's architecture and design decisions.

> Note: not every directory may exist yet — this repo grows incrementally as pieces of the lab get codified.

## Environment overview

A brief, high-level picture of the lab this repo manages:

- Bare-metal/VM hosts running various Linux distributions
- TrueNAS server for bulk storage, NFS shares, and backup targets
- Self-hosted services (databases, media, internal tools, etc.) deployed via Docker
- Configuration and provisioning driven by Ansible and Terraform rather than manual changes

## Usage

Each subdirectory includes its own README or comments where relevant, describing how to run the playbooks, apply the Terraform configs, or use the scripts. General conventions:

- Secrets and environment-specific values are **not** committed — use `.env` files, Ansible Vault, or Terraform variable files (gitignored) as appropriate.
- Changes to running infrastructure should go through this repo first (config as code), rather than being made ad hoc on hosts.

## Status

This is a living repository that evolves alongside the homelab itself. Expect structure and contents to change as new services are added or existing ones are re-architected.

## License

Personal project — no license specified; use at your own risk if referencing for your own lab.
