/**
 * @typedef {Object} MessageEmitter
 * @property {(listener: (message: string, originEvent: MessageEvent) => void) => void} addListener
 * @property {(message: string) => void} emitMessage
 */

/**
 * @param {'parent' | 'child'} identity
 * @param {string} [options.trustedOrigin='*'] 仅 parent 需要配置
 * @param {string} [options.targetSelector='#iframe'] 仅 parent 需要配置
 * @param {string} [options.targetOrigin='*'] 仅 child 需要配置
 * @returns {MessageEmitter}
 */
export function initMessageEmitter(
    identity,
    { trustedOrigin = '*', targetSelector = '#iframe', targetOrigin = '*' } = {}
) {
    switch (identity) {
        case 'parent':
            return {
                addListener(listener) {
                    window.addEventListener('message', e => {
                        if (
                            trustedOrigin === '*' ||
                            e.origin === trustedOrigin
                        ) {
                            listener(e.data, e)
                        }
                    })
                },
                emitMessage(message) {
                    const iframe = document.querySelector(targetSelector)
                    if (iframe) {
                        iframe.src = iframe.src + '#' + message
                    }
                },
            }
        case 'child':
            return {
                addListener(listener) {
                    window.addEventListener('hashchange', e => {
                        listener(window.location.hash.slice(1), e)
                    })
                },
                emitMessage(message) {
                    window.parent.postMessage(message, targetOrigin)
                },
            }
    }
}
