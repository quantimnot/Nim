FROM i386/ubuntu
RUN apt update -qq && apt install --no-install-recommends -yq build-essential git
