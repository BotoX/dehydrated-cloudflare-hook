# dehydrated-cloudflare-hook
My own shitty (yet better than anything else I've tried) version of a dns-01 hook and deploy script for dehydrated letsencrypt client

To use with: [dehydrated](https://github.com/lukas2511/dehydrated).


## Configuration

Set `HOOK_CHAIN="yes"` in `dehydrated/config`.

Your account's CloudFlare email and API key are expected to be in the environment, so make sure to:

```
$ export CF_EMAIL='user@example.com'
$ export CF_KEY='K9uX2HyUjeWg5AhAb'
```

Alternatively, these statements can be placed in `dehydrated/config`, which is automatically sourced by `dehydrated` on startup:

```
echo "export CF_EMAIL='user@example.com'" >> config
echo "export CF_KEY='K9uX2HyUjeWg5AhAb'" >> config
```

Cloudflare API key tutorial is [here](https://support.cloudflare.com/hc/en-us/articles/200167836-Where-do-I-find-my-CloudFlare-API-key-).


## deploy.sh

Is completly optional, edit it for your use case or make sure to delete it if you don't!
