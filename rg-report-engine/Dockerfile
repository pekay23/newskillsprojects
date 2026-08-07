FROM ruby:3.3-alpine

# Install build dependencies and postgres client libs
RUN apk add --no-cache build-base postgresql-dev

WORKDIR /app

COPY Gemfile* ./
RUN bundle config set --local without 'development test' && \
    bundle install

COPY . .

EXPOSE 8084

CMD ["bundle", "exec", "ruby", "app.rb"]
