function get(name) {
    if (name = (new RegExp('[?&]' + encodeURIComponent(name) + '=([^&]*)')).exec(location.search))
        return decodeURIComponent(name[1])
    return null
}
async function getArticle(url) {
    let article = get("a")
    if (get("m") === "1") {
        return (await Mercury.parse(url, {html: article})).content || ""
    } else {
        return article
    }
}
document.documentElement.style.fontSize = get("s") + "px"
let theme = get("t")
if (theme !== null) document.documentElement.classList.add(theme === "1" ? "light" : "dark")
let url = get("u")
getArticle(url).then(article => {
    let domParser = new DOMParser()
    let dom = domParser.parseFromString(get("h"), "text/html")
    dom.getElementsByTagName("article")[0].innerHTML = article
    let baseUrl = url.split("/").slice(0, 3).join("/")
    for (let s of dom.getElementsByTagName("script")) {
        s.parentNode.removeChild(s)
    }
    for (let e of dom.querySelectorAll("*[src]")) {
        if (e.src && !e.src.startsWith("http")) {
            if (e.src.startsWith("/")) {
                e.src = baseUrl + e.src
            } else if (e.src.startsWith(":")) {
                e.src = "http" + e.src
            } else {
                e.src = baseUrl + "/" + e.src
            }
        }
    }
    for (let e of dom.querySelectorAll("*[href]")) {
        if (e.href && !e.href.startsWith("http")) {
            if (e.href.startsWith("/")) {
                e.href = baseUrl + e.href
            } else if (e.href.startsWith(":")) {
                e.href = "http" + e.href
            } else {
                e.href = baseUrl + "/" + e.href
            }
        }
    }
    let main = document.getElementById("main")
    main.innerHTML = dom.body.innerHTML
    main.classList.add("show")
})

