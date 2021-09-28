FROM node:lts-slim

# See https://crbug.com/795759
RUN apt-get update && apt-get install -yq --no-install-recommends libgconf-2-4

# Install latest chrome dev package and fonts to support major charsets (Chinese, Japanese, Arabic, Hebrew, Thai and a few others)
# Note: this installs the necessary libs to make the bundled version of Chromium that Puppeteer
# installs, work.
RUN apt-get update \
    && apt-get install -y --no-install-recommends wget gnupg2 ca-certificates \
    && wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list' \
    && apt-get update \
    && apt-get install -y --no-install-recommends nano google-chrome-unstable fonts-ipafont-gothic fonts-wqy-zenhei fonts-thai-tlwg fonts-kacst fonts-freefont-ttf libxtst6 libxss1 \
       \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /src/*.deb \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir /app
RUN groupadd -r test && useradd -r -g test -G audio,video test \
    && mkdir -p /home/test/Downloads \
    && chown -R test:test /home/test

ADD ./package.json /app/
ADD ./package-lock.json /app/
ADD ./jest-puppeteer.config.js /app
RUN chown -R test:test /app

USER test
RUN cd /app && npm install

ENTRYPOINT ["/usr/local/bin/npm", "--prefix", "/app", "test"]
