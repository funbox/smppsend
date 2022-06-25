FROM centos:centos6

MAINTAINER Ilya Averyanov <ilya@averyanov.org>

ENV LANG=en_US.UTF-8

RUN yum install -y https://yum.kaos.st/kaos-repo-latest.el6.noarch.rpm
RUN yum install -y unzip git erlang19

RUN curl -fSL -o elixir-precompiled.zip https://github.com/elixir-lang/elixir/releases/download/v1.5.1/Precompiled.zip

RUN unzip -d /usr/local elixir-precompiled.zip
RUN mix local.hex --force
RUN mix local.rebar --force
