const puppeteer = require('puppeteer');
const host = "ispconfig:8080";

const timeout = 30 * 1000;
jasmine.DEFAULT_TIMEOUT_INTERVAL = timeout;
page.setDefaultNavigationTimeout(timeout);

describe('phpMyAdmin Web Interface', () => {
  it('should not be available', async () => {
    try {
      await page.goto('https://ispconfig:8080/phpmyadmin');
      throw new Error("phpMyAdmin interface loaded, but it should not be available");
    } catch (error) {
      // should fail
    }
  })
})
