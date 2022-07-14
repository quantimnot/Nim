FROM i386/ubuntu
RUN apt-fast update -qq && apt-fast install --no-install-recommends -yq build-essential git
