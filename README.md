# nextpnr-bin

[nextpnr](https://github.com/YosysHQ/nextpnr), the portable FPGA place-and-route tool, as a portable pre-built package for [edapack](https://dvkit.org/edapack/). It ships the iCE40, ECP5, Nexus and generic backends with their chip databases.

**Documentation:** https://dvkit.org/edapack/nextpnr-bin/

Releases, with one tarball per platform: https://github.com/EDAPack/nextpnr-bin/releases

Install it with [IVPM](https://github.com/fvutils/ivpm):

```yaml
- name: nextpnr-bin
  url: https://github.com/edapack/nextpnr-bin
  src: gh-rls
```
