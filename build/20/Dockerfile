FROM centos:centos6

MAINTAINER Ilya Averyanov <ilya@averyanov.org>

ENV LANG=en_US.UTF-8

RUN yum install -y https://yum.kaos.io/6/release/i386/kaos-repo-7.0-0.el6.noarch.rpm
RUN yum install -y unzip git erlang20 --enablerepo=kaos-testing

RUN curl -fSL -o elixir-precompiled.zip https://github.com/elixir-lang/elixir/releases/download/v1.5.1/Precompiled.zip

RUN unzip -d /usr/local elixir-precompiled.zip
RUN mix local.hex --force
RUN mix local.rebar --force
