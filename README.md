# NATS Client Toolkit

This toolkit extends [nats.lv](https://github.com/drew-herron/nats.lv) providing:

- A client daemon with queue based subscriptions for easy integration into common LabVIEW project frameworks
- JetStream publish support for lossless publishing (coming soon)!

To learn more about NATS see:

- [protocol](https://docs.nats.io/reference/reference-protocols/nats-protocol)
- [installation](https://github.com/nats-io/nats-server/releases/latest)

## Getting Started

**[Documentation / Wiki](https://github.com/andycorb/nats-client-toolkit/wiki)**

### Examples

After VI package installation navigate to NI Example Finder.

![alt text](docs/Images/examples.png)

## Contributing

### Development Setup

1. Install NATS Client Toolkit.vipc
2. Install dev.vipc

### Linting and Testing

1. Run VI Analyzer using the project's [viancfg](nat.lv.viancfg)
1. Add or modify tests within `test\tests`

Test VIs within `test\tests` are automatically run using `test\caraya test runner.vi` and a resulting xml report: `test\nats.client.toolkit.xml`

### Merging Changes

1. Create a PR
1. Describe changes
1. Upload VI Analyzer and unit test results to PR
1. Request review

## License

BSD-3 [LICENSE](LICENSE)

## Acknowledgements

Thanks to Drew Herron for introducing NATS to LabVIEW with [nats.lv](https://github.com/drew-herron/nats.lv).
