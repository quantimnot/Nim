FROM i386/ubuntu
RUN apt-get update -qq && apt-get install --no-install-recommends -yq build-essential git
