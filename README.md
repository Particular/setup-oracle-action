# setup-oracle-action

This action handles the setup and teardown of an Oracle Database for running tests.

## Usage

```yaml
      - name: Setup infrastructure
        uses: Particular/setup-oracle-action@v1.0.0
        with:
          connection-string-name: EnvVarToCreateWithConnectionString
          init-script: /path/to/init-script.sql
          tag: PackageName
```

`connection-string-name` and `tag` are required.

The optional init-script will be executed with SQL PLUS against the created container. The init-script is executed with the system user and may be used to initialize the database with additional users, permissions and more.

## License

The scripts and documentation in this project are released under the [MIT License](LICENSE).
