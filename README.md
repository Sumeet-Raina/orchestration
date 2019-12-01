# Orchestration

## Overview

_Orchestration_ aims to provide a convenient and consistent process for working with _Rails_ and _Docker_ without obscuring underlying components.

At its core _Orchestration_ is just a `Makefile` and a set of `docker-compose.yml` files with sensible, general-purpose default settings. Users are encouraged to tailor the generated build-out to suit their application.

A typical _Rails_ application can be tested, built, pushed to _Docker Hub_ and deployed to _Docker Swarm_ with the following commands:

```bash
make test build push
make deploy manager=user@swarm.example.com env_file=/var/configs/myapp.env
```

## Getting Started

[_Docker_](https://www.docker.com/get-started) and [_Docker Compose_](https://docs.docker.com/compose/install/) must be installed on your system.

### Install

Add _Orchestration_ to your Gemfile:

```ruby
gem 'orchestration', '~> 0.4.0'
```

Install:

```bash
bundle install
```

### Setup

Generate configuration files and select your deployment server:

#### Generate build-out

```bash
rake orchestration:install server=unicorn # (or 'puma' [default], etc.)
```

You will be prompted to enter values for your _Docker_ organisation and repository name.

For example, the respective organisation and repository for https://hub.docker.com/r/redislabs/redis/ are `redislabs` and `redis`.

If you are unsure of these values, they can be modified later by editing `.orchestration.yml` in the root of your project directory.

You are encouraged to modify this build-out to suit your application's needs. Once it has been generated, it belongs to the application.

To rebuild all build-out at any time, pass `force=yes` to the above install command.

#### Configuration files

_Orchestration_ generates the following files where appropriate. Backups are created if a file is replaced.

* `config/database.yml`
* `config/mongoid.yml`
* `config/rabbitmq.yml` (see [RabbitMQ Configuration](#markdown-header-rabbitmq-configuration) for more details)
* `config/unicorn.rb`
* `config/puma.rb`

You may need to merge your previous configurations with the generated files.

Test and development dependency containers bind to a randomly-generated [at install time] local port to avoid collisions. You may compare e.g. `orchestration/docker-compose.test.yml` with the `test` section of the generated `config/database.yml` to see how things fit together.

When setup is complete, add the generated build-out to _Git_:

```bash
git add .
git commit -m "Add Orchestration gem"
```

## Usage

All `make` commands provided by _Orchestration_ recognise the `env` parameter. This is equivalent to setting the `RAILS_ENV` environment variable.

e.g.:
```
# Stop all test containers
make stop env=test
```

The default value for `env` is `development`.

As with any `Makefile` targets can be chained together, e.g.:
```
# Run tests, build, and push image
make test build push
```

### Containers

All auto-detected services will be added to the relevant `docker-compose.<environment>.yml` files at installation time.

#### Start services

```bash
make start
```

#### Stop services

```bash
make stop
```

#### Interface directly with `docker-compose`

```bash
$(make compose env=test) logs -f database
```

### Images

Image tags are generated using the following convention:

```
# See .orchestration.yml for `organization` and `repository` values.
<organization>/<repository>:<git-commit-hash>

# e.g.
acme/anvil:abcd1234
```

#### Build an application image

Note that `git archive` is used to generate the build context. Any uncommitted changes will _not_ be included in the image.
```
make build
```

See [build environment](#markdown-header-build-environment) for more details.

#### Push latest image

You must be logged in to a _Docker_ registry. Use the `docker login` command (see [Docker documentation](https://docs.docker.com/engine/reference/commandline/login/) for further reference).

```
make push
```

### Development

An [`.env`](https://docs.docker.com/compose/env-file/) is created automatically in your project root. This file is _not_ stored in version control. Set all application environment variables in this file.

#### Launching a development server

To load all variables from `.env` and launch a development server, run the following command:

```bash
make serve
```

The application environment will be output on launch for convenience.

To pass extra commands to the _Rails_ server:
```bash
# Custom server, custom port
make serve server='webrick -p 3001'

# Default server, custom port, custom bind address
make serve server='-p 3001 -b 192.168.0.1'
```

### Testing

A default `test` target is provided in your application's main `Makefile`. You are encouraged to modify this target to suit your application's requirements.

To launch all dependency containers, run database migrations, and run tests:
```
make test
```

Note that _Orchestration_ will wait for all services to become fully available (i.e. running and providing valid responses) before attempting to run tests. This is specifically intended to facilitate testing in continuous integration environments.

### Deployment to Docker Swarm

To deploy your application to _Docker Swarm_:
```
make deploy manager=user@manager.swarm.example.com
```

To use a custom `.env` file:
```
make deploy env_file=/path/to/.env manager=user@manager.swarm.example.com
```

Note that the following two variables _must_ be set in the relevant `.env` file (will look in the current working directory if no path provided):

```
# Published port for your application service:
CONTAINER_PORT=3000

# Number of replicas of your application service:
REPLICAS=5
```

It is also recommended to set `SECRET_KEY_BASE` etc. in this file.

## Build Environment

The following environment variables will be passed as `ARG` variables when building images:

```
BUNDLE_BITBUCKET__ORG
BUNDLE_GITHUB__COM
```

Set these variables in your shell if your `Gemfile` references privately-hosted gems on either _Bitbucket_ or _GitHub_.

See related documentation:

* https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/
* https://confluence.atlassian.com/bitbucket/app-passwords-828781300.html

## Healthchecks

[Healthchecks](https://docs.docker.com/engine/reference/builder/#healthcheck) are automatically configured for your application. A healthcheck utility is provided in `orchestration/healthcheck.rb`. The following environment variables can be configured (in the `app` service of `orchestration/docker-compose.production.yml`):

| Variable | Meaning | Default Value |
|-|-|-|
| `WEB_HOST` | Host to reach application (relevant to application container) | `localhost` |
| `WEB_PORT` | Port to reach application (relevant to application container) | `8080` |
| `WEB_HEALTHCHECK_PATH` | Path of expected successful response | `/` |
| `WEB_HEALTHCHECK_READ_TIMEOUT` | Number of seconds to wait for data before failing healthcheck | `10` |
| `WEB_HEALTHCHECK_OPEN_TIMEOUT` | Number of seconds to wait for connection before failing healthcheck | `10` |
| `WEB_HEALTHCHECK_SUCCESS_CODES` | Comma-separated list of HTTP status codes that will be deemed a success | `200,202,204` |

If your application does not have a suitable always-available route to use as a healthcheck, the following one-liner may be useful:

```ruby
# config/routes.rb
get '/healthcheck', to: proc { [200, { 'Content-Type' => 'text/html' }, ['']] }
```

In this case, `WEB_HEALTHCHECK_PATH` must be set to `/healthcheck`.

## Entrypoint

An [entrypoint](https://docs.docker.com/engine/reference/builder/#entrypoint) script for your application is provided which does the following:

* Runs the `CMD` process as the same system user that launched the container (rather than the default `root` user);
* Creates various required temporary directories and removes stale `pid` files;
* Adds a route `host.docker.internal` to the host machine running the container (mimicking the same route provided by _Docker_ itself on _Windows_ and _OS
  X_).

## RabbitMQ Configuration

The [Bunny](https://github.com/ruby-amqp/bunny) _RabbitMQ_ gem does not recognise `config/rabbitmq.yml`. If your application uses _RabbitMQ_ then you must manually update your code to reference this file, e.g.:

```ruby
connection = Bunny.new(config_for(:rabbit_mq)['url'])
connection.start
```

The environment variable `RABBITMQ_URL` can be used to configure _Bunny_ in production (similar to `DATABASE_URL` and `MONGO_URL`).

This is a convention of the _Orchestration_ gem intended to make _RabbitMQ_ configuration consistent with other services.

## License

[MIT License](LICENSE)

## Contributing

Feel free to make a pull request. Use `make test` to ensure that all tests, _Rubocop_ checks, and dependency validations pass correctly.
