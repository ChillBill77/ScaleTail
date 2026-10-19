# homebridge

[Homebridge](https://github.com/homebridge/homebridge) emulates the Apple HomeKit API so non-HomeKit smart-home devices (Philips Hue, IKEA TRADFRI, and hundreds more) show up in the Apple Home app.

This stack runs homebridge with a Tailscale sidecar, as described in [the standard setup](../../documentation/standard-setup.md).

## At a glance

| Item          | Value                                   |
| ------------- | --------------------------------------- |
| Web interface | `https://homebridge.<tailnet>.ts.net`   |
| Service port  | `8581`                                  |
| Image         | `homebridge/homebridge:latest`          |
| Data          | `./homebridge-data/`                    |

## Before you start

- A Tailscale auth key (see `.env`).
- **HomeKit discovery does not work through the sidecar** — see "Deviations from the standard setup". This stack exposes the Homebridge web UI over your Tailnet for administration only.

## Deviations from the standard setup

- **Serve port 8581** — the Homebridge UI listens on 8581, not 80, so the Serve proxy targets `http://127.0.0.1:8581`.
- **`ENABLE_AVAHI=0`** — Avahi (mDNS) is disabled because the sidecar network namespace prevents mDNS broadcasts. HomeKit device discovery is therefore not possible in this stack; run Homebridge with `network_mode: host` (a plain Docker setup, no sidecar) if you need HomeKit app integration and Siri control.
- **Data volume at `/homebridge`** — Homebridge keeps its configuration under `/homebridge`, not `/config`.

## First run

On first start Homebridge prints a setup code to its logs; find it with:

```sh
docker compose logs application | grep -i "setup code"
```

You do not need the setup code to open the web UI — it is only used if you were pairing HomeKit bridges (not possible in this stack).

## Links

- [Homebridge documentation](https://github.com/homebridge/homebridge)
- [Homebridge on Docker](https://github.com/homebridge/homebridge/wiki/Install-Homebridge-on-Docker)
- [Homebridge source code](https://github.com/homebridge/homebridge)
