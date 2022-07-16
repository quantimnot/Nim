FROM i386/ubuntu

RUN apt-get update -qq && apt-get install --no-install-recommends -qq build-essential git ca-certificates && apt-get clean -qq
