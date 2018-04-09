# Highlighter

Tool used to highlight text according to a textmate tmLanguage file.

Output CSS and HTML code.

The built-in themes are from [VSCode](https://github.com/Microsoft/vscode).

## Compilation

Get the required dependencies with:
```
npm install
haxelib install build.hxml
```

Then compile with:
```
haxe build.hxml
```

## Usage as a tool

### Get CSS

This will output the css styling necessary to display the highlighted content.

```
node bin/highlighter.js css [--theme=light|dark|/path/to/file]
```

By default the light theme is used.

### Highlight a file

This will apply syntax highlighting to the whole file and output the result on the console.

```
node bin/highlighter.js highlight --grammar=/path/to/file --input=stdin|file [--file=/path/to/file] [--theme=light|dark|/path/to/file]
```

By default the light theme is used.
If you use `--input=file` you need to specify the `--file` argument.

## Usage as a lib

You need to target nodejs, add `-lib highlighter` to your command.

First create a highlighter:
```haxe
var h = new highlighter.Highlighter("grammar/someGrammar.tmLanguage");
```

Then you can use it to highlight:
```haxe
var s = h.runContent("class C { }"); // Highlight a string

var s = h.runFile("test/some.file"); // Highlight a file

var s = h.runStdin(); // Highlight the content of stdin, if you pipe a file
```

To get the css rules for the style you are using:
```haxe
var s = h.runCss();
```

## License

[MIT](LICENSE.md)
