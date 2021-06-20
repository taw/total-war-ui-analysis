The goal of this project is decoding various UI formats used by Total War games.

Existing decoder for a few formats is at https://github.com/taw/etwng/tree/master/ui_converter but it doesn't support newer games,
and even for games it supports (Empire, Napoleon, Shogun 2) it's not prfect.

### Data structures (incomplete list):

* `Version` block - always starts the file:

* * ASCII `Version`
* * 3 ASCII numbers

* `String` block:

* * uint16 size (can be zero for empty string)
* * that many ASCII bytes

* `Unicode` block:

* * uint16 size (can be zero for empty string)
* * that many UTF-16-LE codepoints

* `EventList` block

* * zero or more `String` blocks
* * one `String` block with value `events_end`

* `Image` block:

* * uint32 ID
* * `String` block path
* * uint32 xsize
* * uint32 ysize
* * uint32 unknown

* `ImageList` block:

* * uint32 count
* * that many `Image` blocks

* `ImagePathList` block:
* * uint32 count
* * that many `String` blocks with image paths

### Files

* `data` - sample files from various games
* `converted` - `.xml` files created by old converter based on files in `data`, or `.fail` files in converter crashed (nothing if unsupported)
* `output` - current output of analysis of files in `data`
* `lib` - code
* `bin` - scripts

### Format - Version002

This format is a bit fake, as these are `.cml` files just being in same folder and with similar-looking headers, but otherwise unrelated, and appeared long after real UI file formats (Rome 2+).

Format is:

* `Version002` header
* any number of (until EOF):
* * `String` key
* * `String` value

### Games

Games currently in repository:

* Empire
* Napoleon
* Shogun 2
* Rome 2
* Warhammer 1
* Warhammer 2
* 3 Kingdoms

Games currently missing:

* Attila
* Thrones
* Troy
* Warhammer 3
