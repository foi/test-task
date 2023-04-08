# test-task

The HTTP Endpoints testing tool.

## Requirements

- You should have crystall installed (optional).
- You should clone the repo (optional).

## Usage

### Run test-task server locally from the repo

`shards run test-task`

### Run test-task server as a docker container

`docker run -p 8080:8080 --rm -d foifirst/test-task`

### I don't want to run my own server instance

You can use the public server instance: http://task.foifirst.space:8080

## How to use the test-task server?

You should provide a payload data and test-task server address. Examples of payload you can find in `./spec/data` folder.

Run the script from the repo: `./check.sh ./spec/data/1.json http://localhost:8080`

## Contributors

- [Kupchenko Alexander](https://github.com/foi) - creator and maintainer
