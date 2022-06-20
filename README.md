# setup-oracle-action

This action handles the setup and teardown of an Oracle database.

## Usage

See [action.yml](action.yml)

```yaml
steps:
- name: Setup Oracle
  uses: Particular/setup-oracle-action@v1.0.0
  with:
    connection-string-name: <my connection string name>
    tag: <my tag>
    init-script: /path/to/init-oracle.sql
```

## License

The scripts and documentation in this project are released under the [MIT License](LICENSE).
