// 使用 puppeteer 暴力破解 QQ 滑块验证码登录

const puppeteer = require('puppeteer')

const RETRY_LIMIT = 10
const sleep = ms => new Promise(r => setTimeout(r, ms))

module.exports = async url => {
    const browser = await puppeteer.launch()
    const page = await browser.newPage()
    let lock, ticket

    page.on('response', async response => {
        if (response.url() === 'https://t.captcha.qq.com/cap_union_new_verify') {
            let data
            try {
                data = await response.json()
                if (data.ticket || data.errorCode === '51') {
                    lock = true
                    ticket = data.ticket
                }
            } catch {
                data = await response.text()
                console.log(data)
            }
        }
    })

    for (let i = 0; i < RETRY_LIMIT; ++i) {
        if (lock) break

        await page.goto(url)

        await sleep(1000)
        await page.waitForSelector('#tcaptcha_iframe')

        let frame = page.frames()[0].childFrames()[1]
        await frame.waitForSelector('#slide')

        const sliderHandle = await frame.$('#slide')
        const handle = await sliderHandle.boundingBox()

        const sliderElement = await frame.$('#tcaptcha_drag_button')
        const slider = await sliderElement.boundingBox()

        await page.mouse.move(
            slider.x + slider.width / 2,
            slider.y + slider.height / 2
        )
        await page.mouse.down()
        await page.mouse.move(
            handle.x + handle.width * 0.75 + 11,
            slider.y + slider.height / 2 + Math.random() * 10 - 5,
            { steps: 50 }
        )
        await page.mouse.up()

        await sleep(1000)
    }

    await browser.close()
    return ticket
}