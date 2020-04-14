package highlighter;

import haxe.extern.EitherType;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.Path;
import haxe.xml.Parser.XmlParserException;
import highlighter.VscodeTextmate;
import js.html.DOMParser;
import js.html.Element;
import js.html.HTMLDocument;
import js.html.Node;
import js.html.NodeList;
import sys.FileSystem;
import sys.io.File;

using StringTools;

class Highlighter {
	static final jsdom:Dynamic = {
		var jsdom = js.Lib.require("jsdom").JSDOM;
		var j = js.Syntax.construct(jsdom);
		j;
	};
	static final DOMParser:DOMParser = js.Syntax.construct(jsdom.window.DOMParser);

	public static function main() {
		var folder = Sys.args()[0];
		patchFolder(folder, [
			"haxe" => new Highlighter("grammars/haxe/haxe.tmLanguage", "dark"),
			"xml" => new Highlighter("grammars/xml/Syntaxes/XML.plist", "dark")
		], function(cls) {
			return switch cls {
				case "haxe": "haxe";
				case "xml": "xml";
				case _: "none";
			}
		});
		// new Highlighter(grammar, "dark").runCss();
	}

	var registry:Registry;
	var grammar:IGrammar;
	var theme:Theme.ThemeData;

	/**
		Create a highlighter.

		@param grammar The path to the grammar file.
		@param theme The path to the theme.
	**/
	public function new(grammar:String, theme:String = "light") {
		this.registry = new Registry();

		if (grammar != "") {
			this.grammar = registry.loadGrammarFromPathSync(grammar);
		}

		this.theme = Theme.load(theme);
		this.registry.setTheme({name: this.theme.name, settings: this.theme.tokenColors});
	}

	/**
		Get the CSS for the theme.
	**/
	public function runCss() {
		trace(CSS.generateStyle(registry));
	}

	/**
		Run the highlighter on the stdin.
	**/
	public function runStdin():String {
		var input = new BytesInput(Bytes.ofString(NodeUtils.readAllStdin()));
		return Code.generateHighlighted(grammar, input);
	}

	/**
		Run the highlighter on some content.

		@param content The content to highlight.
	**/
	public function runContent(content:String):String {
		var input = new BytesInput(Bytes.ofString(content));
		return Code.generateHighlighted(grammar, input);
	}

	/**
		Run the highlighter on some file.

		@param content The content to highlight.
	**/
	public function runFile(path:String):String {
		var input = File.read(path, false);
		return Code.generateHighlighted(grammar, input);
	}

	/**
		Patch the code blocks of a HTML file.

		@param path The path of the file to patch.
		@param grammars The available grammars.
		@param getLang A function used to go from css class list to grammar name.
	**/
	public static function patchFile(path:String, grammars:Map<String, Highlighter>, getLang:String->String):Array<String> {
		try {
			var document = DOMParser.parseFromString(File.getContent(path), TEXT_HTML);
			var missing = new Map<String, Bool>();

			processNode(grammars, getLang, document, missing);

			var serializer = js.Syntax.construct(jsdom.window.XMLSerializer);
			var result = serializer.serializeToString(document);
			// var result = ~/&amp;([a-z]+;)/g.replace(document.conte, "&$1");
			File.saveContent(path, result);

			var a = [];
			for (k in missing.keys()) {
				if (k != "") {
					a.push(k);
				}
			}
			return a;
		} catch (e:Dynamic) {
			if (Std.is(e, XmlParserException)) {
				var e = cast(e, XmlParserException);
				Sys.println('${e.message} at line ${e.lineNumber} char ${e.positionAtLine}');
				Sys.println(e.xml.substr(e.position - 20, 40));
			} else {
				Sys.println(e);
			}

			Sys.println(haxe.CallStack.toString(haxe.CallStack.exceptionStack()));
			throw('Error when parsing "$path"');
		}
	}

	/**
		Patch the code blocks of HTML files in a directory.

		@param path The path of the directory to patch.
		@param grammars The available grammars.
		@param getLang A function used to go from css class list to grammar name.
		@param recursive If the patching should enter the subdirectories.
	**/
	public static function patchFolder(path:String, grammars:Map<String, Highlighter>, getLang:String->String, recursive:Bool = true):Array<String> {
		var missing = new Map<String, Bool>();

		for (entry in FileSystem.readDirectory(path)) {
			var entry_path = Path.join([path, entry]);

			if (FileSystem.isDirectory(entry_path)) {
				if (recursive) {
					var folder_missing = patchFolder(entry_path, grammars, getLang, true);

					for (k in folder_missing) {
						missing.set(k, true);
					}
				}
			} else if (Path.extension(entry_path) == "html") {
				var file_missing = patchFile(entry_path, grammars, getLang);

				for (k in file_missing) {
					missing.set(k, true);
				}
			}
		}

		var a = [];
		for (k in missing.keys()) {
			if (k != "") {
				a.push(k);
			}
		}
		return a;
	}

	static function processNode(grammars:Map<String, Highlighter>, getLang:String->String, document:EitherType<Node, HTMLDocument>,
			missingGrammars:Map<String, Bool>) {
		if (Std.is(document, jsdom.window.Node)) {
			var node:Node = cast document;
			switch (node.nodeName.toLowerCase()) {
				case "pre":
					var code = node.firstChild;

					if (code == null || code.nodeType != Node.ELEMENT_NODE) {
						return;
					}

					var code:Element = cast code;
					var lang = code.hasAttribute("class") ? getLang(code.getAttribute("class")) : "";

					if (grammars.exists(lang)) {
						var original = code.firstChild.textContent.htmlUnescape();
						var highlighted = grammars.get(lang).runContent(original);
						var newNode = DOMParser.parseFromString(highlighted, TEXT_XML).firstChild;
						node.parentNode.replaceChild(newNode, node);
					} else {
						missingGrammars.set(lang, true);
					}

				default:
					processChildren(grammars, getLang, node.childNodes, missingGrammars);
			}
		} else {
			var document:HTMLDocument = cast document;
			processChildren(grammars, getLang, document.childNodes, missingGrammars);
		}
	}

	static function processChildren(grammars:Map<String, Highlighter>, getLang:String->String, nodeList:NodeList, missingGrammars:Map<String, Bool>) {
		for (node in nodeList) {
			processNode(grammars, getLang, node, missingGrammars);
		}
	}
}
