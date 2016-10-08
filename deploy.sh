#!/usr/bin/env bash

# Use this as an example for your needs or don't use it at all.
# I use this on a proxmox hypervisor to generate an ssl cert for:
# - the host
# - two VMs
# - a remote server
# and finally reload all services to apply the new cert.

echo "Not configured, please delete me. Exiting."
exit 1

SSH_CERT="/root/.ssh/id_ed25519_sslsync"

if [[ $# != 3 ]]; then
	echo error: invalid number of parameters 1>&2
	exit 1
fi

DOMAIN="${1}"
KEYFILE="${2}"
CERTFILE="${3}"

if [[ "${DOMAIN}" == "example.com" ]]; then
	echo "Domain: ${DOMAIN}"
	echo "Keyfile: ${KEYFILE}"
	echo "Certfile: ${CERTFILE}"

	# Proxmox VE
	cp -f "${KEYFILE}" "/etc/pve/nodes/pve-example1/pve-ssl.key"
	cp -f "${CERTFILE}" "/etc/pve/nodes/pve-example1/pve-ssl.pem"
	systemctl restart pveproxy

	# VMs
	cp -f "${KEYFILE}" "/rpool/zfsdisks/subvol-100-disk-1/etc/ssl/private/${DOMAIN}.key"
	cp -f "${CERTFILE}" "/rpool/zfsdisks/subvol-100-disk-1/etc/ssl/private/${DOMAIN}.pem"

	cp -f "${KEYFILE}" "/rpool/zfsdisks/subvol-101-disk-1/etc/ssl/private/${DOMAIN}.key"
	cp -f "${CERTFILE}" "/rpool/zfsdisks/subvol-101-disk-1/etc/ssl/private/${DOMAIN}.pem"

	pct exec 100 systemctl reload nginx
	pct exec 100 systemctl reload postfix dovecot
	pct exec 101 service vsftpd restart

	# Remote
	sftp -oIdentityFile=${SSH_CERT} root@another.example.com <<EOF
		put ${KEYFILE} /etc/ssl/private/${DOMAIN}.key
		put ${CERTFILE} /etc/ssl/private/${DOMAIN}.pem
EOF
	ssh -i ${SSH_CERT} root@another.example.com "systemctl reload nginx"
fi

exit 0
