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

## Development

Once the dev container is started do the following:

Log into Azure

```bash
az login
az account set --subscription SUBSCRIPTION_ID
```

Run the npm installation

```bash
npm install
```

To test the setup action an `.env.setup` file in the root directory with the following content

```
# Input overrides
INPUT_CONNECTION-STRING-NAME=OracleConnectionString
INPUT_TAG=setup-oracle-action
INPUT_INIT-SCRIPT=.github/workflows/scripts/init.sql

# Runner overrides
# Use LINUX to run on linux
RUNNER_OS=WINDOWS
RESOURCE_GROUP_OVERRIDE=yourResourceGroup
REGION_OVERRIDE=West Europe
```

then execute the script 

```bash
node -r dotenv/config dist/index.js dotenv_config_path=.env.setup
```

To test the cleanup action change the `.env.cleanup` file in the root directory with to following content

```
# State overrides
STATE_IsPost=true
STATE_containerName=nameOfPreviouslyCreatedContainer
STATE_storageName=nameOfPreviouslyCreatedContainer
```

```bash
node -r dotenv/config dist/index.js dotenv_config_path=.env.cleanup
```