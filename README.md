The goal of this project is decoding various UI formats used by Total War games.

Existing decoder for a few formats is at https://github.com/taw/etwng/tree/master/ui_converter but it doesn't support newer games,
and even for games it supports (Empire, Napoleon, Shogun 2) it's not prfect.

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

Every `VersionXXX` file from Empile, Napoleon, Shogun 2 should work.

All `.cml` and `.fc` files from all games work (they're not really UI files, but they're in same folders and use `VersionXXX` system, so I included them too).

Support for newer games coming soon, hopefully.

There's no guarantee that XML format will remain stable. I might need to tweak it a bit.

### Files

* `data` - sample files from various games
* `converted` - `.xml` files created by old converter based on files in `data`, or `.fail` files in converter crashed (nothing if unsupported)
* `output` - current output of analysis of files in `data`
* `lib` - code
* `bin` - scripts

### Games

Games currently in repository:

* Empire
* Napoleon
* Shogun 2
* Rome 2
* Attila
* Warhammer 1
* Warhammer 2
* Thrones
* Troy
* 3 Kingdoms

Games currently missing:

* Warhammer 3

### Supported level by game

Empire: 199/205 (97%)
Napoleon: 199/201 (99%)
Shogun 2: 284/285 (100%)
Rome 2: 282/306 (92%)
Attila: 178/190 (94%)
Thrones of Britannia: 186/205 (91%)
Warhammer 1: 169/271 (62%)
Warhammer 2: 87/349 (25%)
Troy: 53/395 (13%)
Three Kingdoms: 10/433 (2%)

### Credits

Software written by taw (Tomasz Wegrzanowski).

Special thanks to alpaca for the original research for Napoleon and the original UI converter, and to Cpecific for research on Rome 2+ games.
