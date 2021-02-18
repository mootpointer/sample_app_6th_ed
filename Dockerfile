FROM ruby:2.6.6-alpine AS build-env

ARG RAILS_ROOT=/app
ARG BUILD_PACKAGES="build-base curl-dev git"
ARG DEV_PACKAGES="postgresql-dev yaml-dev zlib-dev nodejs yarn libxml2-dev libxslt-dev"
ARG RUBY_PACKAGES="tzdata"

ENV RAILS_ENV=production SECRET_KEY_BASE=fake NODE_ENV=production BUNDLE_APP_CONFIG="$RAILS_ROOT/.bundle"

WORKDIR $RAILS_ROOT

# install packages
RUN apk update \
    && apk upgrade \
    && apk add --update --no-cache $BUILD_PACKAGES $DEV_PACKAGES $RUBY_PACKAGES

RUN gem install bundler -v 2.2.10

COPY Gemfile* package.json yarn.lock ./
RUN bundle config build.nokogiri --use-system-libraries \
    && bundle config --global frozen 1 \
    && bundle config set --local path 'vendor/bundle' \
    && bundle config set --local without 'development:test:assets' \
    && bundle install -j4 --retry 3 \
    # Remove unneeded files (cached *.gem, *.o, *.c)
    && rm -rf vendor/bundle/ruby/2.5.0/cache/*.gem \
    && find vendor/bundle/ruby/2.6.0/gems/ -name "*.c" -delete \
    && find vendor/bundle/ruby/2.6.0/gems/ -name "*.o" -delete

RUN yarn install --production --check-files
COPY . .
RUN bundle exec bin/rails webpacker:compile
RUN bundle exec bin/rails assets:precompile

RUN rm -rf node_modules tmp/cache app/assets/images app/assets/stylesheets vendor/assets spec

############### Build step done ###############

FROM ruby:2.6.6-alpine
ARG RAILS_ROOT=/app
ARG PACKAGES="tzdata postgresql-client nodejs bash libxml2 libxslt"
ENV RAILS_ENV=production
ENV BUNDLE_APP_CONFIG="$RAILS_ROOT/.bundle"
WORKDIR $RAILS_ROOT
# install packages
RUN apk update \
    && apk upgrade \
    && apk add --update --no-cache $PACKAGES \
    && gem install bundler -v2.2.10
COPY --from=build-env $RAILS_ROOT $RAILS_ROOT

EXPOSE 3000

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
