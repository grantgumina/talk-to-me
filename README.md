Simple Sinatra webapp which uses Amazon's Polly API and Mailgun to accept emails with an article url as the subject line, and return an MP3 of that narrated article. You'll need to 

# Getting Started

## Requirements
1. Ruby
2. Bundler
3. Postgres
4. [AWS SDK](https://docs.aws.amazon.com/sdk-for-ruby/v3/developer-guide/setup-install.html)

## Setup
1. `bundle install`
2. `rake db:setup`
3. Make sure to setup your AWS SDK. The bundle install command should have installed it for you, so just make sure to edit `~/.aws/credentials` and include your AWS access key and secret key.
4. Edit config/database.yml:

```
development:
  adapter: postgresql
  encoding: unicode
  database: ttmdb
  pool: 2
  username: USERNAME
  password: PASSWORD
```

## Run
`rackup config.ru`