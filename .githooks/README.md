Install [Gitleaks](https://github.com/gitleaks/gitleaks#installing), then activate this repository's commit hook in each clone:

```sh
git config core.hooksPath .githooks
```

The hook scans staged changes and rejects commits containing secrets. CI checks pushed commits independently.
