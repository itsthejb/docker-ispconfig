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
    && apt-get install -y --no-install-recommends ca-certificates fonts-freefont-ttf fonts-ipafont-gothic fonts-kacst fonts-liberation fonts-thai-tlwg fonts-wqy-zenhei gconf-service google-chrome-unstable libappindicator1 libasound2 libatk1.0-0 libc6 libcairo2 libcups2 libdbus-1-3 libexpat1 libfontconfig1 libgcc1 libgconf-2-4 libgdk-pixbuf2.0-0 libglib2.0-0 libgtk-3-0 libnspr4 libnss3 libpango-1.0-0 libpangocairo-1.0-0 libstdc++6 libx11-6 libx11-xcb1 libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 libxi6 libxrandr2 libxrender1 libxss1 libxtst6 lsb-release nano wget xdg-utils \
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
