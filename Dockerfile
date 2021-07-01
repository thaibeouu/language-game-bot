FROM elixir:latest as build

COPY . .

RUN export MIX_ENV=prod && \
    rm -Rf _build && \
    mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get && \
    mix release

RUN mkdir /export && \
    tar -xf "_build/prod/prod-0.1.0.tar.gz" -C /export

FROM elixir:slim

EXPOSE 80
EXPOSE 443
ENV REPLACE_OS_VARS=true \
    PORT=80

WORKDIR /app
COPY --from=build /export/ .
COPY dict.txt .

ENTRYPOINT ["/app/bin/prod", "start"]
