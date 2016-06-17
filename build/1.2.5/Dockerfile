FROM centos:centos6

MAINTAINER Ilya Averyanov <ilya@averyanov.org>

ENV ERLANG_VERSION=18
ENV ELIXIR_VERSION=v1.2.5
ENV LANG=en_US.UTF-8

RUN yum install -y https://yum.kaos.io/6/release/i386/kaos-repo-7.0-0.el6.noarch.rpm
RUN yum install -y unzip erlang${ERLANG_VERSION}

RUN curl -fSL -o elixir-precompiled.zip https://github.com/elixir-lang/elixir/releases/download/${ELIXIR_VERSION}/Precompiled.zip

RUN unzip -d /usr/local elixir-precompiled.zip
RUN mix local.hex --force





