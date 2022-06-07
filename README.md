# setup-oracle-action

This action handles the setup and teardown of an Oracle Database for running tests.

## Usage

```yaml
      - name: Setup infrastructure
        uses: Particular/setup-oracle-action@v1.0.0
        with:
          connection-string-name: EnvVarToCreateWithConnectionString
          tag: PackageName
```

`connection-string-name` and `tag` are required.

## License

The scripts and documentation in this project are released under the [MIT License](LICENSE).
