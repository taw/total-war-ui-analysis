The goal of this project is decoding various UI formats used by Total War games.

Existing decoder for a few formats is at https://github.com/taw/etwng/tree/master/ui_converter but it doesn't support newer games, and even for games it supports (Empire, Napoleon, Shogun 2) it's not perfect.

### How to use

You'll need `jruby` and `nokogiri` installed. (or regular `ruby` and `nokogiri`).

Then you can run the converter as:

```
jruby bin/ui2xml path/to/uifile path/to/file.xml
```

And:

```
jruby bin/xml2ui path/to/file.xml path/to/uifile
```

Most `VersionXXX` files work now, details by game below.

The converter also supports all `.cml` and `.fc` files. They're a separate format, but they also have `VersionXXX` header and they live just next to UI files, so I added that too.

There's no guarantee that XML format will remain stable. I might need to tweak it a bit.

### Supported level by game

Checked on every `Version033` from every game I could find. Percentage converting to xml and back perfectly by game:

* Empire: 199/205 (97%)
* Napoleon: 199/201 (99%)
* Shogun 2: 284/285 (100%)
* Rome 2: 283/306 (92%)
* Attila: 180/190 (95%)
* Thrones of Britannia: 189/205 (92%)
* Warhammer 1: 263/271 (97%)
* Warhammer 2: 342/349 (98%)
* Troy: 387/395 (98%)
* Three Kingdoms: 431/433 (100%)

* Total: 2757/2840 (97%)

### Files

* `data` - sample files from various games
* `unpacked` - `.xml` files created by the new converter (or `.fail` files if conversion failed)
* `converted` - `.xml` files created by the old converter (or `.fail` files if conversion failed)
* `output` - automated analysis results for all files from `data`
* `lib` - code
* `bin` - scripts

### Credits

Software written by taw (Tomasz Wegrzanowski).

Special thanks to alpaca for the original research for Napoleon and the original UI converter, and to Cpecific for research on Rome 2+ games.
