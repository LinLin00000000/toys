// 将一个数组拆分成多个指定size的数组
const chunk = (array, size) => {
    const chunks = []
    for (let i = 0, len = array.length; i < len; i += size) {
        chunks.push(array.slice(i, i + size))
    }
    return chunks
}

function pollingGetElement(selector, interval = 3000) {
    return new Promise(resolve => {
        const timer = setInterval(() => {
            const element = document.querySelector(selector)
            if (element !== null) {
                clearInterval(timer)
                resolve(element)
            }
        }, interval)
    })
}

function pollingCheckElement(selector, interval = 3000) {
    return new Promise(resolve => {
        const timer = setInterval(() => {
            const element = document.querySelector(selector)
            if (element === null) {
                clearInterval(timer)
                resolve()
            }
        }, interval)
    })
}

// 创建一个<input>元素并设置相关属性
const folderInput = document.createElement('input')
folderInput.type = 'file'
folderInput.webkitdirectory = true

// 触发选择文件夹事件并读取所有图片文件
folderInput.addEventListener('change', async event => {
    let groups = chunk([...event.target.files], 4)

    for (const group of groups) {
        const imagevote = document.querySelector(
            '#edit-pages > div.main > div > div.leftModule > div.question-nobox > div:nth-child(1) > div.scroll-wrap.question-type-box-warp.wj-scrollbar__wrap > div > div > div.question-type-dl > dl:nth-child(1) > dd > div > label:nth-child(4)'
        )
        imagevote.click()

        const upload = (
            await pollingGetElement(
                '#edit-pages > div.main > div > div.survey-main-wrap > div.center-wrap.operation-wrap > div:nth-child(3)'
            )
        ).firstChild.lastChild.querySelector(
            'input.wj-upload__input[type="file"][multiple]'
        )

        const dt = new DataTransfer()
        group.forEach(f => dt.items.add(f))
        upload.files = dt.files
        upload.dispatchEvent(new Event('change'))

        await pollingCheckElement('.upload-status')
        const confirm = document.querySelector(
            'body > div.wj-dialog__wrapper > div > div.wj-dialog__footer > span > button'
        )
        confirm.click()

        await pollingCheckElement(
            'body > div.wj-dialog__wrapper > div > div.wj-dialog__footer > span > button'
        )
    }
})

// 触发选择文件夹对话框
folderInput.click()
