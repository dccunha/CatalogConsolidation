# CatalogConsolidation

A full-stack Rails development environment for the catalog consolidation project. Rails uses PostgreSQL for its application data. This foundation has no catalog tables, importer, or review screen yet. The files in `docs/refs/`, including `catalog.db`, remain unchanged reference inputs and are not loaded into PostgreSQL.

## Requirements

- Docker Engine
- Docker Compose v2

Ruby, Bundler, Rails, PostgreSQL, and the development gems run inside Docker. No host installation of those tools is needed.

## Start the app

```sh
docker compose up --build
```

Open <http://localhost:3000>. The Rails health endpoint is <http://localhost:3000/up>. Compose waits for PostgreSQL to become healthy; the web service then prepares an empty `catalog_consolidation_development` database. PostgreSQL data lives in the `postgres_data` Docker volume and survives `docker compose down`.

The default credentials are for local development only. To override the password or web port, copy `.env.example` to `.env` and edit `DB_PASSWORD` or `WEB_PORT` before startup. The PostgreSQL port is not published to the host; use the container commands below to inspect it.

## Work inside the containers

```sh
docker compose run --rm web bin/rails console
docker compose run --rm web bin/rails dbconsole
docker compose run --rm web bin/rails db:migrate
docker compose exec db psql -U catalog -d catalog_consolidation_development
docker compose run --rm -e RAILS_ENV=test web bin/rails db:prepare
docker compose run --rm -e RAILS_ENV=test web bin/rails test
```

Development and test use separate PostgreSQL databases. Production is configured through `DATABASE_URL`; this Compose setup runs development only. After changing `Gemfile` or `Gemfile.lock`, rebuild with `docker compose build web` and restart the service.

Stop the app with `docker compose down`. To intentionally delete the PostgreSQL data volume, run `docker compose down -v`.
