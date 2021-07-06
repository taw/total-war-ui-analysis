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
* Rome 2: 282/306 (92%)
* Attila: 178/190 (94%)
* Thrones of Britannia: 186/205 (91%)
* Warhammer 1: 258/271 (95%)
* Warhammer 2: 298/349 (85%)
* Troy: 357/395 (90%)
* Three Kingdoms: 19/433 (4%)

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
