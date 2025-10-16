# Cactus-cli
`cactus-cli` is built upon the `libcactus` library with aim to provide an easy way to stress-test engines, offering multiple tournament formats and easy export of match results.

## Usage
The guide below shows the usage of `cactus-cli`:
| **Command** | **Flags** | Description                                          |
|:------------|:---------:|:-----------------------------------------------------|
|             | --help    | Show context sensitive help                          |
|             | --info    | Show program information                             |
| `init`      | -         | Initialize a new cactus.toml template                |
| `run`       |           | Run the matchup defined in cactus.toml               |
|             | --cwd     | Set a working directory, exports will be stored here |
|             | --config  | Import config from specified cactus.toml             |
|             | --dry     | Dry run to prevent misconfigured runs                |
|             | --profile | Run a profile specified in cactus.toml               |
