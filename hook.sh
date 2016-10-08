#!/usr/bin/env bash

BASEPATH="$(dirname $0)"
split_domain() {
	if [[ -z "${1/*.*.*/}" ]]; then
		domain="$(expr match ${1} '.*\.\(.*\..*\)')"
		subdomain="${1%.*.*}"
	else
		domain="${1}"
		subdomain=""
	fi
}

get_zone() {
	zone=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${1}" \
		-H "X-Auth-Email: ${CF_EMAIL}" \
		-H "X-Auth-Key: ${CF_KEY}" \
		-H "Content-Type: application/json" \
		| grep -Po '(?<="id":")[^"]*' | head -1)

	if [ -z "${zone}" ]; then
		echo "[ZONE] Could not get zone identifier for ${domain}" >&2
		exit 1
	fi
}

if [[ "${1}" = "deploy_challenge" ]]; then
	shift
	split_domain "${1}"
	get_zone "${domain}"
	echo "[CHALLENGE] ${1} CF Zone ID: ${zone}"

	idomain=1
	itoken=3

	while [ -n "${!idomain}" ]; do
		echo "[CHALLENGE] ${!idomain}"
		split_domain "${!idomain}"

		if [ -z "${subdomain}" ]; then
			key="${domain}"
		else
			key="${subdomain}.${domain}"
		fi

		resp=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/${zone}/dns_records" \
			-H "X-Auth-Email: ${CF_EMAIL}" \
			-H "X-Auth-Key: ${CF_KEY}" \
			-H "Content-Type: application/json" \
			--data "{\"type\":\"TXT\",\"name\":\"_acme-challenge.${key}\",\"content\":\"${!itoken}\",\"ttl\":1}")

		if [[ "${resp}" != *"\"success\":true"* ]]; then
			echo "[CHALLENGE] Error occured, check output below:" >&2
			echo "$resp" >&2
			exit 1
		fi

		idomain=$((idomain + 3))
		itoken=$((itoken + 3))
	done

	echo "[CHALLENGE] Waiting for DNS to update..."
	sleep 5
	idomain=1
	itoken=3

	while [ -n "${!idomain}" ]; do
		digresult="$(dig +short TXT _acme-challenge.${!idomain} +trace | grep '^TXT ' | awk '{ print substr($2, 2, length($2) - 2) }')"
		while [ "${digresult}"  != "${!itoken}" ]; do
			echo "[CHALLENGE] Waiting for DNS: ${!idomain} -> \"${digresult}\" != \"${!itoken}\""
			sleep 3
			digresult="$(dig +short TXT _acme-challenge.${!idomain} +trace | grep '^TXT ' | awk '{ print substr($2, 2, length($2) - 2) }')"
		done

		idomain=$((idomain + 3))
		itoken=$((itoken + 3))
	done
fi

if [[ "${1}" = "clean_challenge" ]]; then
	shift
	split_domain "${1}"
	get_zone "${domain}"
	echo "[CLEAN] ${1} CF Zone ID: ${zone}"

	idomain=1
	itoken=3

	while [ -n "${!idomain}" ]; do
		echo "[CLEAN] ${!idomain}"
		split_domain "${!idomain}"

		if [ -z "${subdomain}" ]; then
			key="${domain}"
		else
			key="${subdomain}.${domain}"
		fi

		record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${zone}/dns_records?type=TXT&name=_acme-challenge.${key}&content=${!itoken}" \
			-H "X-Auth-Email: ${CF_EMAIL}" \
			-H "X-Auth-Key: ${CF_KEY}" \
			-H "Content-Type: application/json" \
			| grep -Po '(?<="id":")[^"]*')

		if [ -z "$record" ]; then
			echo "[CLEAN] Could not find TXT record _acme-challenge.${key} in zone ${zone}" >&2
			echo "[CLEAN] No need to clean up then..." >&2
			shift 3
			continue
		fi

		resp=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/${zone}/dns_records/${record}" \
			-H "X-Auth-Email: ${CF_EMAIL}" \
			-H "X-Auth-Key: ${CF_KEY}" \
			-H "Content-Type: application/json")

		if [[ "${resp}" != *"\"success\":true"* ]]; then
			echo "[CLEAN] Error occured, check output below:" >&2
			echo "$resp" >&2
			exit 1
		fi

		idomain=$((idomain + 3))
		itoken=$((itoken + 3))
	done
fi

if [[ "${1}" = "deploy_cert" ]]; then
	domain="${2}"
	privkey="${3}"
	cert="${5}"

	if [[ -f $BASEPATH/deploy.sh ]]; then
		echo "[DEPLOY] ./deploy.sh ${domain} ${privkey} ${cert}"
		$BASEPATH/deploy.sh ${domain} ${privkey} ${cert}
	fi

	exit 0
fi

exit 0