const puppeteer = require('puppeteer');
const host = "ispconfig:8080";

const timeout = 30 * 1000;
jasmine.DEFAULT_TIMEOUT_INTERVAL = timeout;
page.setDefaultNavigationTimeout(timeout);

describe('ISPConfig Admin Interface', () => {
beforeAll(async () => {
    await page.goto("https://" + host);
  })

  it('should be possible to login with the default credentials', async () => {
    await expect(page).toFillForm('form[action="index.php"]', {
      username: 'admin',
      password: 'admin'
    })
    await expect(page).toClick('input[value="Login"]')
    await page.waitForNavigation()
    await expect(page).toMatch('Welcome admin', { timeout: timeout })
  })
})

describe('Roundcube Webmail', () => {
  beforeAll(async () => {
    await page.goto("https://" + host + "/webmail/");
  })

  test('login page is available', async () => {
    await expect(page).toMatch('Roundcube Webmail')
    await expect(page).toMatch('Username')
    await expect(page).toMatch('Password')
    await expect(page).toMatch('Login')
  })
})

