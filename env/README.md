This directory contains a set of scripts for provisioning training environments
for Gravity workshops.

Each environment consists of 3 clean Ubuntu nodes suitable for installing
Gravity cluster. The nodes are provisioned on GCE using terraform >= v0.12.

### Usage Examples

#### Provision Environment

```bash
$ make up ENV=training01 SSH_KEY_PATH=...
$ make up ENV=training02 SSH_KEY_PATH=... REGION=us-east1 ZONE=us-east1-b
```

#### View Environment Information

```bash
$ make out ENV=training01 SSH_KEY_PATH=...
$ make csv ENV=training01 SSH_KEY_PATH=...
```

#### Destroy Environment

```bash
$ make down ENV=training01 SSH_KEY_PATH=...
```
