async function getArticle(data) {
    if (data.fullContent) {
        const result = await Mercury.parse(data.url, {
            html: data.content,
            // HTML is fetched by Flutter; subsequent browser requests would
            // require CORS and must not hold up rendering the first page.
            fetchAllPages: false,
        })
        if (result.error || !result.content || !result.content.trim()) {
            throw new Error("Unable to extract article content")
        }
        return result.content
    }
    return data.content
}

async function renderArticle() {
    const payload = document.getElementById("article-data")
    const data = JSON.parse(payload.textContent)
    payload.remove()
    document.documentElement.style.fontSize = data.fontSize + "px"
    if (data.theme !== null) {
        document.documentElement.classList.add(data.theme === 1 ? "light" : "dark")
    }

    const article = await getArticle(data)
    const dom = new DOMParser().parseFromString(data.header, "text/html")
    dom.querySelector("article").innerHTML = article
    for (const script of dom.querySelectorAll("script")) script.remove()
    for (const element of dom.querySelectorAll("[src], [href]")) {
        for (const attribute of ["src", "href"]) {
            const value = element.getAttribute(attribute)
            if (value) {
                try {
                    element.setAttribute(attribute, new URL(value, data.url).href)
                } catch (_) {
                    // Leave malformed URLs alone without hiding the article.
                }
            }
        }
    }
    const main = document.getElementById("main")
    main.innerHTML = dom.body.innerHTML
    main.classList.add("show")
}

renderArticle().then(
    () => ArticleStatus.postMessage("success"),
    () => ArticleStatus.postMessage("failure"),
)

