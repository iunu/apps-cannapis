FROM ruby:2.6.5

# Install Node. Although I'm pretty sure there's an easier way...
RUN apt-get update && apt-get install -y curl
RUN curl -sL https://deb.nodesource.com/setup_10.x | bash -
RUN apt-get update -qq \
    && apt-get install -qq -y --no-install-recommends \
    build-essential git nodejs postgresql-client

RUN gem install bundler:2.0.2
# Install Yarn
RUN npm i -g yarn

ADD https://github.com/ufoscout/docker-compose-wait/releases/download/2.5.0/wait /wait
RUN chmod +x /wait

# throw errors if Gemfile has been modified since Gemfile.lock
RUN bundle config --global frozen 1

WORKDIR /var/artemis/app

COPY Gemfile* package* yarn.lock ./
RUN bundle install
RUN yarn install --pure-lockfile --silent --check-files

RUN rm -rf /var/artemis/app/tmp/pids/server.pid

COPY . .

EXPOSE 3000
CMD bundle exec puma -t 5:5 -p 3000
