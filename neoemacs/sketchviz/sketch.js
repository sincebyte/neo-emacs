#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const rough = require('roughjs');
const jsdom = require('jsdom');

const FONTS = fs.readFileSync(path.resolve(__dirname, 'font.css'));

/*
 * This file is almost entirely ripped off https://sketchviz.com.
 * Credit where credit is due, please go support them !
 */

var coarse = (function () {
    function getAttributes(element) {
        return Array.prototype.slice.call(element.attributes);
    }

    function getNum(element, attributes) {
        return attributes.map(function (attr) { return parseFloat(element.getAttribute(attr), 10) });
    }

    function getDiam(element, attributes) {
        return attributes.map(function (attr) { return 2 * parseFloat(element.getAttribute(attr), 10) });
    }

    function getCoords(element, attribute) {
        return element
            .getAttribute(attribute)
            .trim()
            .split(' ')
            .filter(function (item) { return item.length > 0 })
            .map(function (item) { return item.trim().split(',').map(function (num) { return parseFloat(num, 10); }) });
    }

    function getSettings(element) {
        var settings = {};

        if (element.hasAttribute('stroke')) {
            settings.stroke = element.getAttribute('stroke');
        }

        if (element.hasAttribute('fill')) {
            settings.fill = element.getAttribute('fill');
        }

        if (element.hasAttribute('stroke-width') && !element.getAttribute('stroke-width').includes('%')) {
            settings.strokeWidth = parseFloat(element.getAttribute('stroke-width', 10));
        }

        return settings;
    }

    return function coarse(svg, options) {
        var blacklist = [
            'cx',
            'cy',
            'd',
            'fill',
            'height',
            'points',
            'r',
            'rx',
            'ry',
            'stroke-width',
            'stroke',
            'width',
            'x',
            'x1',
            'x2',
            'y',
            'y1',
            'y2'
        ];

        function flatten() {
            var rv = [];
            for (var i = 0; i < arguments.length; i++) {
                var arr = arguments[i];
                for (var j = 0; j < arr.length; j++) {
                    rv.push(arr[j]);
                }
            }
            return rv;
        }

        var rc = rough.svg(svg, options || {});

        var children = svg.querySelectorAll('circle, rect, ellipse, line, polygon, polyline, path');

        for (var i = 0; i < children.length; i += 1) {
            var original = children[i];
            var params = [];
            var shapeType;

            switch (original.tagName) {
                case 'circle':
                    params = flatten(getNum(original, ['cx', 'cy']), getDiam(original, ['r']));
                    shapeType = 'circle';
                    break;
                case 'rect':
                    params = flatten(getNum(original, ['x', 'y', 'width', 'height']));
                    shapeType = 'rectangle';
                    break;
                case 'ellipse':
                    params = flatten(getNum(original, ['cx', 'cy']), getDiam(original, ['rx', 'ry']));
                    shapeType = 'ellipse';
                    break;
                case 'line':
                    params = flatten(getNum(original, ['x1', 'y1', 'x2', 'y2']));
                    shapeType = 'line';
                    break;
                case 'polygon':
                    params = [getCoords(original, 'points')];
                    shapeType = 'polygon';
                    break;
                case 'polyline':
                    params = [getCoords(original, 'points')];
                    shapeType = 'linearPath';
                    break;
                case 'path':
                    params = [original.getAttribute('d')];
                    shapeType = 'path';
                    break;
            }

            var replacement = rc[shapeType](...params, getSettings(original));

            var attributes = getAttributes(original).filter(function (attribute) {
                return !blacklist.includes(attribute.name)
            });

            for (var j = 0; j < attributes.length; j++) {
                replacement.setAttribute(attributes[j].name, attributes[j].value);
            }

            original.replaceWith(replacement);
        }
    }
})();

function preprocess(data) {
    /*
     * Pre-process the data.
     */
    data = data.replace(/(<svg(?:[^>]|\n)*>)/, '$1' + FONTS);
    // Use the open source Tinos font, not Times, so that we can get
    // reproducible renders on different OSes.
    data = data.replace(/font-family="Times,serif"/g, 'font-family="Tinos,serif"');

    // Auto-bold: Replace any <text ...>*xxxx*</text> with
    // <text font-family="Sedgwick Ave" ...>*xxxx*</text>
    data = data.replace(
        /<text ([^>]+) font-family="[^"]+" ([^>]+)>\*([^<]+)\*<\/text>/g,
        '<text $1 font-family="Sedgwick Ave" $2>$3</text>'
    );
    return data;
}

function sketchy(data) {
    /*
     * Sketchify a svg
     */
    const dom = new jsdom.JSDOM(data);
    var parsed = dom.window.document.querySelector('svg');
    coarse(parsed);
    return parsed.outerHTML;
}

function main() {
    if (process.argv.length != 4) {
        console.log("Usage: node sketch.js <input.dot> <output.svg>");
        process.exit(1);
    }
    var args = process.argv.slice(2);
    const { spawn } = require('child_process');
    function run(input, output) {
        const dot = spawn('dot', ['-Tsvg', input]);

        dot.stderr.on('data', (data) => {
            console.log(data.toString().split("\n").filter(x => x).map(x => "dot> " + x).join("\n"));
        });
        let buffer = "";
        dot.stdout.on('data', (data) => {
            buffer += data.toString();
        });
        dot.on('close', () => {
            let result = preprocess(buffer.toString());
            fs.writeFile(output, sketchy(result), function (err) {
                if (err) {
                    console.log(err);
                    process.exit(1);
                }
                console.log("Written as '" + output + "'.");
                process.exit(0);
            });
        });
        fs.readFile(input, {}, function (err, data) {
            if (err) {
                console.log(err);
                process.exit(1);
            }
            dot.stdin.write(data.toString());
            dot.stdin.end();
        });
    }

    run(args[0], args[1]);
    console.log("Now watching '" + args[0] + "' !");
    fs.watch(args[0], (event, filename) => {
        if (filename) {
            console.log("File changed! Computing...");
            run(args[0], args[1]);
        }
    });
}

main();
