#!/usr/bin/env bash

_ARGS=(${@})
TRAPPED=false
function safety() {
	echo "*** TRAPPED CTRL-C! ***"
	if ! $TRAPPED; then
		TRAPPED=true
		if [[ "${_ARGS[0]}" == "deploy_challenge" ]]; then
			echo "*** PERFORMING DNS CLEANUP ***"
			clean_challenge ${_ARGS[*]:1}
		fi
		exit 1
	fi
}
trap safety INT

BASEPATH="$(dirname $0)"
function split_domain() {
	if [[ -z "${1/*.*.*/}" ]]; then
		domain="$(expr match ${1} '.*\.\(.*\..*\)')"
		subdomain="${1%.*.*}"
	else
		domain="${1}"
		subdomain=""
	fi
}

function get_cflogin() {
	# You can use this if you are using multiple CF accounts:
#	if [ "${1}" == "domain.one" ]; then
#		CF_EMAIL="account@one.com"
#		CF_KEY="k3y0n3"
#	else
#		CF_EMAIL="account@two.com"
#		CF_KEY="k3ytw0"
#	fi
}

function get_zone() {
	get_cflogin "${1}"

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

function deploy_challenge() {
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
		digresult="$(dig +short TXT _acme-challenge.${!idomain} | tr -d \")"
		while [ "${digresult}"  != "${!itoken}" ]; do
			echo "[CHALLENGE] Waiting for DNS: ${!idomain} -> \"${digresult}\" != \"${!itoken}\""
			sleep 3
			digresult="$(dig +short TXT _acme-challenge.${!idomain} | tr -d \")"
		done

		idomain=$((idomain + 3))
		itoken=$((itoken + 3))
	done
}

function clean_challenge() {
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
}

function deploy_cert() {
	domain="${1}"
	privkey="${2}"
	cert="${4}"

	if [[ -f $BASEPATH/deploy.sh ]]; then
		echo "[DEPLOY] ./deploy.sh ${domain} ${privkey} ${cert}"
		$BASEPATH/deploy.sh ${domain} ${privkey} ${cert}
	fi
}

if [[ "${1}" = "deploy_challenge" ]]; then
	deploy_challenge ${@:2}
elif [[ "${1}" = "clean_challenge" ]]; then
	clean_challenge ${@:2}
elif [[ "${1}" = "deploy_cert" ]]; then
	deploy_cert ${@:2}
fi

exit 0
