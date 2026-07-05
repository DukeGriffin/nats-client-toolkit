# NATS Client Toolkit

This toolkit extends [nats.lv](https://github.com/drew-herron/nats.lv) providing:

- A client daemon with queue based subscriptions for easy integration into common LabVIEW project frameworks
- JetStream publish support for lossless publshing.

To learn more about NATS see:

- [protocol](https://docs.nats.io/reference/reference-protocols/nats-protocol)
- [installation](https://github.com/nats-io/nats-server/releases/latest)

## Getting Started

### Installation

#### VI Package

Install from VIPM #TODO

#### NATS Server

Download NATS server from [NATS.io](https://github.com/nats-io/nats-server/releases/latest). A NATS server must be running on a networked machine.

NATS provides a docker image providing an easy way to get NATS onto NI Linux Real-Time targets.

- [NI Linux RT docker installation](https://nilrt-docs.ni.com/docker/docker.html)
- [NATS docker image](https://hub.docker.com/_/nats0)

## Contributing

### Development Setup

1. Install nats-toolkit.vipc
1. Develop
1. Run VI Analyzer using the project's [viancfg](nat.lv.viancfg)
1. Build using nats-toolkit.vipb
1. Add or modify [tests](test\caraya test runner.vi)
1. Upload VI Analyzer and unit test results to PR

## License

Unless otherwise noted, the NATS Core source files are distributed under the BSD 3-clause license found in the [LICENSE](LICENSE) file.

## Acknowledgements

Thanks to Drew Herron for introducing NATS to LabVIEW with [nats.lv](https://github.com/drew-herron/nats.lv).
