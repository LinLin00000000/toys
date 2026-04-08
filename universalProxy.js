/**
 * Universal Proxy (Vercel Edge & Cloudflare Workers)
 *
 * 【使用说明】
 *
 * 1. 请求格式：
 *    将目标 URL 附加在代理域名之后。
 *    例如：https://<你的代理域名>/https://api.example.com/v1/data
 *
 * 2. 环境变量配置 (必须配置，否则默认拒绝所有请求)：
 *    - ALLOWED_DOMAINS: 允许代理的目标域名白名单，多个域名用逗号分隔。
 *      支持单级通配符（如 *.example.com, api.*.com）。
 *      注意：不支持全局通配符 '*'，且通配符不能与字符直接相连（如 *example.com 是非法的）。
 *      示例：ALLOWED_DOMAINS="api.github.com, *.openai.com"
 *
 * 3. 功能特性：
 *    - 自动处理 CORS 预检请求 (OPTIONS)。
 *    - 自动为响应添加 Access-Control-Allow-Origin: *。
 *    - 自动剔除隐私相关的请求头 (如 x-forwarded-for, cf-connecting-ip 等)。
 *
 * 4. 部署命名提示：
 *    - Vercel: 通常需要将此文件放在 `api/` 目录下，例如命名为 `api/index.js` 或 `api/[...path].js`。
 *    - Cloudflare: 在 Workers 中通常命名为 `index.js`，在 Pages 中通常命名为 `_worker.js`。
 */

/**
* 1. Vercel 专属配置项
*/
export const config = {
  runtime: 'edge',
};

// ==========================================
// 核心处理逻辑
// ==========================================
async function handleRequest(request, env) {
  // 2. 处理浏览器 CORS 预检请求
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS, PATCH',
        'Access-Control-Allow-Headers': request.headers.get('Access-Control-Request-Headers') || '*',
      },
    });
  }

  // 3. 解析用户请求与目标地址 (万能代理模式)
  const urlString = request.url;
  const match = urlString.match(/\/(https?:\/.*)/);
  if (!match) {
    return new Response('Invalid Request. Usage: https://<proxy-domain>/https://target-api.com/...', { status: 400 });
  }

  let targetUrlStr = match[1];
  targetUrlStr = targetUrlStr.replace(/^(https?):\/+/, '$1://');

  try {
    const targetUrl = new URL(targetUrlStr);

    // 4. 【高阶安全机制】环境变量白名单校验 (默认拒绝 + 安全通配符)
    const allowedDomainsStr = env.ALLOWED_DOMAINS || '';
    const isDomainValid = () => {
      // 拆分并清洗规则
      const rules = allowedDomainsStr.split(',')
        .map(d => d.trim())
        // 过滤空字符串，并且【硬性忽略】单独的全局通配符 '*'
        .filter(d => d.length > 0 && d !== '*')
        // 安全增强：禁止通配符与字符直接相连 (如禁止 *github.com)，必须是 *.github.com 或 api.*.com
        .filter(rule => !/[^.]\*|\*[^.]/.test(rule));

      // 安全底线：如果没有留下任何合法规则，默认直接拒绝 (Default Deny)
      if (rules.length === 0) return false;

      return rules.some(rule => {
        // 将通配符规则动态转换为正则表达式
        // 步骤1: 转义域名中的特殊字符 (如把 . 转义为 \.)
        const escapeRegex = (str) => str.replace(/[.+?^${}()|[\]\\]/g, '\\$&');
        
        // 步骤2: 将转义后的 \* 替换为 [^.]+ (仅匹配单级不含点的字符)
        // 这样可以防止 *.example.com 匹配 a.b.example.com，且配合前面的过滤防止了钓鱼域名
        const regexPattern = '^' + escapeRegex(rule).replace(/\\\*/g, '[^.]+') + '$';
        
        const regex = new RegExp(regexPattern, 'i'); // i 表示忽略大小写
        return regex.test(targetUrl.hostname);
      });
    };

    // 如果域名不符合严格的通配符正则，拦截并返回 403
    if (!isDomainValid()) {
      return new Response(`Forbidden: Target domain (${targetUrl.hostname}) is strictly denied by the proxy whitelist.`, { status: 403 });
    }

    // 5. 清洗敏感请求头 (隐私保护 + 剔除 Host 防报错)
    const proxyHeaders = new Headers(request.headers);
    const privacyHeadersToRemove = [
      'x-forwarded-for', 'x-real-ip', 'x-vercel-forwarded-for',
      'x-vercel-ip-country', 'x-vercel-ip-city', 'cf-connecting-ip',
      'cf-ipcountry', 'host'
    ];
    privacyHeadersToRemove.forEach(header => proxyHeaders.delete(header));

    // 6. 重新打包发往远端服务器
    const modifiedRequest = new Request(targetUrl, {
      headers: proxyHeaders,      
      method: request.method,     
      body: request.body,         
      redirect: 'follow',         
    });

    const response = await fetch(modifiedRequest);

    // 7. 处理返回数据并解决前端跨域限制
    const modifiedResponse = new Response(response.body, response);
    modifiedResponse.headers.set('Access-Control-Allow-Origin', '*');
    return modifiedResponse;

  } catch (e) {
    return new Response('Invalid URL or Server Error: ' + e.message, { status: 500 });
  }
}

// ==========================================
// 兼容性导出 (同时支持 Vercel 和 Cloudflare)
// ==========================================
const universalHandler = async function(request) {
  const env = typeof process !== 'undefined' && process.env ? process.env : {};
  return handleRequest(request, env);
};

universalHandler.fetch = async function(request, env, ctx) {
  return handleRequest(request, env || {});
};

export default universalHandler;
