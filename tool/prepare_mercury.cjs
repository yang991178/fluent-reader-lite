const fs = require('node:fs')

function prepareMercury(bundle) {
    // Safari before 16.4 cannot construct lookbehind expressions. The parser
    // only uses captures 1 and 2, so a non-capturing prefix keeps date parsing
    // and the upstream protection against quadratic scans of digit runs.
    const original = String.raw`(?<!\\d)(\\d+)\\s+`
    const compatible = String.raw`(?:^|\\D)(\\d+)\\s+`
    if (bundle.split(original).length !== 2) {
        throw new Error('Expected exactly one Mercury relative-date expression')
    }
    return bundle.replace(original, compatible)
}

if (require.main === module) {
    fs.writeFileSync(process.argv[3], prepareMercury(fs.readFileSync(process.argv[2], 'utf8')))
}

module.exports = { prepareMercury }
