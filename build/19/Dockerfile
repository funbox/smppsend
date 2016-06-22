FROM ubuntu:precise

MAINTAINER Ilya Averyanov <ilya@averyanov.org>

ENV ERLANG_VERSION=1:19.0
ENV ELIXIR_VERSION=v1.3.0
ENV LANG=en_US.UTF-8

RUN locale-gen en_US.UTF-8

RUN apt-get update
RUN apt-get install -y curl

RUN echo "deb http://packages.erlang-solutions.com/ubuntu precise contrib" | tee -a /etc/apt/sources.list.d/erlang_solutions.list
RUN curl -s 'https://packages.erlang-solutions.com/debian/erlang_solutions.asc' | apt-key add -

RUN apt-get update
RUN apt-get install -y esl-erlang=${ERLANG_VERSION} git unzip make

RUN curl -fSL -o elixir-precompiled.zip https://github.com/elixir-lang/elixir/releases/download/${ELIXIR_VERSION}/Precompiled.zip

RUN unzip -d /usr/local elixir-precompiled.zip
RUN mix local.hex --force





