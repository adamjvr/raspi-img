#!/usr/bin/env bash
# Create the ignored development-user configuration consumed during image build.

set -Eeuo pipefail

OUTPUT="${1:-build/noble/dev-user.conf}"
mkdir -p "$(dirname "${OUTPUT}")"

read -r -p 'Development username [adam]: ' username
username="${username:-adam}"

if [[ ! "${username}" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    echo "Invalid username" >&2
    exit 1
fi

password_hash="$(openssl passwd -6)"
ssh_key=""
read -r -p 'Optional SSH public-key file [none]: ' ssh_key_file
if [[ -n "${ssh_key_file}" ]]; then
    ssh_key="$(<"${ssh_key_file}")"
fi

{
    printf 'IMAGE_USER=%q\n' "${username}"
    printf 'IMAGE_PASSWORD_HASH=%q\n' "${password_hash}"
    printf 'IMAGE_SSH_PUBLIC_KEY=%q\n' "${ssh_key}"
} > "${OUTPUT}"

chmod 0600 "${OUTPUT}"
echo "Wrote ${OUTPUT}"
