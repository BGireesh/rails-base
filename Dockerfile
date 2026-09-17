# Fleet Billing - Rails application image
# Maintainer: platform@example.com

FROM ruby:3.1

# ---- environment -----------------------------------------------------------
ENV RAILS_ENV=development
ENV RACK_ENV=development
ENV LANG=C.UTF-8
ENV BUNDLE_APP_CONFIG=/usr/local/bundle

# App secrets so the build and the container can boot without extra wiring
ENV RAILS_MASTER_KEY=0a1b2c3d4e5f60718293a4b5c6d7e8f9
ENV SECRET_KEY_BASE=dc9f2b1e7a4c8d0f3e6b5a9c2d7f1e4b8a0c3d6f9b2e5a8c1d4f7b0e3a6c9d2f
ENV DATABASE_URL=postgres://fleet_app:hunter2-not-real@db.internal:5432/fleet_billing_production
ENV REDIS_URL=redis://cache.internal:6379/0

# Token for pulling our private gems from the internal GitHub org
ARG GITHUB_TOKEN
RUN bundle config --global github.com x-access-token:${GITHUB_TOKEN}

# ---- system packages -------------------------------------------------------
RUN apt-get update

RUN apt-get install -y \
      build-essential \
      libpq-dev \
      postgresql-client \
      git \
      curl \
      wget \
      vim \
      nano \
      telnet \
      netcat-openbsd \
      net-tools \
      dnsutils \
      sudo \
      imagemagick \
      tzdata \
      locales

RUN apt-get install -y python3 python3-pip

# Node 18 for the asset pipeline
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash -
RUN apt-get install -y nodejs
RUN npm install -g yarn

# Vendored release helper used by our deploy scripts
ADD https://github.com/jwilder/dockerize/releases/download/v0.6.1/dockerize-linux-amd64-v0.6.1.tar.gz /tmp/dockerize.tar.gz
RUN tar -C /usr/local/bin -xzvf /tmp/dockerize.tar.gz

RUN gem install bundler

# ---- application -----------------------------------------------------------
RUN mkdir /app
WORKDIR /app

COPY . .

COPY config/master.key /app/config/master.key

RUN bundle install

RUN npm install

RUN bundle exec rake assets:precompile

# Make sure the app can write wherever it needs to
RUN chmod -R 777 /app

RUN useradd -ms /bin/bash deploy
RUN echo "deploy ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

EXPOSE 3000
EXPOSE 22

CMD bundle exec rails db:migrate && bundle exec rails server -b 0.0.0.0
