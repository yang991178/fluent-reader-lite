const assert = require('node:assert/strict')
const fs = require('node:fs')
const test = require('node:test')
const vm = require('node:vm')
const { prepareMercury } = require('../tool/prepare_mercury.cjs')

const units = 'seconds?|minutes?|hours?|days?|weeks?|months?|years?'
const expression = String.raw`new RegExp(` + '`' + String.raw`(?<!\\d)(\\d+)\\s+(${units})\\s+ago` + '`' + ', "i")'

test('Relative dates keep the same numeric and time-unit captures', () => {
    const original = vm.runInNewContext(expression)
    const compatible = vm.runInNewContext(prepareMercury(expression))
    for (const input of ['12 hours ago', 'Updated 300 days ago', '1 minute ago', 'x5 weeks ago', '123 minutes later', 'not a date', '0 seconds ago']) {
        const before = original.exec(input)
        const after = compatible.exec(input)
        assert.deepEqual(before && Array.from(before).slice(1), after && Array.from(after).slice(1), input)
    }
    assert.equal(compatible.test('9'.repeat(100000)), false)
})

test('Refresh aborts when the upstream expression changes or is duplicated', () => {
    assert.throws(() => prepareMercury('changed upstream'), /exactly one/)
    assert.throws(() => prepareMercury(expression + expression), /exactly one/)
})

test('Vendored parser loads without lookbehind support and parses relative dates', async () => {
    const LegacyRegExp = new Proxy(RegExp, {
        construct(target, args) {
            if (String(args[0]).includes('(?<')) throw new SyntaxError('Lookbehind unsupported')
            return Reflect.construct(target, args)
        },
        apply(target, receiver, args) {
            if (String(args[0]).includes('(?<')) throw new SyntaxError('Lookbehind unsupported')
            return Reflect.apply(target, receiver, args)
        },
    })
    const bundle = fs.readFileSync('assets/article/mercury.web.js', 'utf8')
    assert.equal(bundle.includes('(?<!'), false)
    assert.equal(bundle.includes('(?<='), false)
    const context = vm.createContext({ RegExp: LegacyRegExp, URL, setTimeout, clearTimeout, XMLHttpRequest: class {} })
    try {
        vm.runInContext(bundle, context, { displayErrors: false })
    } catch (error) {
        throw new Error(`Parser initialization failed: ${error.message}`)
    }
    const result = await context.Mercury.parse('https://example.com/story', {
        html: '<html><head><title>Story</title></head><body><time datetime="12 hours ago"></time><article><p>' + 'A full paragraph with content. '.repeat(20) + '</p></article></body></html>',
        fetchAllPages: false,
        customExtractor: {
            domain: 'example.com',
            title: { selectors: ['title'] },
            content: { selectors: ['article'] },
            date_published: { selectors: [['time', 'datetime']] },
        },
    })
    assert.ok(result.content.includes('A full paragraph'))
    const expected = Date.now() - 12 * 60 * 60 * 1000
    assert.ok(Math.abs(Date.parse(result.date_published) - expected) < 5000)
})
