# Docker CLI tools
> _Light weight file convention based docker orchestration tool for development._

A wrapper around the docker CLI written in bash with a file based convention
for volume, environment, network and build arguments definitions.

## Installation

Via npm

shell```
$ npm install --save-dev @orbit-online/docker-tools
```

or yarn

shell```
$ yarn add -D @orbit-online/docker-tools
```

Now the binary script alias in package.json like this:
```json
{
    "name": "myapp",
    ...
    "scripts": {
        "docker": "docker"
    }
}
```

Alternatively you could install a task runner like [@orbit-online/create-task-runner](https://github.com/orbit-online/create-task-runner) that understands node_modules binaries and makes your own local scripts / tools easily accessible, under a common unified namespace.

## Docker files

Often we create different container images for different environments.
In development and test environment we mount our code inside the containers and install development specific dependencies. For production / staging builds we copy the code, install production dependencies and maybe we have some compilation steps as well. This separation is baked into the filename convention of this tool. 

Development docker files are called development.Dockerfile and production docker files are called production.Dockerfile.

By default all docker containers/services are located inside a the docker directory of the project root each service/container in their own directory. This behavior can be modified by setting the `DOCKER_SERVICES_PATH` environment variable. See the [configuration](#configuration) section for more information.

## Environment .list files

Files that declares which environment variables that should be accessible inside the running container.
see the [Docker run reference](https://docs.docker.com/engine/reference/commandline/run/#set-environment-variables--e---env---env-file) for more information about the subject.

Consider a service called postgres with the following file/directory layout

```
~/project/
 |- docker/
   |- postgres
     |- development.Dockerfile
     |- development.env.list
```

The `development.env.list` file defines the variables that should be available in
the running container of `~/project/docker/postgres/development.Dockerfile`.

Just list the variables you want to pass along to the container, one variable per line.

```
PGUSER
PGPASSWORD_FILE=/run/secrets/postgres.passwd
PGDATABASE=$DATABASE_NAME
```

In the example file above PGUSER is forwarded from the callers environment,
PGPASSWORD_FILE is set with a static value of `/run/secrets/postgres.passwd` and
the PGDATABASE environment is set to the value of the DATABASE_NAME of the callers environment.

If you want use the same env.list file across multiple docker environments, just call the file `env.list`. Beware! `env.list` _**won't**_ be considered if there exist an environment specific `.env.list` file e.g. `development.env.list`.

_Empty lines are ignored, and lines starting with `#` are discarded and considered comments._

## Build-args .list files

`build-args.list` and `*.build-args.list` files work kind of like env.list files, but the variables are only accessible during image build time instead of container run time.

If you want use the same build-args.list file across multiple docker environments, just call the file `build-args.list`. Beware! `build-args.list` _**will**_ be considered if there exist an environment specific `.build-args.list` file e.g. `development.build-args.list` but the environment specific file will take precedence.

_Empty lines are ignored, and lines starting with `#` are discarded and considered comments._

## Volumes .list files

Mount point definitions go into the volumes.list files, see [Docker run reference](https://docs.docker.com/engine/reference/commandline/run/#mount-volume--v---read-only) for more information.
One volume definition per line, every line is interpolated and passed to docker run as an argument to the `--volume` parameter.

Environment variables can be inserted and used for interpolation with `$`-notation, relative paths are relative to the project root.


```
docker/postgres/data/pgdata:/var/lib/postgresql/data:cached
docker/postgres/data/config:/data/config:ro
```

The volumes list example file about will mount `~project/docker/postgres/data` from the host machine
into the container at `/var/lib/postgresql/data` and make it writable inside the container using the cached strategy.
`~project/docker/data/config` will be mounted inside the container at `/data/config` as read-only.

If you want use the same volumes.list file across multiple docker environments, just call the file `volumes.list`. Beware! `volumes.list` _**will**_ be considered if there exist an environment specific `.volumes.list` file e.g. `development.volumes.list` but the environment specific file will take precedence.

_Empty lines are ignored, and lines starting with `#` are discarded and considered comments._

## Hosts .list files

The hosts list files are used for granting access to additional IPs outside the docker network,
and give the hosts a friendly name inside the container. See `DOCKER_HOSTS_MAP` in the [Configuration](#configuration) section for more information.

List the friendly names from the `DOCKER_HOSTS_MAP` environment variable you want accessible in the container in the .list file.

If you want use the same hosts.list file across multiple docker environments, just call the file `hosts.list`. Beware! `hosts.list` _**will**_ be considered if there exist an environment specific `.hosts.list` file e.g. `development.hosts.list` but the environment specific file will take precedence.

_Empty lines are ignored, and lines starting with `#` are discarded and considered comments._

## Ports .list files

These files are used for exposing ports of the container to the outside world. See the [Docker run reference](https://docs.docker.com/engine/reference/commandline/run/#publish-or-expose-port--p---expose) for more information.

Example file
```
80
# Bind port 80 of the container to 0.0.0.0:8080 of the host (accessible to the public network).
8080:80
# Bind port 80 of the container to 127.0.0.1:8080 of the host (only accessible to the host).
127.0.0.0:8080:80
```

If you want use the same ports.list file across multiple docker environments, just call the file `ports.list`. Beware! `ports.list` _**will**_ be considered if there exist an environment specific `.ports.list` file e.g. `development.ports.list` but the environment specific file will take precedence.

_Empty lines are ignored, and lines starting with `#` are discarded and considered comments._

## Configuration

This tool will look for a .env file in the project root, and interpret the environment variable
definition inside it, and will use them for configuration and possible forwarding the values to containers via their respective [`env.list`](#environment-list-files) files.

| Environment variable   | Default value            | Description |
| :--------------------- | :----------------------- | :---------- |
| `PROJECT_PATH`         | `""`                     | The variable controls what the docker executable considers the root path of the project, all relative paths interpreted of this tool will resolve them from the the root path. |
| `DOCKER_PROJECT`       | `$PROJECT_PATH`          | Overrides `PROJECT_PATH` either `DOCKER_PROJECT` or `PROJECT_PATH` must have a value. |
| `DOCKER_ENVIRONMENT`   | `development`            | The environment to run the containers in (which Dockerfiles to build and run). |
| `DOCKER_ENV_PREFIXES`  | `""`                     | Which environment variable prefixes to consider for output in `docker.sh env` e.g. `APP_`. |
| `DOCKER_HOSTS_MAP`     | `""`                     | Map of friendly hosts and ip addresses that should be accessible to containers defining the names in their hosts.list files. E.g. DOCKER_HOSTS_MAP=( nginx 10.0.0.2 redis '$REDIS_HOST' ) the redis host will be interpreted upon invocation. |
| `DOCKER_SERVICES_PATH` | `$DOCKER_PROJECT/docker` | The path where all docker services/container definition directories live. |
| `DOCKER_DEBUG`         | `""`                     | Setting it 1 is equal to invoking the tool with `bash -x` and it will output all intermediate commands. |
| `DOCKER_NETWORK`       | `bridge`                 | Which docker network to connect the containers to. The default `bridge` will expose all containers to the public network and will issue a warning. |
| `DOCKER_USER_ID`       | `$(id -u)`               | The user id of the host machine, usually 1000. |
