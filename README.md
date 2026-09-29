# CatalogConsolidation

A full-stack Rails development environment for the catalog consolidation project. This bootstrap contains no importer or catalog integration yet. The files in `docs/refs/`, including `catalog.db`, are reference inputs and are not used by the running app.

## Requirements

- Docker Engine
- Docker Compose v2

Ruby, Bundler, Rails, SQLite, and the development gems run inside Docker. No host installation of those tools is needed.

## Start the app

```sh
docker compose build web
docker compose up web
```

Open <http://localhost:3000>. The Rails health endpoint is <http://localhost:3000/up>. The server prepares an empty development SQLite database on startup. The database lives in the `catalog_storage` Docker volume and survives `docker compose down`.

## Work inside the container

After the first startup has prepared the database, these commands work whether or not the server is running:

```sh
docker compose run --rm web bin/rails console
docker compose run --rm web bin/rails dbconsole
docker compose run --rm web bin/rails db:migrate
docker compose run --rm web bin/rake -T
docker compose run --rm -e RAILS_ENV=test web bin/rails test
```

To open a shell in the running server container, use `docker compose exec web sh`. Run other Rails, Bundler, and SQLite commands from that shell. After changing `Gemfile` or `Gemfile.lock`, rebuild with `docker compose build web` and restart the service.

Stop the app with `docker compose down`. To intentionally delete the development database too, run `docker compose down -v`.
