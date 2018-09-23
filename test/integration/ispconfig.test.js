const puppeteer = require('puppeteer');
const host = "ispconfig:8080";

const timeout = 30 * 1000;
jasmine.DEFAULT_TIMEOUT_INTERVAL = timeout;
page.setDefaultNavigationTimeout(timeout);

describe('ISPConfig Admin Interface', () => {
  beforeAll(async () => {
    await page.goto("https://ispconfig:8080");
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

describe('phpMyAdmin Web Interface', () => {
  beforeAll(async () => {
    await page.goto("https://ispconfig:8080/phpmyadmin");
  })

  it('should be possible to login with the default credentials', async () => {
    await expect(page).toFillForm('form[name="login_form"]', {
      pma_username: 'root',
      pma_password: 'pass'
    })
    await expect(page).toClick('input[type="submit"]')
    await page.waitForNavigation()
    await expect(page).toMatch('General Settings')
    await expect(page).toMatch(/(?!Connection for controluser as defined in your configuration failed)/)
    await expect(page).toMatch('Appearance Settings')
    await expect(page).toMatch('Database server')
    await expect(page).toMatch('Web server')
  })
})

describe('Roundcube Webmail', () => {
  beforeAll(async () => {
    await page.goto("https://ispconfig:8080/webmail/");
  })

  test('login page is available', async () => {
    await expect(page).toMatch('Roundcube Webmail')
    await expect(page).toMatch('Username')
    await expect(page).toMatch('Password')
    await expect(page).toMatch('Login')
  })
})

